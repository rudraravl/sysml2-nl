// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract CapitalAllocationVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_RESERVE_BPS = 1000;
    uint256 public constant MAX_MOVEMENT_BPS = 5000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error VaultNotConfigured();
    error VaultInactive();
    error IntegrationNotPermitted(address integration);
    error ActionNotPermitted(bytes4 actionId);
    error CapitalFlowNotAllowed(address token);
    error InsufficientUserShares();
    error InsufficientVaultBalance();
    error InsufficientNonReserveCapital();
    error InsufficientReserveCapital();
    error ReserveRequirementBreach();
    error ExceedsMaxMovement();
    error ReserveRatioInvalid();
    error MovementRatioInvalid();
    error IntegrationAlreadyExists(address integration);
    error IntegrationNotFound(address integration);
    error ActionAlreadyExists(bytes4 actionId);
    error ActionNotFound(bytes4 actionId);
    error InsufficientSharesMinted();

    struct VaultConfig {
        bool active;
        address reservePool;
        uint256 reserveRatioBps;
        uint256 maxMovementBps;
        uint256 totalCapital;
        uint256 reserveCapital;
        uint256 nonReserveCapital;
        uint256 totalShares;
    }

    struct CapitalMovement {
        address integration;
        bytes4 actionId;
        uint256 amount;
        uint256 timestamp;
    }

    struct IntegrationInfo {
        bool permitted;
        uint256 index;
    }

    struct ActionInfo {
        bool permitted;
        uint256 index;
    }

    address public operator;

    mapping(address => VaultConfig) public vaults;
    mapping(address => mapping(address => IntegrationInfo)) internal _integrations;
    mapping(address => address[]) internal _integrationList;
    mapping(address => mapping(bytes4 => ActionInfo)) internal _actions;
    mapping(address => bytes4[]) internal _actionList;
    mapping(address => mapping(address => bool)) public capitalFlowRules;
    mapping(address => mapping(address => uint256)) public userShares;
    mapping(address => mapping(address => CapitalMovement[])) internal _movementHistory;

    event VaultConfigured(
        address indexed token,
        bool active,
        address reservePool,
        uint256 reserveRatioBps,
        uint256 maxMovementBps
    );
    event VaultConfigUpdated(
        address indexed token,
        bool active,
        address reservePool,
        uint256 reserveRatioBps,
        uint256 maxMovementBps
    );
    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 sharesMinted, uint256 totalCapital);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 sharesBurned, uint256 totalCapital);
    event CapitalMoved(
        address indexed token,
        address indexed integration,
        bytes4 indexed actionId,
        uint256 amount,
        uint256 timestamp
    );
    event IntegrationAdded(address indexed token, address indexed integration);
    event IntegrationRemoved(address indexed token, address indexed integration);
    event ActionAuthorized(address indexed token, bytes4 indexed actionId);
    event ActionRevoked(address indexed token, bytes4 indexed actionId);
    event CapitalFlowRuleSet(address indexed token, address indexed flowToken, bool allowed);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier vaultActive(address token) {
        if (!vaults[token].active) revert VaultInactive();
        _;
    }

    modifier vaultConfigured(address token) {
        VaultConfig storage v = vaults[token];
        if (v.reservePool == address(0) && !v.active && v.totalCapital == 0) revert VaultNotConfigured();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function configureVault(
        address token,
        address reservePool,
        uint256 reserveRatioBps,
        uint256 maxMovementBps
    ) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (reservePool == address(0)) revert ZeroAddress();
        if (reserveRatioBps < MIN_RESERVE_BPS || reserveRatioBps > BPS_DENOMINATOR) revert ReserveRatioInvalid();
        if (maxMovementBps == 0 || maxMovementBps > MAX_MOVEMENT_BPS) revert MovementRatioInvalid();

        VaultConfig storage v = vaults[token];
        bool isNew = (v.reservePool == address(0) && !v.active);

        v.active = true;
        v.reservePool = reservePool;
        v.reserveRatioBps = reserveRatioBps;
        v.maxMovementBps = maxMovementBps;

        if (isNew) {
            emit VaultConfigured(token, true, reservePool, reserveRatioBps, maxMovementBps);
        } else {
            emit VaultConfigUpdated(token, true, reservePool, reserveRatioBps, maxMovementBps);
        }
    }

    function updateVaultConfig(
        address token,
        bool active,
        address reservePool,
        uint256 reserveRatioBps,
        uint256 maxMovementBps
    ) external onlyOperator vaultConfigured(token) {
        VaultConfig storage v = vaults[token];

        if (reservePool != address(0)) {
            v.reservePool = reservePool;
        }
        if (reserveRatioBps != 0) {
            if (reserveRatioBps < MIN_RESERVE_BPS || reserveRatioBps > BPS_DENOMINATOR) revert ReserveRatioInvalid();
            v.reserveRatioBps = reserveRatioBps;
        }
        if (maxMovementBps != 0) {
            if (maxMovementBps > MAX_MOVEMENT_BPS) revert MovementRatioInvalid();
            v.maxMovementBps = maxMovementBps;
        }
        v.active = active;

        emit VaultConfigUpdated(token, active, v.reservePool, v.reserveRatioBps, v.maxMovementBps);
    }

    function addIntegration(address token, address integration) external onlyOperator {
        if (integration == address(0)) revert ZeroAddress();
        if (_integrations[token][integration].permitted) revert IntegrationAlreadyExists(integration);

        _integrationList[token].push(integration);
        _integrations[token][integration] = IntegrationInfo({
            permitted: true,
            index: _integrationList[token].length
        });

        emit IntegrationAdded(token, integration);
    }

    function removeIntegration(address token, address integration) external onlyOperator {
        IntegrationInfo storage info = _integrations[token][integration];
        if (!info.permitted) revert IntegrationNotFound(integration);

        uint256 idx = info.index - 1;
        uint256 lastIdx = _integrationList[token].length - 1;

        if (idx != lastIdx) {
            address lastIntegration = _integrationList[token][lastIdx];
            _integrationList[token][idx] = lastIntegration;
            _integrations[token][lastIntegration].index = idx + 1;
        }
        _integrationList[token].pop();

        info.permitted = false;
        info.index = 0;

        emit IntegrationRemoved(token, integration);
    }

    function authorizeAction(address token, bytes4 actionId) external onlyOperator {
        if (_actions[token][actionId].permitted) revert ActionAlreadyExists(actionId);

        _actionList[token].push(actionId);
        _actions[token][actionId] = ActionInfo({
            permitted: true,
            index: _actionList[token].length
        });

        emit ActionAuthorized(token, actionId);
    }

    function revokeAction(address token, bytes4 actionId) external onlyOperator {
        ActionInfo storage info = _actions[token][actionId];
        if (!info.permitted) revert ActionNotFound(actionId);

        uint256 idx = info.index - 1;
        uint256 lastIdx = _actionList[token].length - 1;

        if (idx != lastIdx) {
            bytes4 lastAction = _actionList[token][lastIdx];
            _actionList[token][idx] = lastAction;
            _actions[token][lastAction].index = idx + 1;
        }
        _actionList[token].pop();

        info.permitted = false;
        info.index = 0;

        emit ActionRevoked(token, actionId);
    }

    function setCapitalFlowRule(address token, address flowToken, bool allowed) external onlyOperator {
        if (flowToken == address(0)) revert ZeroAddress();
        capitalFlowRules[token][flowToken] = allowed;
        emit CapitalFlowRuleSet(token, flowToken, allowed);
    }

    function deposit(address token, uint256 amount) external vaultActive(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();

        VaultConfig storage v = vaults[token];

        // Calculate shares to mint before any external interaction (checks-effects-interactions)
        uint256 sharesToMint;
        if (v.totalShares == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * v.totalShares) / v.totalCapital;
        }
        if (sharesToMint < 1) revert InsufficientSharesMinted();

        // Update all state before the external token transfer
        userShares[token][msg.sender] += sharesToMint;
        v.totalShares += sharesToMint;
        v.totalCapital += amount;
        v.reserveCapital += amount;

        // External interaction last; SafeERC20 reverts on failure, rolling back state
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount, sharesToMint, v.totalCapital);
    }

    function withdraw(address token, uint256 sharesToBurn) external vaultActive(token) nonReentrant {
        if (sharesToBurn == 0) revert ZeroAmount();

        VaultConfig storage v = vaults[token];
        uint256 userShare = userShares[token][msg.sender];
        if (userShare < sharesToBurn) revert InsufficientUserShares();

        uint256 amount = (sharesToBurn * v.totalCapital) / v.totalShares;
        if (amount < 1) revert ZeroAmount();

        uint256 fromNonReserve = amount <= v.nonReserveCapital ? amount : v.nonReserveCapital;
        uint256 fromReserve = amount - fromNonReserve;

        uint256 newTotal = v.totalCapital - amount;
        uint256 newReserve = v.reserveCapital - fromReserve;

        if (newTotal > 0 && newReserve * BPS_DENOMINATOR < newTotal * v.reserveRatioBps) {
            revert ReserveRequirementBreach();
        }

        // Update state before external transfer (checks-effects-interactions)
        userShares[token][msg.sender] = userShare - sharesToBurn;
        v.totalShares -= sharesToBurn;
        v.totalCapital = newTotal;
        v.nonReserveCapital -= fromNonReserve;
        v.reserveCapital = newReserve;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, token, amount, sharesToBurn, v.totalCapital);
    }

    function initiateCapitalMovement(
        address token,
        address integration,
        bytes4 actionId,
        uint256 amount
    ) external onlyOperator vaultActive(token) nonReentrant {
        if (!_integrations[token][integration].permitted) revert IntegrationNotPermitted(integration);
        if (!_actions[token][actionId].permitted) revert ActionNotPermitted(actionId);
        if (!capitalFlowRules[token][token]) revert CapitalFlowNotAllowed(token);
        if (amount == 0) revert ZeroAmount();

        VaultConfig storage v = vaults[token];
        if (amount > v.nonReserveCapital) revert InsufficientNonReserveCapital();

        uint256 movementCap = (v.nonReserveCapital * v.maxMovementBps) / BPS_DENOMINATOR;
        if (amount > movementCap) revert ExceedsMaxMovement();

        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientVaultBalance();

        // Update state before external transfer (checks-effects-interactions)
        v.nonReserveCapital -= amount;
        v.totalCapital -= amount;

        IERC20(token).safeTransfer(integration, amount);

        _movementHistory[token][integration].push(
            CapitalMovement({
                integration: integration,
                actionId: actionId,
                amount: amount,
                timestamp: block.timestamp
            })
        );

        emit CapitalMoved(token, integration, actionId, amount, block.timestamp);
    }

    function allocateFromReserve(address token, uint256 amount) external onlyOperator vaultActive(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        VaultConfig storage v = vaults[token];
        if (amount > v.reserveCapital) revert InsufficientReserveCapital();

        v.reserveCapital -= amount;
        v.nonReserveCapital += amount;

        if (v.totalCapital > 0 && v.reserveCapital * BPS_DENOMINATOR < v.totalCapital * v.reserveRatioBps) {
            revert ReserveRequirementBreach();
        }

        emit CapitalMoved(token, v.reservePool, bytes4(uint32(0x414C4C43)), amount, block.timestamp);
    }

    function returnToReserve(address token, uint256 amount) external onlyOperator vaultActive(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        VaultConfig storage v = vaults[token];
        if (amount > v.nonReserveCapital) revert InsufficientNonReserveCapital();

        v.nonReserveCapital -= amount;
        v.reserveCapital += amount;

        emit CapitalMoved(token, address(this), bytes4(uint32(0x52455452)), amount, block.timestamp);
    }

    function getVaultConfig(address token) external view returns (VaultConfig memory) {
        return vaults[token];
    }

    function isIntegrationPermitted(address token, address integration) external view returns (bool) {
        return _integrations[token][integration].permitted;
    }

    function isActionPermitted(address token, bytes4 actionId) external view returns (bool) {
        return _actions[token][actionId].permitted;
    }

    function getIntegrations(address token) external view returns (address[] memory) {
        return _integrationList[token];
    }

    function getActions(address token) external view returns (bytes4[] memory) {
        return _actionList[token];
    }

    function getMovementCount(address token, address integration) external view returns (uint256) {
        return _movementHistory[token][integration].length;
    }

    function getMovement(address token, address integration, uint256 index) external view returns (CapitalMovement memory) {
        return _movementHistory[token][integration][index];
    }

    function getUserShares(address token, address user) external view returns (uint256) {
        return userShares[token][user];
    }

    function getVaultTotalCapital(address token) external view returns (uint256) {
        return vaults[token].totalCapital;
    }

    function getVaultReserveCapital(address token) external view returns (uint256) {
        return vaults[token].reserveCapital;
    }

    function getVaultNonReserveCapital(address token) external view returns (uint256) {
        return vaults[token].nonReserveCapital;
    }
}
