// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @title TokenizedAsset
 * @dev Tokenized representation of real-world assets, backed 1:1 by a stablecoin reserve.
 * Users mint by depositing stablecoins, redeem by burning tokens (minus a 0.1% fee),
 * and transfer tokens freely. The owner can pause mint/redeem, set the operator,
 * and transfer ownership. Only the designated operator can update the stablecoin reserve address.
 */
contract TokenizedAsset {
    // ---------- Token metadata ----------
    string public constant name = "Tokenized Real World Asset";
    string public constant symbol = "TRWA";
    uint8 public constant decimals = 18;

    // ---------- ERC20 state ----------
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ---------- Reserve stablecoin ----------
    IERC20 public stablecoin;

    // ---------- Access control ----------
    address public owner;
    address public operator;

    // ---------- Pause mechanism ----------
    bool public paused;

    // ---------- Constants ----------
    uint256 public constant MIN_MINT_AMOUNT = 100 * 10 ** 18; // 100 stablecoins (18 decimals)
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1% = 10 basis points
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ---------- Events ----------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, uint256 amount, uint256 stablecoinDeposited);
    event Redeem(address indexed redeemer, uint256 amount, uint256 stablecoinWithdrawn, uint256 fee);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event ReserveUpdated(address indexed by, address indexed oldReserve, address indexed newReserve);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------- Custom errors ----------
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumMint();
    error InsufficientBalance();
    error InsufficientAllowance();
    error StablecoinTransferFailed();

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
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

    // ---------- Constructor ----------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit ReserveUpdated(msg.sender, address(0), _stablecoin);
    }

    // ---------- ERC20 view functions ----------
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    // ---------- Mint / Redeem ----------
    /**
     * @dev Mint tokenized assets by depositing an equivalent amount of stablecoin.
     * The caller must first approve this contract to spend the required stablecoin amount.
     * Reverts if paused, amount is zero, or amount is below the minimum.
     */
    function mint(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_MINT_AMOUNT) revert BelowMinimumMint();

        // Transfer stablecoin from caller to this contract (checks-effects-interactions)
        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert StablecoinTransferFailed();

        // Mint tokenized asset to caller
        _totalSupply += amount;
        _balances[msg.sender] += amount;

        emit Transfer(address(0), msg.sender, amount);
        emit Mint(msg.sender, amount, amount);
    }

    /**
     * @dev Redeem tokenized assets for the underlying stablecoin, minus a 0.1% fee.
     * The fee is forwarded to the owner address.
     * Reverts if paused, amount is zero, or balance is insufficient.
     */
    function redeem(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        // Burn tokens first (effects)
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        // Interactions: transfer stablecoin payout to caller
        bool successPayout = stablecoin.transfer(msg.sender, payout);
        if (!successPayout) revert StablecoinTransferFailed();

        // Transfer fee to owner
        if (fee > 0) {
            bool successFee = stablecoin.transfer(owner, fee);
            if (!successFee) revert StablecoinTransferFailed();
        }

        emit Transfer(msg.sender, address(0), amount);
        emit Redeem(msg.sender, amount, payout, fee);
    }

    // ---------- ERC20 standard functions ----------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            unchecked {
                _allowances[from][msg.sender] = allowed - amount;
            }
        }

        _transfer(from, to, amount);
        return true;
    }

    // ---------- Internal helpers ----------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();

        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    // ---------- Operator functions ----------
    /**
     * @dev Update the stablecoin reserve address. Only callable by the operator.
     */
    function updateReserve(address newStablecoin) external onlyOperator {
        if (newStablecoin == address(0)) revert ZeroAddress();
        address old = address(stablecoin);
        stablecoin = IERC20(newStablecoin);
        emit ReserveUpdated(msg.sender, old, newStablecoin);
    }

    // ---------- Owner functions ----------
    /**
     * @dev Set a new operator. Only callable by the owner.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @dev Pause all mint and redeem operations. Only callable by the owner.
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Unpause mint and redeem operations. Only callable by the owner.
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @dev Transfer contract ownership to a new address. Only callable by the owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}
