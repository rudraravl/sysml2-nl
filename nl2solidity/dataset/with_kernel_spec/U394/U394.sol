// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CreatorTimeToken
 * @dev Tokenizes a creator's time, measured in minutes. Holders can buy, sell,
 *      and redeem time tokens. A 5% fee applies to buy and sell transactions
 *      and is custodied on behalf of the creator. Redemption draws from a
 *      separate creator-funded pool at the current price with no fee.
 */
contract CreatorTimeToken {
    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------
    error NotCreator();
    error TradingPaused();
    error InitialSupplyAlreadySet();
    error InvalidSupply();
    error ZeroAmount();
    error ZeroAddress();
    error ZeroPrice();
    error PriceNotSet();
    error InsufficientBalance();
    error InsufficientPayment();
    error InsufficientReserve();
    error InsufficientRedemptionPool();
    error NothingToWithdraw();
    error TransferFailed();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event InitialSupplySet(uint256 supply);
    event Bought(
        address indexed buyer,
        uint256 etherSpent,
        uint256 tokensReceived,
        uint256 fee
    );
    event Sold(
        address indexed seller,
        uint256 tokensSold,
        uint256 etherBeforeFee,
        uint256 fee
    );
    event Redeemed(
        address indexed redeemer,
        uint256 tokensRedeemed,
        uint256 etherReceived
    );
    event FeeWithdrawn(uint256 amount);
    event RedemptionPoolDeposited(uint256 amount);
    event RedemptionPoolWithdrawn(uint256 amount);
    event Paused();
    event Unpaused();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    string public constant name = "CreatorTime";
    string public constant symbol = "CTIME";
    uint8 public constant decimals = 18;
    uint256 public constant FEE_PERCENT = 5;
    uint256 public constant FEE_DENOMINATOR = 100;
    uint256 public constant MIN_SUPPLY = 100;
    uint256 public constant MAX_SUPPLY = 10000;

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------
    address public immutable creator;

    uint256 public totalSupply;
    uint256 public pricePerToken; // wei per 1e18 token base units (one minute)
    uint256 public feePool; // accumulated buy/sell fees, withdrawable by creator
    uint256 public redemptionPool; // creator-funded pool for redemptions
    bool public paused;
    bool public initialSupplySet;

    mapping(address => uint256) public balanceOf;

    // -----------------------------------------------------------------------
    // Reentrancy Guard
    // -----------------------------------------------------------------------
    uint256 private _status = 1;
    uint256 private constant _ENTERED = 2;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyCreator() {
        if (msg.sender != creator) revert NotCreator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor() {
        creator = msg.sender;
    }

    // -----------------------------------------------------------------------
    // Creator — Set Initial Supply (one-time, 100–10 000 minutes)
    // -----------------------------------------------------------------------
    function setInitialSupply(uint256 minutesAmount) external onlyCreator {
        if (initialSupplySet) revert InitialSupplyAlreadySet();
        if (minutesAmount < MIN_SUPPLY || minutesAmount > MAX_SUPPLY)
            revert InvalidSupply();

        initialSupplySet = true;

        uint256 mintAmount = minutesAmount * 10 ** decimals;
        totalSupply += mintAmount;
        balanceOf[creator] += mintAmount;

        emit InitialSupplySet(minutesAmount);
        emit Transfer(address(0), creator, mintAmount);
    }

    // -----------------------------------------------------------------------
    // Creator — Set Token Price
    // -----------------------------------------------------------------------
    function setPrice(uint256 newPrice) external onlyCreator {
        if (newPrice == 0) revert ZeroPrice();
        uint256 oldPrice = pricePerToken;
        pricePerToken = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    // -----------------------------------------------------------------------
    // Creator — Pause / Unpause Trading
    // -----------------------------------------------------------------------
    function pause() external onlyCreator {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyCreator {
        paused = false;
        emit Unpaused();
    }

    // -----------------------------------------------------------------------
    // Creator — Redemption Pool Management
    // -----------------------------------------------------------------------
    function depositRedemptionPool() external payable onlyCreator {
        if (msg.value == 0) revert ZeroAmount();
        redemptionPool += msg.value;
        emit RedemptionPoolDeposited(msg.value);
    }

    function withdrawRedemptionPool(uint256 amount)
        external
        onlyCreator
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (amount > redemptionPool) revert InsufficientRedemptionPool();

        redemptionPool -= amount;

        (bool ok, ) = creator.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit RedemptionPoolWithdrawn(amount);
    }

    // -----------------------------------------------------------------------
    // Creator — Withdraw Accumulated Fees
    // -----------------------------------------------------------------------
    function withdrawFees() external onlyCreator nonReentrant {
        uint256 amount = feePool;
        if (amount == 0) revert NothingToWithdraw();

        feePool = 0;

        (bool ok, ) = creator.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeeWithdrawn(amount);
    }

    // -----------------------------------------------------------------------
    // Buy — Mint tokens at current price; 5% fee to creator
    // -----------------------------------------------------------------------
    function buy() external payable whenNotPaused nonReentrant {
        if (pricePerToken == 0) revert PriceNotSet();
        if (msg.value == 0) revert InsufficientPayment();

        // Fee computed from the exact payment (multiply-then-divide).
        uint256 fee = (msg.value * FEE_PERCENT) / FEE_DENOMINATOR;
        uint256 etherAfterFee = msg.value - fee;
        uint256 tokenAmount = (etherAfterFee * 10 ** decimals) / pricePerToken;
        if (tokenAmount == 0) revert InsufficientPayment();

        // Effects
        feePool += fee;
        totalSupply += tokenAmount;
        balanceOf[msg.sender] += tokenAmount;

        emit Transfer(address(0), msg.sender, tokenAmount);
        emit Bought(msg.sender, msg.value, tokenAmount, fee);
    }

    // -----------------------------------------------------------------------
    // Sell — Burn tokens, receive ETH minus 5% fee; fee to creator
    // -----------------------------------------------------------------------
    function sell(uint256 tokenAmount) external whenNotPaused nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        // Compute the gross ether value and the fee with full precision to
        // avoid divide-before-multiply rounding loss: the fee is derived from
        // the unrounded product (tokenAmount * pricePerToken) rather than from
        // the already-rounded `etherBeforeFee`.
        uint256 etherBeforeFee = (tokenAmount * pricePerToken) / 10 ** decimals;
        uint256 fee = (tokenAmount * pricePerToken * FEE_PERCENT) /
            (10 ** decimals * FEE_DENOMINATOR);
        uint256 etherAfterFee = etherBeforeFee - fee;

        // Reserve check: the gross value (payout + fee) must be covered by the
        // free reserve so the fee pool and redemption pool remain fully backed.
        uint256 freeReserve = address(this).balance - feePool - redemptionPool;
        if (freeReserve < etherBeforeFee) revert InsufficientReserve();

        // Effects
        balanceOf[msg.sender] -= tokenAmount;
        totalSupply -= tokenAmount;
        feePool += fee;

        // Interaction
        (bool ok, ) = msg.sender.call{value: etherAfterFee}("");
        if (!ok) revert TransferFailed();

        emit Transfer(msg.sender, address(0), tokenAmount);
        emit Sold(msg.sender, tokenAmount, etherBeforeFee, fee);
    }

    // -----------------------------------------------------------------------
    // Redeem — Burn tokens; payout from creator's redemption pool, no fee
    // -----------------------------------------------------------------------
    function redeem(uint256 tokenAmount) external whenNotPaused nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        uint256 etherValue = (tokenAmount * pricePerToken) / 10 ** decimals;
        if (redemptionPool < etherValue) revert InsufficientRedemptionPool();

        // Effects
        redemptionPool -= etherValue;
        balanceOf[msg.sender] -= tokenAmount;
        totalSupply -= tokenAmount;

        // Interaction
        (bool ok, ) = msg.sender.call{value: etherValue}("");
        if (!ok) revert TransferFailed();

        emit Transfer(msg.sender, address(0), tokenAmount);
        emit Redeemed(msg.sender, tokenAmount, etherValue);
    }

    // -----------------------------------------------------------------------
    // Transfer — Holder-to-holder (no fee, no price change)
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // View — Available reserve for sell refunds
    // -----------------------------------------------------------------------
    function availableReserve() external view returns (uint256) {
        return address(this).balance - feePool - redemptionPool;
    }

    // -----------------------------------------------------------------------
    // Receive — Reject accidental Ether
    // -----------------------------------------------------------------------
    receive() external payable {
        revert("Use buy() or depositRedemptionPool()");
    }
}
