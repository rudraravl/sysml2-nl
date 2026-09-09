// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract PredictionMarket is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidOutcome();
    error MarketNotFound();
    error MarketNotOpen();
    error MarketClosed();
    error MarketNotCancelled();
    error MarketNotResolved();
    error InsufficientStake();
    error NothingToClaim();
    error AlreadyClaimed();
    error ResolveTooEarly();
    error ZeroAmount();
    error NotOperator();
    error InsufficientFees();

    enum MarketStatus {
        Open,
        Resolved,
        Cancelled
    }

    struct Market {
        uint256 id;
        string description;
        uint256 outcomeCount;
        MarketStatus status;
        uint256 winningOutcome;
        uint256 createdAt;
        uint256 totalStaked;
        mapping(uint256 => uint256) totalStakedPerOutcome;
    }

    struct UserStake {
        uint256 totalStaked;
        mapping(uint256 => uint256) stakedPerOutcome;
        bool claimed;
    }

    IERC20 public immutable baseCurrency;
    address public operator;
    uint256 public creationFee;
    uint256 public accumulatedFees;
    uint256 public constant MIN_OPEN_DURATION = 24 hours;
    uint256 public constant ODDS_PRECISION = 1e18;
    uint256 private _nextMarketId;

    mapping(uint256 => Market) public markets;
    mapping(address => mapping(uint256 => UserStake)) private _userStakes;

    event MarketCreated(
        uint256 indexed marketId,
        string description,
        uint256 outcomeCount,
        address indexed creator,
        uint256 feePaid,
        uint256 createdAt
    );
    event StakePlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcome,
        uint256 amount,
        uint256 totalStakedForOutcome,
        uint256 totalStakedForMarket
    );
    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOutcome,
        uint256 totalStaked,
        uint256 winningPool
    );
    event MarketCancelled(uint256 indexed marketId, uint256 totalStaked);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event WithdrawnCancelled(uint256 indexed marketId, address indexed user, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event CreationFeeUpdated(uint256 previousFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId >= _nextMarketId) revert MarketNotFound();
        _;
    }

    constructor(address baseCurrency_, address operator_) Ownable(msg.sender) {
        if (baseCurrency_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(baseCurrency_);
        operator = operator_;
        creationFee = 1e17; // 0.1 units of base currency
    }

    function createMarket(string calldata description, uint256 outcomeCount)
        external
        returns (uint256 marketId)
    {
        if (outcomeCount < 2) revert InvalidOutcome();

        // Effects: register market before any external interaction.
        marketId = _nextMarketId++;
        Market storage m = markets[marketId];
        m.id = marketId;
        m.description = description;
        m.outcomeCount = outcomeCount;
        m.status = MarketStatus.Open;
        m.winningOutcome = type(uint256).max;
        m.createdAt = block.timestamp;
        m.totalStaked = 0;

        // Interaction: collect creation fee after state is updated.
        if (creationFee > 0) {
            baseCurrency.safeTransferFrom(msg.sender, address(this), creationFee);
            accumulatedFees += creationFee;
        }

        emit MarketCreated(marketId, description, outcomeCount, msg.sender, creationFee, block.timestamp);
    }

    function stake(uint256 marketId, uint256 outcome, uint256 amount)
        external
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketClosed();
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external transfer to prevent reentrancy.
        UserStake storage us = _userStakes[msg.sender][marketId];
        us.stakedPerOutcome[outcome] += amount;
        us.totalStaked += amount;
        m.totalStakedPerOutcome[outcome] += amount;
        m.totalStaked += amount;

        // Interaction: pull staked tokens from user.
        baseCurrency.safeTransferFrom(msg.sender, address(this), amount);

        emit StakePlaced(
            marketId,
            msg.sender,
            outcome,
            amount,
            m.totalStakedPerOutcome[outcome],
            m.totalStaked
        );
    }

    function withdrawCancelled(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Cancelled) revert MarketNotCancelled();

        UserStake storage us = _userStakes[msg.sender][marketId];
        uint256 amount = us.totalStaked;
        if (amount == 0) revert InsufficientStake();

        // Effects: zero out user stakes before transfer.
        us.totalStaked = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            us.stakedPerOutcome[i] = 0;
        }

        // Interaction
        baseCurrency.safeTransfer(msg.sender, amount);

        emit WithdrawnCancelled(marketId, msg.sender, amount);
    }

    function claimWinnings(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Resolved) revert MarketNotResolved();

        UserStake storage us = _userStakes[msg.sender][marketId];
        if (us.claimed) revert AlreadyClaimed();

        uint256 userStakeOnWinner = us.stakedPerOutcome[m.winningOutcome];
        uint256 winningPool = m.totalStakedPerOutcome[m.winningOutcome];

        if (userStakeOnWinner == 0 || winningPool == 0) revert NothingToClaim();

        uint256 payout = (userStakeOnWinner * m.totalStaked) / winningPool;

        // Effects: mark claimed before transfer.
        us.claimed = true;

        // Interaction
        if (payout > 0) {
            baseCurrency.safeTransfer(msg.sender, payout);
        }

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome)
        external
        onlyOperator
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (winningOutcome >= m.outcomeCount) revert InvalidOutcome();
        if (block.timestamp < m.createdAt + MIN_OPEN_DURATION) revert ResolveTooEarly();

        m.status = MarketStatus.Resolved;
        m.winningOutcome = winningOutcome;

        emit MarketResolved(
            marketId,
            winningOutcome,
            m.totalStaked,
            m.totalStakedPerOutcome[winningOutcome]
        );
    }

    function cancelMarket(uint256 marketId) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();

        m.status = MarketStatus.Cancelled;

        emit MarketCancelled(marketId, m.totalStaked);
    }

    function setCreationFee(uint256 newFee) external onlyOperator {
        uint256 previous = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(previous, newFee);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientFees();
        accumulatedFees -= amount;
        baseCurrency.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    function getMarketInfo(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            string memory description,
            uint256 outcomeCount,
            MarketStatus status,
            uint256 winningOutcome,
            uint256 createdAt,
            uint256 totalStaked
        )
    {
        Market storage m = markets[marketId];
        return (
            m.description,
            m.outcomeCount,
            m.status,
            m.winningOutcome,
            m.createdAt,
            m.totalStaked
        );
    }

    function getOutcomeTotalStaked(uint256 marketId, uint256 outcome)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        return markets[marketId].totalStakedPerOutcome[outcome];
    }

    function getOdds(uint256 marketId, uint256 outcome)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage m = markets[marketId];
        if (m.totalStaked == 0) return 0;
        return (m.totalStakedPerOutcome[outcome] * ODDS_PRECISION) / m.totalStaked;
    }

    function getUserStake(address user, uint256 marketId, uint256 outcome)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        return _userStakes[user][marketId].stakedPerOutcome[outcome];
    }

    function getUserTotalStake(address user, uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        return _userStakes[user][marketId].totalStaked;
    }

    function hasClaimed(address user, uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (bool)
    {
        return _userStakes[user][marketId].claimed;
    }

    function marketCount() external view returns (uint256) {
        return _nextMarketId;
    }
}
