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

/**
 * @title DigitalGold
 * @notice A stablecoin protocol that mints a digital gold token backed 1:1 by a reserve asset.
 *         Users mint tokens by depositing the reserve asset, redeem tokens for the reserve
 *         asset, and transfer tokens freely. An operator can adjust minting and redemption fees.
 */
contract DigitalGold {
    // ───────────────────── Custom Errors ─────────────────────
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error Unauthorized();
    error InvalidFee();
    error TransferFailed();

    // ───────────────────── Events ─────────────────────
    event Mint(address indexed sender, address indexed recipient, uint256 reserveAmount, uint256 goldAmount, uint256 fee);
    event Redeem(address indexed sender, address indexed recipient, uint256 goldAmount, uint256 reserveAmount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event RedeemFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ───────────────────── Constants ─────────────────────
    uint256 public constant MAX_FEE = 1000; // 10% cap in basis points
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ───────────────────── ERC20 Metadata ─────────────────────
    string public name;
    string public symbol;
    uint256 public decimals;

    // ───────────────────── State Variables ─────────────────────
    IERC20 public immutable reserveAsset;
    address public operator;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public mintFeeBps;   // basis points, e.g. 50 = 0.5%
    uint256 public redeemFeeBps; // basis points, e.g. 75 = 0.75%

    // ───────────────────── Modifiers ─────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ───────────────────── Constructor ─────────────────────
    /**
     * @param _reserveAsset Address of the ERC20 token used as reserve (e.g. USDC)
     * @param _name         Name of the digital gold token
     * @param _symbol       Symbol of the digital gold token
     * @param _decimals     Decimals of the digital gold token
     * @param _operator     Address of the initial operator who can adjust fees
     */
    constructor(
        address _reserveAsset,
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        address _operator
    ) {
        if (_reserveAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        reserveAsset = IERC20(_reserveAsset);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        operator = _operator;

        mintFeeBps = 50;   // 0.5%
        redeemFeeBps = 75; // 0.75%
    }

    // ───────────────────── ERC20 Read Functions ─────────────────────
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Returns the current balance of the reserve asset held by this contract.
     */
    function reserveBalance() public view returns (uint256) {
        return reserveAsset.balanceOf(address(this));
    }

    // ───────────────────── ERC20 Write Functions ─────────────────────
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
        if (to == address(0)) revert ZeroAddress();

        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                _allowances[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    // ───────────────────── Internal Transfer ─────────────────────
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    // ───────────────────── Minting ─────────────────────
    /**
     * @notice Deposit reserve asset to mint digital gold tokens to a recipient.
     * @dev    The caller must have approved this contract to spend `reserveAmount`
     *         of the reserve asset prior to calling this function.
     * @param recipient      Address that will receive the minted digital gold tokens.
     * @param reserveAmount  Amount of reserve asset to deposit.
     */
    function mint(address recipient, uint256 reserveAmount) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (reserveAmount == 0) revert ZeroAmount();

        uint256 fee = (reserveAmount * mintFeeBps) / BPS_DENOMINATOR;
        uint256 goldAmount = reserveAmount - fee;

        // Effects: update balances before external interaction
        _totalSupply += goldAmount;
        _balances[recipient] += goldAmount;

        // Interactions: pull reserve asset from caller
        bool ok = reserveAsset.transferFrom(msg.sender, address(this), reserveAmount);
        if (!ok) revert TransferFailed();

        emit Mint(msg.sender, recipient, reserveAmount, goldAmount, fee);
        emit Transfer(address(0), recipient, goldAmount);
    }

    // ───────────────────── Redemption ─────────────────────
    /**
     * @notice Burn digital gold tokens to withdraw the underlying reserve asset.
     * @param recipient  Address that will receive the reserve asset.
     * @param goldAmount Amount of digital gold tokens to redeem.
     */
    function redeem(address recipient, uint256 goldAmount) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (goldAmount == 0) revert ZeroAmount();

        uint256 senderBalance = _balances[msg.sender];
        if (senderBalance < goldAmount) revert InsufficientBalance();

        uint256 fee = (goldAmount * redeemFeeBps) / BPS_DENOMINATOR;
        uint256 reserveAmount = goldAmount - fee;

        if (reserveBalance() < reserveAmount) revert InsufficientReserve();

        // Effects: burn tokens
        unchecked {
            _balances[msg.sender] = senderBalance - goldAmount;
        }
        _totalSupply -= goldAmount;

        // Interactions: send reserve asset to recipient
        bool ok = reserveAsset.transfer(recipient, reserveAmount);
        if (!ok) revert TransferFailed();

        emit Redeem(msg.sender, recipient, goldAmount, reserveAmount, fee);
        emit Transfer(msg.sender, address(0), goldAmount);
    }

    // ───────────────────── Operator Functions ─────────────────────
    /**
     * @notice Updates the minting fee (only operator).
     * @param newFee New fee in basis points (1 = 0.01%). Must not exceed MAX_FEE.
     */
    function setMintFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = mintFeeBps;
        mintFeeBps = newFee;
        emit MintFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Updates the redemption fee (only operator).
     * @param newFee New fee in basis points (1 = 0.01%). Must not exceed MAX_FEE.
     */
    function setRedeemFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = redeemFeeBps;
        redeemFeeBps = newFee;
        emit RedeemFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Transfers operator role to a new address (only current operator).
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }
}
