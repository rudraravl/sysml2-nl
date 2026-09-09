// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

/**
 * @title CrossChainAssetBridge
 * @notice Custodies underlying assets and issues internal wrapped token balances that can be
 *         used across chains. The bridge maintains a ledger of wrapped token supplies and
 *         per-user balances for each registered original asset.
 */
contract CrossChainAssetBridge {
    using SafeERC20 for IERC20;

    /* ------------------------------------------------------------------ */
    /*                              Errors                                */
    /* ------------------------------------------------------------------ */

    error NotOperator();
    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotRegistered(address asset);
    error AssetAlreadyRegistered(address asset);
    error WrappedTokenAlreadyRegistered(address wrappedToken);
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientWrappedBalance(address user, uint256 available, uint256 required);

    /* ------------------------------------------------------------------ */
    /*                              Events                                */
    /* ------------------------------------------------------------------ */

    event AssetRegistered(address indexed originalAsset, address indexed wrappedToken);
    event AssetMappingUpdated(address indexed originalAsset, address indexed oldWrapped, address indexed newWrapped);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event PauseStateChanged(bool paused);
    event Deposited(address indexed user, address indexed asset, uint256 amount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);

    /* ------------------------------------------------------------------ */
    /*                            Constants                               */
    /* ------------------------------------------------------------------ */

    /// @notice Minimum deposit threshold, expressed in base units of the underlying asset.
    uint256 public constant MINIMUM_DEPOSIT = 100;

    /* ------------------------------------------------------------------ */
    /*                            State                                   */
    /* ------------------------------------------------------------------ */

    /// @notice Mapping from original asset address to its wrapped token address.
    mapping(address => address) public originalToWrapped;

    /// @notice Mapping from wrapped token address to its original asset address.
    mapping(address => address) public wrappedToOriginal;

    /// @notice Total supply of wrapped tokens minted for each original asset.
    mapping(address => uint256) public wrappedTotalSupply;

    /// @notice Wrapped token balances: originalAsset => user => balance.
    mapping(address => mapping(address => uint256)) public wrappedBalanceOf;

    /// @notice The designated operator that may pause operations and manage asset mappings.
    address public operator;

    /// @notice Whether deposits and withdrawals are globally paused.
    bool public paused;

    /* ------------------------------------------------------------------ */
    /*                           Modifiers                                */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /* ------------------------------------------------------------------ */
    /*                          Constructor                               */
    /* ------------------------------------------------------------------ */

    constructor(address initialOperator) {
        if (initialOperator == address(0)) revert ZeroAddress();
        operator = initialOperator;
        emit OperatorChanged(address(0), initialOperator);
    }

    /* ------------------------------------------------------------------ */
    /*                       Operator Functions                           */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Transfers operator privileges to a new account.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /**
     * @notice Pauses or unpauses all deposit and withdrawal operations.
     * @param state The desired pause state.
     */
    function setPaused(bool state) external onlyOperator {
        paused = state;
        emit PauseStateChanged(state);
    }

    /**
     * @notice Registers a new original asset and its corresponding wrapped token address.
     * @param originalAsset The address of the underlying ERC-20 asset.
     * @param wrappedToken  The address representing the wrapped token on this chain.
     */
    function registerAsset(address originalAsset, address wrappedToken) external onlyOperator {
        if (originalAsset == address(0) || wrappedToken == address(0)) revert ZeroAddress();
        if (originalToWrapped[originalAsset] != address(0)) revert AssetAlreadyRegistered(originalAsset);
        if (wrappedToOriginal[wrappedToken] != address(0)) revert WrappedTokenAlreadyRegistered(wrappedToken);

        originalToWrapped[originalAsset] = wrappedToken;
        wrappedToOriginal[wrappedToken] = originalAsset;

        emit AssetRegistered(originalAsset, wrappedToken);
    }

    /**
     * @notice Updates the wrapped token address for an already registered original asset.
     * @param originalAsset The address of the underlying ERC-20 asset.
     * @param newWrapped    The new wrapped token address to associate.
     */
    function updateAssetMapping(address originalAsset, address newWrapped) external onlyOperator {
        if (originalToWrapped[originalAsset] == address(0)) revert AssetNotRegistered(originalAsset);
        if (newWrapped == address(0)) revert ZeroAddress();
        if (wrappedToOriginal[newWrapped] != address(0)) revert WrappedTokenAlreadyRegistered(newWrapped);

        address oldWrapped = originalToWrapped[originalAsset];
        if (oldWrapped != address(0)) {
            delete wrappedToOriginal[oldWrapped];
        }

        originalToWrapped[originalAsset] = newWrapped;
        wrappedToOriginal[newWrapped] = originalAsset;

        emit AssetMappingUpdated(originalAsset, oldWrapped, newWrapped);
    }

    /* ------------------------------------------------------------------ */
    /*                       Deposit / Withdrawal                         */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Deposits an underlying asset into the bridge and mints the equivalent wrapped
     *         token to the caller's internal balance.
     * @param originalAsset The original asset being deposited.
     * @param amount        The amount of the underlying asset to deposit.
     */
    function deposit(address originalAsset, uint256 amount) external whenNotPaused {
        address wrappedToken = originalToWrapped[originalAsset];
        if (wrappedToken == address(0)) revert AssetNotRegistered(originalAsset);
        if (amount <= MINIMUM_DEPOSIT) revert DepositBelowMinimum(amount, MINIMUM_DEPOSIT);

        // Interactions: pull the underlying asset from the caller into bridge custody.
        IERC20(originalAsset).safeTransferFrom(msg.sender, address(this), amount);

        // Effects: mint wrapped tokens to the caller.
        wrappedBalanceOf[originalAsset][msg.sender] += amount;
        wrappedTotalSupply[originalAsset] += amount;

        emit Deposited(msg.sender, originalAsset, amount);
    }

    /**
     * @notice Burns wrapped tokens held by the caller and returns the corresponding amount
     *         of the underlying asset from the bridge's custody.
     * @param originalAsset The original asset to withdraw.
     * @param amount        The amount of wrapped tokens to burn.
     */
    function withdraw(address originalAsset, uint256 amount) external whenNotPaused {
        address wrappedToken = originalToWrapped[originalAsset];
        if (wrappedToken == address(0)) revert AssetNotRegistered(originalAsset);
        if (amount == 0) revert ZeroAmount();

        uint256 available = wrappedBalanceOf[originalAsset][msg.sender];
        if (available < amount) revert InsufficientWrappedBalance(msg.sender, available, amount);

        // Effects: burn wrapped tokens from the caller.
        wrappedBalanceOf[originalAsset][msg.sender] = available - amount;
        wrappedTotalSupply[originalAsset] -= amount;

        // Interactions: return the underlying asset to the caller.
        IERC20(originalAsset).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, originalAsset, amount);
    }

    /* ------------------------------------------------------------------ */
    /*                          View Functions                            */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the wrapped token address associated with an original asset.
     */
    function wrappedTokenOf(address originalAsset) external view returns (address) {
        return originalToWrapped[originalAsset];
    }

    /**
     * @notice Returns the original asset address associated with a wrapped token.
     */
    function originalAssetOf(address wrappedToken) external view returns (address) {
        return wrappedToOriginal[wrappedToken];
    }

    /**
     * @notice Returns the amount of an underlying asset currently custodied by the bridge.
     */
    function custodiedBalance(address originalAsset) external view returns (uint256) {
        return IERC20(originalAsset).balanceOf(address(this));
    }
}
