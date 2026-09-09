// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_TARGET = 100 ether;
    uint256 public constant MAX_CONTRIBUTION = 1000 ether;
    uint256 private constant PRECISION = 1 ether;

    enum LaunchState { Active, Finalized, Cancelled }

    struct Launch {
        address token;
        uint256 minTarget;
        uint256 totalRaised;
        uint256 startTime;
        uint256 endTime;
        uint256 tokensPerBaseUnit;
        LaunchState state;
    }

    IERC20 public immutable baseToken;
    address public operator;

    mapping(uint256 => Launch) private launches;
    mapping(uint256 => mapping(address => uint256)) private contributions;
    mapping(uint256 => mapping(address => bool)) private claimed;
    uint256 public launchCount;

    event LaunchStarted(
        uint256 indexed launchId,
        address indexed token,
        uint256 minTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 tokensPerBaseUnit
    );
    event LaunchParametersUpdated(
        uint256 indexed launchId,
        uint256 minTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 tokensPerBaseUnit
    );
    event Contributed(
        uint256 indexed launchId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );
    event TokensClaimed(uint256 indexed launchId, address indexed contributor, uint256 tokenAmount);
    event BaseWithdrawn(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, uint256 totalRaised, uint256 totalTokensMinted);
    event LaunchCancelled(uint256 indexed launchId);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error LaunchNotActive();
    error LaunchActive();
    error LaunchNotFinalized();
    error LaunchNotCancelled();
    error LaunchNotFound(uint256 launchId);
    error TargetTooLow(uint256 provided, uint256 minimum);
    error ContributionExceedsMax(uint256 provided, uint256 maximum);
    error AlreadyClaimed();
    error NothingToClaim();
    error NothingToWithdraw();
    error ZeroAddress();
    error InvalidTimeRange();
    error InvalidAmount();
    error LaunchNotStarted();
    error LaunchEnded();
    error LaunchNotEnded();
    error TargetNotMet(uint256 raised, uint256 target);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier launchExists(uint256 launchId) {
        if (launchId >= launchCount) revert LaunchNotFound(launchId);
        _;
    }

    constructor(address _baseToken, address _operator) Ownable(msg.sender) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function startLaunch(
        address token,
        uint256 _minTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 tokensPerBaseUnit
    ) external onlyOperator returns (uint256 launchId) {
        if (token == address(0)) revert ZeroAddress();
        if (_minTarget < MIN_TARGET) revert TargetTooLow(_minTarget, MIN_TARGET);
        if (tokensPerBaseUnit == 0) revert InvalidAmount();
        if (startTime < block.timestamp) revert InvalidTimeRange();
        if (endTime <= startTime) revert InvalidTimeRange();

        launchId = launchCount++;
        launches[launchId] = Launch({
            token: token,
            minTarget: _minTarget,
            totalRaised: 0,
            startTime: startTime,
            endTime: endTime,
            tokensPerBaseUnit: tokensPerBaseUnit,
            state: LaunchState.Active
        });

        emit LaunchStarted(launchId, token, _minTarget, startTime, endTime, tokensPerBaseUnit);
    }

    function setLaunchParameters(
        uint256 launchId,
        uint256 _minTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 tokensPerBaseUnit
    ) external onlyOperator launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Active) revert LaunchNotActive();
        if (launch.totalRaised > 0) revert LaunchActive();
        if (_minTarget < MIN_TARGET) revert TargetTooLow(_minTarget, MIN_TARGET);
        if (tokensPerBaseUnit == 0) revert InvalidAmount();
        if (startTime < block.timestamp) revert InvalidTimeRange();
        if (endTime <= startTime) revert InvalidTimeRange();

        launch.minTarget = _minTarget;
        launch.startTime = startTime;
        launch.endTime = endTime;
        launch.tokensPerBaseUnit = tokensPerBaseUnit;

        emit LaunchParametersUpdated(launchId, _minTarget, startTime, endTime, tokensPerBaseUnit);
    }

    function contribute(uint256 launchId, uint256 amount) external nonReentrant launchExists(launchId) {
        if (amount == 0) revert InvalidAmount();
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Active) revert LaunchNotActive();
        if (block.timestamp < launch.startTime) revert LaunchNotStarted();
        if (block.timestamp > launch.endTime) revert LaunchEnded();

        uint256 newContribution = contributions[launchId][msg.sender] + amount;
        if (newContribution > MAX_CONTRIBUTION) {
            revert ContributionExceedsMax(newContribution, MAX_CONTRIBUTION);
        }

        contributions[launchId][msg.sender] = newContribution;
        launch.totalRaised += amount;

        baseToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Contributed(launchId, msg.sender, amount, launch.totalRaised);
    }

    function finalizeLaunch(uint256 launchId) external onlyOperator launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Active) revert LaunchNotActive();
        if (block.timestamp <= launch.endTime) revert LaunchNotEnded();
        if (launch.totalRaised < launch.minTarget) {
            revert TargetNotMet(launch.totalRaised, launch.minTarget);
        }

        uint256 totalTokens = (launch.totalRaised * launch.tokensPerBaseUnit) / PRECISION;
        launch.state = LaunchState.Finalized;

        IMintableToken(launch.token).mint(address(this), totalTokens);

        emit LaunchFinalized(launchId, launch.totalRaised, totalTokens);
    }

    function cancelLaunch(uint256 launchId) external onlyOperator launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Active) revert LaunchNotActive();
        launch.state = LaunchState.Cancelled;
        emit LaunchCancelled(launchId);
    }

    function claimTokens(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Finalized) revert LaunchNotFinalized();
        if (claimed[launchId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToClaim();

        claimed[launchId][msg.sender] = true;
        uint256 tokenAmount = (contribution * launch.tokensPerBaseUnit) / PRECISION;
        IERC20(launch.token).safeTransfer(msg.sender, tokenAmount);

        emit TokensClaimed(launchId, msg.sender, tokenAmount);
    }

    function withdrawBase(uint256 launchId) external nonReentrant launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Cancelled) revert LaunchNotCancelled();

        uint256 contribution = contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToWithdraw();

        contributions[launchId][msg.sender] = 0;
        baseToken.safeTransfer(msg.sender, contribution);

        emit BaseWithdrawn(launchId, msg.sender, contribution);
    }

    function getLaunch(uint256 launchId) external view launchExists(launchId) returns (Launch memory) {
        return launches[launchId];
    }

    function getContribution(uint256 launchId, address account) external view launchExists(launchId) returns (uint256) {
        return contributions[launchId][account];
    }

    function getAllocatedTokens(uint256 launchId, address account) external view launchExists(launchId) returns (uint256) {
        Launch storage launch = launches[launchId];
        if (launch.state != LaunchState.Finalized) return 0;
        return (contributions[launchId][account] * launch.tokensPerBaseUnit) / PRECISION;
    }

    function hasClaimed(uint256 launchId, address account) external view launchExists(launchId) returns (bool) {
        return claimed[launchId][account];
    }
}
