// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProtocolTreasury
 * @notice Manages a treasury of Ether and a native protocol token. Users can buy
 *         tokens by sending Ether (which accumulates in the treasury) and sell
 *         tokens to receive Ether back. A designated operator may adjust the
 *         token price and withdraw accumulated Ether. Sales incur a 0.5% fee
 *         deducted from the Ether returned to the seller.
 * @dev Implements a minimal ERC20-like interface alongside treasury operations.
 *      All state-mutating treasury functions are protected against reentrancy.
 */
contract ProtocolTreasury {
    /* ------------------------------------------------------------------ */
    /*  Constants                                                          */
    /* ------------------------------------------------------------------ */

    string public constant name = "Protocol Token";
    string public constant symbol = "PT";
    uint8 public constant decimals = 18;

    uint256 private constant ONE_TOKEN = 10 ** 18;
    uint256 public constant MIN_PURCHASE = 0.01 ether;
    uint256 public constant FEE_BPS = 50; // 0.5% = 50 basis points
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /* ------------------------------------------------------------------ */
    /*  State variables                                                    */
    /* ------------------------------------------------------------------ */

    address public operator;
    uint256 public totalSupply;
    uint256 public tokenPrice; // wei per whole token (1e18 units)
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* ------------------------------------------------------------------ */
    /*  Reentrancy guard                                                   */
    /* ------------------------------------------------------------------ */

    uint256 private _locked = 1;

    /* ------------------------------------------------------------------ */
    /*  Events                                                             */
    /* ------------------------------------------------------------------ */

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenPurchase(address indexed buyer, uint256 ethPaid, uint256 tokensMinted);
    event TokenSale(address indexed seller, uint256 tokensBurned, uint256 ethReturned, uint256 feeTaken);
    event EtherWithdrawal(address indexed operator, uint256 amount);
    event PriceUpdated(address indexed operator, uint256 oldPrice, uint256 newPrice);
    event OperatorshipTransferred(address indexed previousOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /*  Errors                                                             */
    /* ------------------------------------------------------------------ */

    error Unauthorized();
    error InsufficientPayment();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientTreasury();
    error InsufficientAllowance();
    error PriceNotPositive();
    error ReentrantCall();
    error EtherTransferFailed();

    /* ------------------------------------------------------------------ */
    /*  Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ------------------------------------------------------------------ */
    /*  Constructor                                                        */
    /* ------------------------------------------------------------------ */

    /**
     * @param initialPrice Initial token price in wei per whole token (1e18 units).
     */
    constructor(uint256 initialPrice) {
        if (initialPrice == 0) revert PriceNotPositive();
        operator = msg.sender;
        tokenPrice = initialPrice;
        emit PriceUpdated(msg.sender, 0, initialPrice);
        emit OperatorshipTransferred(address(0), msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /*  ERC20-style functions                                              */
    /* ------------------------------------------------------------------ */

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        if (allowance[from][msg.sender] < amount) revert InsufficientAllowance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    /* ------------------------------------------------------------------ */
    /*  Operator administration                                            */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Update the token price. Only callable by the operator.
     */
    function setPrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert PriceNotPositive();
        uint256 old = tokenPrice;
        tokenPrice = newPrice;
        emit PriceUpdated(msg.sender, old, newPrice);
    }

    /**
     * @notice Transfer operator privileges to a new address.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorshipTransferred(previous, newOperator);
    }

    /**
     * @notice Withdraw accumulated Ether from the treasury. Only callable by the operator.
     * @param amount Amount of Ether (in wei) to withdraw.
     */
    function withdrawEther(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientTreasury();
        (bool ok, ) = payable(operator).call{value: amount}("");
        if (!ok) revert EtherTransferFailed();
        emit EtherWithdrawal(operator, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  Market operations                                                  */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Purchase tokens by sending Ether. Tokens are minted 1:1 with the
     *         amount paid divided by the current price. Enforced minimum of 0.01 ETH.
     */
    function buyTokens() external payable nonReentrant {
        if (msg.value < MIN_PURCHASE) revert InsufficientPayment();
        uint256 tokensToMint = (msg.value * ONE_TOKEN) / tokenPrice;
        if (tokensToMint == 0) revert ZeroAmount();

        totalSupply += tokensToMint;
        balanceOf[msg.sender] += tokensToMint;

        emit Transfer(address(0), msg.sender, tokensToMint);
        emit TokenPurchase(msg.sender, msg.value, tokensToMint);
    }

    /**
     * @notice Sell tokens to receive Ether back. A 0.5% fee is deducted from the
     *         Ether returned to the seller. Tokens are burned from the caller's balance.
     * @param tokenAmount Number of tokens (in wei units) to sell.
     */
    function sellTokens(uint256 tokenAmount) external nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        uint256 grossEth = (tokenAmount * tokenPrice) / ONE_TOKEN;
        if (grossEth == 0) revert ZeroAmount();

        // Compute the fee directly from the raw product to avoid precision
        // loss inherent in divide-before-multiply.  By multiplying all
        // numerators before any division we preserve maximal precision.
        // fee = tokenAmount * tokenPrice * FEE_BPS / (ONE_TOKEN * BPS_DENOMINATOR)
        // Because FEE_BPS < BPS_DENOMINATOR, fee <= grossEth holds for all
        // non-zero grossEth, so payout = grossEth - fee never underflows.
        uint256 fee = (tokenAmount * tokenPrice * FEE_BPS) / (ONE_TOKEN * BPS_DENOMINATOR);
        uint256 payout = grossEth - fee;

        if (address(this).balance < payout) revert InsufficientTreasury();

        // Checks-Effects-Interactions: update state before external call.
        balanceOf[msg.sender] -= tokenAmount;
        totalSupply -= tokenAmount;

        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert EtherTransferFailed();

        emit Transfer(msg.sender, address(0), tokenAmount);
        emit TokenSale(msg.sender, tokenAmount, payout, fee);
    }

    /* ------------------------------------------------------------------ */
    /*  Views                                                              */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Current Ether held by the treasury.
     */
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /* ------------------------------------------------------------------ */
    /*  Receive                                                            */
    /* ------------------------------------------------------------------ */

    receive() external payable {}
}
