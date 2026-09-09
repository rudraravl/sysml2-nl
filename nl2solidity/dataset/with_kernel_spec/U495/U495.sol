// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenStream is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Stream {
        address sender;
        address recipient;
        address token;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
        bool isActive;
    }

    mapping(uint256 => Stream) public streams;
    uint256 public nextStreamId;

    address public operator;
    uint256 public feePercentage;
    bool public paused;

    uint256 public constant MIN_DURATION = 24 hours;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 1000;

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    );
    event TokensDeposited(uint256 indexed streamId, address indexed depositor, uint256 amount);
    event TokensWithdrawn(uint256 indexed streamId, address indexed recipient, uint256 amount, uint256 fee);
    event StreamCanceled(uint256 indexed streamId, address indexed sender, uint256 returnedAmount);
    event PausedStateChanged(bool isPaused);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address oldOperator, address newOperator);

    error NotOperator();
    error StreamNotActive();
    error StreamDurationTooShort();
    error AmountIsZero();
    error NotStreamSender();
    error NotStreamRecipient();
    error InvalidFeePercentage();
    error NothingToWithdraw();
    error CreationPaused();
    error InvalidAddress();
    error StartTimeInPast();
    error StreamEnded();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert CreationPaused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert InvalidAddress();
        operator = _operator;
        feePercentage = 10;
        nextStreamId = 1;
    }

    function createStream(
        address recipient,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 amount
    ) external whenNotPaused nonReentrant returns (uint256 streamId) {
        if (recipient == address(0)) revert InvalidAddress();
        if (token == address(0)) revert InvalidAddress();
        if (startTime < block.timestamp) revert StartTimeInPast();
        if (endTime <= startTime) revert StreamDurationTooShort();
        if (endTime - startTime < MIN_DURATION) revert StreamDurationTooShort();
        if (amount == 0) revert AmountIsZero();

        streamId = nextStreamId++;
        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            startTime: startTime,
            endTime: endTime,
            totalAmount: amount,
            withdrawnAmount: 0,
            isActive: true
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit StreamCreated(streamId, msg.sender, recipient, token, startTime, endTime, amount);
    }

    function depositToStream(uint256 streamId, uint256 amount) external nonReentrant {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) revert StreamNotActive();
        if (msg.sender != stream.sender) revert NotStreamSender();
        if (block.timestamp >= stream.endTime) revert StreamEnded();
        if (amount == 0) revert AmountIsZero();

        uint256 oldTotal = stream.totalAmount;
        uint256 oldDuration = stream.endTime - stream.startTime;
        stream.totalAmount = oldTotal + amount;
        uint256 newDuration = (stream.totalAmount * oldDuration) / oldTotal;
        stream.endTime = stream.startTime + newDuration;

        IERC20(stream.token).safeTransferFrom(msg.sender, address(this), amount);

        emit TokensDeposited(streamId, msg.sender, amount);
    }

    function withdrawFromStream(uint256 streamId) external nonReentrant {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) revert StreamNotActive();
        if (msg.sender != stream.recipient) revert NotStreamRecipient();

        uint256 vested = _calculateVestedAmount(stream);
        uint256 withdrawable = vested - stream.withdrawnAmount;
        if (withdrawable == 0) revert NothingToWithdraw();

        uint256 fee = (withdrawable * feePercentage) / FEE_DENOMINATOR;
        uint256 amountToRecipient = withdrawable - fee;

        stream.withdrawnAmount = vested;

        IERC20(stream.token).safeTransfer(stream.recipient, amountToRecipient);
        if (fee > 0) {
            IERC20(stream.token).safeTransfer(operator, fee);
        }

        emit TokensWithdrawn(streamId, stream.recipient, amountToRecipient, fee);
    }

    function cancelStream(uint256 streamId) external nonReentrant {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) revert StreamNotActive();
        if (msg.sender != stream.sender) revert NotStreamSender();

        uint256 vested = _calculateVestedAmount(stream);
        uint256 recipientBalance = vested - stream.withdrawnAmount;
        uint256 senderBalance = stream.totalAmount - vested;

        stream.isActive = false;

        if (recipientBalance > 0) {
            uint256 fee = (recipientBalance * feePercentage) / FEE_DENOMINATOR;
            uint256 amountToRecipient = recipientBalance - fee;
            IERC20(stream.token).safeTransfer(stream.recipient, amountToRecipient);
            if (fee > 0) {
                IERC20(stream.token).safeTransfer(operator, fee);
            }
        }

        if (senderBalance > 0) {
            IERC20(stream.token).safeTransfer(stream.sender, senderBalance);
        }

        emit StreamCanceled(streamId, msg.sender, senderBalance);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOperator {
        if (_feePercentage > MAX_FEE) revert InvalidFeePercentage();
        uint256 oldFee = feePercentage;
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(oldFee, _feePercentage);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert InvalidAddress();
        address oldOperator = operator;
        operator = _operator;
        emit OperatorUpdated(oldOperator, _operator);
    }

    function getStream(uint256 streamId)
        external
        view
        returns (
            address sender,
            address recipient,
            address token,
            uint256 startTime,
            uint256 endTime,
            uint256 totalAmount,
            uint256 withdrawnAmount,
            bool isActive
        )
    {
        Stream storage stream = streams[streamId];
        return (
            stream.sender,
            stream.recipient,
            stream.token,
            stream.startTime,
            stream.endTime,
            stream.totalAmount,
            stream.withdrawnAmount,
            stream.isActive
        );
    }

    function vestedAmount(uint256 streamId) external view returns (uint256) {
        return _calculateVestedAmount(streams[streamId]);
    }

    function withdrawableAmount(uint256 streamId) external view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) return 0;
        uint256 vested = _calculateVestedAmount(stream);
        return vested - stream.withdrawnAmount;
    }

    function _calculateVestedAmount(Stream storage stream) internal view returns (uint256) {
        if (block.timestamp >= stream.endTime) {
            return stream.totalAmount;
        } else if (block.timestamp <= stream.startTime) {
            return 0;
        } else {
            return (stream.totalAmount * (block.timestamp - stream.startTime)) / (stream.endTime - stream.startTime);
        }
    }
}
