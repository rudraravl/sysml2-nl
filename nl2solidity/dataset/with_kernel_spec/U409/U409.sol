// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenBasket {
    //--------------------------------------------------------------------
    // Errors
    //--------------------------------------------------------------------
    error ZeroAddress();
    error ZeroShares();
    error ZeroAmount();
    error EmptyBasket();
    error ArrayLengthMismatch();
    error InvalidWeight();
    error InvalidWeightSum();
    error DuplicateToken();
    error TokenIsBasket();
    error TokenInBasket();
    error Unauthorized();
    error Paused();
    error NotPaused();
    error FeeTooHigh();
    error WeightUpdateNotActive();
    error TimelockNotPassed();
    error InsufficientBalance(address account, uint256 available, uint256 needed);
    error InsufficientAllowance(address spender, uint256 available, uint256 needed);
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error ApproveFromZeroAddress();
    error ApproveToZeroAddress();
    error ReentrantCall();
    error SafeTransferFailed();

    //--------------------------------------------------------------------
    // Events
    //--------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposited(address indexed caller, uint256 shares, uint256[] amounts);
    event Redeemed(address indexed caller, uint256 shares, uint256[] amounts);

    event WeightUpdateAnnounced(address indexed operator, uint256 timestamp, uint256[] weights);
    event TargetWeightsUpdated(address indexed caller, uint256[] weights);
    event WeightUpdateCancelled(address indexed operator);

    event DepositFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event BasketPaused(address indexed by);
    event BasketUnpaused(address indexed by);
    event Recovered(IERC20 indexed token, address indexed to, uint256 amount);

    //--------------------------------------------------------------------
    // Constants
    //--------------------------------------------------------------------
    uint256 public constant TOTAL_WEIGHT = 10_000;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant TIMELOCK = 24 hours;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%

    uint8 public constant decimals = 18;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    //--------------------------------------------------------------------
    // ERC-20 metadata + storage
    //--------------------------------------------------------------------
    string public name;
    string public symbol;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    //--------------------------------------------------------------------
    // Access / control
    //--------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;
    uint256 public depositFeeBps; // 10 = 0.1%
    bool public paused;

    uint256 private _status;

    //--------------------------------------------------------------------
    // Basket composition
    //--------------------------------------------------------------------
    IERC20[] public basketTokens;
    mapping(IERC20 => bool) public isBasketToken;
    mapping(IERC20 => uint256) public targetWeights; // basis points

    struct WeightUpdate {
        uint256[] weights; // parallel to basketTokens
        uint256 announcedAt;
        bool active;
    }

    WeightUpdate private pendingUpdate;

    //--------------------------------------------------------------------
    // Modifiers
    //--------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    //--------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------
    constructor(
        string memory name_,
        string memory symbol_,
        IERC20[] memory tokens_,
        uint256[] memory weights_,
        address operator_,
        address feeRecipient_
    ) {
        if (tokens_.length == 0) revert EmptyBasket();
        if (tokens_.length != weights_.length) revert ArrayLengthMismatch();
        if (operator_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();

        name = name_;
        symbol = symbol_;
        owner = msg.sender;
        operator = operator_;
        feeRecipient = feeRecipient_;
        depositFeeBps = 10; // 0.1%

        _status = _NOT_ENTERED;

        uint256 sum = 0;
        for (uint256 i = 0; i < tokens_.length; ++i) {
            IERC20 t = tokens_[i];
            if (address(t) == address(0)) revert ZeroAddress();
            if (address(t) == address(this)) revert TokenIsBasket();
            if (isBasketToken[t]) revert DuplicateToken();

            uint256 w = weights_[i];
            if (w == 0) revert InvalidWeight();

            basketTokens.push(t);
            isBasketToken[t] = true;
            targetWeights[t] = w;
            sum += w;
        }
        if (sum != TOTAL_WEIGHT) revert InvalidWeightSum();

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
        emit FeeRecipientUpdated(address(0), feeRecipient_);
        emit DepositFeeUpdated(0, depositFeeBps);
        emit TargetWeightsUpdated(msg.sender, weights_);
    }

    //--------------------------------------------------------------------
    // ERC-20 view functions
    //--------------------------------------------------------------------
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return _allowances[account][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    //--------------------------------------------------------------------
    // Basket operations
    //--------------------------------------------------------------------

    /**
     * @notice Deposit the basket's underlying tokens (in target proportions)
     *         to mint `shares` basket tokens to the caller.
     * @param shares Number of basket tokens to mint.
     */
    function deposit(uint256 shares) external nonReentrant whenNotPaused {
        if (shares == 0) revert ZeroShares();

        uint256 len = basketTokens.length;
        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            IERC20 t = basketTokens[i];
            uint256 weight = targetWeights[t];

            // Compute fee from the unrounded product to avoid divide-before-multiply.
            uint256 gross = shares * weight;
            uint256 fee = (gross * depositFeeBps) / (TOTAL_WEIGHT * FEE_DENOMINATOR);
            uint256 required = gross / TOTAL_WEIGHT;
            uint256 totalPull = required + fee;

            _safeTransferFrom(t, msg.sender, address(this), totalPull);
            if (fee != 0) {
                _safeTransfer(t, feeRecipient, fee);
            }
            amounts[i] = totalPull;
        }

        _mint(msg.sender, shares);
        emit Deposited(msg.sender, shares, amounts);
    }

    /**
     * @notice Burn `shares` basket tokens and receive a proportional share
     *         of every underlying token currently held by the basket.
     * @param shares Number of basket tokens to burn.
     */
    function redeem(uint256 shares) external nonReentrant whenNotPaused {
        if (shares == 0) revert ZeroShares();
        if (_balances[msg.sender] < shares) {
            revert InsufficientBalance(msg.sender, _balances[msg.sender], shares);
        }

        uint256 supply = _totalSupply;
        uint256 len = basketTokens.length;
        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            IERC20 t = basketTokens[i];
            uint256 held = t.balanceOf(address(this));
            amounts[i] = (held * shares) / supply;
        }

        _burn(msg.sender, shares);

        for (uint256 i = 0; i < len; ++i) {
            if (amounts[i] != 0) {
                _safeTransfer(basketTokens[i], msg.sender, amounts[i]);
            }
        }

        emit Redeemed(msg.sender, shares, amounts);
    }

    //--------------------------------------------------------------------
    // Weight management (operator + 24h timelock)
    //--------------------------------------------------------------------

    /**
     * @notice Announce a new set of target weights for the existing basket
     *         tokens. Becomes committable after the 24h timelock elapses.
     */
    function announceWeightUpdate(uint256[] calldata weights) external onlyOperator {
        if (weights.length != basketTokens.length) revert ArrayLengthMismatch();

        uint256 sum = 0;
        for (uint256 i = 0; i < weights.length; ++i) {
            if (weights[i] == 0) revert InvalidWeight();
            sum += weights[i];
        }
        if (sum != TOTAL_WEIGHT) revert InvalidWeightSum();

        pendingUpdate.weights = weights;
        pendingUpdate.announcedAt = block.timestamp;
        pendingUpdate.active = true;

        emit WeightUpdateAnnounced(msg.sender, block.timestamp, weights);
    }

    /**
     * @notice Finalize the most recently announced weight update after the
     *         timelock has passed.
     */
    function commitWeightUpdate() external {
        if (!pendingUpdate.active) revert WeightUpdateNotActive();
        if (block.timestamp < pendingUpdate.announcedAt + TIMELOCK) revert TimelockNotPassed();

        uint256 len = basketTokens.length;
        for (uint256 i = 0; i < len; ++i) {
            targetWeights[basketTokens[i]] = pendingUpdate.weights[i];
        }

        uint256[] memory weights = pendingUpdate.weights;
        delete pendingUpdate;

        emit TargetWeightsUpdated(msg.sender, weights);
    }

    /**
     * @notice Cancel any pending weight update.
     */
    function cancelWeightUpdate() external onlyOperator {
        if (!pendingUpdate.active) revert WeightUpdateNotActive();
        delete pendingUpdate;
        emit WeightUpdateCancelled(msg.sender);
    }

    //--------------------------------------------------------------------
    // Admin
    //--------------------------------------------------------------------

    function setDepositFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = depositFeeBps;
        depositFeeBps = newFee;
        emit DepositFeeUpdated(old, newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function pause() external onlyOwner {
        if (paused) revert Paused();
        paused = true;
        emit BasketPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit BasketUnpaused(msg.sender);
    }

    /**
     * @notice Recover ERC-20 tokens sent to the contract by accident.
     *         Tokens that are part of the basket cannot be recovered.
     */
    function recoverToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (isBasketToken[token]) revert TokenInBasket();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _safeTransfer(token, to, amount);
        emit Recovered(token, to, amount);
    }

    //--------------------------------------------------------------------
    // Views
    //--------------------------------------------------------------------

    function basketTokensLength() external view returns (uint256) {
        return basketTokens.length;
    }

    function getBasketTokens() external view returns (IERC20[] memory) {
        return basketTokens;
    }

    function getPendingUpdate()
        external
        view
        returns (uint256[] memory weights, uint256 announcedAt, bool active)
    {
        weights = pendingUpdate.weights;
        announcedAt = pendingUpdate.announcedAt;
        active = pendingUpdate.active;
    }

    //--------------------------------------------------------------------
    // ERC-20 internals
    //--------------------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert TransferFromZeroAddress();
        if (to == address(0)) revert TransferToZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert MintToZeroAddress();

        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert BurnFromZeroAddress();

        uint256 balance = _balances[from];
        if (balance < amount) revert InsufficientBalance(from, balance, amount);

        unchecked {
            _balances[from] = balance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function _approve(address account, address spender, uint256 amount) internal {
        if (account == address(0)) revert ApproveFromZeroAddress();
        if (spender == address(0)) revert ApproveToZeroAddress();
        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }

    function _spendAllowance(address account, address spender, uint256 amount) internal {
        uint256 allowed = _allowances[account][spender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(spender, allowed, amount);
            unchecked {
                _allowances[account][spender] = allowed - amount;
            }
        }
    }

    //--------------------------------------------------------------------
    // Safe token transfers
    //--------------------------------------------------------------------

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }
}
