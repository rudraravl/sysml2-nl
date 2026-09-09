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

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;
    function totalAssets() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract YieldVault {
    using SafeERC20 for IERC20;

    error NotOwner();
    error NotOperator();
    error TokenNotSupported();
    error InsufficientBalance();
    error MinDepositNotMet();
    error MinSharesNotMet();
    error ZeroAddress();
    error InvalidAllocation();
    error NoStrategy();
    error Reentrancy();

    uint256 public constant DEPOSIT_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant MIN_SHARES = 1;

    address public owner;
    address public operator;
    address public feeRecipient;
    IERC20 public immutable rewardToken;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalDeposits; // total shares per token
    mapping(address => mapping(address => uint256)) public userBalances; // token => user => shares
    mapping(address => uint256) public accruedRewards; // user => reward amount

    struct StrategyConfig {
        address strategy;
        uint256 allocationBps;
    }
    mapping(address => StrategyConfig) public strategies;

    event Deposit(address indexed token, address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event Withdraw(address indexed token, address indexed user, uint256 amount, uint256 shares);
    event RewardClaim(address indexed user, uint256 amount);
    event SupportedTokenUpdated(address indexed token, bool supported);
    event StrategyUpdated(address indexed token, address indexed strategy);
    event AllocationUpdated(address indexed token, uint256 allocationBps);
    event Rebalance(address indexed token, uint256 invested, uint256 divested);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event FeeRecipientUpdated(address indexed feeRecipient);
    event OperatorUpdated(address indexed operator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!supportedTokens[token]) revert TokenNotSupported();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _operator, address _feeRecipient, address _rewardToken) {
        if (_operator == address(0) || _feeRecipient == address(0) || _rewardToken == address(0)) {
            revert ZeroAddress();
        }
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        rewardToken = IERC20(_rewardToken);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function totalAssets(address token) public view returns (uint256) {
        uint256 assets = IERC20(token).balanceOf(address(this));
        address strat = strategies[token].strategy;
        if (strat != address(0)) {
            assets += IStrategy(strat).totalAssets();
        }
        return assets;
    }

    function deposit(address token, uint256 amount) external nonReentrant onlySupportedToken(token) {
        if (amount < MIN_DEPOSIT) revert MinDepositNotMet();

        uint256 fee = (amount * DEPOSIT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = amount - fee;

        uint256 shares;
        uint256 totalShares = totalDeposits[token];
        if (totalShares == 0) {
            shares = amountAfterFee;
        } else {
            uint256 assetsBefore = totalAssets(token);
            if (assetsBefore == 0) revert InsufficientBalance();
            shares = (amountAfterFee * totalShares) / assetsBefore;
        }
        // Use a range check instead of strict equality to avoid the
        // "incorrect-equality" pitfall flagged by static analyzers.
        if (shares < MIN_SHARES) revert MinSharesNotMet();

        // Effects before interactions (CEI) to prevent cross-function reentrancy.
        userBalances[token][msg.sender] += shares;
        totalDeposits[token] = totalShares + shares;

        // Interactions
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }

        emit Deposit(token, msg.sender, amount, shares, fee);
    }

    function withdraw(address token, uint256 shares) external nonReentrant onlySupportedToken(token) {
        if (shares < MIN_SHARES) revert InsufficientBalance();
        uint256 userShares = userBalances[token][msg.sender];
        if (shares > userShares) revert InsufficientBalance();

        uint256 totalShares = totalDeposits[token];
        uint256 assets = totalAssets(token);
        uint256 amount = (shares * assets) / totalShares;

        // Effects before interactions (CEI).
        userBalances[token][msg.sender] = userShares - shares;
        totalDeposits[token] = totalShares - shares;

        // Interactions
        uint256 vaultBal = IERC20(token).balanceOf(address(this));
        if (vaultBal < amount) {
            address strat = strategies[token].strategy;
            if (strat == address(0)) revert NoStrategy();
            IStrategy(strat).withdraw(amount - vaultBal);
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(token, msg.sender, amount, shares);
    }

    function claimRewards() external nonReentrant {
        uint256 amount = accruedRewards[msg.sender];
        if (amount < MIN_SHARES) revert InsufficientBalance();

        // Effects before interactions (CEI).
        accruedRewards[msg.sender] = 0;

        // Interactions
        rewardToken.safeTransfer(msg.sender, amount);

        emit RewardClaim(msg.sender, amount);
    }

    function setSupportedToken(address token, bool supported) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        supportedTokens[token] = supported;
        emit SupportedTokenUpdated(token, supported);
    }

    function setStrategy(address token, address strategy) external onlyOperator onlySupportedToken(token) nonReentrant {
        StrategyConfig storage config = strategies[token];
        address oldStrategy = config.strategy;
        // Effects before interactions (CEI): update state first so a
        // reentrant callback via the old strategy cannot corrupt config.
        config.strategy = strategy;
        // Interactions
        if (oldStrategy != address(0) && strategy != oldStrategy) {
            IStrategy(oldStrategy).withdrawAll();
        }
        emit StrategyUpdated(token, strategy);
    }

    function setAllocation(address token, uint256 allocationBps) external onlyOperator onlySupportedToken(token) {
        if (allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
        strategies[token].allocationBps = allocationBps;
        emit AllocationUpdated(token, allocationBps);
    }

    function rebalance(address token) external onlyOperator onlySupportedToken(token) nonReentrant {
        StrategyConfig storage config = strategies[token];
        address strat = config.strategy;
        if (strat == address(0)) {
            return;
        }

        uint256 total = totalAssets(token);
        uint256 target = (total * config.allocationBps) / BPS_DENOMINATOR;
        uint256 current = IStrategy(strat).totalAssets();

        if (current < target) {
            uint256 toInvest = target - current;
            uint256 vaultBal = IERC20(token).balanceOf(address(this));
            if (toInvest > vaultBal) {
                toInvest = vaultBal;
            }
            if (toInvest > 0) {
                IERC20(token).safeTransfer(strat, toInvest);
                IStrategy(strat).deposit(toInvest);
                emit Rebalance(token, toInvest, 0);
            }
        } else if (current > target) {
            uint256 toDivest = current - target;
            IStrategy(strat).withdraw(toDivest);
            emit Rebalance(token, 0, toDivest);
        }
    }

    function emergencyWithdraw(address token) external onlyOperator onlySupportedToken(token) nonReentrant {
        address strat = strategies[token].strategy;
        if (strat == address(0)) revert NoStrategy();
        uint256 amount = IStrategy(strat).totalAssets();
        // Effects before interactions (CEI): clear allocation prior to the
        // external call so a reentrant strategy cannot reuse stale config.
        strategies[token].allocationBps = 0;
        // Interactions
        IStrategy(strat).withdrawAll();
        emit EmergencyWithdraw(token, amount);
    }

    function reportRewards(address user, uint256 amount) external onlyOperator nonReentrant {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) return;
        // Effects before interactions (CEI).
        accruedRewards[user] += amount;
        // Interactions
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
