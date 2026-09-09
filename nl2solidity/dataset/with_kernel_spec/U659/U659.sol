// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract CrossChainTokenBridge {
    error OnlyOperator();
    error EnforcedPause();
    error ZeroAddress();
    error InvalidAmount();
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(address account, uint256 required);
    error TransferAlreadyProcessed(bytes32 id);
    error InvalidFee();
    error TokenTransferFailed();

    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        bytes32 destinationChainId,
        uint256 amount,
        uint256 fee,
        uint256 netAmount
    );

    event TokensMinted(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount
    );

    event TokensRedeemed(
        bytes32 indexed redeemId,
        address indexed redeemer,
        address indexed recipient,
        bytes32 sourceChainId,
        uint256 amount,
        uint256 fee,
        uint256 netAmount
    );

    event TokensUnlocked(
        bytes32 indexed redeemId,
        address indexed recipient,
        uint256 amount
    );

    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    uint256 public constant MIN_TRANSFER_AMOUNT = 100;
    uint256 public constant DEFAULT_FEE_BPS = 10;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1000;

    IERC20 public immutable token;
    bytes32 public immutable chainId;

    address public operator;
    bool public paused;
    uint256 public feeBps;

    mapping(address => uint256) public lockedBalances;
    uint256 public totalLocked;

    mapping(address => uint256) public mintedBalances;
    uint256 public totalMintedSupply;

    mapping(bytes32 => bool) public processedTransfers;
    mapping(bytes32 => bool) public processedRedeems;

    uint256 public accumulatedFees;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor(address token_, bytes32 chainId_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();

        token = IERC20(token_);
        chainId = chainId_;
        operator = operator_;
        feeBps = DEFAULT_FEE_BPS;
        paused = false;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(msg.sender, oldFeeBps, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function withdrawFees(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > accumulatedFees) revert InsufficientBalance(address(this), amount);

        accumulatedFees -= amount;
        totalLocked -= amount;

        bool success = token.transfer(recipient, amount);
        if (!success) revert TokenTransferFailed();
    }

    function initiateTransfer(
        uint256 amount,
        address recipient,
        bytes32 destinationChainId
    ) external whenNotPaused returns (bytes32 transferId) {
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum(amount, MIN_TRANSFER_AMOUNT);
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TokenTransferFailed();

        lockedBalances[msg.sender] += netAmount;
        totalLocked += netAmount;

        if (fee > 0) {
            accumulatedFees += fee;
            totalLocked += fee;
        }

        transferId = keccak256(
            abi.encodePacked(
                chainId,
                destinationChainId,
                msg.sender,
                recipient,
                amount,
                netAmount,
                block.number,
                block.timestamp,
                totalLocked
            )
        );

        emit TransferInitiated(
            transferId,
            msg.sender,
            recipient,
            destinationChainId,
            amount,
            fee,
            netAmount
        );
    }

    function claimMintedTokens(
        bytes32 transferId,
        address recipient,
        uint256 netAmount
    ) external onlyOperator whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (netAmount == 0) revert InvalidAmount();
        if (processedTransfers[transferId]) revert TransferAlreadyProcessed(transferId);

        processedTransfers[transferId] = true;

        mintedBalances[recipient] += netAmount;
        totalMintedSupply += netAmount;

        emit TokensMinted(transferId, recipient, netAmount);
    }

    function redeemTokens(
        uint256 amount,
        address recipient,
        bytes32 sourceChainId
    ) external whenNotPaused returns (bytes32 redeemId) {
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum(amount, MIN_TRANSFER_AMOUNT);
        if (recipient == address(0)) revert ZeroAddress();
        if (mintedBalances[msg.sender] < amount) revert InsufficientBalance(msg.sender, amount);

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        mintedBalances[msg.sender] -= amount;
        totalMintedSupply -= amount;

        redeemId = keccak256(
            abi.encodePacked(
                chainId,
                sourceChainId,
                msg.sender,
                recipient,
                amount,
                netAmount,
                block.number,
                block.timestamp,
                totalMintedSupply
            )
        );

        emit TokensRedeemed(
            redeemId,
            msg.sender,
            recipient,
            sourceChainId,
            amount,
            fee,
            netAmount
        );
    }

    function unlockTokens(
        bytes32 redeemId,
        address recipient,
        uint256 netAmount
    ) external onlyOperator whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (netAmount == 0) revert InvalidAmount();
        if (processedRedeems[redeemId]) revert TransferAlreadyProcessed(redeemId);

        uint256 available = totalLocked - accumulatedFees;
        if (available < netAmount) revert InsufficientBalance(address(this), netAmount);

        processedRedeems[redeemId] = true;

        totalLocked -= netAmount;

        if (lockedBalances[recipient] >= netAmount) {
            lockedBalances[recipient] -= netAmount;
        } else {
            lockedBalances[recipient] = 0;
        }

        bool success = token.transfer(recipient, netAmount);
        if (!success) revert TokenTransferFailed();

        emit TokensUnlocked(redeemId, recipient, netAmount);
    }

    function lockedBalanceOf(address account) external view returns (uint256) {
        return lockedBalances[account];
    }

    function mintedBalanceOf(address account) external view returns (uint256) {
        return mintedBalances[account];
    }

    function isTransferProcessed(bytes32 transferId) external view returns (bool) {
        return processedTransfers[transferId];
    }

    function isRedeemProcessed(bytes32 redeemId) external view returns (bool) {
        return processedRedeems[redeemId];
    }

    function calculateFee(uint256 amount) external view returns (uint256 fee, uint256 netAmount) {
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        netAmount = amount - fee;
    }
}
