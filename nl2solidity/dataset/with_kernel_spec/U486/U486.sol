// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PortfolioVaultManager {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultCreated(
        uint256 indexed vaultId,
        address indexed creator,
        address[] tokens,
        uint256[] targetWeights
    );

    event Deposited(
        uint256 indexed vaultId,
        address indexed depositor,
        address indexed token,
        uint256 amount
    );

    event Withdrawn(
        uint256 indexed vaultId,
        address indexed withdrawer,
        address indexed token,
        uint256 amount
    );

    event RebalanceCompleted(
        uint256 indexed vaultId,
        address indexed rebalancer,
        uint256 totalMoved,
        uint256 feeCharged
    );

    event TargetWeightsUpdated(
        uint256 indexed vaultId,
        address indexed operator,
        address[] tokens,
        uint256[] newWeights
    );

    event RebalanceFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ReentrancyGuard();
    error VaultNotFound(uint256 vaultId);
    error TokenNotInVault(address token);
    error InvalidVaultInitialization();
    error InvalidWeights();
    error WeightsSumMismatch();
    error ArrayLengthMismatch();
    error ZeroAddress();
    error InvalidFeeBps();
    error InvalidAmount();
    error InsufficientBalance();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint256 public constant REBALANCE_TOLERANCE = 1; // 1 wei tolerance for rounding

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public operator;
    uint256 public rebalanceFeeBps; // default 50 = 0.5%
    uint256 public vaultCount;
    uint256 public totalFeesCollected;

    uint256 private _locked = 1;

    struct Vault {
        address[] tokens;
        bool active;
        address creator;
    }

    mapping(uint256 => Vault) internal vaults;
    mapping(uint256 => mapping(address => uint256)) public vaultBalances;
    mapping(uint256 => mapping(address => uint256)) public targetWeights;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public userDeposits;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier vaultExists(uint256 vaultId) {
        if (vaultId >= vaultCount || !vaults[vaultId].active) revert VaultNotFound(vaultId);
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        rebalanceFeeBps = 50; // 0.5%
        emit RebalanceFeeUpdated(0, 50);
        emit OperatorUpdated(address(0), _operator);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _isTokenInVault(uint256 vaultId, address token) internal view returns (bool) {
        address[] storage tokens = vaults[vaultId].tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return true;
        }
        return false;
    }

    function _validateRebalanceInputs(
        uint256 vaultId,
        address[] calldata tokens,
        uint256[] calldata newAmounts
    ) internal view returns (uint256 tokenCount, uint256 totalNewValue) {
        address[] storage vaultTokens = vaults[vaultId].tokens;
        tokenCount = vaultTokens.length;

        if (tokens.length != tokenCount) revert ArrayLengthMismatch();
        if (tokens.length != newAmounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < tokenCount; i++) {
            if (tokens[i] != vaultTokens[i]) revert TokenNotInVault(tokens[i]);
            totalNewValue += newAmounts[i];
        }

        if (totalNewValue > 0) {
            for (uint256 i = 0; i < tokenCount; i++) {
                uint256 weight = targetWeights[vaultId][tokens[i]];
                uint256 expectedAmount = (totalNewValue * weight) / BPS_DENOMINATOR;
                if (
                    newAmounts[i] > expectedAmount + REBALANCE_TOLERANCE ||
                    newAmounts[i] + REBALANCE_TOLERANCE < expectedAmount
                ) {
                    revert InvalidWeights();
                }
            }
        }
    }

    function _applyRebalanceMovements(
        uint256 vaultId,
        address[] calldata tokens,
        uint256[] calldata newAmounts,
        address rebalancer
    ) internal returns (uint256 totalMoved) {
        uint256 tokenCount = tokens.length;
        for (uint256 i = 0; i < tokenCount; i++) {
            address token = tokens[i];
            uint256 currentBalance = vaultBalances[vaultId][token];
            uint256 newBalance = newAmounts[i];

            if (newBalance > currentBalance) {
                uint256 diff = newBalance - currentBalance;
                // Effects before interactions
                vaultBalances[vaultId][token] = newBalance;
                _safeTransferFrom(IERC20(token), rebalancer, address(this), diff);
                totalMoved += diff;
            } else if (newBalance < currentBalance) {
                uint256 diff = currentBalance - newBalance;
                // Effects before interactions
                vaultBalances[vaultId][token] = newBalance;
                _safeTransfer(IERC20(token), rebalancer, diff);
                totalMoved += diff;
            }
        }
    }

    function _collectRebalanceFee(
        uint256 vaultId,
        address[] calldata tokens,
        uint256[] calldata newAmounts,
        uint256 totalMoved,
        uint256 totalNewValue
    ) internal returns (uint256 feeCollected) {
        if (totalMoved == 0 || totalNewValue == 0) return 0;

        uint256 tokenCount = tokens.length;
        for (uint256 i = 0; i < tokenCount; i++) {
            address token = tokens[i];
            // Multiplications performed before divisions to avoid divide-before-multiply
            // precision loss: tokenFee = newAmounts[i] * totalMoved * rebalanceFeeBps
            //                                                   / (totalNewValue * BPS_DENOMINATOR)
            uint256 tokenFee = (newAmounts[i] * totalMoved * rebalanceFeeBps) /
                (totalNewValue * BPS_DENOMINATOR);
            if (tokenFee > 0 && vaultBalances[vaultId][token] >= tokenFee) {
                // Effects before interactions
                vaultBalances[vaultId][token] -= tokenFee;
                _safeTransfer(IERC20(token), owner, tokenFee);
                feeCollected += tokenFee;
            }
        }
        totalFeesCollected += feeCollected;
    }

    /*//////////////////////////////////////////////////////////////
                         VAULT CREATION
    //////////////////////////////////////////////////////////////*/

    function createVault(
        address[] calldata tokens,
        uint256[] calldata weights
    ) external returns (uint256 vaultId) {
        if (tokens.length < 2) revert InvalidVaultInitialization();
        if (tokens.length != weights.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] == tokens[j]) revert InvalidVaultInitialization();
            }
        }

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            if (weights[i] == 0) revert InvalidWeights();
            totalWeight += weights[i];
        }
        if (totalWeight != BPS_DENOMINATOR) revert WeightsSumMismatch();

        vaultId = vaultCount++;
        Vault storage vault = vaults[vaultId];
        vault.tokens = tokens;
        vault.active = true;
        vault.creator = msg.sender;

        for (uint256 i = 0; i < tokens.length; i++) {
            targetWeights[vaultId][tokens[i]] = weights[i];
        }

        emit VaultCreated(vaultId, msg.sender, tokens, weights);
    }

    /*//////////////////////////////////////////////////////////////
                       DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 vaultId,
        address token,
        uint256 amount
    ) external vaultExists(vaultId) nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (!_isTokenInVault(vaultId, token)) revert TokenNotInVault(token);

        // Effects before interactions
        vaultBalances[vaultId][token] += amount;
        userDeposits[vaultId][msg.sender][token] += amount;

        _safeTransferFrom(IERC20(token), msg.sender, address(this), amount);

        emit Deposited(vaultId, msg.sender, token, amount);
    }

    function withdraw(
        uint256 vaultId,
        address token,
        uint256 amount
    ) external vaultExists(vaultId) nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (userDeposits[vaultId][msg.sender][token] < amount) revert InsufficientBalance();
        if (vaultBalances[vaultId][token] < amount) revert InsufficientBalance();

        // Effects before interactions
        vaultBalances[vaultId][token] -= amount;
        userDeposits[vaultId][msg.sender][token] -= amount;

        _safeTransfer(IERC20(token), msg.sender, amount);

        emit Withdrawn(vaultId, msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          REBALANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function rebalance(
        uint256 vaultId,
        address[] calldata tokens,
        uint256[] calldata newAmounts
    ) external vaultExists(vaultId) nonReentrant {
        (, uint256 totalNewValue) = _validateRebalanceInputs(vaultId, tokens, newAmounts);

        uint256 totalMoved = _applyRebalanceMovements(vaultId, tokens, newAmounts, msg.sender);

        uint256 feeCollected = _collectRebalanceFee(
            vaultId,
            tokens,
            newAmounts,
            totalMoved,
            totalNewValue
        );

        emit RebalanceCompleted(vaultId, msg.sender, totalMoved, feeCollected);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTargetWeights(
        uint256 vaultId,
        address[] calldata tokens,
        uint256[] calldata weights
    ) external vaultExists(vaultId) onlyOperator {
        address[] storage vaultTokens = vaults[vaultId].tokens;
        uint256 tokenCount = vaultTokens.length;

        if (tokens.length != tokenCount) revert ArrayLengthMismatch();
        if (tokens.length != weights.length) revert ArrayLengthMismatch();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokenCount; i++) {
            if (tokens[i] != vaultTokens[i]) revert TokenNotInVault(tokens[i]);
            if (weights[i] == 0) revert InvalidWeights();
            targetWeights[vaultId][tokens[i]] = weights[i];
            totalWeight += weights[i];
        }
        if (totalWeight != BPS_DENOMINATOR) revert WeightsSumMismatch();

        emit TargetWeightsUpdated(vaultId, msg.sender, tokens, weights);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRebalanceFee(uint256 feeBps) external onlyOwner {
        if (feeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        uint256 oldFee = rebalanceFeeBps;
        rebalanceFeeBps = feeBps;
        emit RebalanceFeeUpdated(oldFee, feeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getVaultTokens(uint256 vaultId) external view vaultExists(vaultId) returns (address[] memory) {
        return vaults[vaultId].tokens;
    }

    function getVaultInfo(uint256 vaultId)
        external
        view
        returns (address[] memory tokens, address creator, bool active)
    {
        Vault storage vault = vaults[vaultId];
        return (vault.tokens, vault.creator, vault.active);
    }

    function getVaultBalance(uint256 vaultId, address token) external view returns (uint256) {
        return vaultBalances[vaultId][token];
    }

    function getTargetWeight(uint256 vaultId, address token) external view returns (uint256) {
        return targetWeights[vaultId][token];
    }

    function getUserDeposit(
        uint256 vaultId,
        address user,
        address token
    ) external view returns (uint256) {
        return userDeposits[vaultId][user][token];
    }

    function getVaultTotalValue(uint256 vaultId) external view vaultExists(vaultId) returns (uint256) {
        address[] storage tokens = vaults[vaultId].tokens;
        uint256 total = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            total += vaultBalances[vaultId][tokens[i]];
        }
        return total;
    }

    function isVaultActive(uint256 vaultId) external view returns (bool) {
        if (vaultId >= vaultCount) return false;
        return vaults[vaultId].active;
    }

    function tokenBelongsToVault(
        uint256 vaultId,
        address token
    ) external view vaultExists(vaultId) returns (bool) {
        return _isTokenInVault(vaultId, token);
    }
}
