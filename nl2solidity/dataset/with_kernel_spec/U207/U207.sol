// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract USD0 {
    /* ========== Constants ========== */
    string public constant name = "USD0";
    string public constant symbol = "USD0";
    uint8 public constant decimals = 18;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap

    /* ========== State ========== */
    IERC20 public immutable collateral;
    address public operator;
    address public pendingOperator;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public collateralizationRatio; // 1e18 == 100%
    uint256 public mintFeeBps;              // fee in basis points
    bool public mintPaused;
    bool public redeemPaused;

    uint256 private _locked = 1;

    /* ========== Events ========== */
    event Mint(address indexed caller, address indexed to, uint256 usdcDeposited, uint256 usd0Minted, uint256 fee);
    event Redeem(address indexed caller, address indexed to, uint256 usd0Burned, uint256 usdcReturned);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event MintPausedChanged(bool paused);
    event RedeemPausedChanged(bool paused);
    event OperatorUpdated(address oldOperator, address newOperator);
    event CollateralizationRatioUpdated(uint256 ratio);

    /* ========== Errors ========== */
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error MintIsPaused();
    error RedeemIsPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeExceedsMax(uint256 fee);
    error CollateralizationTooLow(uint256 collateral, uint256 supply);
    error USDCTransferFailed();
    error NoPendingOperator();
    error ReentrantCall();

    /* ========== Modifiers ========== */
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

    /* ========== Constructor ========== */
    constructor(address _collateral, address _operator) {
        if (_collateral == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateral = IERC20(_collateral);
        operator = _operator;
        mintFeeBps = 10; // 0.1%
        collateralizationRatio = PRECISION; // 100%
        emit OperatorUpdated(address(0), _operator);
        emit MintFeeUpdated(0, 10);
        emit CollateralizationRatioUpdated(PRECISION);
    }

    /* ========== Mint / Redeem ========== */

    function mint(address to, uint256 usdcAmount) external nonReentrant {
        if (mintPaused) revert MintIsPaused();
        if (to == address(0)) revert ZeroAddress();
        if (usdcAmount == 0) revert ZeroAmount();

        uint256 fee = (usdcAmount * mintFeeBps) / BPS_DENOMINATOR;
        uint256 netMint = usdcAmount - fee;

        // Effects: update state before external calls (checks-effects-interactions)
        _mint(to, netMint);
        if (fee > 0) {
            _mint(operator, fee);
        }

        // Interactions: pull USDC collateral from caller
        bool ok = collateral.transferFrom(msg.sender, address(this), usdcAmount);
        if (!ok) revert USDCTransferFailed();

        // Post-interaction invariant check using fresh balance
        _checkAndUpdateCollateralizationRatio();

        emit Mint(msg.sender, to, usdcAmount, netMint, fee);
    }

    function redeem(address to, uint256 usd0Amount) external nonReentrant {
        if (redeemPaused) revert RedeemIsPaused();
        if (to == address(0)) revert ZeroAddress();
        if (usd0Amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < usd0Amount) revert InsufficientBalance();

        // Effects: burn before external call (checks-effects-interactions)
        _burn(msg.sender, usd0Amount);

        // Interactions: return USDC to caller
        bool ok = collateral.transfer(to, usd0Amount);
        if (!ok) revert USDCTransferFailed();

        // Post-interaction invariant check using fresh balance
        _checkAndUpdateCollateralizationRatio();

        emit Redeem(msg.sender, to, usd0Amount, usd0Amount);
    }

    /* ========== ERC20 Standard ========== */

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        _transfer(from, to, amount);
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    /* ========== Operator Controls ========== */

    function setMintFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMax(newFeeBps);
        uint256 oldFee = mintFeeBps;
        mintFeeBps = newFeeBps;
        emit MintFeeUpdated(oldFee, newFeeBps);
    }

    function setMintPaused(bool paused) external onlyOperator {
        mintPaused = paused;
        emit MintPausedChanged(paused);
    }

    function setRedeemPaused(bool paused) external onlyOperator {
        redeemPaused = paused;
        emit RedeemPausedChanged(paused);
    }

    function nominateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NoPendingOperator();
        address old = operator;
        operator = pendingOperator;
        pendingOperator = address(0);
        emit OperatorUpdated(old, operator);
    }

    /* ========== Internal ========== */

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _checkAndUpdateCollateralizationRatio() internal {
        uint256 usdcBalance = collateral.balanceOf(address(this));
        uint256 supply = totalSupply;
        // Direct inequality check: collateral must cover at least 100% of supply
        if (usdcBalance < supply) revert CollateralizationTooLow(usdcBalance, supply);
        // Compute ratio only when supply is non-zero; default to 100% otherwise
        collateralizationRatio = supply > 0 ? (usdcBalance * PRECISION) / supply : PRECISION;
        emit CollateralizationRatioUpdated(collateralizationRatio);
    }
}
