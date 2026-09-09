// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @dev Minimal ERC-20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that revert on failure.
 *      transferFrom is restricted to msg.sender to prevent arbitrary-send-erc20.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool ok = token.approve(spender, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function forceApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current != 0) {
            bool ok = token.approve(spender, 0);
            if (!ok) revert SafeERC20FailedOperation(address(token));
        }
        bool ok = token.approve(spender, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    error SafeERC20FailedOperation(address token);
}

/**
 * @title Ownable
 * @dev Simple ownable contract with owner transfer.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/**
 * @title ReentrancyGuard
 * @dev Prevents reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title DecentralizedMoneyMarket
 * @notice A decentralized money market where users deposit collateral, borrow against it,
 *         repay loans, and withdraw excess collateral. Supports multiple assets with
 *         configurable interest rate models, a 75% max LTV, and a 0.5% origination fee.
 */
contract DecentralizedMoneyMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_LTV = 7500; // 75% in basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant ORIGINATION_FEE_BPS = 50; // 0.5%
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RAY = 1e27;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AssetConfig {
        bool supported;
        bool borrowPaused;
        uint256 baseRatePerYear; // in ray (1e27)
        uint256 multiplierPerYear; // in ray
        uint256 utilizationOptimal; // in ray (e.g. 0.8e27)
        uint256 totalAvailable; // total idle liquidity held for this asset
        uint256 totalBorrows; // total outstanding borrows (principal + accrued interest)
        uint256 lastUpdated; // timestamp of last interest accrual
    }

    struct AccountAsset {
        uint256 deposit; // collateral deposited
        uint256 borrow; // principal borrowed (excludes interest)
        uint256 interestIndex; // last borrow interest index snapshot (ray)
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;

    mapping(address => AssetConfig) public assets;
    mapping(address => mapping(address => AccountAsset)) public accounts; // asset => user => AccountAsset
    mapping(address => uint256) public borrowIndex; // asset => current global borrow index (ray)

    address[] public supportedAssetList;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed asset, address indexed account, uint256 amount);
    event Borrow(address indexed borrower, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed payer, address indexed asset, uint256 amount, uint256 interest);
    event Withdraw(address indexed account, address indexed asset, uint256 amount);
    event AssetAdded(address indexed asset, uint256 baseRate, uint256 multiplier, uint256 optimalUtil);
    event BorrowPaused(address indexed asset, bool paused);
    event RateUpdated(address indexed asset, uint256 baseRate, uint256 multiplier, uint256 optimalUtil);
    event OperatorSet(address indexed operator);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported(address asset);
    error BorrowPausedError(address asset);
    error InsufficientCollateral();
    error InsufficientLiquidity(address asset);
    error InsufficientDeposit();
    error RepayExceedsDebt();
    error NoOutstandingDebt();
    error NotOperator();
    error InvalidRate();
    error AlreadySupported();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert NotOperator();
        _;
    }

    modifier supportedAsset(address asset) {
        if (!assets[asset].supported) revert AssetNotSupported(asset);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function addAsset(
        address asset,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 utilizationOptimal
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].supported) revert AlreadySupported();
        if (baseRatePerYear > RAY) revert InvalidRate();
        if (multiplierPerYear > RAY) revert InvalidRate();
        if (utilizationOptimal == 0 || utilizationOptimal > RAY) revert InvalidRate();

        AssetConfig storage cfg = assets[asset];
        cfg.supported = true;
        cfg.borrowPaused = false;
        cfg.baseRatePerYear = baseRatePerYear;
        cfg.multiplierPerYear = multiplierPerYear;
        cfg.utilizationOptimal = utilizationOptimal;
        cfg.lastUpdated = block.timestamp;

        borrowIndex[asset] = RAY;
        supportedAssetList.push(asset);

        emit AssetAdded(asset, baseRatePerYear, multiplierPerYear, utilizationOptimal);
    }

    function setRateParameters(
        address asset,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 utilizationOptimal
    ) external onlyOperator supportedAsset(asset) {
        if (baseRatePerYear > RAY) revert InvalidRate();
        if (multiplierPerYear > RAY) revert InvalidRate();
        if (utilizationOptimal == 0 || utilizationOptimal > RAY) revert InvalidRate();

        _accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        cfg.baseRatePerYear = baseRatePerYear;
        cfg.multiplierPerYear = multiplierPerYear;
        cfg.utilizationOptimal = utilizationOptimal;

        emit RateUpdated(asset, baseRatePerYear, multiplierPerYear, utilizationOptimal);
    }

    function setBorrowPaused(address asset, bool paused) external onlyOperator supportedAsset(asset) {
        assets[asset].borrowPaused = paused;
        emit BorrowPaused(asset, paused);
    }

    /*//////////////////////////////////////////////////////////////
                         INTEREST ACCRUAL
    //////////////////////////////////////////////////////////////*/

    function _utilization(address asset) internal view returns (uint256) {
        AssetConfig storage cfg = assets[asset];
        if (cfg.totalBorrows == 0) return 0;
        uint256 totalSupply = cfg.totalAvailable + cfg.totalBorrows;
        return (cfg.totalBorrows * RAY) / totalSupply;
    }

    function _borrowRate(address asset) internal view returns (uint256) {
        AssetConfig storage cfg = assets[asset];
        uint256 util = _utilization(asset);
        if (util <= cfg.utilizationOptimal) {
            return cfg.baseRatePerYear + ((cfg.multiplierPerYear * util) / RAY);
        } else {
            uint256 excess = util - cfg.utilizationOptimal;
            uint256 denom = RAY - cfg.utilizationOptimal;
            if (denom == 0) {
                return cfg.baseRatePerYear + cfg.multiplierPerYear;
            }
            // Avoid divide-before-multiply: compute (multiplier * excess) / denom directly
            return cfg.baseRatePerYear + cfg.multiplierPerYear + ((cfg.multiplierPerYear * excess) / denom);
        }
    }

    function _accrueInterest(address asset) internal {
        AssetConfig storage cfg = assets[asset];

        // Use <= to avoid dangerous strict equality with block.timestamp
        if (block.timestamp <= cfg.lastUpdated) return;

        if (cfg.totalBorrows == 0) {
            borrowIndex[asset] = RAY;
            cfg.lastUpdated = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - cfg.lastUpdated;

        uint256 rate = _borrowRate(asset);
        uint256 currentIndex = borrowIndex[asset];

        // interestFactor = 1 + rate * elapsed / SECONDS_PER_YEAR (in ray)
        uint256 interestFactor = RAY + ((rate * elapsed) / SECONDS_PER_YEAR);
        uint256 newIndex = (currentIndex * interestFactor) / RAY;

        uint256 interestAccrued = (cfg.totalBorrows * (newIndex - currentIndex)) / currentIndex;
        cfg.totalBorrows += interestAccrued;
        borrowIndex[asset] = newIndex;
        cfg.lastUpdated = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        AccountAsset storage aa = accounts[asset][msg.sender];

        // Effects: update state before external call (checks-effects-interactions)
        aa.deposit += amount;
        cfg.totalAvailable += amount;

        // Interactions
        IERC20(asset).safeTransferFrom(address(this), amount);

        emit Deposit(msg.sender, asset, msg.sender, amount);
    }

    function borrow(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();

        AssetConfig storage cfg = assets[asset];
        if (cfg.borrowPaused) revert BorrowPausedError(asset);

        _accrueInterest(asset);

        if (cfg.totalAvailable < amount) revert InsufficientLiquidity(asset);

        AccountAsset storage aa = accounts[asset][msg.sender];

        // Calculate origination fee
        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 debtToAdd = amount + fee;

        // Compute current debt and new debt
        uint256 currentDebt = _currentDebt(asset, msg.sender);
        uint256 newDebt = currentDebt + debtToAdd;

        // LTV check: debt must be <= 75% of collateral (same-asset collateral model)
        uint256 collateral = aa.deposit;
        uint256 maxBorrow = (collateral * MAX_LTV) / BPS_DENOMINATOR;
        if (newDebt > maxBorrow) revert InsufficientCollateral();

        // Effects: update state before external call
        aa.borrow += debtToAdd;
        aa.interestIndex = borrowIndex[asset];

        cfg.totalAvailable -= amount;
        cfg.totalBorrows += debtToAdd;

        // Interactions
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, fee);
    }

    function repay(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AccountAsset storage aa = accounts[asset][msg.sender];
        uint256 currentDebt = _currentDebt(asset, msg.sender);

        // Avoid strict equality: use < 1 instead of == 0
        if (currentDebt < 1) revert NoOutstandingDebt();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Determine interest vs principal portion
        uint256 interestPortion = currentDebt - aa.borrow;
        uint256 interestRepaid = repayAmount > interestPortion ? interestPortion : repayAmount;
        uint256 principalRepaid = repayAmount - interestRepaid;

        // Effects: update state before external call (checks-effects-interactions)
        aa.borrow -= principalRepaid;
        aa.interestIndex = borrowIndex[asset];

        AssetConfig storage cfg = assets[asset];
        cfg.totalAvailable += repayAmount;
        cfg.totalBorrows -= repayAmount;

        // Interactions
        IERC20(asset).safeTransferFrom(address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount, interestRepaid);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AccountAsset storage aa = accounts[asset][msg.sender];
        if (aa.deposit < amount) revert InsufficientDeposit();

        // Ensure remaining collateral supports outstanding debt
        uint256 debt = _currentDebt(asset, msg.sender);
        uint256 remainingCollateral = aa.deposit - amount;
        uint256 maxBorrow = (remainingCollateral * MAX_LTV) / BPS_DENOMINATOR;
        if (debt > maxBorrow) revert InsufficientCollateral();

        // Effects
        aa.deposit = remainingCollateral;
        assets[asset].totalAvailable -= amount;

        // Interactions
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function _currentDebt(address asset, address account) internal view returns (uint256) {
        AccountAsset storage aa = accounts[asset][account];
        if (aa.borrow == 0) return 0;
        uint256 idx = borrowIndex[asset];
        return (aa.borrow * idx) / aa.interestIndex;
    }

    function currentDebt(address asset, address account) external view supportedAsset(asset) returns (uint256) {
        return _currentDebt(asset, account);
    }

    function collateralOf(address asset, address account) external view supportedAsset(asset) returns (uint256) {
        return accounts[asset][account].deposit;
    }

    function maxBorrowable(address asset, address account) external view supportedAsset(asset) returns (uint256) {
        uint256 collateral = accounts[asset][account].deposit;
        uint256 debt = _currentDebt(asset, account);
        uint256 maxBorrow = (collateral * MAX_LTV) / BPS_DENOMINATOR;
        return debt >= maxBorrow ? 0 : maxBorrow - debt;
    }

    function borrowRate(address asset) external view supportedAsset(asset) returns (uint256) {
        return _borrowRate(asset);
    }

    function utilization(address asset) external view supportedAsset(asset) returns (uint256) {
        return _utilization(asset);
    }

    function getSupportedAssetCount() external view returns (uint256) {
        return supportedAssetList.length;
    }

    function getSupportedAsset(uint256 index) external view returns (address) {
        return supportedAssetList[index];
    }
}
