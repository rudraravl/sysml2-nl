// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FundShareToken
/// @notice ERC-20 style token representing claims on shares of a regulated
///         financial fund held by an external custodian. The contract itself
///         holds no assets. Minting is operator-gated and subject to a 24-hour
///         timelock; transfers are pausable by the owner and incur a 0.1% fee.
contract FundShareToken {
    error NotOwner();
    error NotOperator();
    error NotAuthorized();
    error ContractPaused();
    error NotPaused();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidRequestId();
    error AlreadyExecuted();
    error AlreadyCancelled();
    error TimelockNotPassed();
    error MintExceedsCap();
    error BelowMinRedemption();
    error InvalidDecimals();

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MintRequested(uint256 indexed requestId, address indexed to, uint256 amount, uint256 requestedAt);
    event MintExecuted(uint256 indexed requestId, address indexed to, uint256 amount);
    event MintCancelled(uint256 indexed requestId, address indexed target, uint256 amount);
    event Burn(address indexed from, uint256 amount, address indexed by);
    event RedemptionRequested(address indexed redeemer, uint256 amount, uint256 indexed nonce);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event MaxSupplyChanged(uint256 previousMaxSupply, uint256 newMaxSupply);
    event MinRedemptionAmountChanged(uint256 previousMin, uint256 newMin);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MINT_TIMELOCK = 24 hours;
    uint256 public constant MAX_DECIMALS = 18;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public operator;
    address public feeRecipient;
    bool public paused;
    uint256 public maxSupply;
    uint256 public minRedemptionAmount;

    struct MintRequest {
        address target;
        uint256 amount;
        uint256 requestedAt;
        bool executed;
        bool cancelled;
    }
    MintRequest[] public mintRequests;

    uint256 public redemptionNonce;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
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

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        uint256 _initialSupply,
        uint256 _maxSupply,
        address _feeRecipient
    ) {
        if (_decimals > MAX_DECIMALS) revert InvalidDecimals();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_maxSupply != 0 && _initialSupply > _maxSupply) revert MintExceedsCap();

        name = _name;
        symbol = _symbol;
        decimals = uint8(_decimals);
        maxSupply = _maxSupply;
        feeRecipient = _feeRecipient;

        owner = msg.sender;
        operator = msg.sender;

        if (_initialSupply > 0) {
            totalSupply = _initialSupply;
            balanceOf[msg.sender] = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        emit MaxSupplyChanged(0, _maxSupply);
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 current = allowance[from][msg.sender];
        if (current < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = current - amount;
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 decreasedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = allowance[msg.sender][spender];
        if (current < decreasedValue) revert InsufficientAllowance();
        uint256 newAllowance = current - decreasedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        uint256 senderBalance = balanceOf[from];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 toReceive = amount - fee;

        balanceOf[from] = senderBalance - amount;
        balanceOf[to] += toReceive;
        if (fee > 0) {
            balanceOf[feeRecipient] += fee;
        }

        if (fee > 0) {
            emit Transfer(from, feeRecipient, fee);
        }
        emit Transfer(from, to, toReceive);
    }

    function requestMint(address to, uint256 amount) external onlyOperator returns (uint256 requestId) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (maxSupply != 0 && totalSupply + amount > maxSupply) revert MintExceedsCap();

        requestId = mintRequests.length;
        mintRequests.push(
            MintRequest({
                target: to,
                amount: amount,
                requestedAt: block.timestamp,
                executed: false,
                cancelled: false
            })
        );

        emit MintRequested(requestId, to, amount, block.timestamp);
    }

    function executeMint(uint256 requestId) external onlyOperator {
        if (requestId >= mintRequests.length) revert InvalidRequestId();
        MintRequest storage req = mintRequests[requestId];
        if (req.cancelled) revert AlreadyCancelled();
        if (req.executed) revert AlreadyExecuted();
        if (block.timestamp < req.requestedAt + MINT_TIMELOCK) revert TimelockNotPassed();
        if (maxSupply != 0 && totalSupply + req.amount > maxSupply) revert MintExceedsCap();

        req.executed = true;
        totalSupply += req.amount;
        balanceOf[req.target] += req.amount;

        emit Transfer(address(0), req.target, req.amount);
        emit MintExecuted(requestId, req.target, req.amount);
    }

    function cancelMint(uint256 requestId) external {
        if (requestId >= mintRequests.length) revert InvalidRequestId();
        MintRequest storage req = mintRequests[requestId];
        if (req.executed) revert AlreadyExecuted();
        if (req.cancelled) revert AlreadyCancelled();
        if (msg.sender != owner && msg.sender != operator) revert NotAuthorized();

        req.cancelled = true;
        emit MintCancelled(requestId, req.target, req.amount);
    }

    function burn(address from, uint256 amount) external onlyOperator {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance();

        balanceOf[from] = bal - amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
        emit Burn(from, amount, msg.sender);
    }

    function redeem(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        if (minRedemptionAmount != 0 && amount < minRedemptionAmount) revert BelowMinRedemption();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 nonce = redemptionNonce;
        redemptionNonce = nonce + 1;

        emit RedemptionRequested(msg.sender, amount, nonce);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientChanged(previous, newFeeRecipient);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply != 0 && totalSupply > newMaxSupply) revert MintExceedsCap();
        uint256 previous = maxSupply;
        maxSupply = newMaxSupply;
        emit MaxSupplyChanged(previous, newMaxSupply);
    }

    function setMinRedemptionAmount(uint256 newMin) external onlyOwner {
        uint256 previous = minRedemptionAmount;
        minRedemptionAmount = newMin;
        emit MinRedemptionAmountChanged(previous, newMin);
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function mintRequestCount() external view returns (uint256) {
        return mintRequests.length;
    }

    function getMintRequest(uint256 requestId)
        external
        view
        returns (
            address target,
            uint256 amount,
            uint256 requestedAt,
            bool executed,
            bool cancelled
        )
    {
        if (requestId >= mintRequests.length) revert InvalidRequestId();
        MintRequest storage req = mintRequests[requestId];
        return (req.target, req.amount, req.requestedAt, req.executed, req.cancelled);
    }

    function isMintExecutable(uint256 requestId) external view returns (bool) {
        if (requestId >= mintRequests.length) return false;
        MintRequest storage req = mintRequests[requestId];
        if (req.executed || req.cancelled) return false;
        if (maxSupply != 0 && totalSupply + req.amount > maxSupply) return false;
        return block.timestamp >= req.requestedAt + MINT_TIMELOCK;
    }

    function timeUntilMintExecutable(uint256 requestId) external view returns (uint256) {
        if (requestId >= mintRequests.length) revert InvalidRequestId();
        MintRequest storage req = mintRequests[requestId];
        uint256 deadline = req.requestedAt + MINT_TIMELOCK;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}
