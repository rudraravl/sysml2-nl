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
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            amount == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableZeroAddress();
    error OwnableUnauthorizedAccount(address account);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableZeroAddress();
        }
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableZeroAddress();
        }
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external virtual onlyOwner {
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
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @title PerpetualFuturesExchange
/// @notice Decentralized exchange for perpetual futures with multi-collateral support.
///         Users deposit approved assets, open/close leveraged positions, adjust
///         leverage, and withdraw free collateral. An operator manages trading pairs,
///         oracle prices, and risk parameters. Maximum leverage is 50x and a 0.1%
///         trading fee is charged on the notional value of every trade.
contract PerpetualFuturesExchange is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant MAX_LEVERAGE = 50;
    uint256 public constant TRADING_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    // ============ State Variables ============

    address public operator;
    address public feeRecipient;

    mapping(address => bool) public approvedCollateralAssets;
    mapping(bytes32 => PairConfig) public pairConfigs;
    mapping(bytes32 => FundingState) public fundingStates;
    mapping(bytes32 => uint256) public oraclePrices;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(address => uint256)) public usedCollateral;
    mapping(address => mapping(bytes32 => Position)) public positions;

    bytes32[] internal _pairKeys;

    // ============ Structs ============

    struct PairConfig {
        address baseAsset;
        address quoteAsset;
        uint256 initialMarginRatio;
        uint256 maintenanceMarginRatio;
        bool isActive;
    }

    struct FundingState {
        int256 cumulativeFundingIndex;
        uint256 lastFundingTime;
        int256 fundingRate;
    }

    struct Position {
        address baseAsset;
        address quoteAsset;
        bool isLong;
        uint256 size;
        uint256 collateral;
        uint256 entryPrice;
        int256 entryFundingIndex;
        uint256 leverage;
    }

    // ============ Events ============

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdrawal(address indexed user, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed user,
        address indexed baseAsset,
        address indexed quoteAsset,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 leverage,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed user,
        address indexed baseAsset,
        address indexed quoteAsset,
        bool isLong,
        uint256 size,
        uint256 collateral,
        int256 pnl,
        uint256 fee
    );
    event LeverageAdjusted(
        address indexed user,
        address indexed baseAsset,
        address indexed quoteAsset,
        uint256 oldLeverage,
        uint256 newLeverage,
        uint256 collateralChange
    );
    event TradingPairAdded(address indexed baseAsset, address indexed quoteAsset, uint256 initialMarginRatio);
    event OraclePriceUpdated(address indexed baseAsset, address indexed quoteAsset, uint256 price);
    event RiskParamsUpdated(
        address indexed baseAsset,
        address indexed quoteAsset,
        uint256 initialMarginRatio,
        uint256 maintenanceMarginRatio
    );
    event FundingRateUpdated(address indexed baseAsset, address indexed quoteAsset, int256 fundingRate);
    event FundingUpdated(address indexed baseAsset, address indexed quoteAsset, int256 cumulativeFundingIndex);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event CollateralAssetApproved(address indexed asset, bool approved);

    // ============ Errors ============

    error NotOperator();
    error ZeroAddress();
    error SameAddress();
    error AssetNotApproved(address asset);
    error PairNotActive(bytes32 pairKey);
    error PairAlreadyActive(bytes32 pairKey);
    error PriceNotSet();
    error InvalidPrice();
    error PositionExists();
    error NoPosition();
    error InsufficientBalance();
    error InsufficientFreeCollateral();
    error InvalidLeverage();
    error LeverageExceedsMax();
    error ZeroAmount();
    error ZeroSize();
    error InvalidMarginRatio();

    // ============ Modifiers ============

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ============ Constructor ============

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = msg.sender;
        feeRecipient = _feeRecipient;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    // ============ Admin Functions ============

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setCollateralApproval(address asset, bool approved) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        approvedCollateralAssets[asset] = approved;
        emit CollateralAssetApproved(asset, approved);
    }

    // ============ Operator Functions ============

    function addTradingPair(
        address baseAsset,
        address quoteAsset,
        uint256 initialMarginRatio,
        uint256 maintenanceMarginRatio,
        int256 fundingRate
    ) external onlyOperator {
        if (baseAsset == address(0) || quoteAsset == address(0)) revert ZeroAddress();
        if (baseAsset == quoteAsset) revert SameAddress();
        if (!approvedCollateralAssets[quoteAsset]) revert AssetNotApproved(quoteAsset);
        if (initialMarginRatio == 0 || initialMarginRatio > PRECISION) revert InvalidMarginRatio();
        if (maintenanceMarginRatio > initialMarginRatio) revert InvalidMarginRatio();

        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        if (pairConfigs[pairKey].isActive) revert PairAlreadyActive(pairKey);

        pairConfigs[pairKey] = PairConfig({
            baseAsset: baseAsset,
            quoteAsset: quoteAsset,
            initialMarginRatio: initialMarginRatio,
            maintenanceMarginRatio: maintenanceMarginRatio,
            isActive: true
        });

        fundingStates[pairKey] = FundingState({
            cumulativeFundingIndex: 0,
            lastFundingTime: block.timestamp,
            fundingRate: fundingRate
        });

        _pairKeys.push(pairKey);

        emit TradingPairAdded(baseAsset, quoteAsset, initialMarginRatio);
    }

    function updateOraclePrice(address baseAsset, address quoteAsset, uint256 price) external onlyOperator {
        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        if (!pairConfigs[pairKey].isActive) revert PairNotActive(pairKey);
        if (price == 0) revert InvalidPrice();
        oraclePrices[pairKey] = price;
        emit OraclePriceUpdated(baseAsset, quoteAsset, price);
    }

    function setRiskParams(
        address baseAsset,
        address quoteAsset,
        uint256 initialMarginRatio,
        uint256 maintenanceMarginRatio
    ) external onlyOperator {
        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        PairConfig storage config = pairConfigs[pairKey];
        if (!config.isActive) revert PairNotActive(pairKey);
        if (initialMarginRatio == 0 || initialMarginRatio > PRECISION) revert InvalidMarginRatio();
        if (maintenanceMarginRatio > initialMarginRatio) revert InvalidMarginRatio();

        config.initialMarginRatio = initialMarginRatio;
        config.maintenanceMarginRatio = maintenanceMarginRatio;
        emit RiskParamsUpdated(baseAsset, quoteAsset, initialMarginRatio, maintenanceMarginRatio);
    }

    function setFundingRate(address baseAsset, address quoteAsset, int256 fundingRate) external onlyOperator {
        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        if (!pairConfigs[pairKey].isActive) revert PairNotActive(pairKey);
        _updateFunding(pairKey);
        fundingStates[pairKey].fundingRate = fundingRate;
        emit FundingRateUpdated(baseAsset, quoteAsset, fundingRate);
    }

    // ============ Public Functions ============

    function updateFunding(address baseAsset, address quoteAsset) public {
        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        if (!pairConfigs[pairKey].isActive) revert PairNotActive(pairKey);
        _updateFunding(pairKey);
    }

    function depositCollateral(address asset, uint256 amount) external nonReentrant {
        if (!approvedCollateralAssets[asset]) revert AssetNotApproved(asset);
        if (amount == 0) revert ZeroAmount();
        collateralBalances[msg.sender][asset] += amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, asset, amount);
    }

    function withdrawCollateral(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 free = _getFreeCollateral(msg.sender, asset);
        if (amount > free) revert InsufficientFreeCollateral();
        collateralBalances[msg.sender][asset] -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, asset, amount);
    }

    function openPosition(
        address baseAsset,
        address quoteAsset,
        bool isLong,
        uint256 size,
        uint256 leverage
    ) external nonReentrant {
        if (size == 0) revert ZeroSize();
        if (leverage < 1 || leverage > MAX_LEVERAGE) revert InvalidLeverage();

        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        PairConfig storage config = pairConfigs[pairKey];
        if (!config.isActive) revert PairNotActive(pairKey);
        if (leverage > PRECISION / config.initialMarginRatio) revert LeverageExceedsMax();

        _updateFunding(pairKey);
        uint256 price = oraclePrices[pairKey];
        if (price == 0) revert PriceNotSet();
        if (positions[msg.sender][pairKey].size > 0) revert PositionExists();

        uint256 notional = (size * price) / PRECISION;
        uint256 requiredMargin = notional / leverage;
        uint256 fee = (notional * TRADING_FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalRequired = requiredMargin + fee;

        if (collateralBalances[msg.sender][quoteAsset] < totalRequired) revert InsufficientBalance();

        collateralBalances[msg.sender][quoteAsset] -= totalRequired;
        usedCollateral[msg.sender][quoteAsset] += requiredMargin;

        IERC20(quoteAsset).safeTransfer(feeRecipient, fee);

        positions[msg.sender][pairKey] = Position({
            baseAsset: baseAsset,
            quoteAsset: quoteAsset,
            isLong: isLong,
            size: size,
            collateral: requiredMargin,
            entryPrice: price,
            entryFundingIndex: fundingStates[pairKey].cumulativeFundingIndex,
            leverage: leverage
        });

        emit PositionOpened(msg.sender, baseAsset, quoteAsset, isLong, size, requiredMargin, leverage, price);
    }

    function closePosition(address baseAsset, address quoteAsset) external nonReentrant {
        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        Position storage position = positions[msg.sender][pairKey];
        if (position.size == 0) revert NoPosition();

        _updateFunding(pairKey);
        uint256 currentPrice = oraclePrices[pairKey];
        if (currentPrice == 0) revert PriceNotSet();

        int256 pricePnl;
        if (position.isLong) {
            pricePnl = (int256(position.size) * (int256(currentPrice) - int256(position.entryPrice))) /
                int256(PRECISION);
        } else {
            pricePnl = (int256(position.size) * (int256(position.entryPrice) - int256(currentPrice))) /
                int256(PRECISION);
        }

        int256 fundingPnl = (int256(position.size) *
            (fundingStates[pairKey].cumulativeFundingIndex - position.entryFundingIndex)) /
            int256(PRECISION);

        int256 totalPnl = pricePnl + fundingPnl;
        uint256 notional = (position.size * currentPrice) / PRECISION;
        uint256 fee = (notional * TRADING_FEE_BPS) / BPS_DENOMINATOR;

        int256 finalCollateralInt = int256(position.collateral) + totalPnl - int256(fee);
        uint256 finalCollateral = finalCollateralInt > 0 ? uint256(finalCollateralInt) : 0;

        usedCollateral[msg.sender][position.quoteAsset] -= position.collateral;
        collateralBalances[msg.sender][position.quoteAsset] += finalCollateral;

        IERC20(position.quoteAsset).safeTransfer(feeRecipient, fee);

        emit PositionClosed(
            msg.sender,
            baseAsset,
            quoteAsset,
            position.isLong,
            position.size,
            position.collateral,
            totalPnl,
            fee
        );

        delete positions[msg.sender][pairKey];
    }

    function adjustLeverage(address baseAsset, address quoteAsset, uint256 newLeverage) external nonReentrant {
        if (newLeverage < 1 || newLeverage > MAX_LEVERAGE) revert InvalidLeverage();

        bytes32 pairKey = _getPairKey(baseAsset, quoteAsset);
        PairConfig storage config = pairConfigs[pairKey];
        if (!config.isActive) revert PairNotActive(pairKey);
        if (newLeverage > PRECISION / config.initialMarginRatio) revert LeverageExceedsMax();

        Position storage position = positions[msg.sender][pairKey];
        if (position.size == 0) revert NoPosition();

        _updateFunding(pairKey);
        uint256 currentPrice = oraclePrices[pairKey];
        if (currentPrice == 0) revert PriceNotSet();

        uint256 notional = (position.size * currentPrice) / PRECISION;
        uint256 requiredMargin = notional / newLeverage;
        uint256 currentMargin = position.collateral;
        uint256 collateralChange;

        if (requiredMargin > currentMargin) {
            uint256 additional = requiredMargin - currentMargin;
            if (collateralBalances[msg.sender][position.quoteAsset] < additional) revert InsufficientBalance();
            collateralBalances[msg.sender][position.quoteAsset] -= additional;
            usedCollateral[msg.sender][position.quoteAsset] += additional;
            position.collateral = requiredMargin;
            collateralChange = additional;
        } else if (requiredMargin < currentMargin) {
            uint256 release = currentMargin - requiredMargin;
            usedCollateral[msg.sender][position.quoteAsset] -= release;
            collateralBalances[msg.sender][position.quoteAsset] += release;
            position.collateral = requiredMargin;
            collateralChange = release;
        }

        uint256 oldLeverage = position.leverage;
        position.leverage = newLeverage;

        emit LeverageAdjusted(msg.sender, baseAsset, quoteAsset, oldLeverage, newLeverage, collateralChange);
    }

    // ============ View Functions ============

    function getFreeCollateral(address user, address asset) external view returns (uint256) {
        return _getFreeCollateral(user, asset);
    }

    function getPosition(address user, address baseAsset, address quoteAsset)
        external
        view
        returns (Position memory)
    {
        return positions[user][_getPairKey(baseAsset, quoteAsset)];
    }

    function getCumulativeFundingIndex(address baseAsset, address quoteAsset) external view returns (int256) {
        return fundingStates[_getPairKey(baseAsset, quoteAsset)].cumulativeFundingIndex;
    }

    function getPairKey(address baseAsset, address quoteAsset) external pure returns (bytes32) {
        return _getPairKey(baseAsset, quoteAsset);
    }

    function pairCount() external view returns (uint256) {
        return _pairKeys.length;
    }

    function allPairKeys() external view returns (bytes32[] memory) {
        return _pairKeys;
    }

    // ============ Internal Functions ============

    function _getPairKey(address baseAsset, address quoteAsset) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseAsset, quoteAsset));
    }

    function _getFreeCollateral(address user, address asset) internal view returns (uint256) {
        uint256 balance = collateralBalances[user][asset];
        uint256 used = usedCollateral[user][asset];
        return balance >= used ? balance - used : 0;
    }

    function _updateFunding(bytes32 pairKey) internal {
        FundingState storage state = fundingStates[pairKey];
        if (state.lastFundingTime < block.timestamp) {
            uint256 timeDelta = block.timestamp - state.lastFundingTime;
            int256 fundingChange = state.fundingRate * int256(timeDelta);
            state.cumulativeFundingIndex += fundingChange;
            state.lastFundingTime = block.timestamp;
            emit FundingUpdated(
                pairConfigs[pairKey].baseAsset,
                pairConfigs[pairKey].quoteAsset,
                state.cumulativeFundingIndex
            );
        }
    }
}
