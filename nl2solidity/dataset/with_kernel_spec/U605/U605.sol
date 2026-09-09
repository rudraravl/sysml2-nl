// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GoldToken
 * @notice A token representing physical gold held in secure vaults.
 *         Users can mint tokens by depositing gold, transfer tokens,
 *         and redeem tokens for physical gold. An operator can pause
 *         and unpause all transfers and redemptions. Only the contract
 *         owner can update the redemption fee percentage. The default
 *         redemption fee is 0.5% (50 basis points), and redemptions are
 *         limited to a maximum of 1000 ounces per transaction.
 */
contract GoldToken {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error ApproveToZeroAddress();
    error InsufficientBalance(address account, uint256 available, uint256 needed);
    error InsufficientAllowance(address spender, uint256 available, uint256 needed);
    error RedemptionExceedsMax(uint256 requested, uint256 maxAllowed);
    error FeeTooHigh(uint256 proposed, uint256 maxAllowed);
    error ContractPaused();
    error Unauthorized();
    error AmountZero();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount, bytes32 indexed depositRef);
    event Redeem(address indexed from, uint256 grossOunces, uint256 feeOunces, uint256 netOunces, bytes32 indexed redemptionRef);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                            METADATA
    //////////////////////////////////////////////////////////////*/
    string public constant name = "Gold Token";
    string public constant symbol = "GOLD";
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_REDEMPTION_OUNCES = 1000 ether; // 1000 * 10**18
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    uint256 public totalGoldOunces;
    uint256 public redemptionFeeBps; // basis points, default 50 = 0.5%
    bool private _paused;
    address private _owner;
    address private _operator;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != _operator) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != _owner && msg.sender != _operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert ContractPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address owner_, address operator_, uint256 redemptionFeeBps_) {
        if (owner_ == address(0) || operator_ == address(0)) revert Unauthorized();
        if (redemptionFeeBps_ > MAX_FEE_BPS) revert FeeTooHigh(redemptionFeeBps_, MAX_FEE_BPS);

        _owner = owner_;
        _operator = operator_;
        redemptionFeeBps = redemptionFeeBps_;

        emit OwnershipTransferred(address(0), owner_);
        emit OperatorChanged(address(0), operator_);
        emit RedemptionFeeUpdated(0, redemptionFeeBps_);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function operator() external view returns (address) {
        return _operator;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    /*//////////////////////////////////////////////////////////////
                         ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
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

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert TransferFromZeroAddress();
        if (to == address(0)) revert TransferToZeroAddress();
        if (amount == 0) revert AmountZero();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0)) revert TransferFromZeroAddress();
        if (spender == address(0)) revert ApproveToZeroAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(spender, currentAllowance, amount);
            }
            unchecked {
                _allowances[tokenOwner][spender] = currentAllowance - amount;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                         MINT / REDEEM
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Mints new tokens to `to`, representing a deposit of `amount` ounces of gold.
     *         Only the owner or operator may call this while the contract is not paused.
     * @param to The address receiving the minted tokens.
     * @param amount The amount of gold deposited, in 18-decimal ounces.
     * @param depositRef An optional reference identifier for the off-chain deposit record.
     */
    function mint(address to, uint256 amount, bytes32 depositRef) external onlyOwnerOrOperator whenNotPaused {
        if (to == address(0)) revert MintToZeroAddress();
        if (amount == 0) revert AmountZero();

        _totalSupply += amount;
        _balances[to] += amount;
        totalGoldOunces += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount, depositRef);
    }

    /**
     * @notice Redeems `ounces` tokens for physical gold. A redemption fee is deducted
     *         from the gold delivered. Redemptions are limited to MAX_REDEMPTION_OUNCES
     *         per transaction and cannot occur while the contract is paused.
     * @param ounces The amount of tokens to redeem, in 18-decimal ounces.
     * @param redemptionRef An optional reference identifier for the off-chain redemption record.
     * @return feeOunces The fee deducted from the redeemed amount.
     * @return netOunces The net ounces of gold to be delivered.
     */
    function redeem(uint256 ounces, bytes32 redemptionRef)
        external
        whenNotPaused
        returns (uint256 feeOunces, uint256 netOunces)
    {
        if (ounces == 0) revert AmountZero();
        if (ounces > MAX_REDEMPTION_OUNCES) revert RedemptionExceedsMax(ounces, MAX_REDEMPTION_OUNCES);

        uint256 callerBalance = _balances[msg.sender];
        if (callerBalance < ounces) revert InsufficientBalance(msg.sender, callerBalance, ounces);

        feeOunces = (ounces * redemptionFeeBps) / BPS_DENOMINATOR;
        netOunces = ounces - feeOunces;

        unchecked {
            _balances[msg.sender] = callerBalance - ounces;
            _totalSupply -= ounces;
            totalGoldOunces -= ounces;
        }

        emit Transfer(msg.sender, address(0), ounces);
        emit Redeem(msg.sender, ounces, feeOunces, netOunces, redemptionRef);
    }

    /*//////////////////////////////////////////////////////////////
                         PAUSE / UNPAUSE
    //////////////////////////////////////////////////////////////*/
    function pause() external onlyOperator {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Updates the redemption fee in basis points. Only callable by the owner.
     * @param newFeeBps The new fee in basis points (must be <= MAX_FEE_BPS).
     */
    function setRedemptionFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Updates the operator address. Only callable by the owner.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert Unauthorized();
        address old = _operator;
        _operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    /**
     * @notice Transfers ownership to a new address. Only callable by the current owner.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Unauthorized();
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Renounces ownership, setting the owner to the zero address.
     */
    function renounceOwnership() external onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }
}
