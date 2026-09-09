// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
        return returndata;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract AccessControl {
    using Address for address;

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function grantRole(bytes32 role, address account) public virtual {
        require(hasRole(getRoleAdmin(role), msg.sender), "AccessControl: sender must be admin to grant role");
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual {
        require(hasRole(getRoleAdmin(role), msg.sender), "AccessControl: sender must be admin to revoke role");
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public virtual {
        require(account == msg.sender, "AccessControl: can only renounce roles for self");
        _revokeRole(role, account);
    }

    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!_roles[role].members[account]) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members[account]) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 adminRole = _roles[role].adminRole;
        return adminRole == bytes32(0) ? DEFAULT_ADMIN_ROLE : adminRole;
    }
}

contract StrategyVault is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    uint256 public constant MAX_FEE_BPS = 50;
    uint256 public constant TIMELOCK = 48 hours;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct StrategyConfig {
        address strategy;
        address proposer;
        uint256 approvalTime;
        uint256 activationTime;
        bool approved;
        bool rejected;
        bool active;
        string metadata;
    }

    struct TokenVault {
        uint256 totalDeposited;
        bool supported;
    }

    uint256 public withdrawalFeeBps;
    address public activeStrategy;
    uint256 public totalShares;
    uint256 public totalValueLocked;

    mapping(address => uint256) public userShares;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => TokenVault) public tokenVaults;
    mapping(address => StrategyConfig) public proposedStrategies;
    address[] public supportedTokensList;

    address public feeRecipient;

    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 shares, uint256 fee);
    event StrategyProposed(address indexed strategy, address indexed proposer, string metadata);
    event StrategyApproved(address indexed strategy, uint256 approvalTime);
    event StrategyRejected(address indexed strategy);
    event StrategyActivated(address indexed strategy, uint256 activationTime);
    event StrategyDeactivated(address indexed strategy);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event TokenSupported(address indexed token, bool supported);

    error TokenNotSupported();
    error InsufficientShares();
    error ZeroAmount();
    error NotGovernance();
    error StrategyAlreadyProposed();
    error StrategyNotProposed();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error StrategyRejectedAlready();
    error TimelockNotElapsed();
    error StrategyAlreadyActive();
    error NoActiveStrategy();
    error FeeExceedsCap();
    error InvalidAddress();
    error InvalidFeeRecipient();
    error InvalidShares();
    error InsufficientVaultBalance();

    modifier onlyGovernance() {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) revert NotGovernance();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!tokenVaults[token].supported) revert TokenNotSupported();
        _;
    }

    constructor(address admin, address _feeRecipient) {
        if (admin == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(GOVERNANCE_ROLE, admin);

        feeRecipient = _feeRecipient;
        withdrawalFeeBps = 0;
    }

    function setTokenSupport(address token, bool supported) external onlyGovernance {
        if (token == address(0)) revert InvalidAddress();
        tokenVaults[token].supported = supported;
        if (supported) {
            bool found = false;
            for (uint256 i = 0; i < supportedTokensList.length; i++) {
                if (supportedTokensList[i] == token) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                supportedTokensList.push(token);
            }
        }
        emit TokenSupported(token, supported);
    }

    function getSupportedTokensCount() external view returns (uint256) {
        return supportedTokensList.length;
    }

    function supportedTokenAt(uint256 index) external view returns (address) {
        return supportedTokensList[index];
    }

    function proposeStrategy(address strategy, string calldata metadata) external {
        if (strategy == address(0)) revert InvalidAddress();
        StrategyConfig storage existing = proposedStrategies[strategy];
        if (existing.proposer != address(0) && !existing.rejected) {
            revert StrategyAlreadyProposed();
        }

        proposedStrategies[strategy] = StrategyConfig({
            strategy: strategy,
            proposer: msg.sender,
            approvalTime: 0,
            activationTime: 0,
            approved: false,
            rejected: false,
            active: false,
            metadata: metadata
        });

        emit StrategyProposed(strategy, msg.sender, metadata);
    }

    function approveStrategy(address strategy) external onlyGovernance {
        StrategyConfig storage cfg = proposedStrategies[strategy];
        if (cfg.proposer == address(0)) revert StrategyNotProposed();
        if (cfg.rejected) revert StrategyRejectedAlready();
        if (cfg.approved) revert StrategyAlreadyApproved();

        cfg.approved = true;
        cfg.approvalTime = block.timestamp;

        emit StrategyApproved(strategy, block.timestamp);
    }

    function rejectStrategy(address strategy) external onlyGovernance {
        StrategyConfig storage cfg = proposedStrategies[strategy];
        if (cfg.proposer == address(0)) revert StrategyNotProposed();
        if (cfg.rejected) revert StrategyRejectedAlready();

        cfg.rejected = true;

        emit StrategyRejected(strategy);
    }

    function activateStrategy(address strategy) external {
        StrategyConfig storage cfg = proposedStrategies[strategy];
        if (!cfg.approved) revert StrategyNotApproved();
        if (cfg.active) revert StrategyAlreadyActive();
        if (block.timestamp < cfg.approvalTime + TIMELOCK) revert TimelockNotElapsed();

        if (activeStrategy != address(0)) {
            proposedStrategies[activeStrategy].active = false;
            emit StrategyDeactivated(activeStrategy);
        }

        cfg.active = true;
        cfg.activationTime = block.timestamp;
        activeStrategy = strategy;

        emit StrategyActivated(strategy, block.timestamp);
    }

    function deactivateStrategy() external onlyGovernance {
        if (activeStrategy == address(0)) revert NoActiveStrategy();
        address current = activeStrategy;
        proposedStrategies[current].active = false;
        activeStrategy = address(0);
        emit StrategyDeactivated(current);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyGovernance {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyGovernance {
        if (newRecipient == address(0)) revert InvalidFeeRecipient();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function deposit(address token, uint256 amount) external nonReentrant onlySupportedToken(token) {
        if (amount == 0) revert ZeroAmount();

        uint256 sharesToMint;
        if (totalShares == 0 || totalValueLocked == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / totalValueLocked;
        }
        if (sharesToMint == 0) revert InvalidShares();

        // Effects before interactions
        userDeposits[msg.sender][token] += amount;
        tokenVaults[token].totalDeposited += amount;
        totalShares += sharesToMint;
        userShares[msg.sender] += sharesToMint;
        totalValueLocked += amount;

        // Interaction
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount, sharesToMint);
    }

    function withdraw(address token, uint256 sharesToBurn) external nonReentrant onlySupportedToken(token) {
        if (sharesToBurn == 0) revert ZeroAmount();
        if (userShares[msg.sender] < sharesToBurn) revert InsufficientShares();
        if (totalShares == 0) revert InsufficientShares();

        // Compute fee from raw proportion (multiply before divide) to avoid divide-before-multiply
        uint256 fee = (sharesToBurn * totalValueLocked * withdrawalFeeBps) / totalShares / BPS_DENOMINATOR;
        uint256 valueToReturn = (sharesToBurn * totalValueLocked) / totalShares;
        if (valueToReturn == 0) revert InsufficientShares();

        uint256 amountToUser = valueToReturn - fee;

        uint256 vaultBalance = IERC20(token).balanceOf(address(this));
        if (vaultBalance < valueToReturn) revert InsufficientVaultBalance();

        // Effects
        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        totalValueLocked -= valueToReturn;

        if (userDeposits[msg.sender][token] >= valueToReturn) {
            userDeposits[msg.sender][token] -= valueToReturn;
        } else {
            userDeposits[msg.sender][token] = 0;
        }
        if (tokenVaults[token].totalDeposited > valueToReturn) {
            tokenVaults[token].totalDeposited -= valueToReturn;
        } else {
            tokenVaults[token].totalDeposited = 0;
        }

        // Interactions
        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }
        if (amountToUser > 0) {
            IERC20(token).safeTransfer(msg.sender, amountToUser);
        }

        emit Withdrawn(msg.sender, token, amountToUser, sharesToBurn, fee);
    }

    function getUserShares(address user) external view returns (uint256) {
        return userShares[user];
    }

    function getUserDeposit(address user, address token) external view returns (uint256) {
        return userDeposits[user][token];
    }

    function getTokenVault(address token) external view returns (TokenVault memory) {
        return tokenVaults[token];
    }

    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory) {
        return proposedStrategies[strategy];
    }

    function canActivate(address strategy) external view returns (bool) {
        StrategyConfig storage cfg = proposedStrategies[strategy];
        return cfg.approved && !cfg.active && block.timestamp >= cfg.approvalTime + TIMELOCK;
    }

    function previewDeposit(address token, uint256 amount) external view returns (uint256) {
        if (!tokenVaults[token].supported) revert TokenNotSupported();
        if (amount == 0) return 0;
        if (totalShares == 0 || totalValueLocked == 0) {
            return amount;
        }
        return (amount * totalShares) / totalValueLocked;
    }

    function previewWithdraw(address token, uint256 shares) external view returns (uint256 netAmount, uint256 fee) {
        if (!tokenVaults[token].supported) revert TokenNotSupported();
        if (totalShares == 0) return (0, 0);
        // Compute fee from raw proportion (multiply before divide) to avoid divide-before-multiply
        fee = (shares * totalValueLocked * withdrawalFeeBps) / totalShares / BPS_DENOMINATOR;
        uint256 value = (shares * totalValueLocked) / totalShares;
        netAmount = value - fee;
    }
}
