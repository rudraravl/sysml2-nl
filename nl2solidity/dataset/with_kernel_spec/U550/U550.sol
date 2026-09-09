// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @title TokenLaunchpad
/// @notice A launchpad that custodies newly minted tokens and a base currency reserve,
///         allowing users to launch new tokens and swap between base currency and launched tokens
///         using a constant-product AMM.
contract TokenLaunchpad {
    /* ========== Constants ========== */

    uint256 public constant MIN_BASE_AMOUNT = 100;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 private constant PRECISION = 1e18;

    /* ========== State Variables ========== */

    address public owner;
    bool public paused;
    uint256 public launchFeeBps; // Launch fee in basis points (50 = 0.5%)

    IERC20 public immutable baseCurrency;
    uint256 public accumulatedFees;
    uint256 public tokenCount;

    /* ========== Structs ========== */

    struct TokenInfo {
        uint256 totalSupply;  // Total supply of the launched token
        uint256 tokenReserve; // Tokens held by the contract (available for swapping)
        uint256 baseReserve;  // Base currency allocated to this token's pool
        uint256 price;        // Current price: base currency per token, scaled by PRECISION
        bool active;          // Whether the token is active
    }

    /* ========== Storage ========== */

    mapping(uint256 => TokenInfo) public tokens;
    mapping(uint256 => mapping(address => uint256)) public tokenBalances;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public tokenAllowances;

    /* ========== Reentrancy Guard ========== */

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "TokenLaunchpad: reentrant call");
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ========== Events ========== */

    event TokenLaunched(
        uint256 indexed tokenId,
        address indexed launcher,
        uint256 totalSupply,
        uint256 baseAmount,
        uint256 netBase,
        uint256 price
    );

    event Swap(
        uint256 indexed tokenId,
        address indexed swapper,
        bool indexed isBuy,
        uint256 baseAmount,
        uint256 tokenAmount,
        uint256 newPrice
    );

    event LaunchFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event Paused(bool paused);

    event FeesWithdrawn(address indexed to, uint256 amount);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event TokenTransfer(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);

    event TokenApproval(
        uint256 indexed tokenId,
        address indexed tokenOwner,
        address indexed spender,
        uint256 amount
    );

    /* ========== Errors ========== */

    error NotOwner();
    error ContractPaused();
    error InsufficientBaseAmount();
    error TokenNotActive();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAmount();
    error FeeTooHigh();
    error ZeroAddress();

    /* ========== Modifiers ========== */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /* ========== Constructor ========== */

    /// @param _baseCurrency The ERC20 base currency used for launching and swapping tokens
    constructor(address _baseCurrency) {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        owner = msg.sender;
        baseCurrency = IERC20(_baseCurrency);
        launchFeeBps = 50; // 0.5%
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ========== Core Functions ========== */

    /// @notice Launches a new token with the given total supply and initial base currency
    /// @param totalSupply The total supply of the new token
    /// @param baseAmount The amount of base currency to provide (must be >= MIN_BASE_AMOUNT)
    /// @return tokenId The ID of the newly launched token
    function launchToken(uint256 totalSupply, uint256 baseAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        if (baseAmount < MIN_BASE_AMOUNT) revert InsufficientBaseAmount();
        if (totalSupply == 0) revert InvalidAmount();

        uint256 fee = (baseAmount * launchFeeBps) / BASIS_POINTS;
        uint256 netBase = baseAmount - fee;

        require(
            baseCurrency.transferFrom(msg.sender, address(this), baseAmount),
            "TokenLaunchpad: base currency transfer failed"
        );

        accumulatedFees += fee;

        tokenId = tokenCount++;

        uint256 initialPrice = (netBase * PRECISION) / totalSupply;

        tokens[tokenId] = TokenInfo({
            totalSupply: totalSupply,
            tokenReserve: totalSupply,
            baseReserve: netBase,
            price: initialPrice,
            active: true
        });

        emit TokenLaunched(tokenId, msg.sender, totalSupply, baseAmount, netBase, initialPrice);
    }

    /// @notice Swaps base currency for launched tokens using a constant-product AMM
    /// @param tokenId The ID of the token to buy
    /// @param baseAmount The amount of base currency to spend
    /// @return tokensOut The amount of tokens received
    function swapBuy(uint256 tokenId, uint256 baseAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokensOut)
    {
        TokenInfo storage token = tokens[tokenId];
        if (!token.active) revert TokenNotActive();
        if (baseAmount == 0) revert InvalidAmount();

        // Constant product: k = tokenReserve * baseReserve
        uint256 k = token.tokenReserve * token.baseReserve;
        uint256 newBaseReserve = token.baseReserve + baseAmount;
        uint256 newTokenReserve = k / newBaseReserve;
        tokensOut = token.tokenReserve - newTokenReserve;

        if (tokensOut == 0) revert InvalidAmount();

        // Effects: update state before interaction
        token.tokenReserve = newTokenReserve;
        token.baseReserve = newBaseReserve;
        token.price = (token.baseReserve * PRECISION) / token.tokenReserve;
        tokenBalances[tokenId][msg.sender] += tokensOut;

        // Interaction: pull base currency from buyer
        require(
            baseCurrency.transferFrom(msg.sender, address(this), baseAmount),
            "TokenLaunchpad: base currency transfer failed"
        );

        emit Swap(tokenId, msg.sender, true, baseAmount, tokensOut, token.price);
    }

    /// @notice Swaps launched tokens back to base currency using a constant-product AMM
    /// @param tokenId The ID of the token to sell
    /// @param tokenAmount The amount of tokens to sell
    /// @return baseOut The amount of base currency received
    function swapSell(uint256 tokenId, uint256 tokenAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 baseOut)
    {
        TokenInfo storage token = tokens[tokenId];
        if (!token.active) revert TokenNotActive();
        if (tokenAmount == 0) revert InvalidAmount();
        if (tokenBalances[tokenId][msg.sender] < tokenAmount) revert InsufficientBalance();

        // Constant product: k = tokenReserve * baseReserve
        uint256 k = token.tokenReserve * token.baseReserve;
        uint256 newTokenReserve = token.tokenReserve + tokenAmount;
        uint256 newBaseReserve = k / newTokenReserve;
        baseOut = token.baseReserve - newBaseReserve;

        if (baseOut == 0) revert InvalidAmount();

        // Effects: update state before interaction
        tokenBalances[tokenId][msg.sender] -= tokenAmount;
        token.tokenReserve = newTokenReserve;
        token.baseReserve = newBaseReserve;
        token.price = (token.baseReserve * PRECISION) / token.tokenReserve;

        // Interaction: send base currency to seller
        require(
            baseCurrency.transfer(msg.sender, baseOut),
            "TokenLaunchpad: base currency transfer failed"
        );

        emit Swap(tokenId, msg.sender, false, baseOut, tokenAmount, token.price);
    }

    /* ========== Token Transfer Functions ========== */

    /// @notice Transfers launched tokens to another address
    /// @param tokenId The ID of the token
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transferToken(uint256 tokenId, address to, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        if (to == address(0)) revert ZeroAddress();
        if (tokenBalances[tokenId][msg.sender] < amount) revert InsufficientBalance();

        tokenBalances[tokenId][msg.sender] -= amount;
        tokenBalances[tokenId][to] += amount;

        emit TokenTransfer(tokenId, msg.sender, to, amount);
        return true;
    }

    /// @notice Approves an address to spend launched tokens on behalf of the caller
    /// @param tokenId The ID of the token
    /// @param spender The spender address
    /// @param amount The amount to approve
    function approveToken(uint256 tokenId, address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();

        tokenAllowances[tokenId][msg.sender][spender] = amount;
        emit TokenApproval(tokenId, msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers launched tokens on behalf of an approved address
    /// @param tokenId The ID of the token
    /// @param from The owner address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transferTokenFrom(uint256 tokenId, address from, address to, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        if (to == address(0)) revert ZeroAddress();
        if (tokenBalances[tokenId][from] < amount) revert InsufficientBalance();
        if (tokenAllowances[tokenId][from][msg.sender] < amount) revert InsufficientAllowance();

        tokenAllowances[tokenId][from][msg.sender] -= amount;
        tokenBalances[tokenId][from] -= amount;
        tokenBalances[tokenId][to] += amount;

        emit TokenTransfer(tokenId, from, to, amount);
        return true;
    }

    /* ========== Owner Functions ========== */

    /// @notice Pauses or unpauses all token launches and swaps
    /// @param _paused True to pause, false to unpause
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Updates the launch fee
    /// @param _feeBps The new fee in basis points (max 10000 = 100%)
    function setLaunchFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BASIS_POINTS) revert FeeTooHigh();
        uint256 oldFee = launchFeeBps;
        launchFeeBps = _feeBps;
        emit LaunchFeeUpdated(oldFee, _feeBps);
    }

    /// @notice Withdraws accumulated launch fees
    /// @param to The recipient address
    function withdrawFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        require(baseCurrency.transfer(to, amount), "TokenLaunchpad: fee withdrawal failed");
        emit FeesWithdrawn(to, amount);
    }

    /// @notice Transfers contract ownership to a new address
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /* ========== View Functions ========== */

    /// @notice Returns token info for a given token ID
    /// @param tokenId The ID of the token
    /// @return totalSupply The total supply of the token
    /// @return tokenReserve The tokens held by the contract
    /// @return baseReserve The base currency held for this token
    /// @return price The current price per token in base currency (scaled by PRECISION)
    /// @return active Whether the token is active
    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (uint256 totalSupply, uint256 tokenReserve, uint256 baseReserve, uint256 price, bool active)
    {
        TokenInfo storage token = tokens[tokenId];
        return (token.totalSupply, token.tokenReserve, token.baseReserve, token.price, token.active);
    }

    /// @notice Returns the balance of a launched token for an address
    /// @param tokenId The ID of the token
    /// @param account The account address
    function getTokenBalance(uint256 tokenId, address account) external view returns (uint256) {
        return tokenBalances[tokenId][account];
    }

    /// @notice Returns the allowance of a spender for a launched token
    /// @param tokenId The ID of the token
    /// @param account The owner address
    /// @param spender The spender address
    function getTokenAllowance(uint256 tokenId, address account, address spender)
        external
        view
        returns (uint256)
    {
        return tokenAllowances[tokenId][account][spender];
    }

    /// @notice Preview the amount of tokens received for a given base currency amount on buy
    /// @param tokenId The ID of the token
    /// @param baseAmount The amount of base currency to spend
    /// @return tokensOut The amount of tokens that would be received
    function getBuyAmountOut(uint256 tokenId, uint256 baseAmount) external view returns (uint256 tokensOut) {
        TokenInfo storage token = tokens[tokenId];
        if (!token.active || baseAmount == 0) return 0;

        uint256 k = token.tokenReserve * token.baseReserve;
        uint256 newBaseReserve = token.baseReserve + baseAmount;
        uint256 newTokenReserve = k / newBaseReserve;
        return token.tokenReserve - newTokenReserve;
    }

    /// @notice Preview the amount of base currency received for a given token amount on sell
    /// @param tokenId The ID of the token
    /// @param tokenAmount The amount of tokens to sell
    /// @return baseOut The amount of base currency that would be received
    function getSellAmountOut(uint256 tokenId, uint256 tokenAmount) external view returns (uint256 baseOut) {
        TokenInfo storage token = tokens[tokenId];
        if (!token.active || tokenAmount == 0) return 0;

        uint256 k = token.tokenReserve * token.baseReserve;
        uint256 newTokenReserve = token.tokenReserve + tokenAmount;
        uint256 newBaseReserve = k / newTokenReserve;
        return token.baseReserve - newBaseReserve;
    }
}
