// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: approve failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract StableTokenSystem is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MINT_FEE_BPS = 50;
    uint256 public constant MIN_MINT_RATIO = 150;
    uint256 public constant MIN_RATIO = 100;
    uint256 public constant MAX_RATIO = 200;
    uint256 public constant INTEREST_RATE_BPS = 500;
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;

    IERC20 public immutable stableToken;
    IERC20 public immutable collateralToken;

    address public operator;
    address public feeRecipient;

    uint256 public collateralizationRatio;
    bool public mintPaused;

    uint256 public totalCollateralReserve;
    uint256 public totalStableMinted;
    uint256 public totalFeesCollected;

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 accruedInterest;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    event Deposit(address indexed user, address indexed token, uint256 amount, string transactionType);
    event Withdraw(address indexed user, address indexed token, uint256 amount, string transactionType);
    event Mint(address indexed user, uint256 amount, uint256 fee, string transactionType);
    event Repay(address indexed user, uint256 amount, uint256 interestPaid, string transactionType);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientSet(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event CollateralizationRatioSet(uint256 oldRatio, uint256 newRatio);
    event MintPauseToggled(bool paused);
    event InterestAccrued(address indexed user, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error OnlyOperator();
    error MintPaused();
    error RatioOutOfRange(uint256 ratio);
    error InsufficientCollateral();
    error InsufficientDebt();
    error InsufficientBalance();
    error NotEnoughExcessCollateral();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier notMintPaused() {
        if (mintPaused) revert MintPaused();
        _;
    }

    constructor(
        address _stableToken,
        address _collateralToken,
        address _operator,
        address _feeRecipient,
        uint256 _initialRatio
    ) Ownable(msg.sender) {
        if (
            _stableToken == address(0) ||
            _collateralToken == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();
        if (_initialRatio < MIN_RATIO || _initialRatio > MAX_RATIO)
            revert RatioOutOfRange(_initialRatio);

        stableToken = IERC20(_stableToken);
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        collateralizationRatio = _initialRatio;

        emit OperatorSet(address(0), _operator);
        emit FeeRecipientSet(address(0), _feeRecipient);
        emit CollateralizationRatioSet(0, _initialRatio);
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];

        if (pos.lastUpdate == 0) {
            pos.lastUpdate = block.timestamp;
            return;
        }

        if (block.timestamp <= pos.lastUpdate) return;

        uint256 elapsed = block.timestamp - pos.lastUpdate;
        if (pos.debt > 0) {
            uint256 interest = (pos.debt * INTEREST_RATE_BPS * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            pos.accruedInterest += interest;
            if (interest > 0) emit InterestAccrued(user, interest);
        }
        pos.lastUpdate = block.timestamp;
    }

    function getTotalDebt(address user) public view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.debt < 1 && pos.accruedInterest < 1) return 0;
        uint256 elapsed = block.timestamp > pos.lastUpdate ? block.timestamp - pos.lastUpdate : 0;
        uint256 pendingInterest = (pos.debt * INTEREST_RATE_BPS * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        return pos.debt + pos.accruedInterest + pendingInterest;
    }

    function getCollateralizationRatio(address user) public view returns (uint256) {
        Position storage pos = positions[user];
        uint256 totalDebt = getTotalDebt(user);
        if (totalDebt < 1) return type(uint256).max;
        return (pos.collateral * 100) / totalDebt;
    }

    function maxMintable(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        uint256 maxDebt = (pos.collateral * 100) / MIN_MINT_RATIO;
        uint256 totalDebt = getTotalDebt(user);
        if (totalDebt >= maxDebt) return 0;
        return maxDebt - totalDebt;
    }

    function withdrawableCollateral(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        uint256 totalDebt = getTotalDebt(user);
        if (totalDebt < 1) return pos.collateral;
        uint256 requiredCollateral = (totalDebt * collateralizationRatio) / 100;
        if (pos.collateral <= requiredCollateral) return 0;
        return pos.collateral - requiredCollateral;
    }

    function getPosition(address user)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 accruedInterest, uint256 lastUpdate)
    {
        Position storage pos = positions[user];
        return (pos.collateral, pos.debt, pos.accruedInterest, pos.lastUpdate);
    }

    function getSystemStats()
        external
        view
        returns (
            uint256 _totalCollateralReserve,
            uint256 _totalStableMinted,
            uint256 _totalFeesCollected,
            uint256 _collateralizationRatio,
            bool _mintPaused
        )
    {
        return (
            totalCollateralReserve,
            totalStableMinted,
            totalFeesCollected,
            collateralizationRatio,
            mintPaused
        );
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        positions[msg.sender].collateral += amount;
        totalCollateralReserve += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, address(collateralToken), amount, "DepositCollateral");
    }

    function mintStable(uint256 amount) external nonReentrant notMintPaused {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];

        uint256 fee = (amount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalNewDebt = amount + fee;

        pos.debt += totalNewDebt;
        totalStableMinted += totalNewDebt;
        totalFeesCollected += fee;

        uint256 totalDebt = pos.debt + pos.accruedInterest;
        if (totalDebt < 1) revert InsufficientDebt();
        uint256 ratio = (pos.collateral * 100) / totalDebt;
        if (ratio < MIN_MINT_RATIO) revert InsufficientCollateral();

        stableToken.safeTransfer(msg.sender, amount);

        emit Mint(msg.sender, amount, fee, "MintStable");
    }

    function repayStable(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        uint256 totalDebt = pos.debt + pos.accruedInterest;
        if (totalDebt < 1) revert InsufficientDebt();

        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;
        uint256 interestPaid = 0;

        if (pos.accruedInterest > 0) {
            if (repayAmount <= pos.accruedInterest) {
                pos.accruedInterest -= repayAmount;
                interestPaid = repayAmount;
                repayAmount = 0;
            } else {
                interestPaid = pos.accruedInterest;
                repayAmount -= pos.accruedInterest;
                pos.accruedInterest = 0;
            }
        }

        if (repayAmount > 0) {
            pos.debt -= repayAmount;
        }

        uint256 debtReduction = interestPaid + repayAmount;
        totalStableMinted -= debtReduction;

        stableToken.safeTransferFrom(msg.sender, address(this), debtReduction);

        emit Repay(msg.sender, debtReduction, interestPaid, "RepayStable");
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        if (pos.collateral < amount) revert InsufficientBalance();

        uint256 totalDebt = pos.debt + pos.accruedInterest;
        if (totalDebt > 0) {
            uint256 requiredCollateral = (totalDebt * collateralizationRatio) / 100;
            if (pos.collateral - amount < requiredCollateral) revert NotEnoughExcessCollateral();
        }

        pos.collateral -= amount;
        totalCollateralReserve -= amount;

        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, address(collateralToken), amount, "WithdrawCollateral");
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientSet(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_RATIO || newRatio > MAX_RATIO)
            revert RatioOutOfRange(newRatio);
        emit CollateralizationRatioSet(collateralizationRatio, newRatio);
        collateralizationRatio = newRatio;
    }

    function toggleMintPause() external onlyOperator {
        mintPaused = !mintPaused;
        emit MintPauseToggled(mintPaused);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (amount > totalFeesCollected) revert InsufficientBalance();
        totalFeesCollected -= amount;
        stableToken.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }
}
