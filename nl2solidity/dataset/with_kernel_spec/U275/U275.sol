// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @title SocialKeyExchange
/// @notice A friend.tech-style social key trading contract. Users buy and sell
/// fungible "keys" of other users (subjects) priced along a linear bonding
/// curve. Each trade incurs a configurable fee (default 5%) credited to the
/// subject, who can withdraw it at any time.
contract SocialKeyExchange {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotAuthorized();
    error TradingPaused();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFeePercentage();
    error MaxKeysExceeded();
    error InsufficientKeys();
    error TransferFailed();
    error NothingToWithdraw();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event KeysPurchased(
        address indexed buyer,
        address indexed subject,
        uint256 amount,
        uint256 totalPrice,
        uint256 fee
    );
    event KeysSold(
        address indexed seller,
        address indexed subject,
        uint256 amount,
        uint256 totalProceeds,
        uint256 fee
    );
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TradingPausedChanged(bool paused);
    event FeesWithdrawn(address indexed account, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Maximum keys a single holder may own of any one subject.
    uint256 public constant MAX_KEYS_PER_USER = 100;
    /// @dev Fee denominator expressed in basis points (10,000 = 100%).
    uint256 public constant FEE_DENOMINATOR = 10_000;
    /// @dev Default fee percentage in basis points (500 = 5%).
    uint256 public constant DEFAULT_FEE_PERCENTAGE = 500;
    /// @dev Upper bound on the configurable fee percentage (1,000 = 10%).
    uint256 public constant MAX_FEE_PERCENTAGE = 1_000;
    /// @dev Base price for the very first key minted of any subject.
    uint256 public constant BASE_PRICE = 1 ether;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable paymentToken;
    address public owner;
    address public operator;
    bool public tradingPaused;
    uint256 public feePercentage;

    /// @dev subject => holder => keys held
    mapping(address => mapping(address => uint256)) public keyBalance;
    /// @dev subject => total keys minted
    mapping(address => uint256) public keySupply;
    /// @dev subject => current marginal price per key
    mapping(address => uint256) public keyPrice;
    /// @dev account => withdrawable fees
    mapping(address => uint256) public collectedFees;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != owner && msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (tradingPaused) revert TradingPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param _paymentToken ERC20 token used for all payments.
    /// @param _operator Address designated to pause trading.
    constructor(address _paymentToken, address _operator) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        paymentToken = IERC20(_paymentToken);
        owner = msg.sender;
        operator = _operator;
        feePercentage = DEFAULT_FEE_PERCENTAGE;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeePercentageUpdated(0, DEFAULT_FEE_PERCENTAGE);
    }

    /*//////////////////////////////////////////////////////////////
                          BONDING CURVE VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Current marginal price per key for `subject`.
    /// @dev Key #(supply+1) costs BASE_PRICE * (supply + 1).
    function getPrice(address subject) public view returns (uint256) {
        return BASE_PRICE * (keySupply[subject] + 1);
    }

    /// @notice Total cost (excluding fee) to buy `amount` keys of `subject`.
    function getBuyCost(address subject, uint256 amount) external view returns (uint256) {
        return _buyCost(keySupply[subject], amount);
    }

    /// @notice Total proceeds (excluding fee) for selling `amount` keys of `subject`.
    function getSellReturn(address subject, uint256 amount) external view returns (uint256) {
        return _sellReturn(keySupply[subject], amount);
    }

    /// @notice Quote for buying `amount` keys: price, fee, and total cost.
    function getBuyQuote(address subject, uint256 amount)
        external
        view
        returns (uint256 price, uint256 fee, uint256 total)
    {
        price = _buyCost(keySupply[subject], amount);
        fee = (price * feePercentage) / FEE_DENOMINATOR;
        total = price + fee;
    }

    /// @notice Quote for selling `amount` keys: proceeds, fee, and payout.
    function getSellQuote(address subject, uint256 amount)
        external
        view
        returns (uint256 proceeds, uint256 fee, uint256 payout)
    {
        proceeds = _sellReturn(keySupply[subject], amount);
        fee = (proceeds * feePercentage) / FEE_DENOMINATOR;
        payout = proceeds - fee;
    }

    /*//////////////////////////////////////////////////////////////
                          TRADING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Buy `amount` keys of `subject`. Caller must have approved the
    /// contract to spend the total cost in payment tokens.
    /// @param subject The address whose keys are being purchased.
    /// @param amount Number of keys to purchase.
    function buyKeys(address subject, uint256 amount) external whenNotPaused {
        if (subject == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 supply = keySupply[subject];
        uint256 newBalance = keyBalance[subject][msg.sender] + amount;
        if (newBalance > MAX_KEYS_PER_USER) revert MaxKeysExceeded();

        uint256 totalPrice = _buyCost(supply, amount);
        uint256 fee = (totalPrice * feePercentage) / FEE_DENOMINATOR;
        uint256 totalCost = totalPrice + fee;

        // Effects.
        keySupply[subject] = supply + amount;
        keyBalance[subject][msg.sender] = newBalance;
        keyPrice[subject] = BASE_PRICE * (supply + amount + 1);
        collectedFees[subject] += fee;

        // Interactions.
        if (!paymentToken.transferFrom(msg.sender, address(this), totalCost))
            revert TransferFailed();

        emit KeysPurchased(msg.sender, subject, amount, totalPrice, fee);
    }

    /// @notice Sell `amount` keys of `subject` back to the contract.
    /// @param subject The address whose keys are being sold.
    /// @param amount Number of keys to sell.
    function sellKeys(address subject, uint256 amount) external whenNotPaused {
        if (subject == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 supply = keySupply[subject];
        if (amount > supply) revert InsufficientKeys();
        uint256 holderBal = keyBalance[subject][msg.sender];
        if (amount > holderBal) revert InsufficientKeys();

        uint256 totalProceeds = _sellReturn(supply, amount);
        uint256 fee = (totalProceeds * feePercentage) / FEE_DENOMINATOR;
        uint256 payout = totalProceeds - fee;

        // Effects.
        keySupply[subject] = supply - amount;
        keyBalance[subject][msg.sender] = holderBal - amount;
        keyPrice[subject] = BASE_PRICE * (supply - amount + 1);
        collectedFees[subject] += fee;

        // Interactions.
        if (!paymentToken.transfer(msg.sender, payout))
            revert TransferFailed();

        emit KeysSold(msg.sender, subject, amount, totalProceeds, fee);
    }

    /// @notice Withdraw all fees collected for the caller.
    function withdrawFees() external {
        uint256 amount = collectedFees[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects.
        collectedFees[msg.sender] = 0;

        // Interactions.
        if (!paymentToken.transfer(msg.sender, amount))
            revert TransferFailed();

        emit FeesWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the global fee percentage. Capped at MAX_FEE_PERCENTAGE.
    /// @param newFee New fee in basis points (e.g. 500 = 5%).
    function setFeePercentage(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        uint256 oldFee = feePercentage;
        feePercentage = newFee;
        emit FeePercentageUpdated(oldFee, newFee);
    }

    /// @notice Designate a new operator who can pause trading.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /// @notice Pause or unpause all key trading.
    /// @param _paused True to pause, false to resume.
    function setTradingPaused(bool _paused) external onlyAuthorized {
        tradingPaused = _paused;
        emit TradingPausedChanged(_paused);
    }

    /// @notice Transfer contract ownership to a new address.
    /// @param newOwner Address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Linear bonding curve. Key #(supply+1) costs BASE_PRICE * (supply + 1).
    /// Buying `amount` keys starting from `supply` sums the marginal prices of
    /// keys #(supply+1) through #(supply+amount):
    ///   BASE_PRICE * amount * (2*supply + amount + 1) / 2
    function _buyCost(uint256 supply, uint256 amount) internal pure returns (uint256) {
        return (BASE_PRICE * amount * (2 * supply + amount + 1)) / 2;
    }

    /// @dev Selling `amount` keys at `supply` returns the most recently minted
    /// keys' marginal prices (LIFO), i.e. keys #supply through #(supply-amount+1):
    ///   BASE_PRICE * amount * (2*supply - amount + 1) / 2
    function _sellReturn(uint256 supply, uint256 amount) internal pure returns (uint256) {
        return (BASE_PRICE * amount * (2 * supply - amount + 1)) / 2;
    }
}
