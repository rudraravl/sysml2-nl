// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IPriceOracle {
    /// @dev Returns the price of `asset` in base currency, with 18 decimals.
    function getAssetPrice(address asset) external view returns (uint256);
}

/**
 * @title SyntheticBasketAsset
 * @notice A synthetic asset that tracks the performance of a basket of digital assets.
 *         The contract does not hold the individual underlying basket assets; instead,
 *         minting and redemption are settled in a single base currency. A 0.5% mint fee
 *         is charged in the base currency and forwarded to a configurable fee recipient.
 *         A designated operator may update the basket composition (at most once every 24h)
 *         and pause/unpause minting and redemption.
 */
contract SyntheticBasketAsset {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(
        address indexed caller,
        address indexed receiver,
        uint256 baseAmount,
        uint256 fee,
        uint256 syntheticAmount
    );
    event Redeem(
        address indexed caller,
        address indexed receiver,
        uint256 syntheticAmount,
        uint256 baseAmount
    );
    event BasketUpdated(
        uint256 indexed timestamp,
        address[] tokens,
        uint256[] weights
    );
    event Paused(address indexed operator, bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorized();
    error PausedError();
    error ZeroAddress();
    error WeightsLengthMismatch();
    error InvalidTotalWeight();
    error BasketUpdateTooSoon();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidBasketValue();
    error InsufficientReserves();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MINT_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WEIGHT_DENOMINATOR = 10_000;
    uint256 public constant UPDATE_INTERVAL = 24 hours;
    uint256 public constant PRICE_DECIMALS = 18;
    uint256 public constant SYNTHETIC_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                             STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable baseCurrency;
    IPriceOracle public immutable oracle;

    address public owner;
    address public operator;
    address public feeRecipient;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address[] public basketTokens;
    mapping(address => uint256) public basketWeight;

    uint256 public lastBasketUpdate;
    bool public paused;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _baseCurrency,
        address _oracle,
        address _operator,
        address _feeRecipient,
        string memory _name,
        string memory _symbol
    ) {
        if (
            _baseCurrency == address(0) ||
            _oracle == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();

        baseCurrency = IERC20(_baseCurrency);
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        feeRecipient = _feeRecipient;
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        lastBasketUpdate = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                        BASKET VALUE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of one synthetic token expressed in base currency (18 decimals).
     * @dev basketValue = sum(weight_i * price_i) / WEIGHT_DENOMINATOR
     */
    function getBasketValue() public view returns (uint256) {
        uint256 length = basketTokens.length;
        if (length == 0) revert InvalidBasketValue();

        uint256 totalValue = 0;
        for (uint256 i = 0; i < length; ++i) {
            address token = basketTokens[i];
            uint256 weight = basketWeight[token];
            uint256 price = oracle.getAssetPrice(token);
            totalValue += (weight * price) / WEIGHT_DENOMINATOR;
        }
        if (totalValue == 0) revert InvalidBasketValue();
        return totalValue;
    }

    /*//////////////////////////////////////////////////////////////
                        MINT / REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint synthetic tokens by providing base currency.
     * @param receiver Address to receive the minted synthetic tokens.
     * @param baseAmount Amount of base currency to spend (18 decimals).
     * @return syntheticAmount Amount of synthetic tokens minted.
     */
    function mint(address receiver, uint256 baseAmount)
        external
        whenNotPaused
        returns (uint256 syntheticAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (baseAmount == 0) revert ZeroAmount();

        uint256 basketValue = getBasketValue();

        uint256 fee = (baseAmount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netBase = baseAmount - fee;

        // syntheticAmount = netBase * 10^SYNTHETIC_DECIMALS / basketValue
        syntheticAmount = (netBase * (10 ** SYNTHETIC_DECIMALS)) / basketValue;
        if (syntheticAmount == 0) revert ZeroAmount();

        // Pull base currency from caller into the contract.
        if (!baseCurrency.transferFrom(msg.sender, address(this), baseAmount)) revert TransferFailed();

        // Forward fee to fee recipient.
        if (fee > 0) {
            if (!baseCurrency.transfer(feeRecipient, fee)) revert TransferFailed();
        }

        // Mint synthetic tokens (effects before interactions with external token done above).
        totalSupply += syntheticAmount;
        balanceOf[receiver] += syntheticAmount;

        emit Mint(msg.sender, receiver, baseAmount, fee, syntheticAmount);
        emit Transfer(address(0), receiver, syntheticAmount);
    }

    /**
     * @notice Redeem synthetic tokens for the equivalent value in base currency.
     * @param receiver Address to receive the base currency.
     * @param syntheticAmount Amount of synthetic tokens to burn.
     * @return baseAmount Amount of base currency returned.
     */
    function redeem(address receiver, uint256 syntheticAmount)
        external
        whenNotPaused
        returns (uint256 baseAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (syntheticAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < syntheticAmount) revert InsufficientBalance();

        uint256 basketValue = getBasketValue();
        // baseAmount = syntheticAmount * basketValue / 10^SYNTHETIC_DECIMALS
        baseAmount = (syntheticAmount * basketValue) / (10 ** SYNTHETIC_DECIMALS);
        if (baseAmount == 0) revert ZeroAmount();
        if (baseCurrency.balanceOf(address(this)) < baseAmount) revert InsufficientReserves();

        // Burn synthetic tokens.
        balanceOf[msg.sender] -= syntheticAmount;
        totalSupply -= syntheticAmount;

        // Transfer base currency to receiver.
        if (!baseCurrency.transfer(receiver, baseAmount)) revert TransferFailed();

        emit Redeem(msg.sender, receiver, syntheticAmount, baseAmount);
        emit Transfer(msg.sender, address(0), syntheticAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20-LIKE TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer synthetic tokens to another address.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` synthetic tokens on behalf of the caller.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer synthetic tokens on behalf of `from` if sufficient allowance exists.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update the basket composition and weights.
     * @dev Can only be called once every 24 hours. Weights must sum to WEIGHT_DENOMINATOR.
     * @param tokens Array of basket token addresses.
     * @param weights Array of corresponding weights in basis points.
     */
    function updateBasket(address[] calldata tokens, uint256[] calldata weights)
        external
        onlyOperator
    {
        if (tokens.length != weights.length) revert WeightsLengthMismatch();
        if (tokens.length == 0) revert InvalidBasketValue();
        if (block.timestamp < lastBasketUpdate + UPDATE_INTERVAL) revert BasketUpdateTooSoon();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (weights[i] == 0) revert ZeroAmount();
            totalWeight += weights[i];
        }
        if (totalWeight != WEIGHT_DENOMINATOR) revert InvalidTotalWeight();

        // Clear previous basket weights.
        uint256 oldLength = basketTokens.length;
        for (uint256 i = 0; i < oldLength; ++i) {
            delete basketWeight[basketTokens[i]];
        }

        // Set new basket.
        delete basketTokens;
        for (uint256 i = 0; i < tokens.length; ++i) {
            basketTokens.push(tokens[i]);
            basketWeight[tokens[i]] = weights[i];
        }

        lastBasketUpdate = block.timestamp;

        emit BasketUpdated(block.timestamp, tokens, weights);
    }

    /**
     * @notice Pause or unpause minting and redemption.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit Paused(msg.sender, _paused);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Change the operator address.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Change the fee recipient address.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Transfer contract ownership.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the list of basket tokens.
     */
    function getBasketTokens() external view returns (address[] memory) {
        return basketTokens;
    }

    /**
     * @notice Returns the number of tokens in the basket.
     */
    function basketSize() external view returns (uint256) {
        return basketTokens.length;
    }

    /**
     * @notice Returns the timestamp when the basket can next be updated.
     */
    function nextBasketUpdate() external view returns (uint256) {
        return lastBasketUpdate + UPDATE_INTERVAL;
    }
}
