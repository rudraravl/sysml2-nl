// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStaking
 * @notice Custodies deposited native tokens and issues liquid staking tokens (LST).
 *         Users deposit native tokens to mint LST, unstake LST to initiate a withdrawal
 *         subject to a 3-day cooling-off period and a 0.5% fee, and claim native tokens
 *         once the cooling-off period elapses. An operator manages the approved validator
 *         registry and their staking allocations.
 */
contract LiquidStaking {
    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error NotOwner();
    error NotOperator();
    error ValidatorAlreadyApproved();
    error ValidatorNotApproved();
    error InsufficientLST();
    error InvalidIndex();
    error WithdrawalNotReady();
    error WithdrawalAlreadyClaimed();
    error NoAllocation();
    error AllocationOverflow();
    error TransferFailed();
    error ReentrancyDetected();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 nativeAmount, uint256 lstMinted);
    event UnstakeRequested(
        address indexed user,
        uint256 lstBurned,
        uint256 nativeGross,
        uint256 nativeFee,
        uint256 nativeNet,
        uint256 readyAt,
        uint256 requestIndex
    );
    event Withdrawn(address indexed user, uint256 nativeAmount, uint256 requestIndex);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event AllocationUpdated(address indexed validator, uint256 newAllocation);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);
    event FeesClaimed(address indexed treasury, uint256 amount);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant COOLING_OFF_PERIOD = 3 days;
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant EXCHANGE_RATE_PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    address public treasury;

    // Liquid staking token accounting (internal)
    mapping(address => uint256) public lstBalance;
    uint256 public totalLSTSupply;

    // Total native tokens custodied by the protocol
    uint256 public totalNativeStaked;

    // Accumulated unstaking fees awaiting treasury claim
    uint256 public accumulatedFees;

    // Approved validator registry
    address[] public validators;
    mapping(address => bool) public isValidator;
    mapping(address => uint256) public validatorAllocation; // weight
    mapping(address => uint256) public validatorStaked;     // native notionally staked
    uint256 public totalAllocation;

    struct WithdrawalRequest {
        uint256 nativeNet; // native tokens the user will receive
        uint256 readyAt;   // timestamp when claimable
        bool claimed;
    }
    mapping(address => WithdrawalRequest[]) public withdrawals;

    // Reentrancy guard
    bool private locked;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        emit OperatorChanged(address(0), _operator);
        emit TreasuryChanged(address(0), _treasury);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    function addValidator(address validator, uint256 allocation) external onlyOperator {
        if (validator == address(0)) revert ZeroAddress();
        if (isValidator[validator]) revert ValidatorAlreadyApproved();
        if (allocation == 0) revert ZeroAmount();
        if (allocation > type(uint256).max - totalAllocation) revert AllocationOverflow();

        isValidator[validator] = true;
        validators.push(validator);
        validatorAllocation[validator] = allocation;
        totalAllocation += allocation;

        emit ValidatorAdded(validator);
        emit AllocationUpdated(validator, allocation);
    }

    function removeValidator(address validator) external onlyOperator {
        if (!isValidator[validator]) revert ValidatorNotApproved();

        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[len - 1];
                validators.pop();
                break;
            }
        }

        isValidator[validator] = false;
        totalAllocation -= validatorAllocation[validator];
        validatorAllocation[validator] = 0;

        emit ValidatorRemoved(validator);
    }

    function setAllocation(address validator, uint256 newAllocation) external onlyOperator {
        if (!isValidator[validator]) revert ValidatorNotApproved();
        if (newAllocation == 0) revert ZeroAmount();

        uint256 old = validatorAllocation[validator];
        if (newAllocation > old && (newAllocation - old) > (type(uint256).max - totalAllocation)) {
            revert AllocationOverflow();
        }

        totalAllocation = totalAllocation - old + newAllocation;
        validatorAllocation[validator] = newAllocation;
        emit AllocationUpdated(validator, newAllocation);
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------
    function deposit() external payable nonReentrant returns (uint256 lstMinted) {
        if (msg.value == 0) revert ZeroAmount();
        if (totalAllocation == 0) revert NoAllocation();

        // Mint LST based on the current exchange rate.
        if (totalLSTSupply == 0 || totalNativeStaked == 0) {
            lstMinted = msg.value;
        } else {
            lstMinted = (msg.value * totalLSTSupply) / totalNativeStaked;
        }

        totalNativeStaked += msg.value;
        lstBalance[msg.sender] += lstMinted;
        totalLSTSupply += lstMinted;

        _distributeToValidators(msg.value);

        emit Deposited(msg.sender, msg.value, lstMinted);
    }

    function unstake(uint256 lstAmount) external nonReentrant returns (uint256 requestIndex) {
        if (lstAmount == 0) revert ZeroAmount();
        if (lstBalance[msg.sender] < lstAmount) revert InsufficientLST();
        if (totalLSTSupply == 0) revert ZeroAmount();

        // Determine gross native amount corresponding to the burned LST.
        uint256 nativeGross = (lstAmount * totalNativeStaked) / totalLSTSupply;

        // Compute the fee with full precision to avoid divide-before-multiply
        // rounding loss: fee = nativeGross * FEE_BPS / BPS_DENOMINATOR, but
        // evaluated as a single division over the product of the inputs.
        uint256 fee = (lstAmount * totalNativeStaked * FEE_BPS) /
            (totalLSTSupply * BPS_DENOMINATOR);

        // Ensure the fee never exceeds the gross amount due to rounding.
        if (fee > nativeGross) fee = nativeGross;

        uint256 nativeNet = nativeGross - fee;

        // Burn LST and reduce protocol accounting.
        lstBalance[msg.sender] -= lstAmount;
        totalLSTSupply -= lstAmount;
        totalNativeStaked -= nativeGross;

        // Reduce validator stakes proportionally.
        _reduceValidatorStakes(nativeGross);

        // Fee retained by the contract for the treasury.
        accumulatedFees += fee;

        uint256 readyAt = block.timestamp + COOLING_OFF_PERIOD;
        requestIndex = withdrawals[msg.sender].length;
        withdrawals[msg.sender].push(
            WithdrawalRequest({ nativeNet: nativeNet, readyAt: readyAt, claimed: false })
        );

        emit UnstakeRequested(msg.sender, lstAmount, nativeGross, fee, nativeNet, readyAt, requestIndex);
    }

    function claim(uint256 requestIndex) external nonReentrant {
        if (requestIndex >= withdrawals[msg.sender].length) revert InvalidIndex();

        WithdrawalRequest storage req = withdrawals[msg.sender][requestIndex];
        if (req.claimed) revert WithdrawalAlreadyClaimed();
        if (block.timestamp < req.readyAt) revert WithdrawalNotReady();

        req.claimed = true;
        uint256 amount = req.nativeNet;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount, requestIndex);
    }

    // ---------------------------------------------------------------------
    // Treasury fee claim
    // ---------------------------------------------------------------------
    function claimFees() external nonReentrant {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();
        accumulatedFees = 0;

        (bool success, ) = payable(treasury).call{value: fees}("");
        if (!success) revert TransferFailed();

        emit FeesClaimed(treasury, fees);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function validatorCount() external view returns (uint256) {
        return validators.length;
    }

    function withdrawalCount(address user) external view returns (uint256) {
        return withdrawals[user].length;
    }

    function getWithdrawal(address user, uint256 index)
        external
        view
        returns (uint256 nativeNet, uint256 readyAt, bool claimed)
    {
        if (index >= withdrawals[user].length) revert InvalidIndex();
        WithdrawalRequest storage req = withdrawals[user][index];
        return (req.nativeNet, req.readyAt, req.claimed);
    }

    function pendingWithdrawal(address user, uint256 index) external view returns (uint256) {
        if (index >= withdrawals[user].length) revert InvalidIndex();
        WithdrawalRequest storage req = withdrawals[user][index];
        if (req.claimed || block.timestamp < req.readyAt) return 0;
        return req.nativeNet;
    }

    function getExchangeRate() external view returns (uint256) {
        if (totalLSTSupply == 0) return EXCHANGE_RATE_PRECISION;
        return (totalNativeStaked * EXCHANGE_RATE_PRECISION) / totalLSTSupply;
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------
    function _distributeToValidators(uint256 amount) internal {
        uint256 remaining = amount;
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            address v = validators[i];
            uint256 alloc = validatorAllocation[v];
            if (alloc == 0) continue;

            uint256 share;
            if (i == len - 1) {
                share = remaining;
            } else {
                share = (amount * alloc) / totalAllocation;
                remaining -= share;
            }
            validatorStaked[v] += share;
        }
    }

    function _reduceValidatorStakes(uint256 amount) internal {
        uint256 remaining = amount;
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            address v = validators[i];
            uint256 staked = validatorStaked[v];
            if (staked == 0) continue;

            uint256 reduction;
            if (i == len - 1) {
                reduction = remaining;
            } else {
                reduction = (amount * staked) / totalNativeStaked;
                if (reduction > remaining) reduction = remaining;
                remaining -= reduction;
            }
            validatorStaked[v] -= reduction;
        }
    }

    // ---------------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------------
    receive() external payable {
        revert("Use deposit()");
    }
}
