// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract LiquidStakingDerivative {
    string public name;
    string public symbol;
    uint8 public decimals;

    IERC20 public immutable baseToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalStakedBase;
    uint256 public accruedFees;

    address public owner;
    address public operator;

    bool public depositsPaused;
    bool public withdrawalsPaused;

    uint256 public feeBps;
    uint256 public constant MAX_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public immutable maxRedeemBase;

    uint256 private _locked = 1;

    event Deposit(address indexed caller, address indexed receiver, uint256 baseAmount, uint256 liquidMinted);
    event Redeem(address indexed caller, address indexed receiver, uint256 liquidBurned, uint256 basePayout, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DepositsPausedChanged(bool paused);
    event WithdrawalsPausedChanged(bool paused);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesClaimed(address indexed operator, uint256 amount);

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error DepositsArePaused();
    error WithdrawalsArePaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeTooHigh();
    error ExceedsMaxRedeem();
    error NothingToClaim();
    error TransferFailed();
    error ReentrancyGuard();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _baseToken,
        address _operator,
        string memory _name,
        string memory _symbol,
        uint8 _baseDecimals
    ) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        baseToken = IERC20(_baseToken);
        maxRedeemBase = 1000 * (10 ** uint256(_baseDecimals));

        owner = msg.sender;
        operator = _operator;
        feeBps = MAX_FEE_BPS;

        name = _name;
        symbol = _symbol;
        decimals = _baseDecimals;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeUpdated(0, feeBps);
    }

    function exchangeRate() public view returns (uint256) {
        if (totalSupply == 0 || totalStakedBase == 0) {
            return 1e18;
        }
        return (totalStakedBase * 1e18) / totalSupply;
    }

    function deposit(address receiver, uint256 baseAmount)
        external
        whenDepositsNotPaused
        nonReentrant
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (baseAmount == 0) revert ZeroAmount();

        uint256 liquidMinted;
        if (totalSupply == 0 || totalStakedBase == 0) {
            liquidMinted = baseAmount;
        } else {
            liquidMinted = (baseAmount * totalSupply) / totalStakedBase;
        }

        totalStakedBase += baseAmount;
        totalSupply += liquidMinted;
        balanceOf[receiver] += liquidMinted;

        bool ok = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, receiver, baseAmount, liquidMinted);
        emit Transfer(address(0), receiver, liquidMinted);
    }

    function redeem(uint256 liquidAmount, address receiver)
        external
        whenWithdrawalsNotPaused
        nonReentrant
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (liquidAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < liquidAmount) revert InsufficientBalance();
        if (totalSupply == 0) revert ZeroAmount();

        // Compute the full numerator once to avoid divide-before-multiply.
        uint256 numerator = liquidAmount * totalStakedBase;

        // Fee computed from the full-precision numerator before any division.
        uint256 fee = (numerator * feeBps) / (totalSupply * BPS_DENOMINATOR);

        // Base amount redeemed (rounded down).
        uint256 baseAmount = numerator / totalSupply;
        if (baseAmount == 0) revert ZeroAmount();
        if (baseAmount > maxRedeemBase) revert ExceedsMaxRedeem();

        // Ensure fee never exceeds baseAmount due to rounding edge cases.
        if (fee > baseAmount) fee = baseAmount;

        uint256 payout = baseAmount - fee;

        balanceOf[msg.sender] -= liquidAmount;
        totalSupply -= liquidAmount;
        totalStakedBase -= baseAmount;
        accruedFees += fee;

        emit Transfer(msg.sender, address(0), liquidAmount);
        emit Redeem(msg.sender, receiver, liquidAmount, payout, fee);

        bool ok = baseToken.transfer(receiver, payout);
        if (!ok) revert TransferFailed();
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
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
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function setDepositsPaused(bool _paused) external onlyOperator {
        depositsPaused = _paused;
        emit DepositsPausedChanged(_paused);
    }

    function setWithdrawalsPaused(bool _paused) external onlyOperator {
        withdrawalsPaused = _paused;
        emit WithdrawalsPausedChanged(_paused);
    }

    function setFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function claimFees() external onlyOperator nonReentrant {
        uint256 amount = accruedFees;
        if (amount == 0) revert NothingToClaim();

        accruedFees = 0;
        totalStakedBase -= amount;

        emit FeesClaimed(msg.sender, amount);

        bool ok = baseToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function totalBaseTokens() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }
}
