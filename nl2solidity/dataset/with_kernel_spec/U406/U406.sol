// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation();
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);
    error SafeERC20InsufficientBalance(address spender, uint256 balance, uint256 needed);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (value != 0 && token.allowance(address(this), spender) != 0) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
        }
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            } else {
                revert SafeERC20FailedOperation();
            }
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert SafeERC20FailedOperation();
            }
        }
    }
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId) external view returns (Position memory);

    function burn(uint256 tokenId) external payable;
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

contract ConcentratedLiquidityVault {
    using SafeERC20 for IERC20;

    error NotOperator();
    error PoolNotAllowed();
    error PositionCreationPaused();
    error InsufficientBalance();
    error InsufficientWorth();
    error InvalidManagementFee();
    error InvalidAddress();
    error PositionNonExistent();
    error NotPositionOwner();
    error DeadlineExpired();
    error ZeroAmount();
    error PriceFeedNotSet();
    error EthTransferFailed();

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event PositionCreated(
        uint256 indexed positionId,
        address indexed user,
        address indexed pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityAdded(uint256 indexed positionId, address indexed user, uint256 amount0, uint256 amount1, uint128 newLiquidity);
    event LiquidityRemoved(uint256 indexed positionId, address indexed user, uint128 liquidityRemoved, uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 indexed positionId, address indexed user, uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1);
    event ManagementFeeChanged(uint16 newFee);
    event PoolAllowed(address indexed pool);
    event PoolDisallowed(address indexed pool);
    event OperatorChanged(address indexed newOperator);
    event FeeRecipientChanged(address indexed newFeeRecipient);
    event PriceFeedSet(address indexed token, address indexed feed);
    event Paused();
    event Unpaused();

    struct Position {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 tokenId;
    }

    struct CreatePositionParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    uint16 public constant MAX_MANAGEMENT_FEE_BPS = 1000;
    uint256 public constant MIN_WORTH = 0.01 ether;
    uint256 public constant BPS_DENOMINATOR = 10000;

    address public operator;
    address public feeRecipient;
    uint16 public managementFeeBps;
    bool public paused;
    INonfungiblePositionManager public immutable positionManager;
    uint256 public nextPositionId;

    mapping(address user => mapping(address token => uint256 balance)) public userBalances;
    mapping(uint256 positionId => Position) public positions;
    mapping(uint256 positionId => address user) public positionOwners;
    mapping(address pool => bool) public allowedPools;
    mapping(address token => AggregatorV3Interface) public priceFeeds;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PositionCreationPaused();
        _;
    }

    modifier poolAllowed(IUniswapV3Pool pool) {
        if (!allowedPools[address(pool)]) revert PoolNotAllowed();
        _;
    }

    modifier validPosition(uint256 positionId) {
        if (positionOwners[positionId] == address(0)) revert PositionNonExistent();
        _;
    }

    modifier onlyPositionOwner(uint256 positionId) {
        if (positionOwners[positionId] != msg.sender) revert NotPositionOwner();
        _;
    }

    constructor(address _operator, address _feeRecipient, INonfungiblePositionManager _positionManager) {
        if (_operator == address(0) || _feeRecipient == address(0) || address(_positionManager) == address(0))
            revert InvalidAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        positionManager = _positionManager;
        nextPositionId = 1;
    }

    function setManagementFee(uint16 _feeBps) external onlyOperator {
        if (_feeBps > MAX_MANAGEMENT_FEE_BPS) revert InvalidManagementFee();
        managementFeeBps = _feeBps;
        emit ManagementFeeChanged(_feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert InvalidAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientChanged(_feeRecipient);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert InvalidAddress();
        operator = _newOperator;
        emit OperatorChanged(_newOperator);
    }

    function addAllowedPool(IUniswapV3Pool pool) external onlyOperator {
        if (address(pool) == address(0)) revert InvalidAddress();
        allowedPools[address(pool)] = true;
        emit PoolAllowed(address(pool));
    }

    function removeAllowedPool(IUniswapV3Pool pool) external onlyOperator {
        allowedPools[address(pool)] = false;
        emit PoolDisallowed(address(pool));
    }

    function setPriceFeed(address token, AggregatorV3Interface feed) external onlyOperator {
        if (token == address(0) || address(feed) == address(0)) revert InvalidAddress();
        priceFeeds[token] = feed;
        emit PriceFeedSet(token, address(feed));
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused();
    }

    function deposit(IERC20 token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        token.safeTransferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender][address(token)] += amount;
        if (token.allowance(address(this), address(positionManager)) < type(uint256).max / 2) {
            token.safeApprove(address(positionManager), type(uint256).max);
        }
        emit Deposit(msg.sender, address(token), amount);
    }

    function withdraw(IERC20 token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = userBalances[msg.sender][address(token)];
        if (amount > balance) revert InsufficientBalance();
        userBalances[msg.sender][address(token)] = balance - amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, address(token), amount);
    }

    function createPosition(CreatePositionParams calldata params)
        external
        whenNotPaused
        poolAllowed(params.pool)
        returns (uint256 positionId)
    {
        if (params.deadline < block.timestamp) revert DeadlineExpired();
        _checkMinimumWorth(params.pool, params.amount0Desired, params.amount1Desired);

        address token0 = params.pool.token0();
        address token1 = params.pool.token1();

        if (userBalances[msg.sender][token0] < params.amount0Desired || userBalances[msg.sender][token1] < params.amount1Desired)
            revert InsufficientBalance();

        userBalances[msg.sender][token0] -= params.amount0Desired;
        userBalances[msg.sender][token1] -= params.amount1Desired;

        IERC20(token0).safeApprove(address(positionManager), type(uint256).max);
        IERC20(token1).safeApprove(address(positionManager), type(uint256).max);

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: params.pool.fee(),
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this),
                deadline: params.deadline
            })
        );

        if (amount0 < params.amount0Desired) {
            userBalances[msg.sender][token0] += params.amount0Desired - amount0;
        }
        if (amount1 < params.amount1Desired) {
            userBalances[msg.sender][token1] += params.amount1Desired - amount1;
        }

        positionId = nextPositionId++;
        positions[positionId] = Position({
            pool: params.pool,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            tokenId: tokenId
        });
        positionOwners[positionId] = msg.sender;

        emit PositionCreated(positionId, msg.sender, address(params.pool), params.tickLower, params.tickUpper, tokenId, liquidity, amount0, amount1);
    }

    function addLiquidity(
        uint256 positionId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external validPosition(positionId) onlyPositionOwner(positionId) {
        if (deadline < block.timestamp) revert DeadlineExpired();
        Position storage pos = positions[positionId];

        address token0 = pos.pool.token0();
        address token1 = pos.pool.token1();

        if (userBalances[msg.sender][token0] < amount0Desired || userBalances[msg.sender][token1] < amount1Desired)
            revert InsufficientBalance();

        userBalances[msg.sender][token0] -= amount0Desired;
        userBalances[msg.sender][token1] -= amount1Desired;

        IERC20(token0).safeApprove(address(positionManager), type(uint256).max);
        IERC20(token1).safeApprove(address(positionManager), type(uint256).max);

        (uint128 newLiquidity, uint256 amount0, uint256 amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: pos.tokenId,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        if (amount0 < amount0Desired) {
            userBalances[msg.sender][token0] += amount0Desired - amount0;
        }
        if (amount1 < amount1Desired) {
            userBalances[msg.sender][token1] += amount1Desired - amount1;
        }

        pos.liquidity = newLiquidity;
        emit LiquidityAdded(positionId, msg.sender, amount0, amount1, newLiquidity);
    }

    function removeLiquidity(
        uint256 positionId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external validPosition(positionId) onlyPositionOwner(positionId) returns (uint256 amount0, uint256 amount1) {
        if (deadline < block.timestamp) revert DeadlineExpired();
        Position storage pos = positions[positionId];
        if (liquidity > pos.liquidity) revert InsufficientBalance();

        (amount0, amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: pos.tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        (uint256 collected0, uint256 collected1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: pos.tokenId,
                recipient: address(this),
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );

        pos.liquidity -= liquidity;
        userBalances[msg.sender][pos.pool.token0()] += collected0;
        userBalances[msg.sender][pos.pool.token1()] += collected1;

        emit LiquidityRemoved(positionId, msg.sender, liquidity, collected0, collected1);
    }

    function collectFees(uint256 positionId)
        external
        validPosition(positionId)
        onlyPositionOwner(positionId)
        returns (uint256 collected0, uint256 collected1)
    {
        Position storage pos = positions[positionId];

        INonfungiblePositionManager.Position memory posInfo = positionManager.positions(pos.tokenId);
        uint128 fees0 = posInfo.tokensOwed0;
        uint128 fees1 = posInfo.tokensOwed1;
        if (fees0 == 0 && fees1 == 0) return (0, 0);

        (collected0, collected1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: pos.tokenId,
                recipient: address(this),
                amount0Max: fees0,
                amount1Max: fees1
            })
        );

        uint256 fee0 = (collected0 * managementFeeBps) / BPS_DENOMINATOR;
        uint256 fee1 = (collected1 * managementFeeBps) / BPS_DENOMINATOR;

        if (fee0 > 0) {
            IERC20(pos.pool.token0()).safeTransfer(feeRecipient, fee0);
        }
        if (fee1 > 0) {
            IERC20(pos.pool.token1()).safeTransfer(feeRecipient, fee1);
        }

        userBalances[msg.sender][pos.pool.token0()] += collected0 - fee0;
        userBalances[msg.sender][pos.pool.token1()] += collected1 - fee1;

        emit FeesCollected(positionId, msg.sender, collected0, collected1, fee0, fee1);
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getPositionCount() external view returns (uint256) {
        return nextPositionId - 1;
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function isPoolAllowed(address pool) external view returns (bool) {
        return allowedPools[pool];
    }

    function _getTokenValue(address token, uint256 amount, AggregatorV3Interface feed) internal view returns (uint256) {
        (, int256 answer, , , ) = feed.latestRoundData();
        if (answer <= 0) revert InsufficientWorth();
        uint8 decimals = feed.decimals();
        return (amount * uint256(answer)) / (10 ** decimals);
    }

    function _checkMinimumWorth(IUniswapV3Pool pool, uint256 amount0, uint256 amount1) internal view {
        address token0 = pool.token0();
        address token1 = pool.token1();
        AggregatorV3Interface feed0 = priceFeeds[token0];
        AggregatorV3Interface feed1 = priceFeeds[token1];
        if (address(feed0) == address(0) || address(feed1) == address(0)) revert PriceFeedNotSet();
        uint256 worth = _getTokenValue(token0, amount0, feed0) + _getTokenValue(token1, amount1, feed1);
        if (worth < MIN_WORTH) revert InsufficientWorth();
    }

    receive() external payable {
        revert EthTransferFailed();
    }
}
