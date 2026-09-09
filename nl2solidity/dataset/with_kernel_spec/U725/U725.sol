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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
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

contract RealWorldAssetLending is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Maximum loan-to-value ratio (70%) expressed in basis points.
    uint16 public constant MAX_LTV_BPS = 7000;

    /// @notice Origination fee (0.5%) expressed in basis points.
    uint16 public constant ORIGINATION_FEE_BPS = 50;

    /// @notice Basis points denominator.
    uint16 public constant BPS_DENOMINATOR = 10000;

    /// @notice Seconds per year, used for annual interest accrual.
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice One in 18-decimal fixed point.
    uint256 private constant ONE_18 = 1e18;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error AssetNotEligible(address asset);
    error AssetAlreadyEligible(address asset);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error LoanOverLTV(uint256 requested, uint256 maxAllowed);
    error InsufficientRepayment();
    error NothingToWithdraw();
    error BorrowingPaused();
    error InvalidInterestRate();
    error InvalidOraclePrice();
    error InvalidDecimals();

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------

    struct CollateralConfig {
        bool eligible;
        uint8 decimals;
        /// @notice Price of one unit of collateral (with 18 decimals) in loan token terms.
        uint256 pricePerUnit;
    }

    struct UserPosition {
        uint256 collateralAmount;
        uint256 principal;
        uint256 interestAccrued;
        uint256 lastAccrualTimestamp;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice The loan token disbursed when users borrow.
    IERC20 public immutable loanToken;

    /// @notice Annual interest rate in basis points (e.g. 500 = 5%).
    uint16 public annualInterestRateBps;

    /// @notice Whether new borrowing is paused.
    bool public borrowingPaused;

    /// @notice Total outstanding principal across all borrowers.
    uint256 public totalPrincipalOutstanding;

    /// @notice Total interest accrued and yet to be collected.
    uint256 public totalInterestPending;

    mapping(address => CollateralConfig) public collateralConfigs;
    address[] public eligibleCollateralList;

    mapping(address => UserPosition) public positions;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event CollateralDeposited(address indexed user, address indexed asset, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed asset, uint256 amount);
    event LoanTaken(address indexed user, uint256 principal, uint256 fee, uint256 totalDebt);
    event LoanRepaid(address indexed user, uint256 principalRepaid, uint256 interestRepaid);
    event InterestRateUpdated(uint16 oldRate, uint16 newRate);
    event CollateralEligibilityUpdated(address indexed asset, bool eligible, uint256 pricePerUnit);
    event BorrowingPausedChanged(bool paused);
    event FeesCollected(address indexed collector, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyEligibleAsset(address asset) {
        if (!collateralConfigs[asset].eligible) revert AssetNotEligible(asset);
        _;
    }

    modifier whenBorrowingNotPaused() {
        if (borrowingPaused) revert BorrowingPaused();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        address loanToken_,
        uint16 initialInterestRateBps_,
        address admin
    ) Ownable(admin) {
        if (loanToken_ == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();
        if (initialInterestRateBps_ == 0 || initialInterestRateBps_ > BPS_DENOMINATOR) {
            revert InvalidInterestRate();
        }
        loanToken = IERC20(loanToken_);
        annualInterestRateBps = initialInterestRateBps_;
    }

    // ---------------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------------

    /// @notice Deposit wrapped RWA collateral.
    /// @param asset The collateral token address.
    /// @param amount The amount to deposit.
    function depositCollateral(address asset, uint256 amount)
        external
        nonReentrant
        onlyEligibleAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(pos);

        pos.collateralAmount += amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, asset, amount);
    }

    /// @notice Borrow loan tokens against deposited collateral.
    /// @param asset The collateral asset backing the loan.
    /// @param borrowAmount The principal amount to borrow.
    function borrow(address asset, uint256 borrowAmount)
        external
        nonReentrant
        onlyEligibleAsset(asset)
        whenBorrowingNotPaused
    {
        if (borrowAmount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(pos);

        uint256 fee = (borrowAmount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 newPrincipal = borrowAmount + fee;

        uint256 collateralValue = _collateralValue(asset, pos.collateralAmount);
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;

        uint256 currentDebt = pos.principal + pos.interestAccrued;
        if (currentDebt + newPrincipal > maxBorrow) {
            revert LoanOverLTV(currentDebt + newPrincipal, maxBorrow);
        }

        pos.principal += newPrincipal;
        pos.lastAccrualTimestamp = block.timestamp;

        totalPrincipalOutstanding += newPrincipal;

        loanToken.safeTransfer(msg.sender, borrowAmount);

        emit LoanTaken(msg.sender, borrowAmount, fee, newPrincipal);
    }

    /// @notice Repay outstanding loan (principal + interest). Excess repayment is refunded.
    /// @param repayAmount The maximum amount of loan token to use for repayment.
    function repay(uint256 repayAmount) external nonReentrant {
        if (repayAmount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(pos);

        uint256 totalDebt = pos.principal + pos.interestAccrued;
        if (totalDebt == 0) revert InsufficientRepayment();

        uint256 amountToTake = repayAmount > totalDebt ? totalDebt : repayAmount;

        uint256 interestPortion = 0;
        uint256 principalPortion = 0;

        if (amountToTake <= pos.interestAccrued) {
            interestPortion = amountToTake;
            pos.interestAccrued -= amountToTake;
        } else {
            interestPortion = pos.interestAccrued;
            principalPortion = amountToTake - pos.interestAccrued;
            pos.interestAccrued = 0;
            pos.principal -= principalPortion;
            totalPrincipalOutstanding -= principalPortion;
        }

        totalInterestPending -= interestPortion;

        loanToken.safeTransferFrom(msg.sender, address(this), amountToTake);

        if (repayAmount > amountToTake) {
            uint256 refund = repayAmount - amountToTake;
            loanToken.safeTransfer(msg.sender, refund);
        }

        emit LoanRepaid(msg.sender, principalPortion, interestPortion);
    }

    /// @notice Withdraw collateral that is not required to back outstanding debt.
    /// @param asset The collateral asset to withdraw.
    /// @param amount The amount to withdraw.
    function withdrawCollateral(address asset, uint256 amount)
        external
        nonReentrant
        onlyEligibleAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(pos);

        if (pos.collateralAmount < amount) revert InsufficientCollateral();

        uint256 remainingCollateral = pos.collateralAmount - amount;
        uint256 collateralValue = _collateralValue(asset, remainingCollateral);
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;

        uint256 currentDebt = pos.principal + pos.interestAccrued;
        if (currentDebt > maxBorrow) revert LoanOverLTV(currentDebt, maxBorrow);

        pos.collateralAmount = remainingCollateral;

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, asset, amount);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    /// @notice Returns the current debt (principal + accrued interest) for a user.
    function getUserDebt(address user) external view returns (uint256) {
        UserPosition memory pos = positions[user];
        uint256 accrued = _pendingInterest(pos);
        return pos.principal + accrued;
    }

    /// @notice Returns the maximum borrowable amount for a user given an asset.
    function maxBorrowable(address user, address asset) external view returns (uint256) {
        UserPosition memory pos = positions[user];
        uint256 accrued = _pendingInterest(pos);
        uint256 currentDebt = pos.principal + accrued;
        uint256 collateralValue = _collateralValue(asset, pos.collateralAmount);
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;
        if (currentDebt >= maxBorrow) return 0;
        return maxBorrow - currentDebt;
    }

    /// @notice Returns the list of eligible collateral assets.
    function getEligibleCollaterals() external view returns (address[] memory) {
        return eligibleCollateralList;
    }

    /// @notice Returns collateral config for an asset.
    function getCollateralConfig(address asset)
        external
        view
        returns (bool eligible, uint8 decimals, uint256 pricePerUnit)
    {
        CollateralConfig memory cfg = collateralConfigs[asset];
        return (cfg.eligible, cfg.decimals, cfg.pricePerUnit);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    /// @notice Set the annual interest rate (in basis points).
    function setInterestRate(uint16 newRateBps) external onlyOwner {
        if (newRateBps == 0 || newRateBps > BPS_DENOMINATOR) revert InvalidInterestRate();
        uint16 old = annualInterestRateBps;
        annualInterestRateBps = newRateBps;
        emit InterestRateUpdated(old, newRateBps);
    }

    /// @notice Add an eligible collateral asset.
    /// @param asset The collateral token address.
    /// @param decimals The token decimals.
    /// @param pricePerUnit The price of one full token unit (18-decimal scaled) in loan token terms.
    function addCollateralAsset(address asset, uint8 decimals, uint256 pricePerUnit)
        external
        onlyOwner
    {
        if (asset == address(0)) revert ZeroAddress();
        if (pricePerUnit == 0) revert InvalidOraclePrice();
        if (decimals == 0 || decimals > 36) revert InvalidDecimals();
        if (collateralConfigs[asset].eligible) revert AssetAlreadyEligible(asset);

        collateralConfigs[asset] = CollateralConfig({
            eligible: true,
            decimals: decimals,
            pricePerUnit: pricePerUnit
        });

        eligibleCollateralList.push(asset);

        emit CollateralEligibilityUpdated(asset, true, pricePerUnit);
    }

    /// @notice Update the price of an existing eligible collateral asset.
    function updateCollateralPrice(address asset, uint256 newPricePerUnit) external onlyOwner {
        if (!collateralConfigs[asset].eligible) revert AssetNotEligible(asset);
        if (newPricePerUnit == 0) revert InvalidOraclePrice();
        collateralConfigs[asset].pricePerUnit = newPricePerUnit;
        emit CollateralEligibilityUpdated(asset, true, newPricePerUnit);
    }

    /// @notice Remove an eligible collateral asset. Existing positions remain, but no new deposits.
    function removeCollateralAsset(address asset) external onlyOwner {
        if (!collateralConfigs[asset].eligible) revert AssetNotEligible(asset);
        collateralConfigs[asset].eligible = false;
        emit CollateralEligibilityUpdated(asset, false, collateralConfigs[asset].pricePerUnit);

        uint256 len = eligibleCollateralList.length;
        for (uint256 i = 0; i < len; i++) {
            if (eligibleCollateralList[i] == asset) {
                eligibleCollateralList[i] = eligibleCollateralList[len - 1];
                eligibleCollateralList.pop();
                break;
            }
        }
    }

    /// @notice Pause or unpause borrowing.
    function setBorrowingPaused(bool paused) external onlyOwner {
        borrowingPaused = paused;
        emit BorrowingPausedChanged(paused);
    }

    /// @notice Collect accumulated interest held by the contract beyond outstanding principal.
    /// @dev Only the excess loan token balance above outstanding principal may be swept.
    function collectFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = loanToken.balanceOf(address(this));
        uint256 collectable = balance > totalPrincipalOutstanding
            ? balance - totalPrincipalOutstanding
            : 0;
        if (collectable < 1) revert NothingToWithdraw();

        totalInterestPending = 0;
        loanToken.safeTransfer(to, collectable);

        emit FeesCollected(to, collectable);
    }

    // ---------------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------------

    /// @dev Accrues interest for a user position based on elapsed time and current rate.
    function _accrueInterest(UserPosition storage pos) internal {
        uint256 accrued = _pendingInterest(pos);
        if (accrued > 0) {
            pos.interestAccrued += accrued;
            totalInterestPending += accrued;
        }
        pos.lastAccrualTimestamp = block.timestamp;
    }

    /// @dev Computes interest accrued since last accrual without mutating state.
    function _pendingInterest(UserPosition memory pos) internal view returns (uint256) {
        uint256 principal = pos.principal;
        if (principal < 1) return 0;

        uint256 last = pos.lastAccrualTimestamp;
        if (last < 1) {
            last = block.timestamp;
        }

        uint256 elapsed = block.timestamp > last ? block.timestamp - last : 0;
        if (elapsed < 1) return 0;

        return (principal * uint256(annualInterestRateBps) * elapsed)
            / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
    }

    /// @dev Converts a collateral amount into loan-token value using the configured price.
    ///      Multiplication is performed before division to avoid precision loss.
    function _collateralValue(address asset, uint256 amount) internal view returns (uint256) {
        CollateralConfig memory cfg = collateralConfigs[asset];
        if (!cfg.eligible) revert AssetNotEligible(asset);

        uint8 decimals = cfg.decimals;
        uint256 pricePerUnit = cfg.pricePerUnit;

        if (decimals <= 18) {
            // Scale amount up to 18 decimals, then apply price.
            // (amount * 10^(18 - decimals) * pricePerUnit) / 1e18
            return (amount * (10 ** (18 - decimals)) * pricePerUnit) / ONE_18;
        } else {
            // Scale amount down from >18 decimals. Multiply first, then divide
            // by the combined factor to preserve precision.
            // (amount * pricePerUnit) / (1e18 * 10^(decimals - 18))
            return (amount * pricePerUnit) / (ONE_18 * (10 ** (decimals - 18)));
        }
    }
}
