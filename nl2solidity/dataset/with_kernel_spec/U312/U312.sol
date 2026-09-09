// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWrappedToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract CrossChainWrappedBridge {
    error NotOperator();
    error EnforcedPause();
    error EnforcedUnpause();
    error ZeroAddress();
    error ZeroAmount();
    error ChainNotSupported(uint256 chainId);
    error ChainAlreadySupported(uint256 chainId);
    error SameChainTransfer(uint256 chainId);
    error AmountNotGreaterThanFee(uint256 amount, uint256 fee);
    error InsufficientDepositedBalance(uint256 available, uint256 required);
    error InsufficientContractBalance(uint256 available, uint256 required);
    error ClaimDoesNotExist(bytes32 claimId);
    error ClaimNotAuthorized(bytes32 claimId, address caller);
    error ClaimAlreadyProcessed(bytes32 claimId);
    error NothingToWithdraw();
    error TokenTransferFailed();

    event Deposit(address indexed user, uint256 indexed destChainId, uint256 amount);
    event TransferInitiated(
        address indexed sender,
        uint256 indexed sourceChainId,
        uint256 indexed destChainId,
        address recipient,
        uint256 amount,
        uint256 fee,
        bytes32 claimId
    );
    event TransferClaimed(address indexed recipient, bytes32 indexed claimId, uint256 amount);
    event IncomingTransferRecorded(
        bytes32 indexed claimId,
        address indexed recipient,
        uint256 indexed sourceChainId,
        uint256 amount
    );
    event ChainAdded(uint256 indexed chainId, address gateway);
    event GatewayUpdated(uint256 indexed chainId, address oldGateway, address newGateway);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeesWithdrawn(address indexed operator, address indexed to, uint256 amount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    IWrappedToken public immutable wrappedToken;
    address public operator;
    uint256 public constant TRANSFER_FEE = 0.01e18;
    bool public paused;
    uint256 public collectedFees;
    uint256 public claimNonce;

    struct ChainConfig {
        bool supported;
        address gateway;
    }

    struct IncomingTransfer {
        address recipient;
        uint256 sourceChainId;
        uint256 amount;
        bool claimed;
    }

    mapping(uint256 => ChainConfig) public chains;
    mapping(address => mapping(uint256 => uint256)) public deposited;
    mapping(bytes32 => IncomingTransfer) public incoming;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert EnforcedUnpause();
        _;
    }

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        wrappedToken = IWrappedToken(token_);
        operator = operator_;
        emit OperatorTransferred(address(0), operator_);
    }

    function addChain(uint256 chainId, address gateway) external onlyOperator {
        if (chains[chainId].supported) revert ChainAlreadySupported(chainId);
        if (gateway == address(0)) revert ZeroAddress();
        chains[chainId] = ChainConfig({supported: true, gateway: gateway});
        emit ChainAdded(chainId, gateway);
    }

    function updateGateway(uint256 chainId, address newGateway) external onlyOperator {
        if (!chains[chainId].supported) revert ChainNotSupported(chainId);
        if (newGateway == address(0)) revert ZeroAddress();
        address oldGateway = chains[chainId].gateway;
        chains[chainId].gateway = newGateway;
        emit GatewayUpdated(chainId, oldGateway, newGateway);
    }

    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator);
    }

    function deposit(uint256 destChainId, uint256 amount) external whenNotPaused {
        if (!chains[destChainId].supported) revert ChainNotSupported(destChainId);
        if (destChainId == block.chainid) revert SameChainTransfer(destChainId);
        if (amount == 0) revert ZeroAmount();

        deposited[msg.sender][destChainId] += amount;

        bool ok = wrappedToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TokenTransferFailed();

        emit Deposit(msg.sender, destChainId, amount);
    }

    function initiateTransfer(
        uint256 destChainId,
        address recipient,
        uint256 amount
    ) external whenNotPaused returns (bytes32 claimId) {
        if (!chains[destChainId].supported) revert ChainNotSupported(destChainId);
        if (destChainId == block.chainid) revert SameChainTransfer(destChainId);
        if (recipient == address(0)) revert ZeroAddress();
        if (amount <= TRANSFER_FEE) revert AmountNotGreaterThanFee(amount, TRANSFER_FEE);

        uint256 available = deposited[msg.sender][destChainId];
        if (available < amount) revert InsufficientDepositedBalance(available, amount);

        deposited[msg.sender][destChainId] -= amount;

        uint256 fee = TRANSFER_FEE;
        uint256 netAmount = amount - fee;
        collectedFees += fee;

        claimId = keccak256(
            abi.encodePacked(
                block.chainid,
                destChainId,
                msg.sender,
                recipient,
                netAmount,
                claimNonce++
            )
        );

        emit TransferInitiated(
            msg.sender,
            block.chainid,
            destChainId,
            recipient,
            netAmount,
            fee,
            claimId
        );
    }

    function recordIncomingTransfer(
        bytes32 claimId,
        address recipient,
        uint256 sourceChainId,
        uint256 amount
    ) external onlyOperator {
        if (incoming[claimId].recipient != address(0)) revert ClaimAlreadyProcessed(claimId);
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        incoming[claimId] = IncomingTransfer({
            recipient: recipient,
            sourceChainId: sourceChainId,
            amount: amount,
            claimed: false
        });

        emit IncomingTransferRecorded(claimId, recipient, sourceChainId, amount);
    }

    function claim(bytes32 claimId) external whenNotPaused {
        IncomingTransfer storage t = incoming[claimId];
        if (t.recipient == address(0)) revert ClaimDoesNotExist(claimId);
        if (t.claimed) revert ClaimAlreadyProcessed(claimId);
        if (t.recipient != msg.sender) revert ClaimNotAuthorized(claimId, msg.sender);

        t.claimed = true;
        uint256 amount = t.amount;

        uint256 ourBalance = wrappedToken.balanceOf(address(this));
        if (ourBalance < amount) revert InsufficientContractBalance(ourBalance, amount);

        bool ok = wrappedToken.transfer(msg.sender, amount);
        if (!ok) revert TokenTransferFailed();

        emit TransferClaimed(msg.sender, claimId, amount);
    }

    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (collectedFees == 0) revert NothingToWithdraw();

        uint256 amount = collectedFees;
        collectedFees = 0;

        bool ok = wrappedToken.transfer(to, amount);
        if (!ok) revert TokenTransferFailed();

        emit FeesWithdrawn(msg.sender, to, amount);
    }

    function isChainSupported(uint256 chainId) external view returns (bool) {
        return chains[chainId].supported;
    }

    function getGateway(uint256 chainId) external view returns (address) {
        return chains[chainId].gateway;
    }

    function getDeposited(address user, uint256 chainId) external view returns (uint256) {
        return deposited[user][chainId];
    }

    function getIncomingTransfer(bytes32 claimId)
        external
        view
        returns (address recipient, uint256 sourceChainId, uint256 amount, bool claimed)
    {
        IncomingTransfer storage t = incoming[claimId];
        return (t.recipient, t.sourceChainId, t.amount, t.claimed);
    }
}
