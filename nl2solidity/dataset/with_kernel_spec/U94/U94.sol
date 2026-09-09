// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract StreamEscrow {
    struct Stream {
        address token;
        uint256 totalAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 streamedAmount;
        uint256 withdrawnAmount;
        uint256 lastUpdateTime;
        bool exists;
    }

    address public owner;
    bool public paused;
    uint256 public protocolFee; // in basis points (1 bp = 0.01%), default 10 = 0.1%
    uint256 public constant MIN_DURATION = 60 seconds;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10000;

    mapping(address => mapping(address => Stream)) public streams;

    event StreamCreated(
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    );
    event StreamDeposited(address indexed sender, address indexed recipient, uint256 amount, uint256 newTotalAmount);
    event StreamCancelled(address indexed sender, address indexed recipient, uint256 remainingAmount);
    event Withdrawn(address indexed sender, address indexed recipient, uint256 amount, uint256 fee);
    event Paused(address account);
    event Unpaused(address account);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();
    error StreamNotExists();
    error StreamExists();
    error InvalidDuration();
    error InvalidAmount();
    error InvalidTime();
    error ContractPaused();
    error NotPaused();
    error InvalidFee();
    error ZeroAddress();
    error InsufficientBalance();
    error StreamEnded();
    error ReentrancyGuard();

    uint256 private _reentrancyStatus;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrancyGuard();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    constructor() {
        owner = msg.sender;
        protocolFee = 10; // 0.1%
        paused = false;
        _reentrancyStatus = 1;
        emit OwnershipTransferred(address(0), owner);
        emit FeeUpdated(0, protocolFee);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        if (paused) revert ContractPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = protocolFee;
        protocolFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function createStream(
        address recipient,
        address token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    ) external whenNotPaused nonReentrant {
        if (recipient == address(0) || token == address(0)) revert ZeroAddress();
        if (streams[msg.sender][recipient].exists) revert StreamExists();
        if (startTime >= endTime) revert InvalidTime();
        if (endTime - startTime < MIN_DURATION) revert InvalidDuration();
        if (totalAmount == 0) revert InvalidAmount();

        streams[msg.sender][recipient] = Stream({
            token: token,
            totalAmount: totalAmount,
            startTime: startTime,
            endTime: endTime,
            streamedAmount: 0,
            withdrawnAmount: 0,
            lastUpdateTime: startTime,
            exists: true
        });

        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), totalAmount);

        emit StreamCreated(msg.sender, recipient, token, totalAmount, startTime, endTime);
    }

    function deposit(address recipient, uint256 amount) external whenNotPaused nonReentrant {
        Stream storage stream = streams[msg.sender][recipient];
        if (!stream.exists) revert StreamNotExists();
        if (amount == 0) revert InvalidAmount();
        if (block.timestamp >= stream.endTime) revert StreamEnded();

        _updateStream(stream);

        // Effects: update state before external interaction
        stream.totalAmount += amount;

        // Interactions
        SafeERC20.safeTransferFrom(IERC20(stream.token), msg.sender, address(this), amount);

        emit StreamDeposited(msg.sender, recipient, amount, stream.totalAmount);
    }

    function withdraw(address sender, uint256 amount) external nonReentrant {
        Stream storage stream = streams[sender][msg.sender];
        if (!stream.exists) revert StreamNotExists();
        if (amount == 0) revert InvalidAmount();

        _updateStream(stream);

        uint256 available = stream.streamedAmount - stream.withdrawnAmount;
        if (amount > available) revert InsufficientBalance();

        // Effects: update state before external interaction
        stream.withdrawnAmount += amount;

        uint256 fee = (amount * protocolFee) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        // Interactions
        if (net > 0) {
            SafeERC20.safeTransfer(IERC20(stream.token), msg.sender, net);
        }
        if (fee > 0) {
            SafeERC20.safeTransfer(IERC20(stream.token), owner, fee);
        }

        emit Withdrawn(sender, msg.sender, amount, fee);
    }

    function cancelStream(address recipient) external nonReentrant {
        Stream storage stream = streams[msg.sender][recipient];
        if (!stream.exists) revert StreamNotExists();

        _updateStream(stream);

        uint256 remaining = stream.totalAmount - stream.streamedAmount;

        // Effects: update state before external interaction
        if (remaining > 0) {
            stream.totalAmount = stream.streamedAmount;
        }

        // Interactions
        if (remaining > 0) {
            SafeERC20.safeTransfer(IERC20(stream.token), msg.sender, remaining);
        }

        emit StreamCancelled(msg.sender, recipient, remaining);
    }

    function _updateStream(Stream storage stream) internal {
        if (block.timestamp <= stream.lastUpdateTime) return;
        if (block.timestamp >= stream.endTime) {
            stream.streamedAmount = stream.totalAmount;
            stream.lastUpdateTime = stream.endTime;
            return;
        }

        uint256 remainingTime = stream.endTime - stream.lastUpdateTime;
        uint256 remainingAmount = stream.totalAmount - stream.streamedAmount;
        uint256 accrued = ((block.timestamp - stream.lastUpdateTime) * remainingAmount) / remainingTime;
        stream.streamedAmount += accrued;
        stream.lastUpdateTime = block.timestamp;
    }

    function getAvailable(address sender, address recipient) external view returns (uint256) {
        Stream storage stream = streams[sender][recipient];
        if (!stream.exists) return 0;

        uint256 currentStreamed;
        if (block.timestamp >= stream.endTime) {
            currentStreamed = stream.totalAmount;
        } else if (block.timestamp <= stream.lastUpdateTime) {
            currentStreamed = stream.streamedAmount;
        } else {
            uint256 remainingTime = stream.endTime - stream.lastUpdateTime;
            uint256 remainingAmount = stream.totalAmount - stream.streamedAmount;
            uint256 accrued = ((block.timestamp - stream.lastUpdateTime) * remainingAmount) / remainingTime;
            currentStreamed = stream.streamedAmount + accrued;
        }

        return currentStreamed - stream.withdrawnAmount;
    }
}
