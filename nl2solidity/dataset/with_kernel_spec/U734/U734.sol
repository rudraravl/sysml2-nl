// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title StablecoinSystem
 * @notice A token-pegged stablecoin system that holds reserves of a base ERC20 token
 *         and mints a stablecoin 1:1 (minus fees). Users deposit the base token to mint
 *         stablecoins and redeem stablecoins to receive the base token back. An operator
 *         can adjust fees and pause/unpause minting and redemption.
 */
contract StablecoinSystem {
    // ---------- Custom Errors ----------
    error ZeroAddress();
    error NotOperator();
    error MintPaused();
    error RedeemPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserves();
    error TransferFailed();
    error FeeTooHigh();
    error AmountZero();

    // ---------- Events ----------
    event Minted(address indexed sender, address indexed recipient, uint256 baseAmount, uint256 mintedAmount, uint256 fee);
    event Redeemed(address indexed sender, address indexed recipient, uint256 stableAmount, uint256 baseAmount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MintFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event RedeemFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MintPausedChanged(bool paused);
    event RedeemPausedChanged(bool paused);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------- Constants ----------
    uint16 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint16 public constant DEFAULT_MINT_FEE_BPS = 20; // 0.2%
    uint16 public constant DEFAULT_REDEEM_FEE_BPS = 50; // 0.5%
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ---------- Token Metadata ----------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ---------- ERC20 State ----------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------- Reserve State ----------
    IERC20 public immutable baseToken;
    uint256 public reserves; // base token held by this contract

    // ---------- Fee & Pause State ----------
    uint16 public mintFeeBps;
    uint16 public redeemFeeBps;
    bool public mintPaused;
    bool public redeemPaused;

    // ---------- Access Control ----------
    address public operator;

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notZero(address a) {
        if (a == address(0)) revert ZeroAddress();
        _;
    }

    // ---------- Constructor ----------
    constructor(
        address _baseToken,
        string memory _name,
        string memory _symbol,
        address _operator
    ) notZero(_baseToken) notZero(_operator) {
        baseToken = IERC20(_baseToken);
        name = _name;
        symbol = _symbol;
        operator = _operator;
        mintFeeBps = DEFAULT_MINT_FEE_BPS;
        redeemFeeBps = DEFAULT_REDEEM_FEE_BPS;
        emit OperatorUpdated(address(0), _operator);
        emit MintFeeUpdated(0, mintFeeBps);
        emit RedeemFeeUpdated(0, redeemFeeBps);
    }

    // ---------- Operator Functions ----------
    function setMintFeeBps(uint16 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint16 old = mintFeeBps;
        mintFeeBps = _feeBps;
        emit MintFeeUpdated(old, _feeBps);
    }

    function setRedeemFeeBps(uint16 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint16 old = redeemFeeBps;
        redeemFeeBps = _feeBps;
        emit RedeemFeeUpdated(old, _feeBps);
    }

    function setMintPaused(bool _paused) external onlyOperator {
        mintPaused = _paused;
        emit MintPausedChanged(_paused);
    }

    function setRedeemPaused(bool _paused) external onlyOperator {
        redeemPaused = _paused;
        emit RedeemPausedChanged(_paused);
    }

    function setOperator(address _operator) external onlyOperator notZero(_operator) {
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    // ---------- ERC20 Functions ----------
    function approve(address spender, uint256 amount) external notZero(spender) returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external notZero(to) returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external notZero(to) returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        unchecked {
            if (allowed != type(uint256).max) {
                allowance[from][msg.sender] = allowed - amount;
            }
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    // ---------- Minting ----------
    /**
     * @notice Mints stablecoins to `recipient` by pulling `baseAmount` of base token from the caller.
     *         A mint fee (in base token) is retained by the contract as reserves.
     * @param baseAmount Amount of base token to deposit.
     * @param recipient  Address to receive the minted stablecoins.
     * @return mintedAmount Amount of stablecoins minted.
     */
    function mint(uint256 baseAmount, address recipient) external notZero(recipient) returns (uint256 mintedAmount) {
        if (mintPaused) revert MintPaused();
        if (baseAmount == 0) revert AmountZero();

        uint256 allowed = baseToken.allowance(msg.sender, address(this));
        if (allowed < baseAmount) revert InsufficientAllowance();

        uint256 fee = (baseAmount * mintFeeBps) / BPS_DENOMINATOR;
        mintedAmount = baseAmount - fee;

        // Pull base token from caller
        bool ok = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!ok) revert TransferFailed();

        // Effects
        reserves += baseAmount;
        totalSupply += mintedAmount;
        balanceOf[recipient] += mintedAmount;

        emit Minted(msg.sender, recipient, baseAmount, mintedAmount, fee);
        emit Transfer(address(0), recipient, mintedAmount);
    }

    // ---------- Redemption ----------
    /**
     * @notice Redeems `stableAmount` of stablecoins for base token sent to `recipient`.
     *         A redemption fee (in base token) is retained by the contract.
     * @param stableAmount Amount of stablecoin to redeem.
     * @param recipient    Address to receive the base token.
     * @return baseOut Amount of base token returned.
     */
    function redeem(uint256 stableAmount, address recipient) external notZero(recipient) returns (uint256 baseOut) {
        if (redeemPaused) revert RedeemPaused();
        if (stableAmount == 0) revert AmountZero();

        uint256 userBal = balanceOf[msg.sender];
        if (userBal < stableAmount) revert InsufficientBalance();

        uint256 fee = (stableAmount * redeemFeeBps) / BPS_DENOMINATOR;
        baseOut = stableAmount - fee;

        if (reserves < baseOut) revert InsufficientReserves();

        // Effects
        unchecked {
            balanceOf[msg.sender] = userBal - stableAmount;
            totalSupply -= stableAmount;
            reserves -= baseOut;
        }

        // Interaction
        bool ok = baseToken.transfer(recipient, baseOut);
        if (!ok) revert TransferFailed();

        emit Redeemed(msg.sender, recipient, stableAmount, baseOut, fee);
        emit Transfer(msg.sender, address(0), stableAmount);
    }

    // ---------- Internal ----------
    function _transfer(address from, address to, uint256 amount) internal {
        if (amount == 0) revert AmountZero();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    // ---------- View ----------
    function getReserveBalance() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }
}
