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

contract WrappedBitcoinBridge {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error FeeExceedsMax(uint256 fee, uint256 max);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error DepositsPaused();
    error RedemptionsPaused();
    error Unauthorized();
    error ReentrancyDetected();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposited(address indexed sender, uint256 wrappedAmount, uint256 lsdMinted, uint256 fee);
    event Redeemed(address indexed sender, uint256 lsdBurned, uint256 wrappedAmount, uint256 fee);
    event BridgeFeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositsPauseStateChanged(bool paused);
    event RedemptionsPauseStateChanged(bool paused);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev Bridge fee is expressed in basis points. 1% = 100 bps.
    uint256 public constant MAX_BRIDGE_FEE = 100; // 1.0%
    uint256 public constant INITIAL_BRIDGE_FEE = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice The wrapped Bitcoin asset custodied by this bridge.
    IERC20 public immutable wrappedAsset;

    /// @notice Total amount of wrapped asset custodied by the bridge.
    uint256 public totalWrappedAssets;

    /// @notice Current bridge fee in basis points.
    uint256 public bridgeFee;

    /// @notice Whether deposits are paused.
    bool public depositsPaused;

    /// @notice Whether redemptions are paused.
    bool public redemptionsPaused;

    /// @notice The operator with administrative privileges.
    address public operator;

    // -----------------------------------------------------------------------
    // LSD Token (ERC20) state
    // -----------------------------------------------------------------------

    string public name;
    string public symbol;
    uint8 public constant decimals = 8;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Reentrancy guard state
    // -----------------------------------------------------------------------

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyDetected();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    modifier whenRedemptionsNotPaused() {
        if (redemptionsPaused) revert RedemptionsPaused();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(
        address _wrappedAsset,
        address _operator,
        string memory _name,
        string memory _symbol
    ) {
        if (_wrappedAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        wrappedAsset = IERC20(_wrappedAsset);
        bridgeFee = INITIAL_BRIDGE_FEE;
        operator = _operator;
        name = _name;
        symbol = _symbol;
        _reentrancyStatus = _NOT_ENTERED;

        emit OperatorSet(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // External functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit wrapped asset to mint LSD. The bridge fee is deducted
     *         from the deposited amount before minting.
     * @param amount The amount of wrapped asset to deposit.
     */
    function deposit(uint256 amount)
        external
        nonReentrant
        whenDepositsNotPaused
    {
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * bridgeFee) / BPS_DENOMINATOR;
        uint256 lsdToMint = amount - fee;

        // Take custody of the wrapped asset
        _safeTransferFrom(wrappedAsset, msg.sender, address(this), amount);
        totalWrappedAssets += amount;

        // Mint LSD to the depositor
        _mint(msg.sender, lsdToMint);

        emit Deposited(msg.sender, amount, lsdToMint, fee);
    }

    /**
     * @notice Redeem LSD to burn it and receive wrapped asset back. The bridge
     *         fee is deducted from the returned wrapped asset amount.
     * @param lsdAmount The amount of LSD to redeem.
     */
    function redeem(uint256 lsdAmount)
        external
        nonReentrant
        whenRedemptionsNotPaused
    {
        if (lsdAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lsdAmount) {
            revert InsufficientBalance(balanceOf[msg.sender], lsdAmount);
        }

        uint256 fee = (lsdAmount * bridgeFee) / BPS_DENOMINATOR;
        uint256 wrappedToReturn = lsdAmount - fee;

        // Ensure contract has enough wrapped asset
        uint256 contractBalance = wrappedAsset.balanceOf(address(this));
        if (contractBalance < wrappedToReturn) {
            revert InsufficientBalance(contractBalance, wrappedToReturn);
        }

        // Burn LSD first (checks-effects-interactions)
        _burn(msg.sender, lsdAmount);

        // Transfer wrapped asset back to the user
        _safeTransfer(wrappedAsset, msg.sender, wrappedToReturn);
        totalWrappedAssets -= wrappedToReturn;

        emit Redeemed(msg.sender, lsdAmount, wrappedToReturn, fee);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Set the bridge fee. Only callable by the operator.
     * @param newFee The new fee in basis points (max 100 = 1.0%).
     */
    function setBridgeFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_BRIDGE_FEE) revert FeeExceedsMax(newFee, MAX_BRIDGE_FEE);
        uint256 oldFee = bridgeFee;
        bridgeFee = newFee;
        emit BridgeFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Pause or unpause deposits. Only callable by the operator.
     */
    function setDepositsPaused(bool _paused) external onlyOperator {
        depositsPaused = _paused;
        emit DepositsPauseStateChanged(_paused);
    }

    /**
     * @notice Pause or unpause redemptions. Only callable by the operator.
     */
    function setRedemptionsPaused(bool _paused) external onlyOperator {
        redemptionsPaused = _paused;
        emit RedemptionsPauseStateChanged(_paused);
    }

    /**
     * @notice Transfer operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator;
        emit OperatorSet(previousOperator, newOperator);
    }

    // -----------------------------------------------------------------------
    // ERC20 functions for the LSD token
    // -----------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Previews the amount of LSD that would be minted for a given deposit.
     * @param amount Amount of wrapped asset to deposit.
     * @return lsdAmount Amount of LSD to be received.
     * @return fee Amount of wrapped asset taken as fee.
     */
    function previewDeposit(uint256 amount) external view returns (uint256 lsdAmount, uint256 fee) {
        fee = (amount * bridgeFee) / BPS_DENOMINATOR;
        lsdAmount = amount - fee;
    }

    /**
     * @notice Previews the amount of wrapped asset that would be returned for a given redemption.
     * @param lsdAmount Amount of LSD to redeem.
     * @return wrappedAmount Amount of wrapped asset to be received.
     * @return fee Amount of wrapped asset taken as fee.
     */
    function previewRedeem(uint256 lsdAmount) external view returns (uint256 wrappedAmount, uint256 fee) {
        fee = (lsdAmount * bridgeFee) / BPS_DENOMINATOR;
        wrappedAmount = lsdAmount - fee;
    }

    // -----------------------------------------------------------------------
    // Internal ERC20 logic
    // -----------------------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(balanceOf[from], amount);
        }
        if (to == address(0)) revert ZeroAddress();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(balanceOf[from], amount);
        }
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Internal safe transfer helpers
    // -----------------------------------------------------------------------

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }
}
