// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NativeStakingPool
 * @notice A staking pool for the native blockchain asset. Users deposit native tokens
 *         and earn yield at a configurable annual percentage rate (APR). A 0.5% fee is
 *         applied to all withdrawals and sent to a designated fee recipient. Only the
 *         operator may update the APR based on external staking returns.
 */
contract NativeStakingPool {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @notice Minimum deposit amount (0.1 native units).
    uint256 public constant MIN_DEPOSIT = 0.1 ether;

    /// @notice Withdrawal fee in basis points (0.5%).
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;

    /// @notice Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Seconds in a year used for APR proration.
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice Precision factor for APR scaling (1e18).
    uint256 public constant PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice Address authorized to update the APR.
    address public operator;

    /// @notice Address that receives withdrawal fees.
    address public feeRecipient;

    /// @notice Current annual percentage rate, scaled by 1e18 (e.g. 5% = 5e16).
    uint256 public apr;

    /// @notice Total principal currently staked in the pool.
    uint256 public totalStaked;

    struct UserInfo {
        uint256 principal;         // Principal staked by the user.
        uint256 accumulatedYield;  // Yield accrued but not yet claimed.
        uint256 lastUpdate;        // Timestamp of the last yield accrual for this user.
    }

    mapping(address => UserInfo) internal _users;

    bool private _locked;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdraw(
        address indexed user,
        uint256 principal,
        uint256 yield,
        uint256 fee,
        uint256 timestamp
    );
    event YieldClaimed(
        address indexed user,
        uint256 yield,
        uint256 fee,
        uint256 timestamp
    );
    event APRUpdated(uint256 oldAPR, uint256 newAPR, uint256 timestamp);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error Unauthorized();
    error ZeroAddress();
    error DepositTooSmall(uint256 sent, uint256 minimum);
    error InsufficientPrincipal();
    error NothingToClaim();
    error InvalidAPR(uint256 provided, uint256 maximum);
    error TransferFailed();
    error ReentrancyDetected();
    error InsufficientPoolBalance();
    error InvalidRecipient();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _operator      Address authorized to update the APR.
     * @param _feeRecipient  Address that receives withdrawal fees.
     * @param _initialAPR    Initial APR scaled by 1e18 (e.g. 5% = 5e16).
     */
    constructor(
        address _operator,
        address _feeRecipient,
        uint256 _initialAPR
    ) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_initialAPR > 1e18) revert InvalidAPR(_initialAPR, 1e18); // max 100%

        operator = _operator;
        feeRecipient = _feeRecipient;
        apr = _initialAPR;

        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        emit APRUpdated(0, _initialAPR, block.timestamp);
    }

    // -----------------------------------------------------------------------
    // External functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit native asset into the staking pool.
     * @dev    Minimum deposit of 0.1 native units is enforced. Pending yield
     *         is accrued before the new principal is added.
     */
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall(msg.value, MIN_DEPOSIT);

        _accrueUser(msg.sender);

        UserInfo storage info = _users[msg.sender];
        info.principal += msg.value;
        if (info.lastUpdate == 0) {
            info.lastUpdate = block.timestamp;
        }
        totalStaked += msg.value;

        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @notice Withdraw a portion of the principal together with all accrued yield.
     * @param principalAmount Amount of principal to withdraw.
     */
    function withdraw(uint256 principalAmount) external nonReentrant {
        if (principalAmount == 0) revert InsufficientPrincipal();

        UserInfo storage info = _users[msg.sender];
        if (principalAmount > info.principal) revert InsufficientPrincipal();

        _accrueUser(msg.sender);

        uint256 yieldAmount = info.accumulatedYield;
        uint256 grossOut = principalAmount + yieldAmount;
        uint256 fee = (grossOut * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netOut = grossOut - fee;

        if (address(this).balance < grossOut) revert InsufficientPoolBalance();

        // Effects
        info.principal -= principalAmount;
        info.accumulatedYield = 0;
        totalStaked -= principalAmount;

        if (info.principal == 0) {
            info.lastUpdate = 0;
        }

        // Interactions
        _sendNative(feeRecipient, fee);
        _sendNative(msg.sender, netOut);

        emit Withdraw(msg.sender, principalAmount, yieldAmount, fee, block.timestamp);
    }

    /**
     * @notice Claim all accrued yield without withdrawing principal.
     */
    function claimYield() external nonReentrant {
        _accrueUser(msg.sender);

        UserInfo storage info = _users[msg.sender];
        uint256 yieldAmount = info.accumulatedYield;
        if (yieldAmount == 0) revert NothingToClaim();

        uint256 fee = (yieldAmount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netOut = yieldAmount - fee;

        if (address(this).balance < yieldAmount) revert InsufficientPoolBalance();

        // Effects
        info.accumulatedYield = 0;

        // Interactions
        _sendNative(feeRecipient, fee);
        _sendNative(msg.sender, netOut);

        emit YieldClaimed(msg.sender, yieldAmount, fee, block.timestamp);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Update the APR. Only callable by the operator.
     * @param newAPR New APR scaled by 1e18 (max 1e18 = 100%).
     */
    function setAPR(uint256 newAPR) external onlyOperator {
        if (newAPR > 1e18) revert InvalidAPR(newAPR, 1e18);

        uint256 oldAPR = apr;
        apr = newAPR;
        emit APRUpdated(oldAPR, newAPR, block.timestamp);
    }

    /**
     * @notice Transfer operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Update the fee recipient.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the stored principal for a user.
     */
    function balanceOf(address user) external view returns (uint256) {
        return _users[user].principal;
    }

    /**
     * @notice Returns the total yield currently available to a user, including
     *         yield accrued but not yet stored.
     */
    function pendingYield(address user) external view returns (uint256) {
        return _accruedYield(user);
    }

    /**
     * @notice Returns full user information.
     */
    function getUserInfo(address user)
        external
        view
        returns (
            uint256 principal,
            uint256 accumulatedYield,
            uint256 pending,
            uint256 lastUpdate
        )
    {
        UserInfo storage info = _users[user];
        return (info.principal, info.accumulatedYield, _accruedYield(user), info.lastUpdate);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /**
     * @dev Computes the total yield available to a user, including yield that has
     *      accrued since the last update but has not yet been persisted to storage.
     *      Avoids strict equality checks on elapsed time.
     */
    function _accruedYield(address user) internal view returns (uint256) {
        UserInfo storage info = _users[user];
        if (info.principal == 0 || info.lastUpdate == 0) {
            return info.accumulatedYield;
        }

        uint256 elapsed = block.timestamp - info.lastUpdate;
        uint256 newYield = (info.principal * apr * elapsed) / (PRECISION * SECONDS_PER_YEAR);
        return info.accumulatedYield + newYield;
    }

    /**
     * @dev Accrues pending yield to storage and refreshes the user's lastUpdate
     *      timestamp. Called before any state-changing user action.
     */
    function _accrueUser(address user) internal {
        UserInfo storage info = _users[user];
        if (info.principal == 0) {
            info.lastUpdate = block.timestamp;
            return;
        }

        if (info.lastUpdate == 0) {
            info.lastUpdate = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - info.lastUpdate;
        if (elapsed > 0) {
            uint256 newYield = (info.principal * apr * elapsed) / (PRECISION * SECONDS_PER_YEAR);
            info.accumulatedYield += newYield;
            info.lastUpdate = block.timestamp;
        }
    }

    /**
     * @dev Sends native asset to a recipient, reverting on failure. Recipient is
     *      restricted to the caller or the configured fee recipient to prevent
     *      arbitrary transfers.
     */
    function _sendNative(address to, uint256 amount) internal {
        if (to != msg.sender && to != feeRecipient) revert InvalidRecipient();
        if (amount == 0) return;

        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // Receive
    // -----------------------------------------------------------------------

    /**
     * @dev Accepts native asset only from the operator to fund the yield reserve.
     *      Direct deposits from other senders must use {deposit}.
     */
    receive() external payable {
        if (msg.sender != operator) revert Unauthorized();
    }
}
