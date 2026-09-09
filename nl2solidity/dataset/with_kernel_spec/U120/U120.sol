// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract CrossChainAssetBridge {
    // ---------- Custom errors ----------
    error NotAuthorized();
    error NotOperator();
    error ContractPaused();
    error TokenNotSupported();
    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxDeposit();
    error InsufficientWrappedSupply();
    error InsufficientBalance();
    error TransferFailed();
    error EthNotAccepted();

    // ---------- Events ----------
    event Deposited(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        uint256 indexed destinationChainId,
        bytes32 depositId
    );

    event Withdrawn(
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        uint256 indexed sourceChainId,
        bytes32 withdrawalId
    );

    event TokenSupportUpdated(address indexed token, bool supported);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ---------- Constants ----------
    uint256 public constant MAX_DEPOSIT_AMOUNT = 1_000_000;
    uint256 public constant BRIDGE_FEE_BASIS_POINTS = 10; // 0.1%
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    // ---------- State ----------
    address public owner;
    address public operator;
    bool public paused;

    /// @dev user => token => net deposited balance (after fee)
    mapping(address => mapping(address => uint256)) public userBalances;

    /// @dev token => total wrapped supply minted on destination chain
    mapping(address => uint256) public totalWrappedSupply;

    /// @dev token => total accumulated fees collected by the bridge
    mapping(address => uint256) public accumulatedFees;

    /// @dev token => supported status
    mapping(address => bool) public supportedTokens;

    uint256 private _nonce;

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    // ---------- Admin ----------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setTokenSupported(address token, bool supported) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        supportedTokens[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    // ---------- Views ----------
    function calculateFee(uint256 amount) public pure returns (uint256) {
        return (amount * BRIDGE_FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function getWrappedSupply(address token) external view returns (uint256) {
        return totalWrappedSupply[token];
    }

    function getAccumulatedFees(address token) external view returns (uint256) {
        return accumulatedFees[token];
    }

    // ---------- Deposit ----------
    function deposit(address token, uint256 amount, uint256 destinationChainId)
        external
        whenNotPaused
        returns (bytes32 depositId)
    {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_DEPOSIT_AMOUNT) revert ExceedsMaxDeposit();

        uint256 fee = calculateFee(amount);
        uint256 netAmount = amount - fee;

        // Effects
        userBalances[msg.sender][token] += netAmount;
        totalWrappedSupply[token] += netAmount;
        accumulatedFees[token] += fee;

        depositId = _generateId(msg.sender, token, amount, destinationChainId, true);

        // Interactions
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount, fee, netAmount, destinationChainId, depositId);
    }

    // ---------- Withdraw ----------
    function withdraw(address recipient, address token, uint256 amount, uint256 sourceChainId)
        external
        onlyOperator
        whenNotPaused
        returns (bytes32 withdrawalId)
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = calculateFee(amount);
        uint256 netAmount = amount - fee;

        if (totalWrappedSupply[token] < netAmount) revert InsufficientWrappedSupply();
        if (userBalances[recipient][token] < netAmount) revert InsufficientBalance();

        // Effects
        totalWrappedSupply[token] -= netAmount;
        userBalances[recipient][token] -= netAmount;
        accumulatedFees[token] += fee;

        withdrawalId = _generateId(recipient, token, amount, sourceChainId, false);

        // Interactions
        _safeTransfer(token, recipient, netAmount);

        emit Withdrawn(recipient, token, amount, fee, netAmount, sourceChainId, withdrawalId);
    }

    // ---------- Internal helpers ----------
    function _generateId(
        address party,
        address token,
        uint256 amount,
        uint256 chainId,
        bool isDeposit
    ) internal returns (bytes32 id) {
        _nonce += 1;
        id = keccak256(
            abi.encodePacked(
                party,
                token,
                amount,
                chainId,
                isDeposit,
                _nonce,
                block.timestamp,
                block.chainid
            )
        );
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // ---------- Reject direct ETH (non-payable: no ether can be locked) ----------
    fallback() external {
        revert EthNotAccepted();
    }
}
