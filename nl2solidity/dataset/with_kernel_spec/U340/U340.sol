// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @notice Minimal ERC-20 interface used by the contract to interact with base tokens.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title IYieldStrategy
 * @notice Minimal interface for external yield-generating strategies that accept
 *         a single base token and return yield-bearing shares.
 */
interface IYieldStrategy {
    function deposit(uint256 assets) external returns (uint256 shares);
    function withdraw(uint256 assets) external returns (uint256 assetsOut);
    function redeem(uint256 shares) external returns (uint256 assetsOut);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
}

/**
 * @title YieldIndexToken
 * @notice A yield-bearing index token representing a diversified portfolio of
 *         yield-generating strategies. Users deposit approved base tokens to
 *         mint index tokens and redeem them for a proportional share of the
 *         portfolio, minus a 0.5% fee directed to a treasury. An operator
 *         manages the strategy registry and rebalances capital between
 *         strategies and idle balances.
 */
contract YieldIndexToken {
    // ============ Custom Errors ============
    error ZeroAddress();
    error NotOperator();
    error BaseTokenNotApproved();
    error BaseTokenAlreadyAdded();
    error BaseTokenInUse();
    error StrategyNotActive();
    error StrategyAlreadyActive();
    error StrategyHasCapital();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientAllocation();
    error InsufficientIdleLiquidity();
    error AmountZero();
    error SameStrategy();
    error BaseTokenMismatch();
    error AllocationExceedsTarget();
    error Reentrancy();
    error SafeTransferFailed();
    error SafeApproveFailed();
    error SafeTransferFromFailed();

    // ============ Events ============
    event Mint(address indexed depositor, address indexed baseToken, uint256 amountDeposited, uint256 indexTokensMinted);
    event Burn(address indexed redeemer, uint256 indexTokensBurned, uint256 totalFeeCharged);
    event StrategyCapitalReallocated(address indexed fromStrategy, address indexed toStrategy, uint256 amount);
    event StrategyCapitalUpdated(address indexed strategy, uint256 allocatedCapital);
    event StrategyAdded(address indexed strategy, address indexed baseToken, uint256 targetAllocation);
    event StrategyRemoved(address indexed strategy);
    event StrategyAllocationUpdated(address indexed strategy, uint256 newTargetAllocation);
    event BaseTokenAdded(address indexed token);
    event BaseTokenRemoved(address indexed token);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============ Constants ============
    uint256 public constant MINIMUM_DEPOSIT = 100e18;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    string public constant name = "Yield Index Token";
    string public constant symbol = "YIT";
    uint8 public constant decimals = 18;

    // ============ State ============
    address public operator;
    address public treasury;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public isBaseToken;
    address[] public baseTokenList;

    struct StrategyInfo {
        address baseToken;
        uint256 sharesHeld;
        uint256 targetAllocation;
        bool isActive;
    }
    mapping(address => StrategyInfo) public strategies;
    address[] public strategyList;

    uint256 private _locked = 1;

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============
    constructor(address _operator, address _treasury) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    // ============ ERC20 Logic ============
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // ============ Safe ERC20 Helpers ============
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert SafeTransferFailed();
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert SafeTransferFromFailed();
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) revert SafeTransferFromFailed();
        }
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert SafeApproveFailed();
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) revert SafeApproveFailed();
        }
    }

    // ============ Portfolio Valuation ============
    function totalPortfolioValue() external view returns (uint256) {
        return _totalPortfolioValue();
    }

    function tokenPortfolioValue(address baseToken) public view returns (uint256) {
        uint256 value = IERC20(baseToken).balanceOf(address(this));
        uint256 len = strategyList.length;
        for (uint256 i; i < len; ) {
            StrategyInfo storage info = strategies[strategyList[i]];
            if (info.isActive && info.baseToken == baseToken && info.sharesHeld > 0) {
                value += IYieldStrategy(strategyList[i]).previewRedeem(info.sharesHeld);
            }
            unchecked { ++i; }
        }
        return value;
    }

    function _totalPortfolioValue() internal view returns (uint256 total) {
        uint256 len = baseTokenList.length;
        for (uint256 i; i < len; ) {
            total += tokenPortfolioValue(baseTokenList[i]);
            unchecked { ++i; }
        }
    }

    // ============ Mint ============
    function mint(address baseToken, uint256 amount) external nonReentrant {
        if (!isBaseToken[baseToken]) revert BaseTokenNotApproved();
        if (amount < MINIMUM_DEPOSIT) revert InsufficientDeposit();

        _safeTransferFrom(IERC20(baseToken), msg.sender, address(this), amount);

        uint256 valueAfter = _totalPortfolioValue();
        uint256 valueBefore = valueAfter - amount;

        uint256 indexToMint;
        if (totalSupply == 0 || valueBefore == 0) {
            indexToMint = amount;
        } else {
            indexToMint = (amount * totalSupply) / valueBefore;
        }
        if (indexToMint == 0) revert AmountZero();

        totalSupply += indexToMint;
        balanceOf[msg.sender] += indexToMint;

        emit Transfer(address(0), msg.sender, indexToMint);
        emit Mint(msg.sender, baseToken, amount, indexToMint);
    }

    // ============ Redeem ============
    function redeem(uint256 indexAmount) external nonReentrant {
        if (indexAmount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < indexAmount) revert InsufficientBalance();

        uint256 currentTotalSupply = totalSupply;

        balanceOf[msg.sender] -= indexAmount;
        totalSupply -= indexAmount;

        uint256 totalFee;
        bool anyPayout;
        uint256 len = baseTokenList.length;
        for (uint256 i; i < len; ) {
            address token = baseTokenList[i];
            uint256 portfolioShare = tokenPortfolioValue(token);
            if (portfolioShare > 0) {
                uint256 grossShare = (indexAmount * portfolioShare) / currentTotalSupply;
                if (grossShare > 0) {
                    uint256 idle = IERC20(token).balanceOf(address(this));
                    if (idle < grossShare) revert InsufficientIdleLiquidity();

                    anyPayout = true;
                    uint256 fee = (grossShare * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
                    uint256 net = grossShare - fee;

                    if (net > 0) {
                        _safeTransfer(IERC20(token), msg.sender, net);
                    }
                    if (fee > 0) {
                        _safeTransfer(IERC20(token), treasury, fee);
                    }
                    totalFee += fee;
                }
            }
            unchecked { ++i; }
        }

        if (!anyPayout) revert InsufficientIdleLiquidity();

        emit Transfer(msg.sender, address(0), indexAmount);
        emit Burn(msg.sender, indexAmount, totalFee);
    }

    // ============ Base Token Management ============
    function addBaseToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isBaseToken[token]) revert BaseTokenAlreadyAdded();
        isBaseToken[token] = true;
        baseTokenList.push(token);
        emit BaseTokenAdded(token);
    }

    function removeBaseToken(address token) external onlyOperator {
        if (!isBaseToken[token]) revert BaseTokenNotApproved();
        uint256 sLen = strategyList.length;
        for (uint256 i; i < sLen; ) {
            if (strategies[strategyList[i]].isActive && strategies[strategyList[i]].baseToken == token) {
                revert BaseTokenInUse();
            }
            unchecked { ++i; }
        }
        isBaseToken[token] = false;
        uint256 bLen = baseTokenList.length;
        for (uint256 i; i < bLen; ) {
            if (baseTokenList[i] == token) {
                baseTokenList[i] = baseTokenList[bLen - 1];
                baseTokenList.pop();
                break;
            }
            unchecked { ++i; }
        }
        emit BaseTokenRemoved(token);
    }

    function getBaseTokenList() external view returns (address[] memory) {
        return baseTokenList;
    }

    function baseTokenCount() external view returns (uint256) {
        return baseTokenList.length;
    }

    // ============ Strategy Management ============
    function addStrategy(address strategy, address baseToken, uint256 targetAllocation) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (!isBaseToken[baseToken]) revert BaseTokenNotApproved();
        if (strategies[strategy].isActive) revert StrategyAlreadyActive();

        strategies[strategy] = StrategyInfo({
            baseToken: baseToken,
            sharesHeld: 0,
            targetAllocation: targetAllocation,
            isActive: true
        });
        strategyList.push(strategy);
        emit StrategyAdded(strategy, baseToken, targetAllocation);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!strategies[strategy].isActive) revert StrategyNotActive();
        if (strategies[strategy].sharesHeld > 0) revert StrategyHasCapital();

        strategies[strategy].isActive = false;
        uint256 len = strategyList.length;
        for (uint256 i; i < len; ) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
            unchecked { ++i; }
        }
        emit StrategyRemoved(strategy);
    }

    function updateStrategyAllocation(address strategy, uint256 newTargetAllocation) external onlyOperator {
        if (!strategies[strategy].isActive) revert StrategyNotActive();
        strategies[strategy].targetAllocation = newTargetAllocation;
        emit StrategyAllocationUpdated(strategy, newTargetAllocation);
    }

    function getStrategyList() external view returns (address[] memory) {
        return strategyList;
    }

    function strategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function getStrategyInfo(address strategy)
        external
        view
        returns (address baseToken, uint256 sharesHeld, uint256 targetAllocation, bool isActive)
    {
        StrategyInfo storage info = strategies[strategy];
        return (info.baseToken, info.sharesHeld, info.targetAllocation, info.isActive);
    }

    // ============ Capital Allocation ============
    function depositToStrategy(address strategy, uint256 amount) external onlyOperator nonReentrant {
        StrategyInfo storage info = strategies[strategy];
        if (!info.isActive) revert StrategyNotActive();
        if (amount == 0) revert AmountZero();

        address baseToken = info.baseToken;
        uint256 idle = IERC20(baseToken).balanceOf(address(this));
        if (idle < amount) revert InsufficientIdleLiquidity();

        uint256 currentValue = info.sharesHeld > 0
            ? IYieldStrategy(strategy).previewRedeem(info.sharesHeld)
            : 0;
        if (currentValue + amount > info.targetAllocation) revert AllocationExceedsTarget();

        _safeApprove(IERC20(baseToken), strategy, amount);
        uint256 sharesReceived = IYieldStrategy(strategy).deposit(amount);
        if (sharesReceived == 0) revert AmountZero();

        info.sharesHeld += sharesReceived;
        emit StrategyCapitalUpdated(strategy, currentValue + amount);
    }

    function withdrawFromStrategy(address strategy, uint256 amount) external onlyOperator nonReentrant {
        StrategyInfo storage info = strategies[strategy];
        if (!info.isActive) revert StrategyNotActive();
        if (amount == 0) revert AmountZero();

        uint256 sharesNeeded = IYieldStrategy(strategy).previewWithdraw(amount);
        if (sharesNeeded > info.sharesHeld) revert InsufficientAllocation();

        uint256 balBefore = IERC20(info.baseToken).balanceOf(address(this));
        IYieldStrategy(strategy).withdraw(amount);
        uint256 balAfter = IERC20(info.baseToken).balanceOf(address(this));
        if (balAfter <= balBefore) revert InsufficientIdleLiquidity();

        info.sharesHeld -= sharesNeeded;
        emit StrategyCapitalUpdated(strategy, IYieldStrategy(strategy).previewRedeem(info.sharesHeld));
    }

    // ============ Rebalance ============
    function rebalance(address fromStrategy, address toStrategy, uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert AmountZero();
        if (fromStrategy == toStrategy) revert SameStrategy();

        address baseToken;

        if (fromStrategy != address(0)) {
            StrategyInfo storage fromInfo = strategies[fromStrategy];
            if (!fromInfo.isActive) revert StrategyNotActive();
            baseToken = fromInfo.baseToken;

            uint256 sharesNeeded = IYieldStrategy(fromStrategy).previewWithdraw(amount);
            if (sharesNeeded > fromInfo.sharesHeld) revert InsufficientAllocation();

            IYieldStrategy(fromStrategy).withdraw(amount);
            fromInfo.sharesHeld -= sharesNeeded;
        } else {
            if (toStrategy == address(0)) revert SameStrategy();
            baseToken = strategies[toStrategy].baseToken;
            uint256 idle = IERC20(baseToken).balanceOf(address(this));
            if (idle < amount) revert InsufficientIdleLiquidity();
        }

        if (toStrategy != address(0)) {
            StrategyInfo storage toInfo = strategies[toStrategy];
            if (!toInfo.isActive) revert StrategyNotActive();
            if (baseToken != toInfo.baseToken) revert BaseTokenMismatch();

            uint256 currentValue = toInfo.sharesHeld > 0
                ? IYieldStrategy(toStrategy).previewRedeem(toInfo.sharesHeld)
                : 0;
            if (currentValue + amount > toInfo.targetAllocation) revert AllocationExceedsTarget();

            _safeApprove(IERC20(baseToken), toStrategy, amount);
            uint256 sharesReceived = IYieldStrategy(toStrategy).deposit(amount);
            if (sharesReceived == 0) revert AmountZero();
            toInfo.sharesHeld += sharesReceived;
        }

        emit StrategyCapitalReallocated(fromStrategy, toStrategy, amount);
    }

    // ============ Admin ============
    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }
}
