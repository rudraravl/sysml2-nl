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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        if (_msgSender() != _owner) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract CrashPredictionGame is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_BET_BASE = 10;
    uint256 public constant FEE_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_MULTIPLIER = 1000 * PRECISION;

    IERC20 public immutable stablecoin;
    uint256 public immutable minBet;

    address public operator;

    uint256 public currentRound;
    uint256 public lastCrashMultiplier;
    uint256 public houseLiquidityPool;
    uint256 public totalActiveBets;

    struct Player {
        uint256 balance;
        uint256 activeRound;
        uint256 betAmount;
        uint256 targetMultiplier;
    }

    mapping(address => Player) public players;
    mapping(uint256 => bytes32) public roundCommitHash;
    mapping(uint256 => bool) public roundEnded;
    mapping(uint256 => uint256) public roundOutcome;

    event RoundStarted(uint256 indexed round, bytes32 commitHash);
    event RoundEnded(uint256 indexed round, uint256 crashMultiplier);
    event BetPlaced(address indexed player, uint256 indexed round, uint256 amount, uint256 targetMultiplier);
    event CashedOut(address indexed player, uint256 indexed round, bool won, uint256 payout, uint256 fee);
    event Deposited(address indexed player, uint256 amount);
    event Withdrawn(address indexed player, uint256 amount);
    event HouseLiquidityAdded(address indexed depositor, uint256 amount);
    event HouseLiquidityWithdrawn(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error RoundNotActive();
    error RoundNotEnded();
    error RoundAlreadyEnded();
    error NoActiveBet();
    error BetAlreadyPlaced();
    error BetTooSmall();
    error InsufficientBalance();
    error InsufficientHouseLiquidity();
    error InvalidReveal();
    error InvalidTargetMultiplier();
    error ZeroAddress();
    error ZeroAmount();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        minBet = MIN_BET_BASE * (10 ** uint256(IERC20Metadata(_stablecoin).decimals()));
    }

    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _newOperator;
        emit OperatorUpdated(previous, _newOperator);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        players[msg.sender].balance += amount;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Player storage p = players[msg.sender];
        if (p.balance < amount) revert InsufficientBalance();
        p.balance -= amount;
        stablecoin.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function placeBet(uint256 amount, uint256 targetMultiplier) external nonReentrant {
        if (amount < minBet) revert BetTooSmall();
        if (currentRound == 0 || roundEnded[currentRound]) revert RoundNotActive();
        if (targetMultiplier < PRECISION || targetMultiplier > MAX_MULTIPLIER) revert InvalidTargetMultiplier();

        Player storage p = players[msg.sender];
        if (p.betAmount > 0) revert BetAlreadyPlaced();
        if (p.balance < amount) revert InsufficientBalance();

        p.balance -= amount;
        p.betAmount = amount;
        p.targetMultiplier = targetMultiplier;
        p.activeRound = currentRound;
        totalActiveBets += amount;

        emit BetPlaced(msg.sender, currentRound, amount, targetMultiplier);
    }

    function cashOut() external nonReentrant {
        Player storage p = players[msg.sender];
        if (p.betAmount == 0) revert NoActiveBet();
        if (!roundEnded[p.activeRound]) revert RoundNotEnded();

        uint256 crash = roundOutcome[p.activeRound];
        uint256 betAmount = p.betAmount;
        uint256 target = p.targetMultiplier;
        uint256 activeRound = p.activeRound;

        totalActiveBets -= betAmount;
        p.betAmount = 0;
        p.targetMultiplier = 0;
        p.activeRound = 0;

        if (crash >= target) {
            uint256 grossPayout = (betAmount * target) / PRECISION;
            uint256 profit = grossPayout - betAmount;
            uint256 fee = (profit * FEE_BPS) / BPS_DENOMINATOR;
            uint256 netPayout = grossPayout - fee;

            uint256 availableForPayout = houseLiquidityPool + betAmount;
            if (availableForPayout < netPayout) revert InsufficientHouseLiquidity();
            houseLiquidityPool = availableForPayout - netPayout;
            p.balance += netPayout;

            emit CashedOut(msg.sender, activeRound, true, netPayout, fee);
        } else {
            houseLiquidityPool += betAmount;
            emit CashedOut(msg.sender, activeRound, false, 0, 0);
        }
    }

    function startRound(bytes32 commitHash) external onlyOperator {
        currentRound++;
        roundCommitHash[currentRound] = commitHash;
        roundEnded[currentRound] = false;
        emit RoundStarted(currentRound, commitHash);
    }

    function setRoundOutcome(bytes32 revealSeed) external onlyOperator {
        if (currentRound == 0 || roundEnded[currentRound]) revert RoundAlreadyEnded();
        if (keccak256(abi.encodePacked(revealSeed)) != roundCommitHash[currentRound]) revert InvalidReveal();

        uint256 range = MAX_MULTIPLIER - PRECISION;
        uint256 crashMultiplier = PRECISION + (uint256(keccak256(abi.encodePacked(revealSeed, currentRound))) % range);

        roundOutcome[currentRound] = crashMultiplier;
        lastCrashMultiplier = crashMultiplier;
        roundEnded[currentRound] = true;

        emit RoundEnded(currentRound, crashMultiplier);
    }

    function depositHouseLiquidity(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        houseLiquidityPool += amount;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit HouseLiquidityAdded(msg.sender, amount);
    }

    function withdrawHouseLiquidity(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (houseLiquidityPool < amount) revert InsufficientHouseLiquidity();
        houseLiquidityPool -= amount;
        stablecoin.safeTransfer(msg.sender, amount);
        emit HouseLiquidityWithdrawn(msg.sender, amount);
    }

    function getPlayer(address player)
        external
        view
        returns (
            uint256 balance,
            uint256 activeRound,
            uint256 betAmount,
            uint256 targetMultiplier
        )
    {
        Player storage p = players[player];
        return (p.balance, p.activeRound, p.betAmount, p.targetMultiplier);
    }

    function getRoundInfo(uint256 round)
        external
        view
        returns (
            bytes32 commitHash,
            bool ended,
            uint256 crashMultiplier
        )
    {
        return (roundCommitHash[round], roundEnded[round], roundOutcome[round]);
    }

    function getHouseLiquidityAvailable() external view returns (uint256) {
        return houseLiquidityPool;
    }

    function getTotalActiveBets() external view returns (uint256) {
        return totalActiveBets;
    }
}
