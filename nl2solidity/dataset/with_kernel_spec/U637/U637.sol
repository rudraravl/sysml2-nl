// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AssetCoverage {
    IERC20 public immutable collateralToken;

    address public operator;

    uint256 public coverageFeeBps;
    uint256 public maxDurationMonths;

    uint256 private nextCoverageId;

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_MONTH = 30 days;
    uint256 public constant HARD_MAX_DURATION_MONTHS = 12;
    uint256 public constant HARD_MAX_FEE_BPS = 1000;

    struct CoveragePosition {
        uint256 collateral;
        uint256 activeCoverage;
        uint256 coverageId;
        uint256 coverageExpiry;
    }

    mapping(address => CoveragePosition) public positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CoverageActivated(
        address indexed user,
        uint256 amount,
        uint256 coverageId,
        uint256 durationMonths,
        uint256 feePaid,
        uint256 expiry
    );
    event CoverageExtended(
        address indexed user,
        uint256 amount,
        uint256 coverageId,
        uint256 durationMonths,
        uint256 feePaid,
        uint256 newExpiry
    );
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CoverageFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxDurationUpdated(uint256 oldMax, uint256 newMax);
    event OperatorUpdated(address oldOperator, address newOperator);

    error OnlyOperator();
    error ZeroAmount();
    error DurationZero();
    error DurationExceedsMax();
    error InsufficientCollateral();
    error NoActiveCoverage();
    error CoverageStillActive();
    error TransferFailed();
    error InvalidAddress();
    error InvalidFee();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        coverageFeeBps = 50;
        maxDurationMonths = HARD_MAX_DURATION_MONTHS;
        nextCoverageId = 1;
    }

    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        CoveragePosition storage pos = positions[msg.sender];
        pos.collateral += amount;

        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit CollateralDeposited(msg.sender, amount);
    }

    function activateCoverage(uint256 coverageAmount, uint256 durationMonths) external {
        if (coverageAmount == 0) revert ZeroAmount();
        if (durationMonths == 0) revert DurationZero();
        if (durationMonths > maxDurationMonths) revert DurationExceedsMax();

        CoveragePosition storage pos = positions[msg.sender];
        if (pos.coverageExpiry > block.timestamp && pos.activeCoverage > 0) revert CoverageStillActive();

        uint256 fee = (coverageAmount * coverageFeeBps * durationMonths) / BPS_DENOMINATOR;
        if (pos.collateral < fee) revert InsufficientCollateral();

        pos.collateral -= fee;
        pos.activeCoverage = coverageAmount;
        pos.coverageId = nextCoverageId;
        pos.coverageExpiry = block.timestamp + durationMonths * SECONDS_PER_MONTH;

        uint256 cid = nextCoverageId;
        nextCoverageId += 1;

        emit CoverageActivated(msg.sender, coverageAmount, cid, durationMonths, fee, pos.coverageExpiry);
    }

    function extendCoverage(uint256 durationMonths) external {
        if (durationMonths == 0) revert DurationZero();
        if (durationMonths > maxDurationMonths) revert DurationExceedsMax();

        CoveragePosition storage pos = positions[msg.sender];
        if (pos.activeCoverage == 0) revert NoActiveCoverage();
        if (pos.coverageExpiry <= block.timestamp) revert NoActiveCoverage();

        uint256 fee = (pos.activeCoverage * coverageFeeBps * durationMonths) / BPS_DENOMINATOR;
        if (pos.collateral < fee) revert InsufficientCollateral();

        pos.collateral -= fee;
        pos.coverageExpiry += durationMonths * SECONDS_PER_MONTH;

        emit CoverageExtended(
            msg.sender,
            pos.activeCoverage,
            pos.coverageId,
            durationMonths,
            fee,
            pos.coverageExpiry
        );
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        CoveragePosition storage pos = positions[msg.sender];

        uint256 locked = 0;
        if (pos.coverageExpiry > block.timestamp) {
            locked = pos.activeCoverage;
        }

        uint256 available = pos.collateral >= locked ? pos.collateral - locked : 0;
        if (amount > available) revert InsufficientCollateral();

        pos.collateral -= amount;

        bool ok = collateralToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function availableCollateral(address user) external view returns (uint256) {
        CoveragePosition storage pos = positions[user];
        uint256 locked = 0;
        if (pos.coverageExpiry > block.timestamp) {
            locked = pos.activeCoverage;
        }
        if (pos.collateral < locked) return 0;
        return pos.collateral - locked;
    }

    function getPosition(address user)
        external
        view
        returns (
            uint256 collateral,
            uint256 activeCoverage,
            uint256 coverageId,
            uint256 coverageExpiry
        )
    {
        CoveragePosition storage pos = positions[user];
        return (pos.collateral, pos.activeCoverage, pos.coverageId, pos.coverageExpiry);
    }

    function setCoverageFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps == 0 || newFeeBps > HARD_MAX_FEE_BPS) revert InvalidFee();
        emit CoverageFeeUpdated(coverageFeeBps, newFeeBps);
        coverageFeeBps = newFeeBps;
    }

    function setMaxDurationMonths(uint256 newMax) external onlyOperator {
        if (newMax == 0) revert DurationZero();
        if (newMax > HARD_MAX_DURATION_MONTHS) revert DurationExceedsMax();
        emit MaxDurationUpdated(maxDurationMonths, newMax);
        maxDurationMonths = newMax;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }
}
