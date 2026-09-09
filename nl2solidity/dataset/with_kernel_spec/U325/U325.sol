// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Token {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeTokenTransfer {
    function safeTransfer(IERC20Token token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20Token.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeTokenTransfer: transfer failed");
    }

    function safeTransferFrom(IERC20Token token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20Token.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeTokenTransfer: transferFrom failed");
    }
}

contract TokenLaunchpad {
    using SafeTokenTransfer for IERC20Token;

    error LaunchNotExists();
    error DepositWindowClosed();
    error LaunchPaused();
    error LaunchNotPaused();
    error LaunchNotFinalized();
    error LaunchAlreadyFinalized();
    error LaunchStillActive();
    error BelowMinimumDeposit();
    error ZeroAddress();
    error NotOperator();
    error NotOwner();
    error NothingToClaim();
    error NothingToWithdraw();
    error InvalidParameters();
    error NoDeposits();
    error ReentrantCall();

    uint256 public constant FEE_BPS = 500;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;

    address public immutable baseCurrency;
    address public treasury;
    address public operator;
    address public owner;
    uint256 public launchCounter;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    struct Launch {
        address projectToken;
        address projectOwner;
        uint256 tokenSupply;
        uint256 targetRaise;
        uint256 startTime;
        uint256 endTime;
        uint256 totalDeposited;
        uint256 tokensPerBase;
        uint256 baseUsedFraction;
        bool finalized;
        bool paused;
        bool exists;
    }

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public deposits;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawnExcess;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LaunchStarted(
        uint256 indexed launchId,
        address indexed projectToken,
        address indexed projectOwner,
        uint256 tokenSupply,
        uint256 targetRaise,
        uint256 startTime,
        uint256 endTime
    );
    event Deposited(uint256 indexed launchId, address indexed user, uint256 amount, uint256 fee);
    event TokensClaimed(uint256 indexed launchId, address indexed user, uint256 tokenAmount);
    event ExcessWithdrawn(uint256 indexed launchId, address indexed user, uint256 baseAmount);
    event LaunchFinalized(
        uint256 indexed launchId,
        uint256 totalDeposited,
        uint256 tokensPerBase,
        uint256 baseUsedFraction,
        uint256 baseToProject
    );
    event LaunchPaused(uint256 indexed launchId);
    event LaunchUnpaused(uint256 indexed launchId);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier launchExists(uint256 launchId) {
        if (!launches[launchId].exists) revert LaunchNotExists();
        _;
    }

    constructor(address _baseCurrency, address _treasury, address _operator) {
        if (_baseCurrency == address(0) || _treasury == address(0) || _operator == address(0))
            revert ZeroAddress();
        baseCurrency = _baseCurrency;
        treasury = _treasury;
        operator = _operator;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function createLaunch(
        address _projectToken,
        address _projectOwner,
        uint256 _tokenSupply,
        uint256 _targetRaise,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOperator returns (uint256 launchId) {
        if (_projectToken == address(0) || _projectOwner == address(0)) revert ZeroAddress();
        if (_tokenSupply == 0 || _targetRaise == 0) revert InvalidParameters();
        if (_endTime <= _startTime) revert InvalidParameters();
        if (_startTime < block.timestamp) revert InvalidParameters();

        launchId = ++launchCounter;
        Launch storage l = launches[launchId];
        l.projectToken = _projectToken;
        l.projectOwner = _projectOwner;
        l.tokenSupply = _tokenSupply;
        l.targetRaise = _targetRaise;
        l.startTime = _startTime;
        l.endTime = _endTime;
        l.exists = true;

        IERC20Token(_projectToken).safeTransferFrom(msg.sender, address(this), _tokenSupply);

        emit LaunchStarted(
            launchId,
            _projectToken,
            _projectOwner,
            _tokenSupply,
            _targetRaise,
            _startTime,
            _endTime
        );
    }

    function finalizeLaunch(uint256 launchId) external onlyOperator launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (l.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < l.endTime) revert LaunchStillActive();

        uint256 totalDeposited = l.totalDeposited;
        uint256 targetRaise = l.targetRaise;
        uint256 tokenSupply = l.tokenSupply;

        if (totalDeposited == 0) {
            l.finalized = true;
            IERC20Token(l.projectToken).safeTransfer(l.projectOwner, tokenSupply);
            emit LaunchFinalized(launchId, 0, 0, 0, 0);
            return;
        }

        l.tokensPerBase = (tokenSupply * PRECISION) / totalDeposited;

        if (totalDeposited > targetRaise) {
            l.baseUsedFraction = (targetRaise * PRECISION) / totalDeposited;
        } else {
            l.baseUsedFraction = PRECISION;
        }

        uint256 baseToProject = totalDeposited > targetRaise ? targetRaise : totalDeposited;
        IERC20Token(baseCurrency).safeTransfer(l.projectOwner, baseToProject);

        l.finalized = true;

        emit LaunchFinalized(
            launchId,
            totalDeposited,
            l.tokensPerBase,
            l.baseUsedFraction,
            baseToProject
        );
    }

    function pauseLaunch(uint256 launchId) external onlyOperator launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (l.paused) revert LaunchPaused();
        l.paused = true;
        emit LaunchPaused(launchId);
    }

    function unpauseLaunch(uint256 launchId) external onlyOperator launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (!l.paused) revert LaunchNotPaused();
        l.paused = false;
        emit LaunchUnpaused(launchId);
    }

    function deposit(uint256 launchId, uint256 amount)
        external
        nonReentrant
        launchExists(launchId)
    {
        Launch storage l = launches[launchId];
        if (l.finalized) revert LaunchAlreadyFinalized();
        if (l.paused) revert LaunchPaused();
        if (block.timestamp < l.startTime || block.timestamp > l.endTime) revert DepositWindowClosed();
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOM;
        uint256 net = amount - fee;

        IERC20Token(baseCurrency).safeTransferFrom(msg.sender, address(this), amount);
        IERC20Token(baseCurrency).safeTransfer(treasury, fee);

        deposits[launchId][msg.sender] += net;
        l.totalDeposited += net;

        emit Deposited(launchId, msg.sender, net, fee);
    }

    function claimTokens(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (!l.finalized) revert LaunchNotFinalized();
        if (l.totalDeposited == 0) revert NoDeposits();
        if (hasClaimed[launchId][msg.sender]) revert NothingToClaim();

        uint256 userDeposit = deposits[launchId][msg.sender];
        if (userDeposit == 0) revert NothingToClaim();

        uint256 tokenAmount = (userDeposit * l.tokensPerBase) / PRECISION;
        if (tokenAmount == 0) revert NothingToClaim();

        hasClaimed[launchId][msg.sender] = true;
        IERC20Token(l.projectToken).safeTransfer(msg.sender, tokenAmount);

        emit TokensClaimed(launchId, msg.sender, tokenAmount);
    }

    function withdrawExcess(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (!l.finalized) revert LaunchNotFinalized();
        if (l.totalDeposited == 0) revert NoDeposits();
        if (hasWithdrawnExcess[launchId][msg.sender]) revert NothingToWithdraw();

        uint256 userDeposit = deposits[launchId][msg.sender];
        if (userDeposit == 0) revert NothingToWithdraw();

        uint256 excess = (userDeposit * (PRECISION - l.baseUsedFraction)) / PRECISION;
        if (excess == 0) revert NothingToWithdraw();

        hasWithdrawnExcess[launchId][msg.sender] = true;
        IERC20Token(baseCurrency).safeTransfer(msg.sender, excess);

        emit ExcessWithdrawn(launchId, msg.sender, excess);
    }

    function getLaunch(uint256 launchId) external view launchExists(launchId) returns (Launch memory) {
        return launchess[launchId];
    }

    function pendingTokens(uint256 launchId, address user)
        external
        view
        launchExists(launchId)
        returns (uint256)
    {
        Launch storage l = launches[launchId];
        if (!l.finalized || l.totalDeposited == 0) return 0;
        return (deposits[launchId][user] * l.tokensPerBase) / PRECISION;
    }

    function pendingExcess(uint256 launchId, address user)
        external
        view
        launchExists(launchId)
        returns (uint256)
    {
        Launch storage l = launches[launchId];
        if (!l.finalized || l.totalDeposited == 0) return 0;
        return (deposits[launchId][user] * (PRECISION - l.baseUsedFraction)) / PRECISION;
    }
}
