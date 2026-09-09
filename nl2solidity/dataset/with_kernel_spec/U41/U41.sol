Looking at the error, the issue is "Stack too deep" caused by the public `launches` mapping auto-generating a getter for a struct with 13 fields, plus the `getLaunch` function returning the full struct. I'll make the mapping private and split the getter functions.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LaunchOrchestrator {
    uint256 public constant MIN_DURATION = 24 hours;
    uint256 public constant MAX_FEE_BPS = 500; // 5%
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_TOTAL_TOKENS = 1_000_000_000 * 1e18;
    uint256 public constant MAX_SLOPE = 1e20;
    uint256 public constant MAX_INTERCEPT = 1e24;

    address public owner;
    address public operator;
    uint256 public globalFeeBps;
    bool public launchCreationPaused;
    uint256 private _locked = 1;

    struct Launch {
        address creator;
        address projectToken;
        address baseToken;
        uint256 slope;
        uint256 intercept;
        uint256 startTime;
        uint256 endTime;
        uint256 totalProjectTokens;
        uint256 soldTokens;
        uint256 baseCollected;
        uint256 feesCollected;
        bool unsoldWithdrawn;
        bool baseWithdrawn;
    }

    struct Participant {
        uint256 purchasedTokens;
        uint256 tokensWithdrawn;
        uint256 feeClaimed;
    }

    mapping(uint256 => Launch) private _launches;
    mapping(uint256 => mapping(address => Participant)) private _participants;
    uint256 public launchCount;

    event LaunchCreated(
        uint256 indexed launchId,
        address indexed creator,
        address projectToken,
        address baseToken,
        uint256 slope,
        uint256 intercept,
        uint256 startTime,
        uint256 endTime,
        uint256 totalProjectTokens
    );
    event TokensPurchased(
        uint256 indexed launchId,
        address indexed buyer,
        uint256 baseAmount,
        uint256 projectTokens,
        uint256 fee
    );
    event TokensWithdrawn(uint256 indexed launchId, address indexed participant, uint256 amount);
    event FeeWithdrawn(uint256 indexed launchId, address indexed participant, uint256 amount);
    event UnsoldTokensWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);
    event BaseTokensWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);
    event GlobalFeeUpdated(uint256 oldFee, uint256 newFee);
    event LaunchCreationPaused();
    event LaunchCreationUnpaused();
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error ZeroAddress();
    error InvalidParameters();
    error InvalidDuration();
    error LaunchNotActive();
    error LaunchNotConcluded();
    error InsufficientTokens();
    error InsufficientBalance();
    error AlreadyWithdrawn();
    error NoFeeToClaim();
    error NotOperator();
    error NotOwner();
    error FeeTooHigh();
    error NotCreator();
    error LaunchCreationPausedError();
    error ReentrantCall();
    error SafeTransferFailed();
    error SafeTransferFromFailed();
    error LaunchNotFound();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (launchCreationPaused) revert LaunchCreationPausedError();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier launchExists(uint256 launchId) {
        if (_launches[launchId].creator == address(0)) revert LaunchNotFound();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        globalFeeBps = 200;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setGlobalFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit GlobalFeeUpdated(globalFeeBps, _feeBps);
        globalFeeBps = _feeBps;
    }

    function pauseLaunchCreation() external onlyOperator {
        launchCreationPaused = true;
        emit LaunchCreationPaused();
    }

    function unpauseLaunchCreation() external onlyOperator {
        launchCreationPaused = false;
        emit LaunchCreationUnpaused();
    }

    function createLaunch(
        address projectToken,
        address baseToken,
        uint256 slope,
        uint256 intercept,
        uint256 duration,
        uint256 totalProjectTokens
    ) external whenNotPaused nonReentrant returns (uint256 launchId) {
        if (projectToken == address(0) || baseToken == address(0)) revert ZeroAddress();
        if (duration < MIN_DURATION) revert InvalidDuration();
        if (slope > MAX_SLOPE) revert InvalidParameters();
        if (intercept > MAX_INTERCEPT) revert InvalidParameters();
        if (totalProjectTokens == 0 || totalProjectTokens > MAX_TOTAL_TOKENS)
            revert InvalidParameters();
        if (slope == 0 && intercept == 0) revert InvalidParameters();

        launchId = launchCount++;
        Launch storage l = _launches[launchId];
        l.creator = msg.sender;
        l.projectToken = projectToken;
        l.baseToken = baseToken;
        l.slope = slope;
        l.intercept = intercept;
        l.startTime = block.timestamp;
        l.endTime = block.timestamp + duration;
        l.totalProjectTokens = totalProjectTokens;

        _safeTransferFrom(projectToken, msg.sender, address(this), totalProjectTokens);

        emit LaunchCreated(
            launchId,
            msg.sender,
            projectToken,
            baseToken,
            slope,
            intercept,
            l.startTime,
            l.endTime,
            totalProjectTokens
        );
    }

    function buyTokens(uint256 launchId, uint256 maxBaseAmount)
        external
        nonReentrant
        launchExists(launchId)
    {
        if (maxBaseAmount == 0) revert InvalidParameters();

        Launch storage l = _launches[launchId];
        if (block.timestamp < l.startTime || block.timestamp >= l.endTime)
            revert LaunchNotActive();
        if (l.soldTokens >= l.totalProjectTokens) revert InsufficientTokens();

        uint256 n = _computeTokensForBase(launchId, maxBaseAmount);
        if (n == 0) revert InsufficientTokens();

        uint256 cost = _computeCost(launchId, n);
        if (cost > maxBaseAmount) {
            n -= 1;
            if (n == 0) revert InsufficientTokens();
            cost = _computeCost(launchId, n);
        }

        uint256 fee = (cost * globalFeeBps) / BPS_DENOMINATOR;
        uint256 netCost = cost - fee;

        l.soldTokens += n;
        l.baseCollected += netCost;
        l.feesCollected += fee;
        _participants[launchId][msg.sender].purchasedTokens += n;

        _safeTransferFrom(l.baseToken, msg.sender, address(this), cost);

        emit TokensPurchased(launchId, msg.sender, cost, n, fee);
    }

    function withdrawTokens(uint256 launchId) external nonReentrant launchExists(launchId) {
        Participant storage p = _participants[launchId][msg.sender];

        uint256 withdrawable = p.purchasedTokens - p.tokensWithdrawn;
        if (withdrawable == 0) revert InsufficientBalance();

        p.tokensWithdrawn += withdrawable;

        _safeTransfer(_launches[launchId].projectToken, msg.sender, withdrawable);

        emit TokensWithdrawn(launchId, msg.sender, withdrawable);
    }

    function claimFees(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage l = _launches[launchId];
        if (block.timestamp < l.endTime) revert LaunchNotConcluded();
        if (l.soldTokens == 0) revert NoFeeToClaim();

        Participant storage p = _participants[launchId][msg.sender];
        uint256 share = (l.feesCollected * p.purchasedTokens) / l.soldTokens;
        uint256 claimable = share - p.feeClaimed;
        if (claimable == 0) revert NoFeeToClaim();

        p.feeClaimed += claimable;

        _safeTransfer(l.baseToken, msg.sender, claimable);

        emit FeeWithdrawn(launchId, msg.sender, claimable);
    }

    function withdrawUnsoldTokens(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage l = _launches[launchId];
        if (msg.sender != l.creator) revert NotCreator();
        if (block.timestamp < l.endTime) revert LaunchNotConcluded();
        if (l.unsoldWithdrawn) revert AlreadyWithdrawn();

        l.unsoldWithdrawn = true;
        uint256 unsold = l.totalProjectTokens - l.soldTokens;

        if (unsold > 0) {
            _safeTransfer(l.projectToken, l.creator, unsold);
        }

        emit UnsoldTokensWithdrawn(launchId, l.creator, unsold);
    }

    function withdrawBaseTokens(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage l = _launches[launchId];
        if (msg.sender != l.creator) revert NotCreator();
        if (block.timestamp < l.endTime) revert LaunchNotConcluded();
        if (l.baseWithdrawn) revert AlreadyWithdrawn();

        l.baseWithdrawn = true;
        uint256 amount = l.baseCollected;

        if (amount > 0) {
            _safeTransfer(l.baseToken, l.creator, amount);
        }

        emit BaseTokensWithdrawn(launchId, l.creator, amount);
    }

    function _computeCostInternal(
        uint256 intercept,
        uint256 slope,
        uint256 s,
        uint256 n
    ) internal pure returns (uint256) {
        uint256 linear = (intercept * n) / PRECISION;
        uint256 sn = s * n;
        uint256 nn = n * n;
        uint256 quadratic = (slope * (2 * sn + nn)) / (2 * PRECISION * PRECISION);
        return linear + quadratic;
    }

    function _computeCost(uint256 launchId, uint256 n)
        internal
        view
        returns (uint256)
    {
        Launch storage l = _launches[launchId];
        return _computeCostInternal(l.intercept, l.slope, l.soldTokens, n);
    }

    function _computeTokensForBase(uint256 launchId, uint256 maxBase)
        internal
        view
        returns (uint256)
    {
        Launch storage l = _launches[launchId];
        uint256 intercept = l.intercept;
        uint256 slope = l.slope;
        uint256 s = l.soldTokens;
        uint256 available = l.totalProjectTokens - s;
        if (available == 0) return 0;

        uint256 lo = 0;
        uint256 hi = available;
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 cost = _computeCostInternal(intercept, slope, s, mid);
            if (cost <= maxBase) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return lo;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFromFailed();
        }
    }

    function computeCost(uint256 launchId, uint256 n)
        external
        view
        returns (uint256)
    {
        return _computeCost(launchId, n);
    }

    function computeTokensForBase(uint256 launchId, uint256 maxBase)
        external
        view
        returns (uint256)
    {
        return _computeTokensForBase(launchId, maxBase);
    }

    function getWithdrawableTokens(uint256 launchId, address account)
        external
        view
        returns (uint256)
    {
        Participant storage p = _participants[launchId][account];
        return p.purchasedTokens - p.tokensWithdrawn;
    }

    function getClaimableFees(uint256 launchId, address account)
        external
        view
        returns (uint256)
    {
        Launch storage l = _launches[launchId];
        if (block.timestamp < l.endTime || l.soldTokens == 0) return 0;
        Participant storage p = _participants[launchId][account];
        uint256 share = (l.feesCollected * p.purchasedTokens) / l.soldTokens;
        return share - p.feeClaimed;
    }

    function getLaunchConfig(uint256 launchId)
        external
        view
        returns (
            address creator,
            address projectToken,
            address baseToken,
            uint256 slope,
            uint256 intercept,
            uint256 startTime,
            uint256 endTime,
            uint256 totalProjectTokens
        )
    {
        Launch storage l = _launches[launchId];
        creator = l.creator;
        projectToken = l.projectToken;
        baseToken = l.baseToken;
        slope = l.slope;
        intercept = l.intercept;
        startTime = l.startTime;
        endTime = l.endTime;
        totalProjectTokens = l.totalProjectTokens;
    }

    function getLaunchState(uint256 launchId)
        external
        view
        returns (
            uint256 soldTokens,
            uint256 baseCollected,
            uint256 feesCollected,
            bool unsoldWithdrawn,
            bool baseWithdrawn
        )
    {
        Launch storage l = _launches[launchId];
        soldTokens = l.soldTokens;
        baseCollected = l.baseCollected;
        feesCollected = l.feesCollected;
        unsoldWithdrawn = l.unsoldWithdrawn;
        baseWithdrawn = l.baseWithdrawn;
    }

    function getParticipant(uint256 launchId, address account)
        external
        view
        returns (uint256 purchasedTokens, uint256 tokensWithdrawn, uint256 feeClaimed)
    {
        Participant storage p = _participants[launchId][account];
        purchasedTokens = p.purchasedTokens;
        tokensWithdrawn = p.tokensWithdrawn;
        feeClaimed = p.feeClaimed;
    }
}
