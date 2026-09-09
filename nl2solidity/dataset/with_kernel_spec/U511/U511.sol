// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title DecentralizedStablecoinSystem
 * @notice Manages a decentralized stablecoin backed by a volatile reserve asset.
 *         Users deposit the reserve asset to mint a 1:1 pegged stablecoin, redeem
 *         stablecoin for the reserve asset (minus a redemption fee), and transfer
 *         stablecoin between accounts. The owner may configure the redemption fee
 *         and pause minting/redemption operations.
 */
contract DecentralizedStablecoinSystem {
    // --- Custom Errors ---
    error NotOwner();
    error ZeroAddress();
    error ContractPaused();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error SupplyCapExceeded();
    error FeeExceedsMaximum();
    error InsufficientReserve();
    error TransferFailed();
    error ReentrantCall();

    // --- Events ---
    event StablecoinMinted(address indexed account, uint256 stablecoinAmount, uint256 reserveDeposited);
    event StablecoinBurned(address indexed account, uint256 stablecoinAmount, uint256 reserveReturned, uint256 feeCollected);
    event ReserveDeposited(address indexed account, uint256 amount);
    event ReserveWithdrawn(address indexed account, uint256 amount);
    event StablecoinTransfer(address indexed from, address indexed to, uint256 amount);
    event StablecoinApproval(address indexed owner, address indexed spender, uint256 amount);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Constants ---
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant DEFAULT_REDEMPTION_FEE_BPS = 50; // 0.5%
    uint8 public constant decimals = 18;

    // --- Token Metadata ---
    string public name;
    string public symbol;

    // --- Core State ---
    address public owner;
    IERC20Minimal public immutable reserveToken;

    uint256 public totalReserve;      // Global reserve pool held by the contract
    uint256 public totalSupply;       // Global stablecoin supply
    uint256 public redemptionFeeBps;  // Redemption fee in basis points
    bool public paused;

    mapping(address => uint256) public reserveBalance;    // Per-account reserve deposits
    mapping(address => uint256) public stableBalance;     // Per-account stablecoin balances
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private _locked = 1;

    // --- Modifiers ---
    modifier onlyOwner() {
        if (owner == address(0) || msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- Constructor ---
    constructor(
        address reserveToken_,
        string memory name_,
        string memory symbol_
    ) {
        if (reserveToken_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        reserveToken = IERC20Minimal(reserveToken_);
        name = name_;
        symbol = symbol_;
        redemptionFeeBps = DEFAULT_REDEMPTION_FEE_BPS;
        emit OwnershipTransferred(address(0), msg.sender);
        emit RedemptionFeeUpdated(0, DEFAULT_REDEMPTION_FEE_BPS);
    }

    // --- Owner Functions ---

    /**
     * @notice Set the redemption fee in basis points. Capped at BASIS_POINTS (100%).
     */
    function setRedemptionFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BASIS_POINTS) revert FeeExceedsMaximum();
        uint256 oldFeeBps = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Pause minting and redemption operations.
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause minting and redemption operations.
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Transfer contract ownership to a new address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Renounce ownership, leaving the contract without an owner.
     */
    function renounceOwnership() external onlyOwner {
        address previousOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    // --- Core Operations ---

    /**
     * @notice Deposit reserve tokens to mint an equal amount of stablecoin at 1:1.
     * @param amount The amount of reserve tokens to deposit (and stablecoin to mint).
     */
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (totalSupply + amount > MAX_SUPPLY) revert SupplyCapExceeded();

        // Effects: update all state before the external transfer to follow
        // checks-effects-interactions and avoid stale balance reads.
        totalReserve += amount;
        reserveBalance[msg.sender] += amount;
        totalSupply += amount;
        stableBalance[msg.sender] += amount;

        // Interactions
        bool success = reserveToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit ReserveDeposited(msg.sender, amount);
        emit StablecoinMinted(msg.sender, amount, amount);
    }

    /**
     * @notice Redeem stablecoin for reserve tokens. A redemption fee is deducted
     *         from the returned reserve asset and retained in the reserve pool.
     * @param amount The amount of stablecoin to burn.
     */
    function redeem(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (stableBalance[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * redemptionFeeBps) / BASIS_POINTS;
        uint256 returnAmount = amount - fee;

        if (totalReserve < returnAmount) revert InsufficientReserve();

        // Effects
        stableBalance[msg.sender] -= amount;
        totalSupply -= amount;
        totalReserve -= returnAmount;

        // Saturating decrement of the per-account reserve tracker; the redeemed
        // reserve may exceed the user's recorded deposit entry.
        uint256 userReserve = reserveBalance[msg.sender];
        reserveBalance[msg.sender] = userReserve > returnAmount ? userReserve - returnAmount : 0;

        // Interactions
        bool success = reserveToken.transfer(msg.sender, returnAmount);
        if (!success) revert TransferFailed();

        emit StablecoinBurned(msg.sender, amount, returnAmount, fee);
        emit ReserveWithdrawn(msg.sender, returnAmount);
    }

    /**
     * @notice Transfer stablecoin between two accounts.
     * @param to The recipient address.
     * @param amount The amount of stablecoin to transfer.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (stableBalance[msg.sender] < amount) revert InsufficientBalance();

        stableBalance[msg.sender] -= amount;
        stableBalance[to] += amount;

        emit StablecoinTransfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Approve another address to spend stablecoin on behalf of the caller.
     * @param spender Address to approve.
     * @param amount Amount of stablecoin to approve.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit StablecoinApproval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer stablecoin from one address to another using an allowance.
     * @param from Sender address.
     * @param to Recipient address.
     * @param amount Amount of stablecoin to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (stableBalance[from] < amount) revert InsufficientBalance();
        if (allowance[from][msg.sender] < amount) revert InsufficientAllowance();

        allowance[from][msg.sender] -= amount;
        stableBalance[from] -= amount;
        stableBalance[to] += amount;

        emit StablecoinTransfer(from, to, amount);
        return true;
    }

    // --- View Functions ---

    /**
     * @notice Returns the stablecoin balance of an account.
     */
    function stableBalanceOf(address account) external view returns (uint256) {
        return stableBalance[account];
    }

    /**
     * @notice Returns the reserve asset balance credited to an account.
     */
    function reserveBalanceOf(address account) external view returns (uint256) {
        return reserveBalance[account];
    }

    /**
     * @notice Returns the accumulated redemption fees retained in the reserve pool.
     */
    function accumulatedFees() external view returns (uint256) {
        if (totalReserve > totalSupply) {
            return totalReserve - totalSupply;
        }
        return 0;
    }
}
