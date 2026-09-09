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
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract Pausable {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    function _pause() internal {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract TokenLaunchpad is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error LaunchNotFound();
    error LaunchNotActive();
    error LaunchStillActive();
    error LaunchAlreadyFinalized();
    error DepositBelowMinimum();
    error DurationExceedsMaximum();
    error DurationIsZero();
    error ZeroAddress();
    error InvalidFeePercentage();
    error InvalidProjectTokenSupply();
    error NoContribution();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error NotLaunchCreator();
    error NothingToWithdraw();
    error NotOperator();

    struct Launch {
        address projectToken;
        address pool;
        address creator;
        uint256 startTime;
        uint256 endTime;
        uint256 totalBaseCollected;
        uint256 totalProjectTokens;
        bool finalized;
    }

    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 public constant MAX_DURATION = 30 days;
    uint256 public constant MAX_FEE_BPS = 5000;
    uint256 private constant FEE_DENOMINATOR = 10000;

    IERC20 public immutable baseToken;
    address public operator;
    uint256 public feeBps;

    uint256 public launchCount;
    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeePercentageUpdated(uint256 previousFeeBps, uint256 newFeeBps);
    event LaunchCreated(
        uint256 indexed launchId,
        address indexed creator,
        address indexed projectToken,
        address pool,
        uint256 startTime,
        uint256 endTime,
        uint256 totalProjectTokens
    );
    event Deposited(
        uint256 indexed launchId,
        address indexed depositor,
        uint256 baseAmount,
        uint256 totalBaseCollected
    );
    event Claimed(
        uint256 indexed launchId,
        address indexed claimant,
        uint256 projectTokenAmount
    );
    event Withdrawn(
        uint256 indexed launchId,
        address indexed user,
        uint256 baseAmount
    );
    event RemainingWithdrawn(
        uint256 indexed launchId,
        address indexed creator,
        uint256 baseAmount,
        uint256 feeAmount
    );

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier launchExists(uint256 launchId) {
        if (launchId >= launchCount) revert LaunchNotFound();
        _;
    }

    constructor(address _baseToken, address _operator, uint256 _feeBps) {
        if (_baseToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert InvalidFeePercentage();
        baseToken = IERC20(_baseToken);
        operator = _operator;
        feeBps = _feeBps;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setFeePercentage(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFeePercentage();
        emit FeePercentageUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function createLaunch(
        address projectToken,
        address pool,
        uint256 duration,
        uint256 totalProjectTokens
    ) external whenNotPaused returns (uint256 launchId) {
        if (projectToken == address(0) || pool == address(0)) revert ZeroAddress();
        if (duration == 0) revert DurationIsZero();
        if (duration > MAX_DURATION) revert DurationExceedsMaximum();
        if (totalProjectTokens == 0) revert InvalidProjectTokenSupply();

        IERC20(projectToken).safeTransferFrom(msg.sender, address(this), totalProjectTokens);

        launchId = launchCount++;
        uint256 startTime = block.timestamp;

        launches[launchId] = Launch({
            projectToken: projectToken,
            pool: pool,
            creator: msg.sender,
            startTime: startTime,
            endTime: startTime + duration,
            totalBaseCollected: 0,
            totalProjectTokens: totalProjectTokens,
            finalized: false
        });

        emit LaunchCreated(launchId, msg.sender, projectToken, pool, startTime, startTime + duration, totalProjectTokens);
    }

    function deposit(uint256 launchId, uint256 amount) external nonReentrant whenNotPaused launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (block.timestamp >= launch.endTime) revert LaunchNotActive();
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();

        baseToken.safeTransferFrom(msg.sender, address(this), amount);

        contributions[launchId][msg.sender] += amount;
        launch.totalBaseCollected += amount;

        emit Deposited(launchId, msg.sender, amount, launch.totalBaseCollected);
    }

    function claim(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (block.timestamp < launch.endTime) revert LaunchStillActive();
        if (hasClaimed[launchId][msg.sender]) revert AlreadyClaimed();
        if (hasWithdrawn[launchId][msg.sender]) revert NoContribution();

        uint256 userContribution = contributions[launchId][msg.sender];
        if (userContribution == 0) revert NoContribution();
        uint256 totalCollected = launch.totalBaseCollected;
        if (totalCollected == 0) revert NoContribution();

        hasClaimed[launchId][msg.sender] = true;

        uint256 projectTokenAmount = (userContribution * launch.totalProjectTokens) / totalCollected;

        IERC20(launch.projectToken).safeTransfer(msg.sender, projectTokenAmount);

        emit Claimed(launchId, msg.sender, projectTokenAmount);
    }

    function withdraw(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (block.timestamp < launch.endTime) revert LaunchStillActive();
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (hasClaimed[launchId][msg.sender]) revert AlreadyClaimed();
        if (hasWithdrawn[launchId][msg.sender]) revert AlreadyWithdrawn();

        uint256 amount = contributions[launchId][msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        hasWithdrawn[launchId][msg.sender] = true;
        contributions[launchId][msg.sender] = 0;
        launch.totalBaseCollected -= amount;

        baseToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(launchId, msg.sender, amount);
    }

    function withdrawRemaining(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (msg.sender != launch.creator) revert NotLaunchCreator();
        if (block.timestamp < launch.endTime) revert LaunchStillActive();
        if (launch.finalized) revert LaunchAlreadyFinalized();

        launch.finalized = true;

        uint256 totalCollected = launch.totalBaseCollected;
        if (totalCollected == 0) revert NothingToWithdraw();

        uint256 feeAmount = (totalCollected * feeBps) / FEE_DENOMINATOR;
        uint256 creatorAmount = totalCollected - feeAmount;

        if (feeAmount > 0) {
            baseToken.safeTransfer(owner(), feeAmount);
        }
        if (creatorAmount > 0) {
            baseToken.safeTransfer(launch.creator, creatorAmount);
        }

        emit RemainingWithdrawn(launchId, launch.creator, creatorAmount, feeAmount);
    }

    function getLaunch(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (
            address projectToken,
            address pool,
            address creator,
            uint256 startTime,
            uint256 endTime,
            uint256 totalBaseCollected,
            uint256 totalProjectTokens,
            bool finalized
        )
    {
        Launch storage launch = launches[launchId];
        return (
            launch.projectToken,
            launch.pool,
            launch.creator,
            launch.startTime,
            launch.endTime,
            launch.totalBaseCollected,
            launch.totalProjectTokens,
            launch.finalized
        );
    }

    function getContribution(uint256 launchId, address account) external view launchExists(launchId) returns (uint256) {
        return contributions[launchId][account];
    }

    function hasUserClaimed(uint256 launchId, address account) external view launchExists(launchId) returns (bool) {
        return hasClaimed[launchId][account];
    }

    function hasUserWithdrawn(uint256 launchId, address account) external view launchExists(launchId) returns (bool) {
        return hasWithdrawn[launchId][account];
    }

    function previewClaim(uint256 launchId, address account) external view launchExists(launchId) returns (uint256) {
        Launch storage launch = launches[launchId];
        uint256 userContribution = contributions[launchId][account];
        if (userContribution == 0 || launch.totalBaseCollected == 0) return 0;
        return (userContribution * launch.totalProjectTokens) / launch.totalBaseCollected;
    }
}
