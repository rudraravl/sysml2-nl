// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!token.transfer(to, value)) revert SafeERC20FailedOperation(address(token));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (!token.approve(spender, value)) revert SafeERC20FailedOperation(address(token));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance > type(uint256).max - value) revert SafeERC20FailedOperation(address(token));
        if (!token.approve(spender, currentAllowance + value)) revert SafeERC20FailedOperation(address(token));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < value) revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, value);
        if (!token.approve(spender, currentAllowance - value)) revert SafeERC20FailedOperation(address(token));
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title DiversifiedPortfolio
 * @notice Manages user investments in a diversified portfolio of ERC-20 assets.
 *         Users deposit supported tokens, withdraw individual assets or a
 *         proportional slice of their whole portfolio, and an operator may
 *         rebalance target allocations at most once every 24 hours. A capped
 *         withdrawal fee (max 5%) is sent to the operator on every withdrawal.
 */
contract DiversifiedPortfolio is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported(address asset);
    error AssetAlreadySupported(address asset);
    error InvalidAllocationPercentage(uint256 percentage);
    error InvalidAllocationSum(uint256 sum, uint256 expected);
    error AllocationLengthMismatch();
    error InsufficientBalance(address user, address asset, uint256 requested, uint256 available);
    error WithdrawalFeeTooHigh(uint256 feeBps, uint256 maxBps);
    error RebalanceTooFrequent(uint256 lastRebalance, uint256 nextAllowed);
    error NothingToWithdraw();
    error EmptyPortfolio();
    error InvalidSharePercentage(uint256 percentage);
    error AssetHasOutstandingBalance(address asset);
    error NotOperator(address caller);
    error TransferFromFailed();

    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 totalUserDeposited);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 feeAmount, uint256 netAmount);
    event PortfolioRebalanced(address indexed operator, address[] assets, uint256[] newAllocations, uint256 timestamp);
    event WithdrawalFeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event AssetAdded(address indexed asset, uint256 allocationBps);
    event AssetRemoved(address indexed asset);

    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REBALANCE_COOLDOWN = 24 hours;

    address public operator;
    uint256 public withdrawalFeeBps;
    uint256 public lastRebalanceTimestamp;

    address[] public supportedAssets;
    mapping(address => bool) public isAssetSupported;
    mapping(address => uint256) public targetAllocationBps;

    mapping(address => mapping(address => uint256)) public userBalance;
    mapping(address => uint256) public userTotalDeposited;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator(msg.sender);
        _;
    }

    modifier supported(address asset) {
        if (!isAssetSupported[asset]) revert AssetNotSupported(asset);
        _;
    }

    constructor(
        address _operator,
        address[] memory _assets,
        uint256[] memory _allocations,
        uint256 _withdrawalFeeBp
    ) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_assets.length != _allocations.length) revert AllocationLengthMismatch();
        if (_withdrawalFeeBp > MAX_WITHDRAWAL_FEE_BPS)
            revert WithdrawalFeeTooHigh(_withdrawalFeeBp, MAX_WITHDRAWAL_FEE_BPS);
        if (_assets.length == 0) revert EmptyPortfolio();

        operator = _operator;
        withdrawalFeeBps = _withdrawalFeeBp;
        lastRebalanceTimestamp = block.timestamp;

        uint256 sum = 0;
        for (uint256 i = 0; i < _assets.length; i++) {
            address asset = _assets[i];
            uint256 alloc = _allocations[i];
            if (asset == address(0)) revert ZeroAddress();
            if (isAssetSupported[asset]) revert AssetAlreadySupported(asset);
            if (alloc == 0 || alloc > BPS_DENOMINATOR) revert InvalidAllocationPercentage(alloc);

            isAssetSupported[asset] = true;
            supportedAssets.push(asset);
            targetAllocationBps[asset] = alloc;
            sum += alloc;

            emit AssetAdded(asset, alloc);
        }
        if (sum != BPS_DENOMINATOR) revert InvalidAllocationSum(sum, BPS_DENOMINATOR);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS)
            revert WithdrawalFeeTooHigh(newFeeBps, MAX_WITHDRAWAL_FEE_BPS);
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(operator, old, newFeeBps);
    }

    function addAsset(address asset, uint256 allocationBps) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (isAssetSupported[asset]) revert AssetAlreadySupported(asset);
        if (allocationBps == 0 || allocationBps > BPS_DENOMINATOR)
            revert InvalidAllocationPercentage(allocationBps);

        uint256 currentSum = _totalAllocation();
        if (currentSum + allocationBps > BPS_DENOMINATOR)
            revert InvalidAllocationSum(currentSum + allocationBps, BPS_DENOMINATOR);

        isAssetSupported[asset] = true;
        supportedAssets.push(asset);
        targetAllocationBps[asset] = allocationBps;

        emit AssetAdded(asset, allocationBps);
    }

    function removeAsset(address asset) external onlyOperator supported(asset) {
        if (IERC20(asset).balanceOf(address(this)) > 0)
            revert AssetHasOutstandingBalance(asset);

        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[len - 1];
                supportedAssets.pop();
                break;
            }
        }
        isAssetSupported[asset] = false;
        delete targetAllocationBps[asset];

        emit AssetRemoved(asset);
    }

    function rebalance(
        address[] calldata assets,
        uint256[] calldata newAllocations
    ) external onlyOperator {
        if (assets.length == 0) revert EmptyPortfolio();
        if (assets.length != newAllocations.length) revert AllocationLengthMismatch();
        if (assets.length != supportedAssets.length) revert AllocationLengthMismatch();

        if (block.timestamp < lastRebalanceTimestamp + REBALANCE_COOLDOWN) {
            revert RebalanceTooFrequent(
                lastRebalanceTimestamp,
                lastRebalanceTimestamp + REBALANCE_COOLDOWN
            );
        }

        uint256 sum = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!isAssetSupported[assets[i]]) revert AssetNotSupported(assets[i]);
            if (newAllocations[i] > BPS_DENOMINATOR)
                revert InvalidAllocationPercentage(newAllocations[i]);
            sum += newAllocations[i];
        }
        if (sum != BPS_DENOMINATOR) revert InvalidAllocationSum(sum, BPS_DENOMINATOR);

        for (uint256 i = 0; i < assets.length; i++) {
            targetAllocationBps[assets[i]] = newAllocations[i];
        }

        lastRebalanceTimestamp = block.timestamp;

        emit PortfolioRebalanced(operator, assets, newAllocations, block.timestamp);
    }

    function deposit(address asset, uint256 amount) external nonReentrant supported(asset) {
        if (amount == 0) revert ZeroAmount();

        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        // Use msg.sender explicitly as the source to avoid arbitrary-from issues.
        if (!IERC20(asset).transferFrom(msg.sender, address(this), amount))
            revert TransferFromFailed();
        uint256 received = IERC20(asset).balanceOf(address(this)) - balanceBefore;

        userBalance[msg.sender][asset] += received;
        userTotalDeposited[msg.sender] += received;

        emit Deposit(msg.sender, asset, received, userTotalDeposited[msg.sender]);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant supported(asset) {
        if (amount == 0) revert ZeroAmount();

        uint256 available = userBalance[msg.sender][asset];
        if (amount > available)
            revert InsufficientBalance(msg.sender, asset, amount, available);

        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects before interactions.
        userBalance[msg.sender][asset] -= amount;
        userTotalDeposited[msg.sender] -= amount;

        IERC20(asset).safeTransfer(msg.sender, netAmount);
        if (fee > 0) {
            IERC20(asset).safeTransfer(operator, fee);
        }

        emit Withdraw(msg.sender, asset, amount, fee, netAmount);
    }

    function withdrawPortfolio(uint256 shareBps) external nonReentrant {
        if (shareBps == 0 || shareBps > BPS_DENOMINATOR)
            revert InvalidSharePercentage(shareBps);

        uint256 len = supportedAssets.length;
        if (len == 0) revert EmptyPortfolio();

        // Pre-compute all withdrawals and update state before any external calls.
        address[] memory assetsToWithdraw = new address[](len);
        uint256[] memory netAmounts = new uint256[](len);
        uint256[] memory fees = new uint256[](len);
        uint256[] memory grossAmounts = new uint256[](len);
        uint256 count = 0;

        for (uint256 i = 0; i < len; i++) {
            address asset = supportedAssets[i];
            uint256 userBal = userBalance[msg.sender][asset];
            if (userBal == 0) continue;

            // Compute gross and fee without divide-then-multiply: combine factors first.
            uint256 grossAmount = (userBal * shareBps) / BPS_DENOMINATOR;
            if (grossAmount == 0) continue;

            uint256 fee = (userBal * shareBps * withdrawalFeeBps) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
            if (fee > grossAmount) fee = grossAmount;
            uint256 netAmount = grossAmount - fee;

            // Effects: update state before interactions.
            userBalance[msg.sender][asset] -= grossAmount;
            userTotalDeposited[msg.sender] -= grossAmount;

            assetsToWithdraw[count] = asset;
            grossAmounts[count] = grossAmount;
            fees[count] = fee;
            netAmounts[count] = netAmount;
            count++;
        }

        if (count == 0) revert NothingToWithdraw();

        // Interactions: perform transfers after all state updates.
        for (uint256 i = 0; i < count; i++) {
            address asset = assetsToWithdraw[i];
            IERC20(asset).safeTransfer(msg.sender, netAmounts[i]);
            if (fees[i] > 0) {
                IERC20(asset).safeTransfer(operator, fees[i]);
            }
            emit Withdraw(msg.sender, asset, grossAmounts[i], fees[i], netAmounts[i]);
        }
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function getTargetAllocation(address asset) external view returns (uint256) {
        return targetAllocationBps[asset];
    }

    function getUserBalance(address user, address asset) external view returns (uint256) {
        return userBalance[user][asset];
    }

    function getContractBalance(address asset) external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function canRebalance() external view returns (bool) {
        return block.timestamp >= lastRebalanceTimestamp + REBALANCE_COOLDOWN;
    }

    function nextRebalanceTime() external view returns (uint256) {
        return lastRebalanceTimestamp + REBALANCE_COOLDOWN;
    }

    function totalAllocationSum() external view returns (uint256) {
        return _totalAllocation();
    }

    function _totalAllocation() internal view returns (uint256 sum) {
        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; i++) {
            sum += targetAllocationBps[supportedAssets[i]];
        }
    }
}
