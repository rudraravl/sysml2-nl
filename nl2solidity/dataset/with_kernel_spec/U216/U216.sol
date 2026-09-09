// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GameTokenDistribution
/// @notice Manages token distribution for a new game release with a fixed maximum supply.
/// @dev Tokens are allocated by the owner and claimed by players. After claiming, players
///      can transfer tokens to other players. All token movement can be paused by the owner.
contract GameTokenDistribution {
    // -------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error TransferPaused();
    error AlreadyClaimed();
    error NoAllocation();
    error InsufficientBalance();
    error AllocationExceedsMax();
    error TotalAllocationExceedsMax();
    error DistributionExceedsMax();
    error TransferFailed();

    // -------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------
    string public constant name = "GameToken";
    string public constant symbol = "GMT";
    uint8 public constant decimals = 18;

    /// @notice Maximum tokens that will ever be distributed (1,000,000 with 18 decimals).
    uint256 public constant MAX_TOTAL_DISTRIBUTION = 1_000_000 * 10**18;

    /// @notice Maximum allocation any single player can receive (100,000 with 18 decimals).
    uint256 public constant MAX_ALLOCATION_PER_PLAYER = 100_000 * 10**18;

    // -------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------
    address public owner;
    bool public paused;
    uint256 public totalDistributed;
    uint256 public totalAllocated;

    mapping(address => uint256) public allocations;
    mapping(address => bool) public hasClaimed;
    mapping(address => uint256) public balances;

    // -------------------------------------------------------------
    // Events
    // -------------------------------------------------------------
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AllocationSet(address indexed player, uint256 amount);
    event Claimed(address indexed player, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Paused();
    event Unpaused();
    event EtherWithdrawn(address indexed to, uint256 amount);

    // -------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransferPaused();
        _;
    }

    // -------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -------------------------------------------------------------
    // Owner Functions
    // -------------------------------------------------------------
    /// @notice Sets or updates the token allocation for a player.
    /// @dev Allocation cannot be changed after the player has claimed. The sum of
    ///      all allocations is bounded by MAX_TOTAL_DISTRIBUTION.
    /// @param player The address of the player to allocate tokens to.
    /// @param amount The number of tokens (with 18 decimals) to allocate.
    function setAllocation(address player, uint256 amount) external onlyOwner {
        if (player == address(0)) revert ZeroAddress();
        if (hasClaimed[player]) revert AlreadyClaimed();
        if (amount > MAX_ALLOCATION_PER_PLAYER) revert AllocationExceedsMax();

        uint256 oldAllocation = allocations[player];
        uint256 newTotalAllocated = totalAllocated - oldAllocation + amount;
        if (newTotalAllocated > MAX_TOTAL_DISTRIBUTION) revert TotalAllocationExceedsMax();

        totalAllocated = newTotalAllocated;
        allocations[player] = amount;

        emit AllocationSet(player, amount);
    }

    /// @notice Pauses all token claims and transfers.
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    /// @notice Unpauses token claims and transfers.
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    /// @notice Transfers contract ownership to a new address.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Withdraws any Ether that may have been force-sent to the contract.
    /// @dev Only callable by the owner. Uses checks-effects-interactions and checks
    ///      the low-level call success flag.
    /// @param to The address to send the Ether to.
    function withdrawEther(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount == 0) revert ZeroAmount();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EtherWithdrawn(to, amount);
    }

    // -------------------------------------------------------------
    // Player Functions
    // -------------------------------------------------------------
    /// @notice Claims the caller's allocated tokens, crediting them to their balance.
    /// @dev Each player can only claim once. The claimed amount is added to totalDistributed.
    function claim() external whenNotPaused {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 amount = allocations[msg.sender];
        if (amount == 0) revert NoAllocation();
        if (totalDistributed + amount > MAX_TOTAL_DISTRIBUTION) revert DistributionExceedsMax();

        // Effects
        hasClaimed[msg.sender] = true;
        totalDistributed += amount;
        balances[msg.sender] += amount;

        // Events
        emit Claimed(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    /// @notice Transfers tokens to another player.
    /// @dev Conforms to the ERC20 transfer interface and returns a boolean.
    /// @param to The recipient address.
    /// @param amount The number of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // Effects
        balances[msg.sender] -= amount;
        balances[to] += amount;

        // Events
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // -------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------
    /// @notice Returns the fixed total supply of game tokens.
    function totalSupply() external pure returns (uint256) {
        return MAX_TOTAL_DISTRIBUTION;
    }

    /// @notice Returns the current token balance of an account.
    /// @param account The address to query.
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /// @notice Returns the allocation set for a player (claimable if not yet claimed).
    /// @param player The address to query.
    function allocationOf(address player) external view returns (uint256) {
        return allocations[player];
    }

    /// @notice Returns the remaining tokens available for distribution.
    function remainingDistribution() external view returns (uint256) {
        return MAX_TOTAL_DISTRIBUTION - totalDistributed;
    }

    /// @notice Returns the remaining allocation capacity across all players.
    function remainingAllocationCapacity() external view returns (uint256) {
        return MAX_TOTAL_DISTRIBUTION - totalAllocated;
    }

    /// @notice Returns the claimable token amount for a player.
    /// @param player The address to query.
    function claimableOf(address player) external view returns (uint256) {
        if (hasClaimed[player]) return 0;
        return allocations[player];
    }
}
