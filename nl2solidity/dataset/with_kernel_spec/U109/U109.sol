// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedValidatorOperations {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotAdmin();
    error NotRegistered();
    error AlreadyRegistered();
    error InsufficientStake();
    error RegistrationsPaused();
    error ValidatorKeyAlreadyAssigned();
    error ValidatorNotAssigned();
    error ValidatorStillActive();
    error NotOperatorOfValidator();
    error ZeroAddress();
    error InvalidValidatorKey();
    error InvalidAmount();
    error NothingToWithdraw();
    error TransferFailed();
    error CannotRemoveActiveOperator();
    error DuplicateOperatorInSet();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event OperatorRegistered(address indexed operator, uint256 stake);
    event ValidatorKeyAssigned(bytes32 indexed validatorKey, address[] operatorSet);
    event PerformanceMetricsUpdated(
        address indexed operator,
        uint256 uptimeBps,
        uint256 attestations,
        uint256 proposals
    );
    event EtherDeposited(address indexed depositor, bytes32 indexed validatorKey, uint256 amount);
    event EtherWithdrawn(
        address indexed withdrawer,
        bytes32 indexed validatorKey,
        uint256 amount,
        uint256 fee
    );
    event MinOperatorStakeUpdated(uint256 oldMin, uint256 newMin);
    event RegistrationsPausedChanged(bool paused);
    event OperatorRemoved(address indexed operator, uint256 refundedStake);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event ValidatorDeactivated(bytes32 indexed validatorKey);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant DEFAULT_MIN_OPERATOR_STAKE = 32 ether;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------
    struct Operator {
        uint256 stake;
        uint256 registeredAt;
        bool active;
        uint256 uptimeBps;
        uint256 attestations;
        uint256 proposals;
    }

    struct Validator {
        bytes32 key;
        address[] operatorSet;
        bool active;
        uint256 totalDeposits;
        mapping(address => uint256) deposits;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    address public admin;
    uint256 public minOperatorStake;
    bool public registrationsPaused;
    address public feeRecipient;

    address[] public operatorList;
    mapping(address => Operator) public operators;
    mapping(address => uint256) private operatorIndex; // 1-based, 0 = not in list

    mapping(bytes32 => Validator) public validators;
    bytes32[] public validatorKeys;
    mapping(bytes32 => uint256) private validatorKeyIndex; // 1-based, 0 = not in list

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyRegistered() {
        if (!operators[msg.sender].active) revert NotRegistered();
        _;
    }

    modifier whenNotPaused() {
        if (registrationsPaused) revert RegistrationsPaused();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        admin = msg.sender;
        feeRecipient = _feeRecipient;
        minOperatorStake = DEFAULT_MIN_OPERATOR_STAKE;
        emit MinOperatorStakeUpdated(0, minOperatorStake);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------
    function setMinOperatorStake(uint256 _newMin) external onlyAdmin {
        if (_newMin == 0) revert InvalidAmount();
        emit MinOperatorStakeUpdated(minOperatorStake, _newMin);
        minOperatorStake = _newMin;
    }

    function setRegistrationsPaused(bool _paused) external onlyAdmin {
        registrationsPaused = _paused;
        emit RegistrationsPausedChanged(_paused);
    }

    function setFeeRecipient(address _newRecipient) external onlyAdmin {
        if (_newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _newRecipient);
        feeRecipient = _newRecipient;
    }

    function updatePerformanceMetrics(
        address _operator,
        uint256 _uptimeBps,
        uint256 _attestations,
        uint256 _proposals
    ) external onlyAdmin {
        if (!operators[_operator].active) revert NotRegistered();
        if (_uptimeBps > BPS_DENOMINATOR) revert InvalidAmount();

        operators[_operator].uptimeBps = _uptimeBps;
        operators[_operator].attestations = _attestations;
        operators[_operator].proposals = _proposals;

        emit PerformanceMetricsUpdated(_operator, _uptimeBps, _attestations, _proposals);
    }

    function removeOperator(address _operator) external onlyAdmin {
        Operator storage op = operators[_operator];
        if (!op.active) revert NotRegistered();

        // Prevent removal if the operator still participates in an active validator.
        for (uint256 i = 0; i < validatorKeys.length; i++) {
            Validator storage v = validators[validatorKeys[i]];
            if (v.active && _isOperatorInSet(v.operatorSet, _operator)) {
                revert CannotRemoveActiveOperator();
            }
        }

        uint256 refund = op.stake;
        op.active = false;
        op.stake = 0;
        op.uptimeBps = 0;
        op.attestations = 0;
        op.proposals = 0;

        _removeFromOperatorList(_operator);

        emit OperatorRemoved(_operator, refund);

        if (refund > 0) {
            (bool ok, ) = payable(_operator).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
    }

    function deactivateValidator(bytes32 _validatorKey) external onlyAdmin {
        Validator storage v = validators[_validatorKey];
        if (v.operatorSet.length == 0) revert ValidatorNotAssigned();
        if (!v.active) revert ValidatorStillActive();
        v.active = false;
        emit ValidatorDeactivated(_validatorKey);
    }

    // -------------------------------------------------------------------------
    // Operator registration
    // -------------------------------------------------------------------------
    function registerAsOperator() external payable whenNotPaused {
        Operator storage op = operators[msg.sender];
        if (op.active) revert AlreadyRegistered();
        if (msg.value < minOperatorStake) revert InsufficientStake();

        op.active = true;
        op.stake = msg.value;
        op.registeredAt = block.timestamp;
        op.uptimeBps = 0;
        op.attestations = 0;
        op.proposals = 0;

        operatorIndex[msg.sender] = operatorList.length + 1;
        operatorList.push(msg.sender);

        emit OperatorRegistered(msg.sender, msg.value);
    }

    function topUpStake() external payable onlyRegistered {
        operators[msg.sender].stake += msg.value;
        emit OperatorRegistered(msg.sender, operators[msg.sender].stake);
    }

    // -------------------------------------------------------------------------
    // Validator key proposal / assignment
    // -------------------------------------------------------------------------
    function proposeValidatorKey(bytes32 _validatorKey, address[] calldata _operatorSet)
        external
        whenNotPaused
        onlyRegistered
    {
        if (_validatorKey == bytes32(0)) revert InvalidValidatorKey();
        if (_operatorSet.length == 0) revert InvalidAmount();

        Validator storage v = validators[_validatorKey];
        if (v.active || v.operatorSet.length != 0) revert ValidatorKeyAlreadyAssigned();

        // Validate that all proposed operators are registered and unique.
        for (uint256 i = 0; i < _operatorSet.length; i++) {
            if (_operatorSet[i] == address(0)) revert ZeroAddress();
            if (!operators[_operatorSet[i]].active) revert NotRegistered();
            for (uint256 j = i + 1; j < _operatorSet.length; j++) {
                if (_operatorSet[i] == _operatorSet[j]) revert DuplicateOperatorInSet();
            }
        }

        // The proposing operator must be part of the operator set.
        if (!_isOperatorInSet(_operatorSet, msg.sender)) revert NotOperatorOfValidator();

        v.key = _validatorKey;
        v.active = true;
        v.operatorSet = _operatorSet;
        v.totalDeposits = 0;

        validatorKeyIndex[_validatorKey] = validatorKeys.length + 1;
        validatorKeys.push(_validatorKey);

        emit ValidatorKeyAssigned(_validatorKey, _operatorSet);
    }

    // -------------------------------------------------------------------------
    // Deposits
    // -------------------------------------------------------------------------
    function depositEther(bytes32 _validatorKey) external payable {
        if (msg.value == 0) revert InvalidAmount();
        Validator storage v = validators[_validatorKey];
        if (v.operatorSet.length == 0) revert ValidatorNotAssigned();
        if (!v.active) revert ValidatorStillActive();

        v.deposits[msg.sender] += msg.value;
        v.totalDeposits += msg.value;

        emit EtherDeposited(msg.sender, _validatorKey, msg.value);
    }

    // -------------------------------------------------------------------------
    // Withdrawals
    // -------------------------------------------------------------------------
    function withdrawEther(bytes32 _validatorKey) external {
        Validator storage v = validators[_validatorKey];
        if (v.operatorSet.length == 0) revert ValidatorNotAssigned();
        if (v.active) revert ValidatorStillActive();

        uint256 amount = v.deposits[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Checks-effects-interactions
        v.deposits[msg.sender] = 0;
        v.totalDeposits -= amount;

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        emit EtherWithdrawn(msg.sender, _validatorKey, payout, fee);

        if (fee > 0) {
            (bool okFee, ) = payable(feeRecipient).call{value: fee}("");
            if (!okFee) revert TransferFailed();
        }
        if (payout > 0) {
            (bool ok, ) = payable(msg.sender).call{value: payout}("");
            if (!ok) revert TransferFailed();
        }
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------
    function getOperatorCount() external view returns (uint256) {
        return operatorList.length;
    }

    function getOperatorList() external view returns (address[] memory) {
        return operatorList;
    }

    function getOperator(address _operator)
        external
        view
        returns (
            uint256 stake,
            uint256 registeredAt,
            bool active,
            uint256 uptimeBps,
            uint256 attestations,
            uint256 proposals
        )
    {
        Operator storage op = operators[_operator];
        return (
            op.stake,
            op.registeredAt,
            op.active,
            op.uptimeBps,
            op.attestations,
            op.proposals
        );
    }

    function getValidatorCount() external view returns (uint256) {
        return validatorKeys.length;
    }

    function getValidatorKeys() external view returns (bytes32[] memory) {
        return validatorKeys;
    }

    function getValidatorOperatorSet(bytes32 _validatorKey)
        external
        view
        returns (address[] memory)
    {
        return validators[_validatorKey].operatorSet;
    }

    function getValidatorTotalDeposits(bytes32 _validatorKey)
        external
        view
        returns (uint256)
    {
        return validators[_validatorKey].totalDeposits;
    }

    function getValidatorDeposit(bytes32 _validatorKey, address _depositor)
        external
        view
        returns (uint256)
    {
        return validators[_validatorKey].deposits[_depositor];
    }

    function isValidatorActive(bytes32 _validatorKey) external view returns (bool) {
        return validators[_validatorKey].active;
    }

    function isOperatorInValidatorSet(bytes32 _validatorKey, address _operator)
        external
        view
        returns (bool)
    {
        return _isOperatorInSet(validators[_validatorKey].operatorSet, _operator);
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------
    function _isOperatorInSet(address[] memory _set, address _operator)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < _set.length; i++) {
            if (_set[i] == _operator) return true;
        }
        return false;
    }

    function _removeFromOperatorList(address _operator) internal {
        uint256 idx = operatorIndex[_operator];
        if (idx == 0) return; // not in list
        uint256 listIndex = idx - 1;
        uint256 lastIndex = operatorList.length - 1;

        if (listIndex != lastIndex) {
            address lastOperator = operatorList[lastIndex];
            operatorList[listIndex] = lastOperator;
            operatorIndex[lastOperator] = listIndex + 1;
        }
        operatorList.pop();
        operatorIndex[_operator] = 0;
    }

    // -------------------------------------------------------------------------
    // Receive / fallback (allow direct ETH to be held by contract)
    // -------------------------------------------------------------------------
    receive() external payable {}
    fallback() external payable {}
}
