// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
    function getSqrtPriceX96(address token0, address token1) external view returns (uint160);
}

interface IDEXPool {
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    function liquidity() external view returns (uint128);
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
}

contract ConcentratedLiquidityVault {
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error RebalanceLimitExceeded();
    error InvalidTickRange();
    error InvalidFeeTier();
    error NoSharesToWithdraw();
    error NoRewardsToClaim();
    error SameTokens();
    error NotConfigured();
    error ReentrantCall();
    error TransferFailed();
    error AlreadyConfigured();

    event Deposit(address indexed user, uint256 amount0, uint256 amount1, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 sharesBurned, uint256 amount0, uint256 amount1);
    event RewardClaimed(address indexed user, uint256 rewardAmount, uint256 performanceFee);
    event Rebalance(
        address indexed operator,
        int24 oldTickLower,
        int24 oldTickUpper,
        int24 newTickLower,
        int24 newTickUpper,
        uint256 timestamp
    );
    event FeeTierUpdated(uint24 oldFeeTier, uint24 newFeeTier);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event RewardsDeposited(address indexed depositor, uint256 amount);
    event PositionUpdated(uint128 liquidity, int24 tickLower, int24 tickUpper);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CollectedFromPool(uint128 collected0, uint128 collected1);

    struct UserDeposit {
        uint256 shares;
        uint256 rewardDebt;
        uint256 claimedRewards;
    }

    struct PositionState {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bool active;
    }

    uint256 private constant MAX_REBALANCES_PER_DAY = 5;
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant PERFORMANCE_FEE_BPS = 10; // 0.1%
    uint256 private constant BPS_DENOMINATOR = 10000;
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = 887272;

    address public owner;
    address public operator;
    address public immutable token0;
    address public immutable token1;
    address public rewardToken;
    address public dexPool;
    address public oracle;

    uint24 public feeTier;
    int24 public tickSpacing;

    uint256 public totalShares;
    uint256 public accRewardPerShare;
    uint256 public unclaimedRewards;

    PositionState public position;

    mapping(address => UserDeposit) public deposits;

    uint256[] private rebalanceTimestamps;
    uint256 public totalRebalances;

    bool public configured;
    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier onlyConfigured() {
        if (!configured) revert NotConfigured();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _token0,
        address _token1,
        address _rewardToken,
        address _oracle,
        uint24 _feeTier,
        int24 _tickSpacing
    ) {
        if (_token0 == address(0) || _token1 == address(0) || _rewardToken == address(0)) revert ZeroAddress();
        if (_token0 == _token1) revert SameTokens();
        if (_rewardToken == _token0 || _rewardToken == _token1) revert SameTokens();
        if (_oracle == address(0)) revert ZeroAddress();

        owner = msg.sender;
        operator = msg.sender;
        token0 = _token0;
        token1 = _token1;
        rewardToken = _rewardToken;
        oracle = _oracle;
        feeTier = _feeTier;
        tickSpacing = _tickSpacing;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function configure(
        address _dexPool,
        int24 _tickLower,
        int24 _tickUpper
    ) external onlyOwner {
        if (_dexPool == address(0)) revert ZeroAddress();
        if (configured) revert AlreadyConfigured();
        _checkTicks(_tickLower, _tickUpper);

        dexPool = _dexPool;
        position.tickLower = _tickLower;
        position.tickUpper = _tickUpper;
        position.active = true;
        configured = true;

        emit PositionUpdated(0, _tickLower, _tickUpper);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function setOracle(address _oracle) external onlyOperator {
        if (_oracle == address(0)) revert ZeroAddress();
        address old = oracle;
        oracle = _oracle;
        emit OracleUpdated(old, _oracle);
    }

    function setFeeTier(uint24 _feeTier, int24 _tickSpacing) external onlyOperator {
        if (_feeTier > 1_000_000) revert InvalidFeeTier();
        uint24 old = feeTier;
        feeTier = _feeTier;
        tickSpacing = _tickSpacing;
        emit FeeTierUpdated(old, _feeTier);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function deposit(uint256 amount0, uint256 amount1) external nonReentrant onlyConfigured returns (uint256 shares) {
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();

        _updateRewardPool();

        shares = _calculateShares(amount0, amount1);
        if (shares < 1) revert ZeroAmount();

        // Effects: update state before external interactions
        UserDeposit storage ud = deposits[msg.sender];
        ud.shares += shares;
        ud.rewardDebt += (shares * accRewardPerShare) / 1e18;
        totalShares += shares;

        // Interactions: pull tokens after state is committed
        if (amount0 > 0) {
            _safeTransferFrom(token0, msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            _safeTransferFrom(token1, msg.sender, address(this), amount1);
        }

        emit Deposit(msg.sender, amount0, amount1, shares);
    }

    function withdraw(uint256 sharesToBurn) external nonReentrant onlyConfigured returns (uint256 amount0, uint256 amount1) {
        UserDeposit storage ud = deposits[msg.sender];
        if (ud.shares < 1) revert NoSharesToWithdraw();
        if (sharesToBurn < 1 || sharesToBurn > ud.shares) revert InsufficientBalance();

        _updateRewardPool();

        // Read balances for proportional withdrawal
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));
        amount0 = (bal0 * sharesToBurn) / totalShares;
        amount1 = (bal1 * sharesToBurn) / totalShares;

        // Compute pending rewards before share changes
        uint256 pending = (ud.shares * accRewardPerShare) / 1e18 - ud.rewardDebt;
        uint256 perfFee = 0;
        uint256 netReward = 0;
        if (pending > 0) {
            perfFee = (pending * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;
            netReward = pending - perfFee;
        }

        // Effects: update all state before any external transfers
        ud.shares -= sharesToBurn;
        totalShares -= sharesToBurn;
        ud.rewardDebt = (ud.shares * accRewardPerShare) / 1e18;
        if (pending > 0) {
            ud.claimedRewards += pending;
        }

        // Interactions: transfer rewards then principal
        if (netReward > 0) {
            _safeTransfer(rewardToken, msg.sender, netReward);
            if (perfFee > 0) {
                _safeTransfer(rewardToken, owner, perfFee);
            }
            emit RewardClaimed(msg.sender, netReward, perfFee);
        }

        if (amount0 > 0) {
            _safeTransfer(token0, msg.sender, amount0);
        }
        if (amount1 > 0) {
            _safeTransfer(token1, msg.sender, amount1);
        }

        emit Withdraw(msg.sender, sharesToBurn, amount0, amount1);
    }

    function claimRewards() external nonReentrant onlyConfigured returns (uint256 rewardAmount) {
        _updateRewardPool();

        UserDeposit storage ud = deposits[msg.sender];
        if (ud.shares < 1) revert NoRewardsToClaim();

        uint256 pending = (ud.shares * accRewardPerShare) / 1e18 - ud.rewardDebt;
        if (pending < 1) revert NoRewardsToClaim();

        uint256 perfFee = (pending * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;
        rewardAmount = pending - perfFee;

        // Effects: update state before external transfer
        ud.rewardDebt = (ud.shares * accRewardPerShare) / 1e18;
        ud.claimedRewards += pending;

        // Interactions
        _safeTransfer(rewardToken, msg.sender, rewardAmount);
        if (perfFee > 0) {
            _safeTransfer(rewardToken, owner, perfFee);
        }

        emit RewardClaimed(msg.sender, rewardAmount, perfFee);
    }

    function rebalance(int24 newTickLower, int24 newTickUpper) external onlyOperator onlyConfigured nonReentrant {
        _checkTicks(newTickLower, newTickUpper);
        _enforceRebalanceLimit();

        _updateRewardPool();

        int24 oldTickLower = position.tickLower;
        int24 oldTickUpper = position.tickUpper;
        uint128 oldLiquidity = position.liquidity;

        // Effects: commit all state changes before external calls
        position.tickLower = newTickLower;
        position.tickUpper = newTickUpper;
        position.active = true;
        position.liquidity = 0;

        rebalanceTimestamps.push(block.timestamp);
        totalRebalances++;

        // Interactions: burn and collect from old position
        if (oldLiquidity > 0) {
            try IDEXPool(dexPool).burn(oldTickLower, oldTickUpper, oldLiquidity) returns (uint256, uint256) {} catch {}

            try IDEXPool(dexPool).collect(
                address(this),
                oldTickLower,
                oldTickUpper,
                type(uint128).max,
                type(uint128).max
            ) returns (uint128 collected0, uint128 collected1) {
                emit CollectedFromPool(collected0, collected1);
            } catch {}
        }

        // Read available balances and approve DEX
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));

        if (bal0 > 0) {
            IERC20(token0).approve(dexPool, bal0);
        }
        if (bal1 > 0) {
            IERC20(token1).approve(dexPool, bal1);
        }

        // Estimate and set liquidity before minting
        uint128 newLiquidity = _estimateLiquidityForAmounts(bal0, bal1, newTickLower, newTickUpper);
        position.liquidity = newLiquidity;

        if (newLiquidity > 0) {
            try IDEXPool(dexPool).mint(
                address(this),
                newTickLower,
                newTickUpper,
                newLiquidity,
                ""
            ) returns (uint256, uint256) {
                // liquidity already set above
            } catch {
                position.liquidity = 0;
            }
        }

        emit Rebalance(msg.sender, oldTickLower, oldTickUpper, newTickLower, newTickUpper, block.timestamp);
        emit PositionUpdated(position.liquidity, newTickLower, newTickUpper);
    }

    function depositRewards(uint256 amount) external onlyConfigured nonReentrant {
        if (amount < 1) revert ZeroAmount();

        _updateRewardPool();
        unclaimedRewards += amount;

        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);

        emit RewardsDeposited(msg.sender, amount);
    }

    function pendingRewards(address user) external view returns (uint256) {
        UserDeposit storage ud = deposits[user];
        if (totalShares < 1 || ud.shares < 1) return 0;

        uint256 currentAcc = accRewardPerShare;
        if (unclaimedRewards > 0) {
            uint256 rewardPerShare = (unclaimedRewards * 1e18) / totalShares;
            currentAcc = accRewardPerShare + rewardPerShare;
        }

        uint256 pending = (ud.shares * currentAcc) / 1e18 - ud.rewardDebt;
        uint256 perfFee = (pending * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;
        return pending - perfFee;
    }

    function getUserDeposit(address user) external view returns (uint256 shares, uint256 rewardDebt, uint256 claimedRewards) {
        UserDeposit storage ud = deposits[user];
        return (ud.shares, ud.rewardDebt, ud.claimedRewards);
    }

    function getRebalancesInLast24Hours() public view returns (uint256) {
        uint256 cutoff = block.timestamp - SECONDS_PER_DAY;
        uint256 count = 0;
        uint256 len = rebalanceTimestamps.length;
        for (uint256 i = 0; i < len; i++) {
            if (rebalanceTimestamps[i] >= cutoff) {
                count++;
            }
        }
        return count;
    }

    function getPositionState() external view returns (
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _liquidity,
        bool _active
    ) {
        return (position.tickLower, position.tickUpper, position.liquidity, position.active);
    }

    function getVaultBalances() external view returns (uint256 balance0, uint256 balance1) {
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
    }

    function _enforceRebalanceLimit() internal {
        uint256 cutoff = block.timestamp - SECONDS_PER_DAY;
        uint256 len = rebalanceTimestamps.length;
        uint256 recentCount = 0;
        for (uint256 i = 0; i < len; i++) {
            if (rebalanceTimestamps[i] >= cutoff) {
                recentCount++;
            }
        }
        if (recentCount >= MAX_REBALANCES_PER_DAY) {
            revert RebalanceLimitExceeded();
        }
    }

    function _checkTicks(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < MIN_TICK) revert InvalidTickRange();
        if (tickUpper > MAX_TICK) revert InvalidTickRange();
    }

    function _calculateShares(uint256 amount0, uint256 amount1) internal view returns (uint256) {
        if (totalShares < 1) {
            return amount0 + amount1;
        }

        uint256 vaultBal0 = IERC20(token0).balanceOf(address(this));
        uint256 vaultBal1 = IERC20(token1).balanceOf(address(this));
        uint256 totalVault = vaultBal0 + vaultBal1;

        if (totalVault < 1) return amount0 + amount1;

        return ((amount0 + amount1) * totalShares) / totalVault;
    }

    function _estimateLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128) {
        uint256 price0 = IPriceOracle(oracle).getPrice(token0);
        uint256 price1 = IPriceOracle(oracle).getPrice(token1);

        if (price0 < 1 || price1 < 1) return 0;

        uint256 valueInToken1 = (amount0 * price0) / price1 + amount1;

        if (valueInToken1 < 1) return 0;
        if (valueInToken1 > type(uint128).max) return type(uint128).max;

        uint256 rangeFactor = _rangeFactor(tickLower, tickUpper);
        uint128 estimated = uint128((valueInToken1 * rangeFactor) / 1e18);

        return estimated;
    }

    function _rangeFactor(int24 tickLower, int24 tickUpper) internal pure returns (uint256) {
        int256 range = int256(tickUpper) - int256(tickLower);
        if (range <= 0) return 1e18;
        uint256 absRange = uint256(range);
        uint256 factor = (absRange * 1e18) / 1000;
        if (factor < 1) return 1e18;
        if (factor > 10e18) return 10e18;
        return factor;
    }

    function _updateRewardPool() internal {
        if (totalShares < 1 || unclaimedRewards < 1) return;
        uint256 rewardPerShare = (unclaimedRewards * 1e18) / totalShares;
        accRewardPerShare += rewardPerShare;
        unclaimedRewards = 0;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (amount < 1) revert ZeroAmount();
        _safeTransfer(token, msg.sender, amount);
    }
}
