// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOptionsExchange {
    function openAuction(
        address underlying,
        uint256 amount,
        uint256 strikePrice,
        uint256 expiry,
        bytes calldata params
    ) external returns (uint256 grossPremium);

    function settleAuction(uint256 auctionId) external returns (uint256 returnedUnderlying);
}

contract OptionsStrategyVault {
    // ----- Errors -----
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();
    error WithdrawalNotReady();
    error NoPendingWithdrawal();
    error FeeExceedsCap();
    error InvalidStrikePrice();
    error InvalidExpiry();
    error AuctionAlreadyExists();
    error AuctionNotFound();
    error AuctionAlreadySettled();
    error SettlementNotReady();
    error ReentrancyDetected();

    // ----- Constants -----
    uint256 public constant MAX_ROLLOVER_FEE_BPS = 50; // 0.5%
    uint256 public constant WITHDRAWAL_DELAY = 7 days;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ----- Token references -----
    IERC20 public immutable underlyingToken;
    IERC20 public immutable optionsToken;

    // ----- Access control -----
    address public owner;
    address public operator;
    address public optionsExchange;

    // ----- Fee & totals -----
    uint256 public rolloverFeeBps;
    uint256 public totalAssets;

    // ----- User balances -----
    mapping(address => uint256) public userBalance;

    struct PendingWithdrawal {
        uint256 amount;
        uint256 requestTime;
    }
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    // ----- Strategy config -----
    struct StrategyConfig {
        uint256 strikePrice;
        uint256 expiry;
        uint256 premiumCollected;
        bool active;
    }
    StrategyConfig public currentStrategy;

    // ----- Auction tracking -----
    struct AuctionInfo {
        uint256 auctionId;
        uint256 underlyingAmount;
        uint256 strikePrice;
        uint256 expiry;
        uint256 grossPremium;
        uint256 fee;
        uint256 netPremium;
        bool settled;
        bool exists;
    }
    mapping(uint256 => AuctionInfo) public auctions;
    uint256[] public auctionIds;

    // ----- Reentrancy guard -----
    uint256 private _locked = 1;

    // ----- Events -----
    event Deposit(address indexed user, uint256 amount, uint256 newTotalAssets);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 requestTime);
    event WithdrawalExecuted(address indexed user, uint256 amount);
    event StrategyRolloverCompleted(
        uint256 indexed auctionId,
        uint256 grossPremium,
        uint256 fee,
        uint256 netPremium,
        uint256 strikePrice,
        uint256 expiry
    );
    event AuctionInitiated(
        uint256 indexed auctionId,
        uint256 underlyingAmount,
        uint256 strikePrice,
        uint256 expiry,
        address indexed initiatedBy
    );
    event OptionsSettled(uint256 indexed auctionId, uint256 returnedUnderlying, address indexed settledBy);
    event RolloverFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OptionsExchangeUpdated(address oldExchange, address newExchange);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address oldOwner, address newOwner);

    // ----- Modifiers -----
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ----- Constructor -----
    constructor(
        address underlyingToken_,
        address optionsToken_,
        address optionsExchange_,
        address operator_,
        uint256 rolloverFeeBps_
    ) {
        if (underlyingToken_ == address(0)) revert ZeroAddress();
        if (optionsToken_ == address(0)) revert ZeroAddress();
        if (optionsExchange_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (rolloverFeeBps_ > MAX_ROLLOVER_FEE_BPS) revert FeeExceedsCap();

        underlyingToken = IERC20(underlyingToken_);
        optionsToken = IERC20(optionsToken_);
        optionsExchange = optionsExchange_;
        operator = operator_;
        rolloverFeeBps = rolloverFeeBps_;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OptionsExchangeUpdated(address(0), optionsExchange_);
        emit OperatorUpdated(address(0), operator_);
        emit RolloverFeeUpdated(0, rolloverFeeBps_);
    }

    // ----- Admin functions -----

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setRolloverFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_ROLLOVER_FEE_BPS) revert FeeExceedsCap();
        uint256 old = rolloverFeeBps;
        rolloverFeeBps = newFeeBps;
        emit RolloverFeeUpdated(old, newFeeBps);
    }

    function setOptionsExchange(address newExchange) external onlyOwner {
        if (newExchange == address(0)) revert ZeroAddress();
        address old = optionsExchange;
        optionsExchange = newExchange;
        emit OptionsExchangeUpdated(old, newExchange);
    }

    // ----- User functions -----

    function deposit(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();

        userBalance[msg.sender] += amount;
        totalAssets += amount;

        _safeTransferFrom(underlyingToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, totalAssets);
    }

    function requestWithdrawal(uint256 amount) external {
        if (amount < 1) revert ZeroAmount();

        PendingWithdrawal storage existing = pendingWithdrawals[msg.sender];
        if (existing.amount > 0) {
            userBalance[msg.sender] += existing.amount;
            totalAssets += existing.amount;
        }

        if (userBalance[msg.sender] < amount) revert InsufficientBalance();

        userBalance[msg.sender] -= amount;
        totalAssets -= amount;

        pendingWithdrawals[msg.sender] = PendingWithdrawal({
            amount: amount,
            requestTime: block.timestamp
        });

        emit WithdrawalRequested(msg.sender, amount, block.timestamp);
    }

    function withdraw() external nonReentrant {
        PendingWithdrawal storage pw = pendingWithdrawals[msg.sender];
        if (pw.amount < 1) revert NoPendingWithdrawal();
        if (block.timestamp < pw.requestTime + WITHDRAWAL_DELAY) revert WithdrawalNotReady();

        uint256 amount = pw.amount;
        pw.amount = 0;
        pw.requestTime = 0;

        _safeTransfer(underlyingToken, msg.sender, amount);

        emit WithdrawalExecuted(msg.sender, amount);
    }

    // ----- Strategy functions -----

    function initiateStrategyRollover(
        uint256 auctionId,
        uint256 strikePrice,
        uint256 expiry,
        bytes calldata exchangeParams
    ) external nonReentrant returns (uint256 grossPremium, uint256 fee, uint256 netPremium) {
        if (strikePrice < 1) revert InvalidStrikePrice();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        if (auctions[auctionId].exists) revert AuctionAlreadyExists();

        uint256 amountToDeploy = underlyingToken.balanceOf(address(this));
        if (amountToDeploy < 1) revert ZeroAmount();

        // ----- Effects (before external call) -----
        currentStrategy.strikePrice = strikePrice;
        currentStrategy.expiry = expiry;
        currentStrategy.active = true;

        AuctionInfo storage info = auctions[auctionId];
        info.auctionId = auctionId;
        info.underlyingAmount = amountToDeploy;
        info.strikePrice = strikePrice;
        info.expiry = expiry;
        info.exists = true;
        auctionIds.push(auctionId);

        // ----- Interactions -----
        grossPremium = IOptionsExchange(optionsExchange).openAuction(
            address(underlyingToken),
            amountToDeploy,
            strikePrice,
            expiry,
            exchangeParams
        );

        // ----- Effects (dependent on return value, protected by nonReentrant) -----
        fee = (grossPremium * rolloverFeeBps) / BPS_DENOMINATOR;
        netPremium = grossPremium - fee;

        info.grossPremium = grossPremium;
        info.fee = fee;
        info.netPremium = netPremium;

        currentStrategy.premiumCollected += netPremium;

        emit StrategyRolloverCompleted(auctionId, grossPremium, fee, netPremium, strikePrice, expiry);
    }

    function initiateAuction(
        uint256 auctionId,
        uint256 underlyingAmount,
        uint256 strikePrice,
        uint256 expiry,
        bytes calldata exchangeParams
    ) external onlyOperator nonReentrant returns (uint256 grossPremium) {
        if (strikePrice < 1) revert InvalidStrikePrice();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        if (underlyingAmount < 1) revert ZeroAmount();
        if (auctions[auctionId].exists) revert AuctionAlreadyExists();
        if (underlyingAmount > underlyingToken.balanceOf(address(this))) revert InsufficientBalance();

        // ----- Effects (before external call) -----
        AuctionInfo storage info = auctions[auctionId];
        info.auctionId = auctionId;
        info.underlyingAmount = underlyingAmount;
        info.strikePrice = strikePrice;
        info.expiry = expiry;
        info.exists = true;
        auctionIds.push(auctionId);

        currentStrategy.strikePrice = strikePrice;
        currentStrategy.expiry = expiry;
        currentStrategy.active = true;

        // ----- Interactions -----
        grossPremium = IOptionsExchange(optionsExchange).openAuction(
            address(underlyingToken),
            underlyingAmount,
            strikePrice,
            expiry,
            exchangeParams
        );

        // ----- Effects (dependent on return value, protected by nonReentrant) -----
        uint256 feeAmount = (grossPremium * rolloverFeeBps) / BPS_DENOMINATOR;
        uint256 netPremium = grossPremium - feeAmount;

        info.grossPremium = grossPremium;
        info.fee = feeAmount;
        info.netPremium = netPremium;

        currentStrategy.premiumCollected += netPremium;

        emit AuctionInitiated(auctionId, underlyingAmount, strikePrice, expiry, msg.sender);
        emit StrategyRolloverCompleted(auctionId, grossPremium, feeAmount, netPremium, strikePrice, expiry);
    }

    function settleExpiredOptions(uint256 auctionId)
        external
        onlyOperator
        nonReentrant
        returns (uint256 returnedUnderlying)
    {
        AuctionInfo storage info = auctions[auctionId];
        if (!info.exists) revert AuctionNotFound();
        if (info.settled) revert AuctionAlreadySettled();
        if (block.timestamp < info.expiry) revert SettlementNotReady();

        // ----- Effects (before external call) -----
        info.settled = true;
        currentStrategy.active = false;

        // ----- Interactions -----
        returnedUnderlying = IOptionsExchange(optionsExchange).settleAuction(auctionId);

        // ----- Effects (dependent on return value) -----
        totalAssets += returnedUnderlying;

        emit OptionsSettled(auctionId, returnedUnderlying, msg.sender);
    }

    // ----- View functions -----

    function pendingWithdrawalAmount(address user) external view returns (uint256) {
        return pendingWithdrawals[user].amount;
    }

    function pendingWithdrawalReadyAt(address user) external view returns (uint256) {
        uint256 amount = pendingWithdrawals[user].amount;
        if (amount > 0) {
            return pendingWithdrawals[user].requestTime + WITHDRAWAL_DELAY;
        }
        return 0;
    }

    function auctionCount() external view returns (uint256) {
        return auctionIds.length;
    }

    function getAuction(uint256 auctionId) external view returns (AuctionInfo memory) {
        return auctions[auctionId];
    }

    function currentStrategyConfig() external view returns (StrategyConfig memory) {
        return currentStrategy;
    }

    function vaultUnderlyingBalance() external view returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }

    function optionsTokenBalance() external view returns (uint256) {
        return optionsToken.balanceOf(address(this));
    }

    function computeRolloverFee(uint256 grossPremium) external view returns (uint256) {
        return (grossPremium * rolloverFeeBps) / BPS_DENOMINATOR;
    }

    // ----- Internal helpers -----

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
