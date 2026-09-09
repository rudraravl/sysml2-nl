// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SocialPlatformToken
/// @notice Core token contract for a social media platform. Users hold platform
///         tokens, stake them with registered creators to mint community tokens,
///         and may unstake to redeem their platform tokens. A designated operator
///         may mint new platform tokens subject to a monthly cap.
contract SocialPlatformToken {
    // --------------------------------------------------------------------
    // Metadata
    // --------------------------------------------------------------------
    string public constant NAME = "SocialPlatform";
    string public constant SYMBOL = "SOC";
    uint8 public constant DECIMALS = 18;

    // --------------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------------
    /// @dev Maximum number of platform tokens the operator may mint per month.
    uint256 public constant MAX_MINT_PER_MONTH = 1_000_000 * 10 ** uint256(DECIMALS);

    /// @dev Duration used to define a "month" for the minting cap.
    uint256 public constant MONTH_SECONDS = 30 days;

    /// @dev Staking fee of 0.5% expressed in basis points.
    uint256 public constant FEE_BASIS_POINTS = 50;

    /// @dev Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // --------------------------------------------------------------------
    // Access control
    // --------------------------------------------------------------------
    address public operator;
    address public feeRecipient;

    // --------------------------------------------------------------------
    // Supply accounting
    // --------------------------------------------------------------------
    uint256 public totalSupply;
    /// @dev Tokens held by the contract that have been minted but not yet
    ///      allocated to any user.
    uint256 public reserveBalance;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    /// @dev Tokens allocated by the operator to a specific user, awaiting claim.
    mapping(address => uint256) public pendingAllocation;

    // --------------------------------------------------------------------
    // Monthly mint tracking
    // --------------------------------------------------------------------
    uint256 public monthStartTimestamp;
    uint256 public mintedThisMonth;

    // --------------------------------------------------------------------
    // Community tokens (one per creator)
    // --------------------------------------------------------------------
    struct CommunityToken {
        string name;
        string symbol;
        uint256 totalSupply;
        bool registered;
    }

    mapping(address => CommunityToken) public communityTokens;

    /// @dev creator => user => community token balance
    mapping(address => mapping(address => uint256)) public communityBalanceOf;

    /// @dev creator => user => platform tokens currently locked as stake
    mapping(address => mapping(address => uint256)) public stakedBalanceOf;

    // --------------------------------------------------------------------
    // Events
    // --------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Minted(address indexed caller, uint256 amount);
    event Allocated(address indexed user, uint256 amount);
    event Acquired(address indexed user, uint256 amount);
    event Staked(
        address indexed user,
        address indexed creator,
        uint256 amount,
        uint256 fee,
        uint256 stakedAmount
    );
    event Unstaked(address indexed user, address indexed creator, uint256 amount);
    event CommunityTokenRegistered(address indexed creator, string name, string symbol);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // --------------------------------------------------------------------
    // Errors
    // --------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error MonthlyMintCapExceeded(uint256 requested, uint256 remaining);
    error CreatorNotRegistered(address creator);
    error CreatorAlreadyRegistered(address creator);
    error InsufficientCommunityBalance();
    error InsufficientStakeBalance();
    error NothingToAcquire();

    // --------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonZero(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // --------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------
    constructor(address _feeRecipient) nonZero(_feeRecipient) {
        operator = msg.sender;
        feeRecipient = _feeRecipient;
        monthStartTimestamp = block.timestamp;
    }

    // --------------------------------------------------------------------
    // Operator administration
    // --------------------------------------------------------------------
    /// @notice Updates the address that receives staking fees.
    function setFeeRecipient(address newRecipient) external onlyOperator nonZero(newRecipient) {
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    /// @notice Transfers operator privileges to a new address.
    function transferOperator(address newOperator) external onlyOperator nonZero(newOperator) {
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    /// @notice Registers a creator and their associated community token metadata.
    function registerCreator(
        address creator,
        string calldata name_,
        string calldata symbol_
    ) external onlyOperator nonZero(creator) {
        if (communityTokens[creator].registered) revert CreatorAlreadyRegistered(creator);
        communityTokens[creator] = CommunityToken({
            name: name_,
            symbol: symbol_,
            totalSupply: 0,
            registered: true
        });
        emit CommunityTokenRegistered(creator, name_, symbol_);
    }

    // --------------------------------------------------------------------
    // Minting
    // --------------------------------------------------------------------
    /// @dev Resets the monthly mint counter if the current month has elapsed.
    function _refreshMonth() internal {
        if (block.timestamp >= monthStartTimestamp + MONTH_SECONDS) {
            monthStartTimestamp = block.timestamp;
            mintedThisMonth = 0;
        }
    }

    /// @notice Mints new platform tokens into the reserve pool, subject to the
    ///         monthly cap. Only callable by the operator.
    function mint(uint256 amount) external onlyOperator {
        if (amount == 0) revert InvalidAmount();
        _refreshMonth();
        uint256 remaining = MAX_MINT_PER_MONTH - mintedThisMonth;
        if (amount > remaining) revert MonthlyMintCapExceeded(amount, remaining);
        mintedThisMonth += amount;
        totalSupply += amount;
        reserveBalance += amount;
        emit Minted(msg.sender, amount);
        emit Transfer(address(0), address(this), amount);
    }

    /// @notice Allocates reserved tokens to a specific user for later claiming.
    function allocate(address user, uint256 amount) external onlyOperator nonZero(user) {
        if (amount == 0) revert InvalidAmount();
        if (reserveBalance < amount) revert InsufficientReserve();
        reserveBalance -= amount;
        pendingAllocation[user] += amount;
        emit Allocated(user, amount);
    }

    // --------------------------------------------------------------------
    // ERC20 standard functions
    // --------------------------------------------------------------------
    /// @notice Transfers platform tokens to another user.
    function transfer(address to, uint256 amount) external nonZero(to) returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Approves a spender to transfer tokens on behalf of the caller.
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens on behalf of an approved spender.
    function transferFrom(address from, address to, uint256 amount) external nonZero(to) returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    // --------------------------------------------------------------------
    // Internal ERC20 helpers
    // --------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (amount == 0) revert InvalidAmount();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // --------------------------------------------------------------------
    // User actions
    // --------------------------------------------------------------------
    /// @notice Claims any platform tokens that the operator has allocated to
    ///         the caller.
    function acquire() external {
        uint256 amount = pendingAllocation[msg.sender];
        if (amount == 0) revert NothingToAcquire();
        pendingAllocation[msg.sender] = 0;
        balanceOf[msg.sender] += amount;
        emit Acquired(msg.sender, amount);
        emit Transfer(address(this), msg.sender, amount);
    }

    /// @notice Stakes platform tokens with a registered creator. A 0.5% fee is
    ///         deducted from the staked platform tokens and sent to the fee
    ///         recipient. The remaining amount is locked and the caller receives
    ///         an equal amount of the creator's community tokens.
    function stake(address creator, uint256 amount) external nonZero(creator) {
        if (amount == 0) revert InvalidAmount();
        if (!communityTokens[creator].registered) revert CreatorNotRegistered(creator);
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        uint256 stakedAmount = amount - fee;

        // Effects: update balances before any external interaction
        balanceOf[msg.sender] -= amount;
        balanceOf[feeRecipient] += fee;

        stakedBalanceOf[creator][msg.sender] += stakedAmount;
        communityBalanceOf[creator][msg.sender] += stakedAmount;
        communityTokens[creator].totalSupply += stakedAmount;

        emit Staked(msg.sender, creator, amount, fee, stakedAmount);
    }

    /// @notice Redeems community tokens for the underlying staked platform
    ///         tokens. The caller's community token balance for the creator is
    ///         reduced and the corresponding platform tokens are returned.
    function unstake(address creator, uint256 communityAmount) external nonZero(creator) {
        if (communityAmount == 0) revert InvalidAmount();
        if (!communityTokens[creator].registered) revert CreatorNotRegistered(creator);
        if (communityBalanceOf[creator][msg.sender] < communityAmount) {
            revert InsufficientCommunityBalance();
        }
        if (stakedBalanceOf[creator][msg.sender] < communityAmount) {
            revert InsufficientStakeBalance();
        }

        // Effects: reduce balances before returning platform tokens
        communityBalanceOf[creator][msg.sender] -= communityAmount;
        stakedBalanceOf[creator][msg.sender] -= communityAmount;
        balanceOf[msg.sender] += communityAmount;
        communityTokens[creator].totalSupply -= communityAmount;

        emit Unstaked(msg.sender, creator, communityAmount);
    }

    // --------------------------------------------------------------------
    // Views
    // --------------------------------------------------------------------
    function name() external pure returns (string memory) {
        return NAME;
    }

    function symbol() external pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    /// @notice Returns community token metadata for a creator.
    function getCommunityToken(address creator)
        external
        view
        returns (string memory name_, string memory symbol_, uint256 totalSupply_, bool registered_)
    {
        CommunityToken storage ct = communityTokens[creator];
        return (ct.name, ct.symbol, ct.totalSupply, ct.registered);
    }

    /// @notice Returns a user's staked platform tokens and community token
    ///         balance for a given creator.
    function getUserStake(address creator, address user)
        external
        view
        returns (uint256 staked, uint256 community)
    {
        return (stakedBalanceOf[creator][user], communityBalanceOf[creator][user]);
    }

    /// @notice Returns the remaining mintable amount for the current month.
    function monthlyMintRemaining() external view returns (uint256) {
        if (block.timestamp >= monthStartTimestamp + MONTH_SECONDS) {
            return MAX_MINT_PER_MONTH;
        }
        return MAX_MINT_PER_MONTH - mintedThisMonth;
    }
}
