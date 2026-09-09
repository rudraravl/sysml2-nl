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
 * @title FiatPeggedStablecoin
 * @notice A fiat-pegged stablecoin collateralized by a single major cryptocurrency.
 *         Users mint stablecoins by depositing the backing token, redeem stablecoins
 *         for the backing token, and transfer stablecoins between accounts.
 *         A fixed 0.5% mint fee is taken from each deposit and routed to a fee recipient.
 *         A daily mint cap (default 1,000,000 stablecoins) limits issuance velocity.
 *         A designated operator may tune the peg ratio and the daily mint cap.
 */
contract FiatPeggedStablecoin {
    // ============ Constants ============
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MINT_FEE_BPS = 50; // 0.5%
    uint256 public constant DEFAULT_MAX_DAILY_MINT = 1_000_000 * WAD;

    // ============ ERC-20 Metadata ============
    string public name;
    string public symbol;
    uint256 public immutable decimals;

    // ============ ERC-20 State ============
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ Backing / Peg State ============
    IERC20 public immutable backingToken;
    uint256 public reserveBalance; // net backing held as collateral (excludes fees sent out)
    uint256 public pegRatio;        // stablecoins minted per 1 backing token, scaled by WAD

    // ============ Daily Mint Cap ============
    uint256 public maxDailyMint;    // max stablecoins mintable per UTC day
    uint256 public dailyMinted;     // stablecoins minted in the current day
    uint256 public currentDay;     // block.timestamp / 1 days

    // ============ Access Control ============
    address public owner;
    address public operator;
    address public feeRecipient;

    // ============ Events ============
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Mint(
        address indexed sender,
        address indexed recipient,
        uint256 stableAmount,
        uint256 depositAmount,
        uint256 feeAmount
    );
    event Redeem(address indexed sender, uint256 stableAmount, uint256 backingAmount);
    event PegRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MaxDailyMintUpdated(uint256 oldLimit, uint256 newLimit);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeeRecipientUpdated(address oldFeeRecipient, address newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error InvalidPegRatio();
    error DailyMintCapExceeded();
    error Unauthorized();
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ============ Constructor ============
    constructor(
        address _backingToken,
        address _initialOwner,
        address _initialOperator,
        address _feeRecipient,
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        uint256 _initialPegRatio
    ) {
        if (_backingToken == address(0)) revert ZeroAddress();
        if (_initialOwner == address(0)) revert ZeroAddress();
        if (_initialOperator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_initialPegRatio == 0) revert InvalidPegRatio();

        backingToken = IERC20(_backingToken);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        pegRatio = _initialPegRatio;
        maxDailyMint = DEFAULT_MAX_DAILY_MINT;
        currentDay = block.timestamp / 1 days;

        owner = _initialOwner;
        operator = _initialOperator;
        feeRecipient = _feeRecipient;

        emit OwnershipTransferred(address(0), _initialOwner);
        emit OperatorUpdated(address(0), _initialOperator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit PegRatioUpdated(0, _initialPegRatio);
        emit MaxDailyMintUpdated(0, DEFAULT_MAX_DAILY_MINT);
    }

    // ============ ERC-20 ============
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (amount == 0) revert InvalidAmount();
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ============ Mint ============
    /**
     * @notice Mint stablecoins to `recipient` by depositing `depositAmount` of the backing token.
     * @dev A 0.5% fee is deducted from the deposit and forwarded to the fee recipient.
     *      The net deposit collateralizes the minted stablecoins at the current peg ratio.
     *      The daily mint cap applies to the amount of stablecoins minted.
     */
    function mint(address recipient, uint256 depositAmount) external {
        if (depositAmount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = (depositAmount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netDeposit = depositAmount - fee;
        if (netDeposit == 0) revert InvalidAmount();

        uint256 stableAmount = (netDeposit * pegRatio) / WAD;
        if (stableAmount == 0) revert InvalidAmount();

        _updateDailyMintCap(stableAmount);

        // Effects
        reserveBalance += netDeposit;
        totalSupply += stableAmount;
        balanceOf[recipient] += stableAmount;

        // Interactions
        _safeTransferFrom(address(backingToken), msg.sender, address(this), depositAmount);
        if (fee > 0) {
            _safeTransfer(address(backingToken), feeRecipient, fee);
        }

        emit Transfer(address(0), recipient, stableAmount);
        emit Mint(msg.sender, recipient, stableAmount, depositAmount, fee);
    }

    // ============ Redeem ============
    /**
     * @notice Burn `stableAmount` stablecoins and return the corresponding backing tokens.
     */
    function redeem(uint256 stableAmount) external {
        if (stableAmount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance();

        uint256 backingAmount = (stableAmount * WAD) / pegRatio;
        if (backingAmount == 0) revert InvalidAmount();
        if (backingAmount > reserveBalance) revert InsufficientReserve();

        // Effects
        balanceOf[msg.sender] -= stableAmount;
        totalSupply -= stableAmount;
        reserveBalance -= backingAmount;

        // Interactions
        _safeTransfer(address(backingToken), msg.sender, backingAmount);

        emit Transfer(msg.sender, address(0), stableAmount);
        emit Redeem(msg.sender, stableAmount, backingAmount);
    }

    // ============ Operator Configuration ============
    function setPegRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0) revert InvalidPegRatio();
        uint256 old = pegRatio;
        pegRatio = newRatio;
        emit PegRatioUpdated(old, newRatio);
    }

    function setMaxDailyMint(uint256 newLimit) external onlyOperator {
        if (newLimit == 0) revert InvalidAmount();
        uint256 old = maxDailyMint;
        maxDailyMint = newLimit;
        emit MaxDailyMintUpdated(old, newLimit);
    }

    // ============ Owner Administration ============
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    // ============ Views ============
    function totalReserve() external view returns (uint256) {
        return reserveBalance;
    }

    function reserveTokenBalance() external view returns (uint256) {
        return backingToken.balanceOf(address(this));
    }

    function dailyMintRemaining() external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        if (today != currentDay) return maxDailyMint;
        return maxDailyMint >= dailyMinted ? maxDailyMint - dailyMinted : 0;
    }

    function mintFeeBps() external pure returns (uint256) {
        return MINT_FEE_BPS;
    }

    // ============ Internal Helpers ============
    function _updateDailyMintCap(uint256 amount) internal {
        uint256 today = block.timestamp / 1 days;
        if (today != currentDay) {
            currentDay = today;
            dailyMinted = 0;
        }
        uint256 newTotal = dailyMinted + amount;
        if (newTotal > maxDailyMint) revert DailyMintCapExceeded();
        dailyMinted = newTotal;
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount) // transferFrom
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount) // transfer
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
