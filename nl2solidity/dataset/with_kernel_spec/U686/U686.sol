// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CollateralMarketVault
 * @notice A vault that custodies an arbitrary ERC-20 token as collateral.
 * Users can deposit, withdraw available (undelegated) collateral, and delegate
 * portions of their deposits to approved operators. The owner manages the
 * operator set and their maximum commitment limits.
 */
contract CollateralMarketVault {
    // --- Errors ---
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientAvailableBalance();
    error InsufficientDelegatedBalance();
    error OperatorNotApproved();
    error OperatorAlreadyApproved();
    error ExceedsMaxOperators();
    error ExceedsOperatorCommitment();
    error NewCommitmentBelowCurrent();

    // --- Events ---
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralDelegated(address indexed user, address indexed operator, uint256 amount);
    event CollateralUndelegated(address indexed user, address indexed operator, uint256 amount);
    event OperatorAdded(address indexed operator, uint256 maxCommitment);
    event OperatorRemoved(address indexed operator);
    event OperatorCommitmentUpdated(address indexed operator, uint256 newMaxCommitment);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Constants ---
    uint256 public constant MAX_OPERATORS = 100;

    // --- State Variables ---
    IERC20 public immutable collateralToken;
    address public owner;

    uint256 public totalDeposited;

    mapping(address => uint256) public userBalances;
    mapping(address => uint256) public userDelegatedTotal;
    mapping(address => mapping(address => uint256)) public userDelegations;
    mapping(address => uint256) public operatorMaxCommitment;
    mapping(address => uint256) public operatorCommitted;
    mapping(address => bool) public isOperator;

    address[] internal _operatorList;
    mapping(address => uint256) internal _operatorIndexPlusOne;

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // --- Constructor ---
    constructor(address _collateralToken) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- Internal ---

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
    }

    // --- User Functions ---

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        userBalances[msg.sender] += amount;
        totalDeposited += amount;

        _safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 available = availableBalance(msg.sender);
        if (amount > available) revert InsufficientAvailableBalance();

        userBalances[msg.sender] -= amount;
        totalDeposited -= amount;

        _safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function delegate(address operator, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!isOperator[operator]) revert OperatorNotApproved();

        uint256 available = availableBalance(msg.sender);
        if (amount > available) revert InsufficientAvailableBalance();

        uint256 newOperatorCommitted = operatorCommitted[operator] + amount;
        if (newOperatorCommitted > operatorMaxCommitment[operator]) {
            revert ExceedsOperatorCommitment();
        }

        userDelegations[msg.sender][operator] += amount;
        userDelegatedTotal[msg.sender] += amount;
        operatorCommitted[operator] = newOperatorCommitted;

        emit CollateralDelegated(msg.sender, operator, amount);
    }

    function undelegate(address operator, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 currentDelegation = userDelegations[msg.sender][operator];
        if (amount > currentDelegation) revert InsufficientDelegatedBalance();

        userDelegations[msg.sender][operator] = currentDelegation - amount;
        userDelegatedTotal[msg.sender] -= amount;
        operatorCommitted[operator] -= amount;

        emit CollateralUndelegated(msg.sender, operator, amount);
    }

    // --- Owner Functions ---

    function addOperator(address operator, uint256 maxCommitment) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (isOperator[operator]) revert OperatorAlreadyApproved();
        if (_operatorList.length >= MAX_OPERATORS) revert ExceedsMaxOperators();

        isOperator[operator] = true;
        operatorMaxCommitment[operator] = maxCommitment;
        _operatorIndexPlusOne[operator] = _operatorList.length + 1;
        _operatorList.push(operator);

        emit OperatorAdded(operator, maxCommitment);
    }

    function removeOperator(address operator) external onlyOwner {
        if (!isOperator[operator]) revert OperatorNotApproved();

        isOperator[operator] = false;
        operatorMaxCommitment[operator] = 0;

        uint256 idxPlusOne = _operatorIndexPlusOne[operator];
        uint256 lastIndex = _operatorList.length - 1;

        if (idxPlusOne - 1 != lastIndex) {
            address lastOperator = _operatorList[lastIndex];
            _operatorList[idxPlusOne - 1] = lastOperator;
            _operatorIndexPlusOne[lastOperator] = idxPlusOne;
        }

        _operatorList.pop();
        _operatorIndexPlusOne[operator] = 0;

        emit OperatorRemoved(operator);
    }

    function setOperatorMaxCommitment(address operator, uint256 newMaxCommitment) external onlyOwner {
        if (!isOperator[operator]) revert OperatorNotApproved();
        if (newMaxCommitment < operatorCommitted[operator]) revert NewCommitmentBelowCurrent();

        operatorMaxCommitment[operator] = newMaxCommitment;

        emit OperatorCommitmentUpdated(operator, newMaxCommitment);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // --- Public View Functions ---

    function availableBalance(address user) public view returns (uint256) {
        return userBalances[user] - userDelegatedTotal[user];
    }

    function userDelegationTo(address user, address operator) external view returns (uint256) {
        return userDelegations[user][operator];
    }

    function operatorCount() external view returns (uint256) {
        return _operatorList.length;
    }

    function operatorAt(uint256 index) external view returns (address) {
        return _operatorList[index];
    }

    function getOperators() external view returns (address[] memory) {
        return _operatorList;
    }
}
