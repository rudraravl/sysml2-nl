// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FanSubscription {
    uint256 public constant MAX_DURATION_MONTHS = 12;
    uint256 public constant SECONDS_PER_MONTH = 30 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 500; // 5%

    address public operator;
    address public feeRecipient;
    uint256 public systemFeeBps;

    struct Subscription {
        uint256 monthlyAmount;
        uint256 startTime;
        uint256 endTime;
        bool canceled;
    }

    mapping(address => bool) public isRegisteredCreator;
    mapping(address => mapping(address => Subscription)) public subscriptions;

    event CreatorAdded(address indexed creator);
    event CreatorRemoved(address indexed creator);
    event SystemFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event SubscriptionCreated(
        address indexed fan,
        address indexed creator,
        uint256 monthlyAmount,
        uint256 durationMonths,
        uint256 endTime,
        uint256 feeAmount
    );
    event SubscriptionRenewed(
        address indexed fan,
        address indexed creator,
        uint256 durationMonths,
        uint256 newEndTime,
        uint256 feeAmount
    );
    event SubscriptionCanceled(address indexed fan, address indexed creator, uint256 canceledAt);

    error NotOperator();
    error ZeroAddress();
    error CreatorAlreadyRegistered();
    error CreatorNotRegistered();
    error InvalidDuration();
    error InvalidMonthlyAmount();
    error FeeTooHigh();
    error SubscriptionAlreadyActive();
    error SubscriptionNotFound();
    error SubscriptionNotActive();
    error IncorrectPayment();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        systemFeeBps = DEFAULT_FEE_BPS;
        emit SystemFeeUpdated(0, DEFAULT_FEE_BPS);
    }

    function addCreator(address creator) external onlyOperator {
        if (creator == address(0)) revert ZeroAddress();
        if (isRegisteredCreator[creator]) revert CreatorAlreadyRegistered();
        isRegisteredCreator[creator] = true;
        emit CreatorAdded(creator);
    }

    function removeCreator(address creator) external onlyOperator {
        if (!isRegisteredCreator[creator]) revert CreatorNotRegistered();
        isRegisteredCreator[creator] = false;
        emit CreatorRemoved(creator);
    }

    function setSystemFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps >= BPS_DENOMINATOR) revert FeeTooHigh();
        uint256 oldFeeBps = systemFeeBps;
        systemFeeBps = newFeeBps;
        emit SystemFeeUpdated(oldFeeBps, newFeeBps);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function subscribe(address creator, uint256 monthlyAmount, uint256 durationMonths) external payable {
        if (!isRegisteredCreator[creator]) revert CreatorNotRegistered();
        if (monthlyAmount == 0) revert InvalidMonthlyAmount();
        if (durationMonths == 0 || durationMonths > MAX_DURATION_MONTHS) revert InvalidDuration();

        Subscription storage sub = subscriptions[msg.sender][creator];
        if (sub.endTime > block.timestamp && !sub.canceled) revert SubscriptionAlreadyActive();

        uint256 totalPayment = monthlyAmount * durationMonths;
        if (msg.value != totalPayment) revert IncorrectPayment();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + durationMonths * SECONDS_PER_MONTH;

        sub.monthlyAmount = monthlyAmount;
        sub.startTime = startTime;
        sub.endTime = endTime;
        sub.canceled = false;

        uint256 feeAmount = _distributePayment(creator, totalPayment);

        emit SubscriptionCreated(msg.sender, creator, monthlyAmount, durationMonths, endTime, feeAmount);
    }

    function renew(address creator, uint256 durationMonths) external payable {
        if (!isRegisteredCreator[creator]) revert CreatorNotRegistered();
        if (durationMonths == 0 || durationMonths > MAX_DURATION_MONTHS) revert InvalidDuration();

        Subscription storage sub = subscriptions[msg.sender][creator];
        if (sub.monthlyAmount == 0) revert SubscriptionNotFound();

        uint256 totalPayment = sub.monthlyAmount * durationMonths;
        if (msg.value != totalPayment) revert IncorrectPayment();

        uint256 newEndTime;
        if (sub.endTime < block.timestamp || sub.canceled) {
            newEndTime = block.timestamp + durationMonths * SECONDS_PER_MONTH;
        } else {
            newEndTime = sub.endTime + durationMonths * SECONDS_PER_MONTH;
        }

        sub.endTime = newEndTime;
        sub.canceled = false;

        uint256 feeAmount = _distributePayment(creator, totalPayment);

        emit SubscriptionRenewed(msg.sender, creator, durationMonths, newEndTime, feeAmount);
    }

    function cancel(address creator) external {
        Subscription storage sub = subscriptions[msg.sender][creator];
        if (sub.monthlyAmount == 0) revert SubscriptionNotFound();
        if (sub.canceled || sub.endTime <= block.timestamp) revert SubscriptionNotActive();

        sub.canceled = true;
        sub.endTime = block.timestamp;

        emit SubscriptionCanceled(msg.sender, creator, block.timestamp);
    }

    function getSubscription(address fan, address creator)
        external
        view
        returns (uint256 monthlyAmount, uint256 startTime, uint256 endTime, bool canceled, bool isActive)
    {
        Subscription storage sub = subscriptions[fan][creator];
        monthlyAmount = sub.monthlyAmount;
        startTime = sub.startTime;
        endTime = sub.endTime;
        canceled = sub.canceled;
        isActive = !sub.canceled && sub.endTime > block.timestamp;
    }

    function isSubscriptionActive(address fan, address creator) external view returns (bool) {
        Subscription storage sub = subscriptions[fan][creator];
        return !sub.canceled && sub.endTime > block.timestamp;
    }

    function _distributePayment(address creator, uint256 amount) internal returns (uint256 feeAmount) {
        feeAmount = (amount * systemFeeBps) / BPS_DENOMINATOR;
        uint256 creatorAmount = amount - feeAmount;

        if (creator == feeRecipient) {
            (bool ok, ) = feeRecipient.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            if (feeAmount > 0) {
                (bool okFee, ) = feeRecipient.call{value: feeAmount}("");
                if (!okFee) revert TransferFailed();
            }
            if (creatorAmount > 0) {
                (bool okCreator, ) = creator.call{value: creatorAmount}("");
                if (!okCreator) revert TransferFailed();
            }
        }
    }
}
