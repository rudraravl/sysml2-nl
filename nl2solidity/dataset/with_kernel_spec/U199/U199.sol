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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) {
            require(address(token).code.length > 0, "SafeERC20: address is not a contract");
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFromSelf(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, to, amount);
        if (!success) {
            require(address(token).code.length > 0, "SafeERC20: address is not a contract");
            revert("SafeERC20: transferFrom failed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract BasisTradingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error AmountBelowMinimum();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error FeeExceedsMaximum();
    error PositionNotActive();
    error PositionAlreadyClosed();
    error InvalidCollateralRatio();
    error NotAuthorizedOperator();

    event StablecoinDeposited(address indexed user, uint256 amountDeposited, uint256 feeCharged, uint256 netCredited);
    event StablecoinWithdrawn(address indexed user, uint256 amount);
    event WrappedCryptoDeposited(address indexed user, uint256 amount);
    event WrappedCryptoWithdrawn(address indexed user, uint256 amountWithdrawn, uint256 feeCharged, uint256 netTransferred);
    event BasisPositionOpened(uint256 indexed positionId, uint256 size, uint256 collateralRatio);
    event BasisPositionClosed(uint256 indexed positionId);
    event CollateralRatioAdjusted(uint256 indexed positionId, uint256 oldRatio, uint256 newRatio);
    event StablecoinDepositFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event WrappedCryptoWithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesCollected(address indexed recipient, uint256 stablecoinFees, uint256 wrappedCryptoFees);

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant MIN_COLLATERAL_RATIO_BPS = 10000;
    uint256 public constant DEFAULT_STABLECOIN_DEPOSIT_FEE_BPS = 10;
    uint256 public constant MIN_STABLECOIN_DEPOSIT = 100 * 10 ** 18;

    IERC20 public immutable stablecoin;
    IERC20 public immutable wrappedCrypto;

    mapping(address => uint256) public stablecoinBalances;
    mapping(address => uint256) public wrappedCryptoBalances;

    uint256 public totalStablecoinPool;
    uint256 public totalWrappedCryptoPool;

    uint256 public stablecoinDepositFeeBps;
    uint256 public wrappedCryptoWithdrawalFeeBps;

    uint256 public accumulatedStablecoinFees;
    uint256 public accumulatedWrappedCryptoFees;

    address public operator;

    struct BasisPosition {
        uint256 size;
        uint256 collateralRatio;
        bool isOpen;
        uint256 createdAt;
    }

    mapping(uint256 => BasisPosition) public positions;
    uint256 public nextPositionId;
    uint256 public openPositionCount;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorizedOperator();
        _;
    }

    constructor(address _stablecoin, address _wrappedCrypto, address _operator) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_wrappedCrypto == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        wrappedCrypto = IERC20(_wrappedCrypto);
        operator = _operator;
        stablecoinDepositFeeBps = DEFAULT_STABLECOIN_DEPOSIT_FEE_BPS;
        wrappedCryptoWithdrawalFeeBps = 0;
        nextPositionId = 1;
    }

    function depositStablecoin(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_STABLECOIN_DEPOSIT) revert AmountBelowMinimum();

        uint256 fee = (amount * stablecoinDepositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        stablecoin.safeTransferFromSelf(address(this), amount);

        stablecoinBalances[msg.sender] += netAmount;
        totalStablecoinPool += netAmount;
        accumulatedStablecoinFees += fee;

        emit StablecoinDeposited(msg.sender, amount, fee, netAmount);
    }

    function withdrawStablecoin(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stablecoinBalances[msg.sender] < amount) revert InsufficientBalance();
        if (totalStablecoinPool < amount) revert InsufficientLiquidity();

        stablecoinBalances[msg.sender] -= amount;
        totalStablecoinPool -= amount;

        stablecoin.safeTransfer(msg.sender, amount);

        emit StablecoinWithdrawn(msg.sender, amount);
    }

    function depositWrappedCrypto(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        wrappedCrypto.safeTransferFromSelf(address(this), amount);

        wrappedCryptoBalances[msg.sender] += amount;
        totalWrappedCryptoPool += amount;

        emit WrappedCryptoDeposited(msg.sender, amount);
    }

    function withdrawWrappedCrypto(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (wrappedCryptoBalances[msg.sender] < amount) revert InsufficientBalance();
        if (totalWrappedCryptoPool < amount) revert InsufficientLiquidity();

        uint256 fee = (amount * wrappedCryptoWithdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        wrappedCryptoBalances[msg.sender] -= amount;
        totalWrappedCryptoPool -= amount;
        accumulatedWrappedCryptoFees += fee;

        wrappedCrypto.safeTransfer(msg.sender, netAmount);

        emit WrappedCryptoWithdrawn(msg.sender, amount, fee, netAmount);
    }

    function setStablecoinDepositFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        uint256 oldFee = stablecoinDepositFeeBps;
        stablecoinDepositFeeBps = _feeBps;
        emit StablecoinDepositFeeUpdated(oldFee, _feeBps);
    }

    function setWrappedCryptoWithdrawalFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        uint256 oldFee = wrappedCryptoWithdrawalFeeBps;
        wrappedCryptoWithdrawalFeeBps = _feeBps;
        emit WrappedCryptoWithdrawalFeeUpdated(oldFee, _feeBps);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = _operator;
        emit OperatorUpdated(oldOperator, _operator);
    }

    function openBasisPosition(uint256 size, uint256 collateralRatio) external onlyOwner nonReentrant returns (uint256 positionId) {
        if (size == 0) revert ZeroAmount();
        if (collateralRatio < MIN_COLLATERAL_RATIO_BPS) revert InvalidCollateralRatio();

        positionId = nextPositionId++;

        positions[positionId] = BasisPosition({
            size: size,
            collateralRatio: collateralRatio,
            isOpen: true,
            createdAt: block.timestamp
        });

        openPositionCount++;

        emit BasisPositionOpened(positionId, size, collateralRatio);
    }

    function closeBasisPosition(uint256 positionId) external onlyOwner nonReentrant {
        BasisPosition storage position = positions[positionId];
        if (!position.isOpen) revert PositionAlreadyClosed();

        position.isOpen = false;
        openPositionCount--;

        emit BasisPositionClosed(positionId);
    }

    function adjustCollateralRatio(uint256 positionId, uint256 newCollateralRatio) external onlyOperator {
        BasisPosition storage position = positions[positionId];
        if (!position.isOpen) revert PositionNotActive();
        if (newCollateralRatio < MIN_COLLATERAL_RATIO_BPS) revert InvalidCollateralRatio();

        uint256 oldRatio = position.collateralRatio;
        position.collateralRatio = newCollateralRatio;

        emit CollateralRatioAdjusted(positionId, oldRatio, newCollateralRatio);
    }

    function withdrawFees(address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        uint256 stablecoinFees = accumulatedStablecoinFees;
        uint256 wrappedCryptoFees = accumulatedWrappedCryptoFees;

        accumulatedStablecoinFees = 0;
        accumulatedWrappedCryptoFees = 0;

        if (stablecoinFees > 0) {
            stablecoin.safeTransfer(recipient, stablecoinFees);
        }
        if (wrappedCryptoFees > 0) {
            wrappedCrypto.safeTransfer(recipient, wrappedCryptoFees);
        }

        emit FeesCollected(recipient, stablecoinFees, wrappedCryptoFees);
    }

    function getStablecoinBalance(address user) external view returns (uint256) {
        return stablecoinBalances[user];
    }

    function getWrappedCryptoBalance(address user) external view returns (uint256) {
        return wrappedCryptoBalances[user];
    }

    function getPosition(uint256 positionId) external view returns (BasisPosition memory) {
        return positions[positionId];
    }
}
