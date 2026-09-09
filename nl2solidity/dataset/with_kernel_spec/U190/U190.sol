// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FROM_FAILED"
        );
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "Ownable: zero address");
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract TokenLaunchpad is Ownable {
    using SafeERC20 for IERC20;

    enum LaunchState { Idle, Active, Paused, Finalized, Closed }

    struct LaunchConfig {
        uint256 startTime;
        uint256 endTime;
        uint256 totalProjectTokens;
        uint256 targetBaseAmount;
        uint256 hardCap;
        uint256 minContribution;
        uint256 maxContribution;
        uint256 totalContributed;
        LaunchState state;
    }

    uint256 private constant MIN_CONTRIBUTION_PERIOD = 24 hours;
    uint256 public constant MAX_INDIVIDUAL_CAP = 1000 ether;

    IERC20 public immutable baseCurrency;
    IERC20 public projectToken;
    LaunchConfig public launch;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public hasClaimedTokens;
    mapping(address => uint256) public withdrawnExcess;

    uint256 public totalExcessWithdrawn;
    uint256 public totalTokensClaimed;
    bool public raisedBaseWithdrawn;
    bool public unclaimedTokensWithdrawn;

    error Unauthorized();
    error InvalidLaunchState();
    error InvalidParameters();
    error ContributionPeriodTooShort();
    error IndividualCapExceeded();
    error ContributionTooSmall();
    error ContributionTooLarge();
    error HardCapExceeded();
    error LaunchNotEnded();
    error NothingToClaim();
    error AlreadyClaimed();
    error NoExcessToWithdraw();
    error ZeroAddress();
    error ProjectTokenNotSet();
    error InsufficientProjectTokens();
    error ZeroAmount();
    error AlreadyWithdrawn();

    event LaunchStarted(
        uint256 indexed startTime,
        uint256 indexed endTime,
        uint256 totalProjectTokens,
        uint256 targetBaseAmount,
        uint256 hardCap
    );
    event LaunchPaused();
    event LaunchUnpaused();
    event LaunchFinalized(bool success, uint256 totalContributed);
    event LaunchClosed();
    event Contributed(address indexed account, uint256 amount);
    event TokensClaimed(address indexed account, uint256 tokenAmount);
    event ExcessWithdrawn(address indexed account, uint256 baseAmount);
    event ContributionLimitsUpdated(uint256 minContribution, uint256 maxContribution);
    event ProjectTokenUpdated(address indexed token);
    event ProjectTokensDeposited(uint256 amount);
    event RaisedBaseWithdrawn(address indexed recipient, uint256 amount);
    event UnclaimedTokensWithdrawn(address indexed recipient, uint256 amount);

    modifier onlyState(LaunchState _state) {
        if (launch.state != _state) revert InvalidLaunchState();
        _;
    }

    constructor(address _baseCurrency) Ownable(msg.sender) {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(_baseCurrency);
    }

    function startLaunch(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalProjectTokens,
        uint256 _targetBaseAmount,
        uint256 _hardCap,
        uint256 _minContribution,
        uint256 _maxContribution
    ) external onlyOwner onlyState(LaunchState.Idle) {
        if (_endTime <= _startTime) revert InvalidParameters();
        if (_endTime - _startTime < MIN_CONTRIBUTION_PERIOD) revert ContributionPeriodTooShort();
        if (_maxContribution > MAX_INDIVIDUAL_CAP) revert IndividualCapExceeded();
        if (_maxContribution < _minContribution) revert InvalidParameters();
        if (_totalProjectTokens == 0 || _targetBaseAmount == 0 || _hardCap == 0) revert ZeroAmount();
        if (_hardCap < _targetBaseAmount) revert InvalidParameters();

        launch = LaunchConfig({
            startTime: _startTime,
            endTime: _endTime,
            totalProjectTokens: _totalProjectTokens,
            targetBaseAmount: _targetBaseAmount,
            hardCap: _hardCap,
            minContribution: _minContribution,
            maxContribution: _maxContribution,
            totalContributed: 0,
            state: LaunchState.Active
        });

        raisedBaseWithdrawn = false;
        unclaimedTokensWithdrawn = false;
        totalExcessWithdrawn = 0;
        totalTokensClaimed = 0;

        emit LaunchStarted(_startTime, _endTime, _totalProjectTokens, _targetBaseAmount, _hardCap);
    }

    function setProjectToken(address _token) external onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        projectToken = IERC20(_token);
        emit ProjectTokenUpdated(_token);
    }

    function setContributionLimits(uint256 _minContribution, uint256 _maxContribution)
        external
        onlyOwner
        onlyState(LaunchState.Active)
    {
        if (_maxContribution > MAX_INDIVIDUAL_CAP) revert IndividualCapExceeded();
        if (_maxContribution < _minContribution) revert InvalidParameters();
        launch.minContribution = _minContribution;
        launch.maxContribution = _maxContribution;
        emit ContributionLimitsUpdated(_minContribution, _maxContribution);
    }

    function pause() external onlyOwner onlyState(LaunchState.Active) {
        launch.state = LaunchState.Paused;
        emit LaunchPaused();
    }

    function unpause() external onlyOwner onlyState(LaunchState.Paused) {
        launch.state = LaunchState.Active;
        emit LaunchUnpaused();
    }

    function finalize() external onlyOwner {
        LaunchConfig storage l = launch;
        if (l.state != LaunchState.Active && l.state != LaunchState.Paused) revert InvalidLaunchState();
        if (block.timestamp < l.endTime) revert LaunchNotEnded();

        bool success = l.totalContributed >= l.targetBaseAmount;
        l.state = LaunchState.Finalized;
        emit LaunchFinalized(success, l.totalContributed);
    }

    function closeLaunch() external onlyOwner onlyState(LaunchState.Finalized) {
        launch.state = LaunchState.Closed;
        emit LaunchClosed();
    }

    function depositProjectTokens(uint256 amount) external onlyOwner {
        if (address(projectToken) == address(0)) revert ProjectTokenNotSet();
        if (amount == 0) revert ZeroAmount();
        projectToken.safeTransferFrom(msg.sender, address(this), amount);
        emit ProjectTokensDeposited(amount);
    }

    function withdrawRaisedBase(address recipient) external onlyOwner onlyState(LaunchState.Closed) {
        if (recipient == address(0)) revert ZeroAddress();
        if (raisedBaseWithdrawn) revert AlreadyWithdrawn();
        raisedBaseWithdrawn = true;
        uint256 amount = launch.totalContributed - totalExcessWithdrawn;
        if (amount > 0) {
            baseCurrency.safeTransfer(recipient, amount);
        }
        emit RaisedBaseWithdrawn(recipient, amount);
    }

    function withdrawUnclaimedTokens(address recipient) external onlyOwner onlyState(LaunchState.Closed) {
        if (recipient == address(0)) revert ZeroAddress();
        if (address(projectToken) == address(0)) revert ProjectTokenNotSet();
        if (unclaimedTokensWithdrawn) revert AlreadyWithdrawn();
        unclaimedTokensWithdrawn = true;
        uint256 amount = launch.totalProjectTokens - totalTokensClaimed;
        if (amount > 0) {
            projectToken.safeTransfer(recipient, amount);
        }
        emit UnclaimedTokensWithdrawn(recipient, amount);
    }

    function contribute(uint256 amount) external onlyState(LaunchState.Active) {
        if (amount == 0) revert ZeroAmount();

        LaunchConfig storage l = launch;
        if (block.timestamp < l.startTime || block.timestamp > l.endTime) revert InvalidLaunchState();
        if (amount < l.minContribution) revert ContributionTooSmall();

        uint256 newContribution = contributions[msg.sender] + amount;
        if (newContribution > l.maxContribution) revert ContributionTooLarge();
        if (l.totalContributed + amount > l.hardCap) revert HardCapExceeded();

        contributions[msg.sender] = newContribution;
        l.totalContributed += amount;

        baseCurrency.safeTransferFrom(msg.sender, address(this), amount);
        emit Contributed(msg.sender, amount);
    }

    function claimTokens() external onlyState(LaunchState.Finalized) {
        if (address(projectToken) == address(0)) revert ProjectTokenNotSet();
        if (hasClaimedTokens[msg.sender]) revert AlreadyClaimed();

        LaunchConfig storage l = launch;
        uint256 contribution = contributions[msg.sender];
        if (contribution == 0) revert NothingToClaim();
        if (l.totalContributed < l.targetBaseAmount) revert NothingToClaim();

        uint256 tokenAmount = (contribution * l.totalProjectTokens) / l.totalContributed;
        if (tokenAmount == 0) revert NothingToClaim();
        if (projectToken.balanceOf(address(this)) < tokenAmount) revert InsufficientProjectTokens();

        hasClaimedTokens[msg.sender] = true;
        totalTokensClaimed += tokenAmount;
        projectToken.safeTransfer(msg.sender, tokenAmount);
        emit TokensClaimed(msg.sender, tokenAmount);
    }

    function withdrawExcess() external onlyState(LaunchState.Finalized) {
        LaunchConfig storage l = launch;
        uint256 contribution = contributions[msg.sender];
        if (contribution == 0) revert NoExcessToWithdraw();

        uint256 refundable = 0;
        if (l.totalContributed < l.targetBaseAmount) {
            refundable = contribution;
        } else {
            uint256 effectiveContribution =
                (contribution * l.targetBaseAmount) / l.totalContributed;
            if (contribution > effectiveContribution) {
                refundable = contribution - effectiveContribution;
            }
        }

        uint256 alreadyWithdrawn = withdrawnExcess[msg.sender];
        uint256 toWithdraw = refundable > alreadyWithdrawn
            ? refundable - alreadyWithdrawn
            : 0;
        if (toWithdraw == 0) revert NoExcessToWithdraw();

        withdrawnExcess[msg.sender] = alreadyWithdrawn + toWithdraw;
        totalExcessWithdrawn += toWithdraw;

        baseCurrency.safeTransfer(msg.sender, toWithdraw);
        emit ExcessWithdrawn(msg.sender, toWithdraw);
    }

    function claimableTokens(address account) external view returns (uint256) {
        if (launch.state != LaunchState.Finalized || hasClaimedTokens[account]) return 0;
        uint256 contribution = contributions[account];
        if (contribution == 0 || launch.totalContributed < launch.targetBaseAmount) return 0;
        return (contribution * launch.totalProjectTokens) / launch.totalContributed;
    }

    function withdrawableExcess(address account) external view returns (uint256) {
        if (launch.state != LaunchState.Finalized) return 0;
        uint256 contribution = contributions[account];
        if (contribution == 0) return 0;

        uint256 refundable = 0;
        if (launch.totalContributed < launch.targetBaseAmount) {
            refundable = contribution;
        } else {
            uint256 effective =
                (contribution * launch.targetBaseAmount) / launch.totalContributed;
            if (contribution > effective) {
                refundable = contribution - effective;
            }
        }
        uint256 alreadyWithdrawn = withdrawnExcess[account];
        return refundable > alreadyWithdrawn ? refundable - alreadyWithdrawn : 0;
    }

    function getLaunchInfo()
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 totalProjectTokens,
            uint256 targetBaseAmount,
            uint256 hardCap,
            uint256 minContribution,
            uint256 maxContribution,
            uint256 totalContributed,
            LaunchState state
        )
    {
        LaunchConfig storage l = launch;
        return (
            l.startTime,
            l.endTime,
            l.totalProjectTokens,
            l.targetBaseAmount,
            l.hardCap,
            l.minContribution,
            l.maxContribution,
            l.totalContributed,
            l.state
        );
    }
}
