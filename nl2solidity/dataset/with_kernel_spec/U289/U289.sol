// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Minimal ERC20 interface
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @notice Wrappers around ERC20 operations that throw on failure when the token
 *         implementation returns no value or returns false.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            amount == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: bad approve"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
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

/**
 * @title EnumerableSet
 * @notice Minimal AddressSet implementation supporting add/remove/contains/values.
 */
library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) {
            return false;
        }
        uint256 lastIndex = set._values.length;
        if (valueIndex != lastIndex) {
            address lastValue = set._values[lastIndex - 1];
            set._values[valueIndex - 1] = lastValue;
            set._indexes[lastValue] = valueIndex;
        }
        set._values.pop();
        delete set._indexes[value];
        return true;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

/**
 * @title Ownable
 * @notice Minimal single-owner access control.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

/**
 * @title ReentrancyGuard
 * @notice Minimal reentrancy protection.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title InterestRateSwapManager
 * @notice Manages interest rate swap agreements backed by deposited collateral tokens.
 *         Users open swaps by depositing collateral meeting a minimum collateralization
 *         ratio (120%), may add/remove collateral while active, and close swaps to
 *         settle accrued interest and reclaim remaining collateral. A designated
 *         operator may pause new openings and curate the supported asset list, while
 *         the owner sets the base swap fee (default 0.05% of notional) and may withdraw
 *         accumulated fees. Maximum swap duration is 90 days.
 */
contract InterestRateSwapManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @dev 120% minimum collateralization ratio expressed in basis points.
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 12000;
    /// @dev Maximum allowed swap duration.
    uint256 public constant MAX_SWAP_DURATION = 90 days;
    /// @dev Basis points scaler (10000 = 100%).
    uint256 public constant BASIS_POINTS = 10000;
    /// @dev Default swap fee in basis points (5 = 0.05%).
    uint256 public constant DEFAULT_SWAP_FEE_BPS = 5;
    /// @dev Annual seconds, used for interest accrual apportioning.
    uint256 public constant YEAR = 365 days;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------

    struct SwapPosition {
        address user;
        address collateralAsset;
        uint256 notionalValue;
        uint256 collateralAmount;
        uint256 fixedRateBps; // annual fixed rate in basis points
        uint40 startTime;
        uint40 duration;
        bool isActive;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    EnumerableSet.AddressSet internal supportedAssets;
    mapping(address => bool) public operators;
    bool public swapPaused;
    uint256 public swapFeeBps;

    uint256 public nextSwapId;
    mapping(uint256 => SwapPosition) public swaps;
    mapping(address => uint256[]) internal userSwapIds;
    mapping(address => uint256) public accumulatedFees;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NotOperator();
    error Unauthorized();
    error SwapPaused();
    error AssetNotSupported();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroNotional();
    error InvalidRate();
    error DurationExceedsMax();
    error InsufficientCollateralization();
    error SwapNotActive();
    error InvalidFee();
    error InsufficientCollateral();
    error NothingToClaim();
    error AssetAlreadySupported();
    error AssetNotInSupportedSet();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event SwapOpened(
        uint256 indexed swapId,
        address indexed user,
        address indexed collateralAsset,
        uint256 notionalValue,
        uint256 collateralAmount,
        uint256 feePaid,
        uint256 fixedRateBps,
        uint40 startTime,
        uint40 duration
    );

    event SwapClosed(
        uint256 indexed swapId,
        address indexed user,
        uint256 collateralReturned,
        uint256 interestSettled,
        uint40 closeTime
    );

    event CollateralChanged(
        uint256 indexed swapId,
        address indexed user,
        bool isAddition,
        uint256 amount,
        uint256 newCollateralBalance
    );

    event AssetSupported(address indexed asset, bool status);
    event OperatorUpdated(address indexed operator, bool status);
    event SwapPauseUpdated(bool paused);
    event SwapFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed token, address indexed recipient, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier onlyOperatorOrOwner() {
        if (!operators[msg.sender] && msg.sender != owner()) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (swapPaused) revert SwapPaused();
        _;
    }

    modifier validAsset(address asset) {
        if (!supportedAssets.contains(asset)) revert AssetNotSupported();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address[] memory initialAssets) Ownable() {
        swapFeeBps = DEFAULT_SWAP_FEE_BPS;
        for (uint256 i = 0; i < initialAssets.length; ++i) {
            address asset = initialAssets[i];
            if (asset == address(0)) revert ZeroAddress();
            bool added = supportedAssets.add(asset);
            if (added) {
                emit AssetSupported(asset, true);
            }
        }
    }

    // ---------------------------------------------------------------------
    // External / Public functions
    // ---------------------------------------------------------------------

    /**
     * @notice Opens a new interest rate swap by depositing collateral.
     * @param collateralAsset Address of the supported ERC20 collateral token.
     * @param collateralAmount Amount of collateral tokens to deposit.
     * @param notionalValue Notional amount of the swap (in token units).
     * @param fixedRateBps Annual fixed interest rate in basis points.
     * @param duration Duration of the swap in seconds (must be <= 90 days).
     * @return swapId The ID assigned to the newly created swap.
     */
    function openSwap(
        address collateralAsset,
        uint256 collateralAmount,
        uint256 notionalValue,
        uint256 fixedRateBps,
        uint40 duration
    )
        external
        nonReentrant
        whenNotPaused
        validAsset(collateralAsset)
        returns (uint256 swapId)
    {
        if (collateralAmount == 0) revert ZeroAmount();
        if (notionalValue == 0) revert ZeroNotional();
        if (fixedRateBps == 0 || fixedRateBps > BASIS_POINTS) revert InvalidRate();
        if (duration == 0 || duration > MAX_SWAP_DURATION) revert DurationExceedsMax();

        // Enforce minimum collateralization ratio.
        uint256 requiredCollateral = (notionalValue * MIN_COLLATERALIZATION_RATIO) / BASIS_POINTS;
        if (collateralAmount < requiredCollateral) revert InsufficientCollateralization();

        // Compute opening fee (0.05% of notional by default).
        uint256 fee = (notionalValue * swapFeeBps) / BASIS_POINTS;

        // Transfer collateral + fee from user. Fee is retained as protocol revenue.
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount + fee);
        accumulatedFees[collateralAsset] += fee;

        swapId = nextSwapId++;
        uint40 startTime = uint40(block.timestamp);

        swaps[swapId] = SwapPosition({
            user: msg.sender,
            collateralAsset: collateralAsset,
            notionalValue: notionalValue,
            collateralAmount: collateralAmount,
            fixedRateBps: fixedRateBps,
            startTime: startTime,
            duration: duration,
            isActive: true
        });
        userSwapIds[msg.sender].push(swapId);

        emit SwapOpened(
            swapId,
            msg.sender,
            collateralAsset,
            notionalValue,
            collateralAmount,
            fee,
            fixedRateBps,
            startTime,
            duration
        );
    }

    /**
     * @notice Closes an active swap, settles accrued interest against collateral,
     *         and returns the remaining collateral to the user.
     * @param swapId ID of the swap to close.
     * @return collateralReturned Amount of collateral tokens returned to the user.
     */
    function closeSwap(uint256 swapId) external nonReentrant returns (uint256 collateralReturned) {
        SwapPosition storage pos = swaps[swapId];
        if (!pos.isActive) revert SwapNotActive();
        if (pos.user != msg.sender) revert Unauthorized();

        uint256 interestSettled = _accruedInterest(pos);
        uint256 collateral = pos.collateralAmount;

        if (interestSettled >= collateral) {
            collateralReturned = 0;
        } else {
            collateralReturned = collateral - interestSettled;
        }

        address asset = pos.collateralAsset;
        address swapUser = pos.user;

        // Effects: clear state before external transfer.
        delete swaps[swapId];
        _removeSwapIdFromUserList(swapUser, swapId);

        // Interaction: return remaining collateral.
        if (collateralReturned > 0) {
            IERC20(asset).safeTransfer(msg.sender, collateralReturned);
        }

        emit SwapClosed(swapId, msg.sender, collateralReturned, interestSettled, uint40(block.timestamp));
    }

    /**
     * @notice Adds collateral to an active swap.
     * @param swapId ID of the swap.
     * @param amount Amount of collateral tokens to add.
     */
    function addCollateral(uint256 swapId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        SwapPosition storage pos = swaps[swapId];
        if (!pos.isActive) revert SwapNotActive();
        if (pos.user != msg.sender) revert Unauthorized();

        // Effects: update state before external transfer to prevent reentrancy.
        pos.collateralAmount += amount;

        // Interaction: pull collateral from user.
        IERC20(pos.collateralAsset).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralChanged(swapId, msg.sender, true, amount, pos.collateralAmount);
    }

    /**
     * @notice Removes collateral from an active swap, subject to maintaining the
     *         minimum collateralization ratio against the notional.
     * @param swapId ID of the swap.
     * @param amount Amount of collateral tokens to withdraw.
     */
    function removeCollateral(uint256 swapId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        SwapPosition storage pos = swaps[swapId];
        if (!pos.isActive) revert SwapNotActive();
        if (pos.user != msg.sender) revert Unauthorized();
        if (amount > pos.collateralAmount) revert InsufficientCollateral();

        uint256 remaining = pos.collateralAmount - amount;
        uint256 requiredCollateral = (pos.notionalValue * MIN_COLLATERALIZATION_RATIO) / BASIS_POINTS;
        if (remaining < requiredCollateral) revert InsufficientCollateralization();

        // Effects: update state before external transfer.
        pos.collateralAmount = remaining;
        address asset = pos.collateralAsset;

        // Interaction: send collateral to user.
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit CollateralChanged(swapId, msg.sender, false, amount, remaining);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    /**
     * @notice Pauses or unpauses new swap openings. Existing swaps remain actionable.
     */
    function setSwapPaused(bool _paused) external onlyOperatorOrOwner {
        swapPaused = _paused;
        emit SwapPauseUpdated(_paused);
    }

    /**
     * @notice Adds or removes a token from the supported collateral list.
     */
    function setAssetSupported(address asset, bool status) external onlyOperatorOrOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (status) {
            bool added = supportedAssets.add(asset);
            if (!added) revert AssetAlreadySupported();
        } else {
            bool removed = supportedAssets.remove(asset);
            if (!removed) revert AssetNotInSupportedSet();
        }
        emit AssetSupported(asset, status);
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------

    /**
     * @notice Updates the base swap fee (in basis points), capped at 100%.
     */
    function setSwapFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BASIS_POINTS) revert InvalidFee();
        uint256 old = swapFeeBps;
        swapFeeBps = _feeBps;
        emit SwapFeeUpdated(old, _feeBps);
    }

    /**
     * @notice Grants or revokes operator privileges.
     */
    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    /**
     * @notice Withdraws accumulated protocol fees for a given token.
     */
    function withdrawFees(address asset, address recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0 || accumulatedFees[asset] < amount) revert NothingToClaim();
        accumulatedFees[asset] -= amount;
        IERC20(asset).safeTransfer(recipient, amount);
        emit FeesWithdrawn(asset, recipient, amount);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    function isAssetSupported(address asset) external view returns (bool) {
        return supportedAssets.contains(asset);
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets.values();
    }

    function getSwap(uint256 swapId) external view returns (SwapPosition memory) {
        return swaps[swapId];
    }

    function getUserSwaps(address user) external view returns (uint256[] memory) {
        return userSwapIds[user];
    }

    function getSwapStatus(uint256 swapId)
        external
        view
        returns (bool isActive, bool isExpired, uint40 timeRemaining)
    {
        SwapPosition storage pos = swaps[swapId];
        isActive = pos.isActive;
        uint40 endTime = pos.startTime + pos.duration;
        isExpired = block.timestamp >= endTime;
        timeRemaining = isExpired ? 0 : endTime - uint40(block.timestamp);
    }

    function getCollateralizationRatio(uint256 swapId) external view returns (uint256 ratioBps) {
        SwapPosition storage pos = swaps[swapId];
        if (pos.notionalValue == 0) return 0;
        ratioBps = (pos.collateralAmount * BASIS_POINTS) / pos.notionalValue;
    }

    function pendingInterest(uint256 swapId) external view returns (uint256) {
        SwapPosition storage pos = swaps[swapId];
        if (!pos.isActive) return 0;
        return _accruedInterestView(pos);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /**
     * @dev Computes interest accrued up to `min(now, startTime + duration)` using a
     *      linear model: notional * fixedRateBps * elapsedSeconds / (YEAR * BASIS_POINTS).
     *      Avoids strict equality checks; a zero elapsed time naturally yields zero.
     */
    function _accruedInterestView(SwapPosition storage pos) internal view returns (uint256) {
        uint40 endTime = pos.startTime + pos.duration;
        uint256 elapsed;
        if (block.timestamp >= endTime) {
            elapsed = uint256(endTime - pos.startTime);
        } else {
            elapsed = uint256(block.timestamp - pos.startTime);
        }
        // No strict equality check needed: when elapsed is 0 the product is 0.
        return (pos.notionalValue * pos.fixedRateBps * elapsed) / (YEAR * BASIS_POINTS);
    }

    /**
     * @dev Returns accrued interest for an active swap (capped at duration).
     */
    function _accruedInterest(SwapPosition storage pos) internal view returns (uint256) {
        return _accruedInterestView(pos);
    }

    /**
     * @dev Removes a swapId from the user's swap list by swapping with the last element.
     */
    function _removeSwapIdFromUserList(address user, uint256 swapId) internal {
        uint256[] storage ids = userSwapIds[user];
        uint256 len = ids.length;
        for (uint256 i = 0; i < len; ++i) {
            if (ids[i] == swapId) {
                if (i != len - 1) {
                    ids[i] = ids[len - 1];
                }
                ids.pop();
                return;
            }
        }
    }
}
