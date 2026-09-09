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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0), "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IFarm {
    function deposit(uint256 amountBase, uint256 amountBorrowed) external;
    function withdraw(uint256 amountBase, uint256 amountBorrowed) external returns (uint256 returnedBase, uint256 returnedBorrowed);
    function positionValue(address owner) external view returns (uint256 totalValue, uint256 debtValue);
}

contract LeveragedYieldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error InvalidStrategy();
    error StrategyNotActive();
    error InsufficientBalance();
    error PositionNotActive();
    error MaxLeverageExceeded();
    error NotLiquidatable();
    error InsufficientLiquidity();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        uint256 indexed positionId,
        uint256 indexed strategyId,
        uint256 collateral,
        uint256 borrowed
    );
    event CollateralAdded(address indexed user, uint256 indexed positionId, uint256 amount);
    event PositionClosed(
        address indexed user,
        uint256 indexed positionId,
        uint256 returnedBase,
        uint256 returnedBorrowed,
        uint256 profit,
        uint256 fee
    );
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 indexed positionId,
        uint256 seizedCollateral,
        uint256 reward
    );
    event StrategyRegistered(uint256 indexed strategyId, address farm, address borrowedToken, uint256 maxLeverage);
    event StrategyDeactivated(uint256 indexed strategyId);
    event MaxLeverageUpdated(uint256 indexed strategyId, uint256 newMaxLeverage);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    uint256 public constant MAX_LEVERAGE_CAP = 10;
    uint256 public constant PROFIT_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant LIQUIDATION_REWARD_BPS = 100;

    struct Strategy {
        address farm;
        address borrowedToken;
        uint256 maxLeverage;
        bool active;
    }

    struct Position {
        uint256 strategyId;
        uint256 collateral;
        uint256 borrowed;
        bool active;
    }

    IERC20 public immutable baseToken;
    address public operator;
    address public feeRecipient;

    Strategy[] public strategies;

    mapping(address => uint256) public availableBalance;
    mapping(address => Position[]) public positions;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier validStrategy(uint256 strategyId) {
        if (strategyId >= strategies.length) revert InvalidStrategy();
        if (!strategies[strategyId].active) revert StrategyNotActive();
        _;
    }

    constructor(address _baseToken, address _operator, address _feeRecipient) Ownable(msg.sender) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        baseToken = IERC20(_baseToken);
        operator = _operator;
        feeRecipient = _feeRecipient;

        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        availableBalance[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (availableBalance[msg.sender] < amount) revert InsufficientBalance();

        availableBalance[msg.sender] -= amount;
        baseToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function openPosition(
        uint256 strategyId,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) external nonReentrant validStrategy(strategyId) {
        if (collateralAmount == 0) revert ZeroAmount();
        if (borrowAmount == 0) revert ZeroAmount();
        if (availableBalance[msg.sender] < collateralAmount) revert InsufficientBalance();

        Strategy storage strat = strategies[strategyId];

        uint256 maxBorrow = collateralAmount * (strat.maxLeverage - 1);
        if (borrowAmount > maxBorrow) revert MaxLeverageExceeded();

        IERC20 borrowedToken = IERC20(strat.borrowedToken);
        if (borrowedToken.balanceOf(address(this)) < borrowAmount) revert InsufficientLiquidity();

        availableBalance[msg.sender] -= collateralAmount;

        baseToken.safeApprove(strat.farm, collateralAmount);
        borrowedToken.safeApprove(strat.farm, borrowAmount);

        IFarm(strat.farm).deposit(collateralAmount, borrowAmount);

        baseToken.safeApprove(strat.farm, 0);
        borrowedToken.safeApprove(strat.farm, 0);

        positions[msg.sender].push(
            Position({
                strategyId: strategyId,
                collateral: collateralAmount,
                borrowed: borrowAmount,
                active: true
            })
        );

        uint256 positionId = positions[msg.sender].length - 1;
        emit PositionOpened(msg.sender, positionId, strategyId, collateralAmount, borrowAmount);
    }

    function addCollateral(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position[] storage userPositions = positions[msg.sender];
        if (positionId >= userPositions.length) revert PositionNotActive();
        Position storage pos = userPositions[positionId];
        if (!pos.active) revert PositionNotActive();

        if (availableBalance[msg.sender] < amount) revert InsufficientBalance();

        availableBalance[msg.sender] -= amount;
        pos.collateral += amount;

        Strategy storage strat = strategies[pos.strategyId];
        baseToken.safeApprove(strat.farm, amount);
        IFarm(strat.farm).deposit(amount, 0);
        baseToken.safeApprove(strat.farm, 0);

        emit CollateralAdded(msg.sender, positionId, amount);
    }

    function closePosition(uint256 positionId) external nonReentrant {
        Position[] storage userPositions = positions[msg.sender];
        if (positionId >= userPositions.length) revert PositionNotActive();
        Position storage pos = userPositions[positionId];
        if (!pos.active) revert PositionNotActive();

        Strategy storage strat = strategies[pos.strategyId];
        IERC20 borrowedToken = IERC20(strat.borrowedToken);

        (uint256 returnedBase, uint256 returnedBorrowed) = IFarm(strat.farm).withdraw(pos.collateral, pos.borrowed);

        pos.active = false;

        uint256 profit = 0;
        if (returnedBase > pos.collateral) {
            profit = returnedBase - pos.collateral;
        }

        uint256 fee = (profit * PROFIT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netBaseReturn = returnedBase - fee;

        availableBalance[msg.sender] += netBaseReturn;

        if (fee > 0) {
            baseToken.safeTransfer(feeRecipient, fee);
        }

        if (returnedBorrowed > pos.borrowed) {
            borrowedToken.safeTransfer(msg.sender, returnedBorrowed - pos.borrowed);
        } else if (returnedBorrowed < pos.borrowed) {
            uint256 deficit = pos.borrowed - returnedBorrowed;
            if (availableBalance[msg.sender] >= deficit) {
                availableBalance[msg.sender] -= deficit;
            } else {
                uint256 coverFromBalance = availableBalance[msg.sender];
                availableBalance[msg.sender] = 0;
                uint256 remaining = deficit - coverFromBalance;
                uint256 vaultBorrowed = borrowedToken.balanceOf(address(this));
                if (vaultBorrowed >= remaining) {
                    borrowedToken.safeTransfer(msg.sender, remaining);
                }
            }
        }

        emit PositionClosed(msg.sender, positionId, returnedBase, returnedBorrowed, profit, fee);
    }

    function liquidate(address user, uint256 positionId) external nonReentrant {
        Position[] storage userPositions = positions[user];
        if (positionId >= userPositions.length) revert PositionNotActive();
        Position storage pos = userPositions[positionId];
        if (!pos.active) revert PositionNotActive();

        Strategy storage strat = strategies[pos.strategyId];
        IFarm farm = IFarm(strat.farm);

        (uint256 totalValue, uint256 debtValue) = farm.positionValue(user);
        if (totalValue >= debtValue) revert NotLiquidatable();

        (uint256 returnedBase, uint256 returnedBorrowed) = farm.withdraw(pos.collateral, pos.borrowed);

        pos.active = false;

        IERC20 borrowedToken = IERC20(strat.borrowedToken);

        uint256 seizedBase = returnedBase;
        uint256 liquidationReward = (seizedBase * LIQUIDATION_REWARD_BPS) / BPS_DENOMINATOR;

        if (liquidationReward > seizedBase) {
            liquidationReward = seizedBase;
        }

        if (liquidationReward > 0) {
            baseToken.safeTransfer(msg.sender, liquidationReward);
        }

        emit Liquidated(msg.sender, user, positionId, seizedBase, liquidationReward);
    }

    function registerStrategy(
        address farm,
        address borrowedToken,
        uint256 maxLeverage
    ) external onlyOperator returns (uint256 strategyId) {
        if (farm == address(0)) revert ZeroAddress();
        if (borrowedToken == address(0)) revert ZeroAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE_CAP) revert MaxLeverageExceeded();

        strategies.push(
            Strategy({
                farm: farm,
                borrowedToken: borrowedToken,
                maxLeverage: maxLeverage,
                active: true
            })
        );

        strategyId = strategies.length - 1;
        emit StrategyRegistered(strategyId, farm, borrowedToken, maxLeverage);
    }

    function setMaxLeverage(uint256 strategyId, uint256 newMaxLeverage) external onlyOperator {
        if (strategyId >= strategies.length) revert InvalidStrategy();
        if (newMaxLeverage == 0 || newMaxLeverage > MAX_LEVERAGE_CAP) revert MaxLeverageExceeded();

        strategies[strategyId].maxLeverage = newMaxLeverage;
        emit MaxLeverageUpdated(strategyId, newMaxLeverage);
    }

    function deactivateStrategy(uint256 strategyId) external onlyOperator {
        if (strategyId >= strategies.length) revert InvalidStrategy();
        strategies[strategyId].active = false;
        emit StrategyDeactivated(strategyId);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientChanged(previous, newFeeRecipient);
    }

    function getStrategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function getStrategy(uint256 strategyId)
        external
        view
        returns (address farm, address borrowedToken, uint256 maxLeverage, bool active)
    {
        if (strategyId >= strategies.length) revert InvalidStrategy();
        Strategy storage strat = strategies[strategyId];
        return (strat.farm, strat.borrowedToken, strat.maxLeverage, strat.active);
    }

    function getPositionCount(address user) external view returns (uint256) {
        return positions[user].length;
    }

    function getPosition(address user, uint256 positionId)
        external
        view
        returns (uint256 strategyId, uint256 collateral, uint256 borrowed, bool active)
    {
        if (positionId >= positions[user].length) revert PositionNotActive();
        Position storage pos = positions[user][positionId];
        return (pos.strategyId, pos.collateral, pos.borrowed, pos.active);
    }

    function getAvailableBalance(address user) external view returns (uint256) {
        return availableBalance[user];
    }
}
