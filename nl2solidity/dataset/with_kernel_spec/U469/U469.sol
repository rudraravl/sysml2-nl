// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

error TransferFailed();
error NotOwner();
error StreamPaused();
error ZeroAddress();
error InvalidAmount();
error InvalidRate();
error StreamNotFound();
error NotStreamSender();
error NotRecipient();
error NoWithdrawableAmount();
error FeeTooHigh();
error ReentrancyGuard();

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}

contract TokenStream {
    event StreamCreated(
        address indexed sender,
        address indexed recipient,
        address indexed token,
        uint256 streamId,
        uint256 totalAmount,
        uint256 startTime,
        uint256 ratePerSecond
    );

    event StreamDeposited(
        address indexed sender,
        address indexed token,
        uint256 indexed streamId,
        uint256 amount,
        uint256 newTotalAmount
    );

    event StreamWithdrawn(
        address indexed sender,
        address indexed recipient,
        address indexed token,
        uint256 streamId,
        uint256 grossAmount,
        uint256 feeAmount,
        uint256 netAmount
    );

    event Paused(address indexed owner);
    event Unpaused(address indexed owner);
    event FeeUpdated(address indexed owner, uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct Stream {
        address recipient;
        address token;
        uint256 totalAmount;
        uint256 startTime;
        uint256 ratePerSecond;
        uint256 withdrawnAmount;
    }

    uint256 public constant MIN_STREAM_AMOUNT = 100;
    uint256 public constant MAX_FEE_BPS = 10000;
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public owner;
    bool public paused;
    uint256 public feeBps;

    mapping(address => mapping(uint256 => Stream)) public streams;
    mapping(address => uint256) public streamCount;
    mapping(address => uint256) public tokenBalances;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus = _NOT_ENTERED;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert StreamPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyGuard();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        feeBps = 10;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(msg.sender, old, newFeeBps);
    }

    function createStream(
        address recipient,
        address token,
        uint256 amount,
        uint256 ratePerSecond
    ) external whenNotPaused nonReentrant returns (uint256 streamId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (amount < MIN_STREAM_AMOUNT) revert InvalidAmount();
        if (ratePerSecond == 0) revert InvalidRate();

        // Effects: update state before external call (checks-effects-interactions)
        streamId = streamCount[msg.sender]++;
        streams[msg.sender][streamId] = Stream({
            recipient: recipient,
            token: token,
            totalAmount: amount,
            startTime: block.timestamp,
            ratePerSecond: ratePerSecond,
            withdrawnAmount: 0
        });
        tokenBalances[token] += amount;

        // Interactions
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);

        emit StreamCreated(
            msg.sender,
            recipient,
            token,
            streamId,
            amount,
            block.timestamp,
            ratePerSecond
        );
    }

    function depositToStream(uint256 streamId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (streamId >= streamCount[msg.sender]) revert StreamNotFound();

        Stream storage stream = streams[msg.sender][streamId];

        // Effects: update state before external call (checks-effects-interactions)
        stream.totalAmount += amount;
        tokenBalances[stream.token] += amount;

        // Interactions
        SafeERC20.safeTransferFrom(IERC20(stream.token), msg.sender, address(this), amount);

        emit StreamDeposited(
            msg.sender,
            stream.token,
            streamId,
            amount,
            stream.totalAmount
        );
    }

    function withdraw(address sender, uint256 streamId) external whenNotPaused nonReentrant {
        if (streamId >= streamCount[sender]) revert StreamNotFound();

        Stream storage stream = streams[sender][streamId];
        if (msg.sender != stream.recipient) revert NotRecipient();

        uint256 available = _available(stream);
        if (available < 1) revert NoWithdrawableAmount();

        uint256 fee = (available * feeBps) / FEE_DENOMINATOR;
        uint256 net = available - fee;

        // Effects: update state before external calls (checks-effects-interactions)
        stream.withdrawnAmount += available;
        tokenBalances[stream.token] -= available;

        // Interactions
        if (net > 0) {
            SafeERC20.safeTransfer(IERC20(stream.token), stream.recipient, net);
        }
        if (fee > 0) {
            SafeERC20.safeTransfer(IERC20(stream.token), owner, fee);
        }

        emit StreamWithdrawn(
            sender,
            stream.recipient,
            stream.token,
            streamId,
            available,
            fee,
            net
        );
    }

    function availableToWithdraw(address sender, uint256 streamId) external view returns (uint256) {
        if (streamId >= streamCount[sender]) return 0;
        return _available(streams[sender][streamId]);
    }

    function getStream(address sender, uint256 streamId) external view returns (Stream memory) {
        if (streamId >= streamCount[sender]) revert StreamNotFound();
        return streams[sender][streamId];
    }

    function getStreamCount(address sender) external view returns (uint256) {
        return streamCount[sender];
    }

    function getStopTime(address sender, uint256 streamId) external view returns (uint256) {
        if (streamId >= streamCount[sender]) revert StreamNotFound();
        Stream storage stream = streams[sender][streamId];
        return stream.startTime + (stream.totalAmount / stream.ratePerSecond);
    }

    function _available(Stream storage stream) internal view returns (uint256) {
        if (block.timestamp <= stream.startTime) return 0;
        uint256 elapsed = block.timestamp - stream.startTime;
        uint256 accrued = elapsed * stream.ratePerSecond;
        if (accrued > stream.totalAmount) {
            accrued = stream.totalAmount;
        }
        // Guard against underflow: if withdrawnAmount exceeds accrued, return 0
        if (accrued <= stream.withdrawnAmount) return 0;
        return accrued - stream.withdrawnAmount;
    }
}
