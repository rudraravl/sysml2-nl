// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

/**
 * @title CarbonAllowanceToken
 * @notice Tokenized representation of real-world carbon allowances.
 *         The contract custodies no digital assets directly: stablecoin
 *         deposits are forwarded to a designated treasury, and redemptions
 *         are settled off-chain against the underlying real-world asset.
 *         A price floor compounds by 0.4% per month and a 0.5% fee is
 *         applied to all user-initiated redemptions.
 */
contract CarbonAllowanceToken {
    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------
    string public constant name = "Carbon Allowance Token";
    string public constant symbol = "CAT";
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 private constant ONE_TOKEN = 1e18;
    uint256 private constant SECONDS_PER_MONTH = 30 days;
    uint256 private constant MONTHLY_INCREASE_BPS = 40;    // 0.4% per month
    uint256 private constant REDEMPTION_FEE_BPS = 50;     // 0.5% per redemption
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ---------------------------------------------------------------------
    // Token state
    // ---------------------------------------------------------------------
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ---------------------------------------------------------------------
    // External dependencies and roles
    // ---------------------------------------------------------------------
    IERC20 public immutable stablecoin;
    address public treasury;
    address public operator;
    address private _owner;

    // ---------------------------------------------------------------------
    // Price floor
    // ---------------------------------------------------------------------
    uint256 public priceFloor;            // stablecoin units per whole token (1e18 token wei)
    uint256 public lastPriceFloorUpdate;

    // ---------------------------------------------------------------------
    // Pause state
    // ---------------------------------------------------------------------
    bool public paused;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PriceFloorUpdated(uint256 oldPriceFloor, uint256 newPriceFloor, uint256 timestamp);
    event TokensAcquired(address indexed buyer, uint256 stableAmount, uint256 tokenAmount);
    event TokensRedeemed(address indexed redeemer, uint256 tokenAmount, uint256 netAmount, uint256 feeAmount);
    event UnderlyingRedemptionInitiated(address indexed account, uint256 tokenAmount, uint256 timestamp);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error ExpectedPause();
    error InvalidAmount();
    error PriceFloorNotPositive();
    error InsufficientBalance(address account, uint256 available, uint256 needed);
    error InsufficientAllowance(address spender, uint256 available, uint256 needed);
    error StablecoinTransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address stablecoin_,
        address treasury_,
        address operator_,
        uint256 initialPriceFloor
    ) {
        if (stablecoin_ == address(0) || treasury_ == address(0) || operator_ == address(0)) revert ZeroAddress();
        if (initialPriceFloor == 0) revert PriceFloorNotPositive();

        stablecoin = IERC20(stablecoin_);
        treasury = treasury_;
        operator = operator_;
        priceFloor = initialPriceFloor;
        lastPriceFloorUpdate = block.timestamp;
        _owner = msg.sender;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ---------------------------------------------------------------------
    // ERC20 views
    // ---------------------------------------------------------------------
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    // ---------------------------------------------------------------------
    // Price floor accrual (0.4% per month, compounded)
    // ---------------------------------------------------------------------
    /**
     * @notice Returns the projected price floor including all pending monthly
     *         increases without mutating state.
     */
    function currentPriceFloor() public view returns (uint256) {
        uint256 checkpoint = lastPriceFloorUpdate;
        if (block.timestamp - checkpoint < SECONDS_PER_MONTH) {
            return priceFloor;
        }

        uint256 projected = priceFloor;
        uint256 factor = BPS_DENOMINATOR + MONTHLY_INCREASE_BPS;
        while (block.timestamp - checkpoint >= SECONDS_PER_MONTH) {
            projected = (projected * factor) / BPS_DENOMINATOR;
            checkpoint += SECONDS_PER_MONTH;
        }
        return projected;
    }

    /**
     * @notice Applies all pending monthly increases to the stored price floor.
     *         Uses a duration-based loop to avoid divide-then-multiply patterns
     *         and strict equality on computed month counts.
     */
    function accruePriceFloor() public returns (uint256) {
        if (block.timestamp - lastPriceFloorUpdate < SECONDS_PER_MONTH) {
            return priceFloor;
        }

        uint256 oldPriceFloor = priceFloor;
        uint256 factor = BPS_DENOMINATOR + MONTHLY_INCREASE_BPS;
        while (block.timestamp - lastPriceFloorUpdate >= SECONDS_PER_MONTH) {
            priceFloor = (priceFloor * factor) / BPS_DENOMINATOR;
            lastPriceFloorUpdate += SECONDS_PER_MONTH;
        }

        emit PriceFloorUpdated(oldPriceFloor, priceFloor, block.timestamp);
        return priceFloor;
    }

    /**
     * @notice Operator sets a new price floor, resetting the monthly accrual clock.
     */
    function setPriceFloor(uint256 newPriceFloor) external onlyOperator {
        if (newPriceFloor == 0) revert PriceFloorNotPositive();
        uint256 old = priceFloor;
        priceFloor = newPriceFloor;
        lastPriceFloorUpdate = block.timestamp;
        emit PriceFloorUpdated(old, newPriceFloor, block.timestamp);
    }

    // ---------------------------------------------------------------------
    // Acquire tokens by depositing the approved stablecoin
    // ---------------------------------------------------------------------
    /**
     * @notice Deposit `stableAmount` of the approved stablecoin to mint tokens.
     *         The stablecoin is forwarded directly to the treasury; this contract
     *         never custodies the deposited digital assets.
     */
    function acquire(uint256 stableAmount) external whenNotPaused nonReentrant returns (uint256) {
        if (stableAmount == 0) revert InvalidAmount();

        accruePriceFloor();

        uint256 tokenAmount = (stableAmount * ONE_TOKEN) / priceFloor;
        if (tokenAmount == 0) revert InvalidAmount();

        bool ok = stablecoin.transferFrom(msg.sender, treasury, stableAmount);
        if (!ok) revert StablecoinTransferFailed();

        _mint(msg.sender, tokenAmount);
        emit TokensAcquired(msg.sender, stableAmount, tokenAmount);
        return tokenAmount;
    }

    // ---------------------------------------------------------------------
    // Redeem tokens for the underlying real-world asset
    // ---------------------------------------------------------------------
    /**
     * @notice Burn tokens to redeem the underlying real-world carbon allowance.
     *         A 0.5% fee is routed to the treasury in token form; the net
     *         remainder is burned and signals an off-chain redemption of the
     *         real-world asset.
     */
    function redeem(uint256 tokenAmount) external whenNotPaused nonReentrant returns (uint256) {
        if (tokenAmount == 0) revert InvalidAmount();
        uint256 senderBalance = _balances[msg.sender];
        if (senderBalance < tokenAmount) revert InsufficientBalance(msg.sender, senderBalance, tokenAmount);

        uint256 feeAmount = (tokenAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = tokenAmount - feeAmount;

        // Burn the net portion that is redeemed for the underlying asset.
        _burn(msg.sender, netAmount);

        // Route the fee portion to the treasury in token form.
        if (feeAmount > 0) {
            _transfer(msg.sender, treasury, feeAmount);
        }

        emit TokensRedeemed(msg.sender, tokenAmount, netAmount, feeAmount);
        return netAmount;
    }

    // ---------------------------------------------------------------------
    // Operator: initiate redemption of the underlying asset for an account
    // ---------------------------------------------------------------------
    /**
     * @notice Operator initiates redemption of the underlying real-world asset
     *         for `account`. The full `tokenAmount` is burned and the event is
     *         emitted for off-chain settlement.
     */
    function initiateRedemption(address account, uint256 tokenAmount) external onlyOperator {
        if (account == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert InvalidAmount();
        uint256 accountBalance = _balances[account];
        if (accountBalance < tokenAmount) revert InsufficientBalance(account, accountBalance, tokenAmount);

        _burn(account, tokenAmount);
        emit UnderlyingRedemptionInitiated(account, tokenAmount, block.timestamp);
    }

    // ---------------------------------------------------------------------
    // ERC20 transfer / approve
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 current = _allowances[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientAllowance(spender, current, subtractedValue);
        _approve(msg.sender, spender, current - subtractedValue);
        return true;
    }

    // ---------------------------------------------------------------------
    // Pause controls (operator)
    // ---------------------------------------------------------------------
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit PausedStateChanged(false);
    }

    // ---------------------------------------------------------------------
    // Administration (owner)
    // ---------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryChanged(old, newTreasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // ---------------------------------------------------------------------
    // Internal ERC20 logic
    // ---------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);

        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 current = _allowances[owner_][spender];
        if (current != type(uint256).max) {
            if (current < amount) revert InsufficientAllowance(spender, current, amount);
            _allowances[owner_][spender] = current - amount;
        }
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert InsufficientBalance(account, accountBalance, amount);
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}
