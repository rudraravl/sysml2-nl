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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(address(token).code.length > 0, "SafeERC20: address is not a contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(address(token).code.length > 0, "SafeERC20: address is not a contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
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

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }
}

contract ArtistHypePredictionMarket is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakeToken;
    address public treasury;
    address public operator;

    uint256 public constant MIN_STAKE = 100;
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    enum Outcome {
        None,
        ArtistA,
        ArtistB,
        Draw
    }

    struct Market {
        address artistA;
        address artistB;
        uint256 startTime;
        uint256 endTime;
        uint256 totalStakedA;
        uint256 totalStakedB;
        bool resolved;
        Outcome winner;
        uint256 hypeScoreA;
        uint256 hypeScoreB;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public stakedOnA;
    mapping(uint256 => mapping(address => uint256)) public stakedOnB;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    uint256 public marketCount;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed artistA,
        address indexed artistB,
        uint256 startTime,
        uint256 endTime
    );
    event Staked(
        uint256 indexed marketId,
        address indexed user,
        Outcome indexed outcome,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        Outcome winner,
        uint256 hypeScoreA,
        uint256 hypeScoreB
    );
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 payout, uint256 fee);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error CallerNotOperator();
    error MarketDoesNotExist();
    error MarketAlreadyResolved();
    error MarketNotActive();
    error MarketNotEnded();
    error InvalidArtists();
    error InvalidDuration();
    error InvalidStartTime();
    error InvalidOutcome();
    error BelowMinimumStake();
    error NoStakeToClaim();
    error NoStakeOnWinner();
    error AlreadyClaimed();
    error ZeroAddress();
    error ReentrantCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert CallerNotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor(
        address _stakeToken,
        address _treasury,
        address _operator
    ) Ownable(msg.sender) {
        if (_stakeToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stakeToken = IERC20(_stakeToken);
        treasury = _treasury;
        operator = _operator;
        _reentrancyStatus = _NOT_ENTERED;
    }

    function createMarket(
        address _artistA,
        address _artistB,
        uint256 _startTime,
        uint256 _duration
    ) external onlyOperator returns (uint256 marketId) {
        if (_artistA == address(0) || _artistB == address(0)) revert ZeroAddress();
        if (_artistA == _artistB) revert InvalidArtists();
        if (_duration == 0) revert InvalidDuration();
        if (_startTime < block.timestamp) revert InvalidStartTime();

        marketId = marketCount++;
        Market storage m = markets[marketId];
        m.artistA = _artistA;
        m.artistB = _artistB;
        m.startTime = _startTime;
        m.endTime = _startTime + _duration;

        emit MarketCreated(marketId, _artistA, _artistB, m.startTime, m.endTime);
    }

    function stake(
        uint256 marketId,
        Outcome outcome,
        uint256 amount
    ) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.artistA == address(0)) revert MarketDoesNotExist();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome != Outcome.ArtistA && outcome != Outcome.ArtistB) revert InvalidOutcome();
        if (block.timestamp < m.startTime || block.timestamp > m.endTime) revert MarketNotActive();
        if (amount < MIN_STAKE) revert BelowMinimumStake();

        // Effects: update state before external call (checks-effects-interactions)
        if (outcome == Outcome.ArtistA) {
            stakedOnA[marketId][msg.sender] += amount;
            m.totalStakedA += amount;
        } else {
            stakedOnB[marketId][msg.sender] += amount;
            m.totalStakedB += amount;
        }

        // Interactions: transfer tokens after state is committed
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(marketId, msg.sender, outcome, amount);
    }

    function resolveMarket(
        uint256 marketId,
        uint256 _hypeScoreA,
        uint256 _hypeScoreB
    ) external onlyOperator {
        Market storage m = markets[marketId];
        if (m.artistA == address(0)) revert MarketDoesNotExist();
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp <= m.endTime) revert MarketNotEnded();

        m.hypeScoreA = _hypeScoreA;
        m.hypeScoreB = _hypeScoreB;
        if (_hypeScoreA > _hypeScoreB) {
            m.winner = Outcome.ArtistA;
        } else if (_hypeScoreB > _hypeScoreA) {
            m.winner = Outcome.ArtistB;
        } else {
            m.winner = Outcome.Draw;
        }
        m.resolved = true;

        emit MarketResolved(marketId, m.winner, _hypeScoreA, _hypeScoreB);
    }

    function claimWinnings(uint256 marketId) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.artistA == address(0)) revert MarketDoesNotExist();
        if (!m.resolved) revert MarketNotEnded();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        // Effects: mark as claimed before any external calls
        hasClaimed[marketId][msg.sender] = true;

        if (m.winner == Outcome.Draw) {
            uint256 userStakeA = stakedOnA[marketId][msg.sender];
            uint256 userStakeB = stakedOnB[marketId][msg.sender];
            uint256 refund = userStakeA + userStakeB;
            if (refund == 0) revert NoStakeToClaim();

            // Interactions
            stakeToken.safeTransfer(msg.sender, refund);
            emit WinningsClaimed(marketId, msg.sender, refund, 0);
            return;
        }

        uint256 userStake;
        uint256 winningPool;
        uint256 losingPool;

        if (m.winner == Outcome.ArtistA) {
            userStake = stakedOnA[marketId][msg.sender];
            winningPool = m.totalStakedA;
            losingPool = m.totalStakedB;
        } else {
            userStake = stakedOnB[marketId][msg.sender];
            winningPool = m.totalStakedB;
            losingPool = m.totalStakedA;
        }

        if (userStake == 0) revert NoStakeOnWinner();
        if (winningPool == 0) revert NoStakeOnWinner();

        // Compute profit: userStake * losingPool / winningPool
        // Compute fee on profit using full precision (multiply all numerators before dividing)
        // to avoid divide-before-multiply precision loss:
        //   fee = userStake * losingPool * FEE_BPS / (winningPool * BPS_DENOMINATOR)
        uint256 profit = (userStake * losingPool) / winningPool;
        uint256 fee = (userStake * losingPool * FEE_BPS) / (winningPool * BPS_DENOMINATOR);
        uint256 payout = userStake + profit - fee;

        // Interactions
        if (fee > 0) {
            stakeToken.safeTransfer(treasury, fee);
        }
        if (payout > 0) {
            stakeToken.safeTransfer(msg.sender, payout);
        }

        emit WinningsClaimed(marketId, msg.sender, payout, fee);
    }

    function getMarket(uint256 marketId)
        external
        view
        returns (
            address artistA,
            address artistB,
            uint256 startTime,
            uint256 endTime,
            uint256 totalStakedA,
            uint256 totalStakedB,
            bool resolved,
            Outcome winner,
            uint256 hypeScoreA,
            uint256 hypeScoreB
        )
    {
        Market storage m = markets[marketId];
        return (
            m.artistA,
            m.artistB,
            m.startTime,
            m.endTime,
            m.totalStakedA,
            m.totalStakedB,
            m.resolved,
            m.winner,
            m.hypeScoreA,
            m.hypeScoreB
        );
    }

    function getUserStake(uint256 marketId, address user)
        external
        view
        returns (uint256 stakeA, uint256 stakeB)
    {
        return (stakedOnA[marketId][user], stakedOnB[marketId][user]);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address previous = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(previous, _treasury);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _operator;
        emit OperatorUpdated(previous, _operator);
    }
}
