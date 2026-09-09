// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SeigniorageStablecoin {
    // --- Token Metadata ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // --- Immutable Config ---
    IERC20 public immutable reserveToken;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_PAUSE_DURATION = 24 hours;
    uint256 public constant MAX_DEVIATION_BPS = 100; // 1%
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // --- State ---
    address public operator;
    uint256 public totalSupply;
    uint256 public targetPrice; // reserve per stablecoin, scaled by PRICE_PRECISION
    uint256 public redemptionPausedUntil;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, uint256 reserveAmount, uint256 stableAmount);
    event Redeem(address indexed redeemer, uint256 stableAmount, uint256 reservePayout, uint256 fee);
    event TargetPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event RedemptionPaused(uint256 until);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // --- Custom Errors ---
    error NotOperator();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidPrice();
    error PriceDeviationTooHigh();
    error ExceedsMaxSupply();
    error InsufficientBalance();
    error InsufficientAllowance();
    error RedemptionIsPaused();
    error InvalidPauseDuration();
    error TransferFailed();
    error ReentrantCall();

    // --- Reentrancy Guard ---
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // --- Constructor ---
    constructor(
        address _reserveToken,
        address _operator,
        string memory _name,
        string memory _symbol,
        uint256 _initialTargetPrice
    ) {
        if (_reserveToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialTargetPrice == 0) revert InvalidPrice();

        reserveToken = IERC20(_reserveToken);
        operator = _operator;
        name = _name;
        symbol = _symbol;
        targetPrice = _initialTargetPrice;

        emit OperatorChanged(address(0), _operator);
    }

    // --- ERC20 ---

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0) || from == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // --- Mint / Redeem ---

    function mint(uint256 reserveAmount) external nonReentrant {
        if (reserveAmount == 0) revert InvalidAmount();

        uint256 stableAmount = (reserveAmount * PRICE_PRECISION) / targetPrice;
        if (stableAmount == 0) revert InvalidAmount();
        if (totalSupply + stableAmount > MAX_SUPPLY) revert ExceedsMaxSupply();

        // Effects (before interactions)
        totalSupply += stableAmount;
        balanceOf[msg.sender] += stableAmount;

        // Interactions
        if (!reserveToken.transferFrom(msg.sender, address(this), reserveAmount)) {
            revert TransferFailed();
        }

        emit Transfer(address(0), msg.sender, stableAmount);
        emit Mint(msg.sender, reserveAmount, stableAmount);
    }

    function redeem(uint256 stableAmount) external nonReentrant {
        if (stableAmount == 0) revert InvalidAmount();
        if (block.timestamp < redemptionPausedUntil) revert RedemptionIsPaused();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance();

        // Compute payout and fee in a single expression to avoid divide-before-multiply.
        // payout = stableAmount * targetPrice * (BPS_DENOMINATOR - REDEMPTION_FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR)
        // fee    = stableAmount * targetPrice * REDEMPTION_FEE_BPS / (PRICE_PRECISION * BPS_DENOMINATOR)
        uint256 numerator = stableAmount * targetPrice;
        uint256 payout = (numerator * (BPS_DENOMINATOR - REDEMPTION_FEE_BPS)) / (PRICE_PRECISION * BPS_DENOMINATOR);
        uint256 fee = (numerator * REDEMPTION_FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR);

        // Effects (before interactions)
        balanceOf[msg.sender] -= stableAmount;
        totalSupply -= stableAmount;

        // Interactions
        if (!reserveToken.transfer(msg.sender, payout)) {
            revert TransferFailed();
        }

        emit Transfer(msg.sender, address(0), stableAmount);
        emit Redeem(msg.sender, stableAmount, payout, fee);
    }

    // --- Operator Functions ---

    function adjustTargetPrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert InvalidPrice();

        uint256 currentPrice = targetPrice;
        uint256 diff = newPrice > currentPrice
            ? newPrice - currentPrice
            : currentPrice - newPrice;

        if (diff * BPS_DENOMINATOR >= currentPrice * MAX_DEVIATION_BPS) revert PriceDeviationTooHigh();

        targetPrice = newPrice;
        emit TargetPriceUpdated(currentPrice, newPrice);
    }

    function pauseRedemptions(uint256 duration) external onlyOperator {
        if (duration == 0 || duration > MAX_PAUSE_DURATION) revert InvalidPauseDuration();
        redemptionPausedUntil = block.timestamp + duration;
        emit RedemptionPaused(redemptionPausedUntil);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // --- Views ---

    function reservePoolBalance() external view returns (uint256) {
        return reserveToken.balanceOf(address(this));
    }

    function isRedemptionPaused() external view returns (bool) {
        return block.timestamp < redemptionPausedUntil;
    }
}
