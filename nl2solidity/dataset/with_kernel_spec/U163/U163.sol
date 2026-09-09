// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract OptionsMarket {
    error NotOwner();
    error NotOperator();
    error NotWriter();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidParams();
    error InvalidSeries();
    error SeriesNotActive();
    error SeriesIsPaused();
    error SeriesNotPaused();
    error SeriesExpired();
    error NotPastExpiry();
    error SeriesNotSettled();
    error SeriesAlreadySettled();
    error AlreadyClaimed();
    error MaxSeriesReached();
    error InsufficientCollateral();
    error InsufficientOptions();
    error ExerciseWindowClosed();
    error ClaimWindowNotOpen();
    error SettleWindowNotOpen();
    error InvalidExpiry();
    error TransferFailed();
    error ReentrantCall();

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    address public owner;
    address public operator;
    address public treasury;
    IERC20 public immutable collateralToken;

    uint256 public constant MAX_ACTIVE_SERIES = 200;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant CLAIM_WINDOW = 7 days;
    uint256 public constant FORCE_SETTLE_DELAY = 7 days;

    uint256 public feeRateBps = 10; // 0.1%
    uint256 public activeSeriesCount;
    uint256 public seriesCounter;

    struct Series {
        address writer;
        bool isCall;
        uint256 strikePrice;
        uint256 expiry;
        uint256 collateralPerOption;
        uint256 premiumPerOption;
        uint256 maxSupply;
        uint256 totalSold;
        bool active;
        uint256 settlementPrice;
        bool settled;
        uint256 settlementTime;
        bool writerClaimed;
    }

    mapping(uint256 => Series) internal _series;
    mapping(address => uint256) public collateralBalances;
    mapping(address => mapping(uint256 => uint256)) public userOptions;
    mapping(uint256 => uint256) public seriesCollateral;
    mapping(uint256 => uint256) public seriesPayoutPaid;
    mapping(uint256 => bool) public seriesPaused;

    event SeriesCreated(
        uint256 indexed seriesId,
        address indexed writer,
        bool isCall,
        uint256 strikePrice,
        uint256 expiry,
        uint256 maxSupply
    );
    event OptionsPurchased(uint256 indexed seriesId, address indexed buyer, uint256 amount, uint256 premium, uint256 fee);
    event OptionsExercised(uint256 indexed seriesId, address indexed buyer, uint256 amount, uint256 payout);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event SeriesPaused(uint256 indexed seriesId);
    event SeriesUnpaused(uint256 indexed seriesId);
    event SeriesSettled(uint256 indexed seriesId, uint256 settlementPrice);
    event WriterClaimed(uint256 indexed seriesId, address indexed writer, uint256 amount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OperatorUpdated(address oldOperator, address newOperator);

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _collateralToken, address _treasury, address _operator) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        collateralToken = IERC20(_collateralToken);
        treasury = _treasury;
        operator = _operator;
        _status = _NOT_ENTERED;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        collateralBalances[msg.sender] += amount;
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender] < amount) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= amount;
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function createSeries(
        bool isCall,
        uint256 strikePrice,
        uint256 expiry,
        uint256 collateralPerOption,
        uint256 premiumPerOption,
        uint256 maxSupply
    ) external nonReentrant returns (uint256 seriesId) {
        if (activeSeriesCount >= MAX_ACTIVE_SERIES) revert MaxSeriesReached();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        if (maxSupply == 0) revert ZeroAmount();
        if (collateralPerOption == 0) revert InvalidParams();
        if (strikePrice == 0) revert InvalidParams();

        uint256 totalCollateral = collateralPerOption * maxSupply;
        if (collateralBalances[msg.sender] < totalCollateral) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= totalCollateral;

        seriesId = ++seriesCounter;
        _series[seriesId] = Series({
            writer: msg.sender,
            isCall: isCall,
            strikePrice: strikePrice,
            expiry: expiry,
            collateralPerOption: collateralPerOption,
            premiumPerOption: premiumPerOption,
            maxSupply: maxSupply,
            totalSold: 0,
            active: true,
            settlementPrice: 0,
            settled: false,
            settlementTime: 0,
            writerClaimed: false
        });
        seriesCollateral[seriesId] = totalCollateral;
        activeSeriesCount++;

        emit SeriesCreated(seriesId, msg.sender, isCall, strikePrice, expiry, maxSupply);
    }

    function buyOption(uint256 seriesId, uint256 amount) external nonReentrant {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        if (!s.active) revert SeriesNotActive();
        if (seriesPaused[seriesId]) revert SeriesIsPaused();
        if (block.timestamp >= s.expiry) revert SeriesExpired();
        if (amount == 0) revert ZeroAmount();
        if (s.totalSold + amount > s.maxSupply) revert InsufficientOptions();

        uint256 premium = s.premiumPerOption * amount;
        uint256 fee = (premium * feeRateBps) / BPS_DENOMINATOR;
        uint256 totalCost = premium + fee;

        // Effects: update all state before external token transfers.
        collateralBalances[s.writer] += premium;
        s.totalSold += amount;
        userOptions[msg.sender][seriesId] += amount;

        // Interactions: pull payment from buyer and send fee to treasury.
        if (!collateralToken.transferFrom(msg.sender, address(this), totalCost)) revert TransferFailed();
        if (fee > 0) {
            if (!collateralToken.transfer(treasury, fee)) revert TransferFailed();
        }

        emit OptionsPurchased(seriesId, msg.sender, amount, premium, fee);
    }

    function exerciseOption(uint256 seriesId, uint256 amount) external nonReentrant {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        if (!s.settled) revert SeriesNotSettled();
        if (s.writerClaimed) revert AlreadyClaimed();
        if (block.timestamp >= s.settlementTime + CLAIM_WINDOW) revert ExerciseWindowClosed();
        if (amount == 0) revert ZeroAmount();
        if (userOptions[msg.sender][seriesId] < amount) revert InsufficientOptions();

        uint256 perOption = _payoutPerOption(s);
        uint256 payout = perOption * amount;
        if (seriesPayoutPaid[seriesId] + payout > seriesCollateral[seriesId]) revert InsufficientCollateral();

        userOptions[msg.sender][seriesId] -= amount;
        seriesPayoutPaid[seriesId] += payout;

        if (payout > 0) {
            if (!collateralToken.transfer(msg.sender, payout)) revert TransferFailed();
        }

        emit OptionsExercised(seriesId, msg.sender, amount, payout);
    }

    function _payoutPerOption(Series storage s) internal view returns (uint256) {
        if (!s.settled) return 0;
        if (s.isCall) {
            if (s.settlementPrice > s.strikePrice) {
                uint256 diff = s.settlementPrice - s.strikePrice;
                return diff > s.collateralPerOption ? s.collateralPerOption : diff;
            }
        } else {
            if (s.strikePrice > s.settlementPrice) {
                uint256 diff = s.strikePrice - s.settlementPrice;
                return diff > s.collateralPerOption ? s.collateralPerOption : diff;
            }
        }
        return 0;
    }

    function setSettlementPrice(uint256 seriesId, uint256 price) external onlyOperator nonReentrant {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        if (block.timestamp < s.expiry) revert NotPastExpiry();
        if (s.settled) revert SeriesAlreadySettled();

        s.settlementPrice = price;
        s.settled = true;
        s.settlementTime = block.timestamp;
        if (s.active) {
            s.active = false;
            activeSeriesCount--;
        }
        emit SeriesSettled(seriesId, price);
    }

    function forceSettleSeries(uint256 seriesId) external nonReentrant {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        if (s.settled) revert SeriesAlreadySettled();
        if (block.timestamp < s.expiry + FORCE_SETTLE_DELAY) revert SettleWindowNotOpen();

        s.settlementPrice = 0;
        s.settled = true;
        s.settlementTime = block.timestamp;
        if (s.active) {
            s.active = false;
            activeSeriesCount--;
        }
        emit SeriesSettled(seriesId, 0);
    }

    function claimWriterCollateral(uint256 seriesId) external nonReentrant {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        if (msg.sender != s.writer) revert NotWriter();
        if (!s.settled) revert SeriesNotSettled();
        if (s.writerClaimed) revert AlreadyClaimed();
        if (block.timestamp < s.settlementTime + CLAIM_WINDOW) revert ClaimWindowNotOpen();

        uint256 remaining = seriesCollateral[seriesId] - seriesPayoutPaid[seriesId];
        s.writerClaimed = true;
        if (remaining > 0) {
            collateralBalances[s.writer] += remaining;
        }
        emit WriterClaimed(seriesId, s.writer, remaining);
    }

    function pauseSeries(uint256 seriesId) external onlyOperator {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        if (seriesPaused[seriesId]) revert SeriesIsPaused();
        seriesPaused[seriesId] = true;
        emit SeriesPaused(seriesId);
    }

    function unpauseSeries(uint256 seriesId) external onlyOperator {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        if (!seriesPaused[seriesId]) revert SeriesNotPaused();
        seriesPaused[seriesId] = false;
        emit SeriesUnpaused(seriesId);
    }

    function setFeeRate(uint256 newRate) external onlyOwner {
        if (newRate > BPS_DENOMINATOR) revert InvalidParams();
        uint256 old = feeRateBps;
        feeRateBps = newRate;
        emit FeeRateUpdated(old, newRate);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getSeriesCore(uint256 seriesId)
        external
        view
        returns (address writer, bool isCall, uint256 strikePrice, uint256 expiry)
    {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        return (s.writer, s.isCall, s.strikePrice, s.expiry);
    }

    function getSeriesPricing(uint256 seriesId)
        external
        view
        returns (uint256 collateralPerOption, uint256 premiumPerOption, uint256 maxSupply, uint256 totalSold)
    {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        return (s.collateralPerOption, s.premiumPerOption, s.maxSupply, s.totalSold);
    }

    function getSeriesState(uint256 seriesId)
        external
        view
        returns (bool active, bool settled, uint256 settlementPrice, uint256 settlementTime, bool writerClaimed)
    {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        Series storage s = _series[seriesId];
        return (s.active, s.settled, s.settlementPrice, s.settlementTime, s.writerClaimed);
    }

    function getSeriesWriter(uint256 seriesId) external view returns (address) {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        return _series[seriesId].writer;
    }

    function getUserOptions(address user, uint256 seriesId) external view returns (uint256) {
        return userOptions[user][seriesId];
    }

    function getPayoutPerOption(uint256 seriesId) external view returns (uint256) {
        if (seriesId == 0 || seriesId > seriesCounter) revert InvalidSeries();
        return _payoutPerOption(_series[seriesId]);
    }

    function remainingCollateralForSeries(uint256 seriesId) external view returns (uint256) {
        return seriesCollateral[seriesId] - seriesPayoutPaid[seriesId];
    }
}
