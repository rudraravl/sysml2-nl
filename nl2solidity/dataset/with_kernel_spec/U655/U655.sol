// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPaymentToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PrivateCompanyShares {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotIssuer();
    error ZeroAddress();
    error ShareClassNotFound();
    error TransferRestricted(address account);
    error InsufficientBalance();
    error InsufficientAllowance();
    error BelowMinimumSubscription();
    error BuybackNotActive();
    error BuybackActive();
    error InvalidAmount();
    error InvalidNominalValue();
    error TransferFailed();
    error NotApprovedHolder();
    error AlreadyApproved();
    error NotApproved();
    error Reentrancy();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event ShareClassCreated(uint256 indexed classId, string name, uint256 nominalValue, bool transferRestricted);
    event ShareClassConfigUpdated(uint256 indexed classId, uint256 nominalValue, bool transferRestricted);
    event SharesIssued(uint256 indexed classId, address indexed to, uint256 amount);
    event SharesSubscribed(uint256 indexed classId, address indexed subscriber, uint256 shares, uint256 paymentAmount);
    event SharesTransferred(uint256 indexed classId, address indexed from, address indexed to, uint256 amount, uint256 fee);
    event SharesRedeemed(uint256 indexed classId, address indexed from, uint256 shares, uint256 paymentAmount);
    event BuybackInitiated(uint256 indexed classId, uint256 price);
    event BuybackCancelled(uint256 indexed classId);
    event HolderApprovalUpdated(uint256 indexed classId, address indexed holder, bool approved);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);
    event IssuerTransferred(address indexed previousIssuer, address indexed newIssuer);
    event BuybackFunded(uint256 amount);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant TRANSFER_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_SUBSCRIPTION = 100; // minimum payment token units

    // -------------------------------------------------------------------------
    // Reentrancy guard
    // -------------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    address public issuer;
    address public feeCollector;
    IPaymentToken public immutable paymentToken;

    struct ShareClass {
        string name;
        uint256 nominalValue; // payment token units per share
        bool transferRestricted;
        bool buybackActive;
        uint256 buybackPrice; // payment token units per share during buyback
        uint256 totalSupply;
        bool exists;
    }

    mapping(uint256 => ShareClass) private _shareClasses;
    uint256 public shareClassCount;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(uint256 => mapping(address => bool)) private _approvedHolders;

    modifier onlyIssuer() {
        if (msg.sender != issuer) revert NotIssuer();
        _;
    }

    modifier validClass(uint256 classId) {
        if (!_shareClasses[classId].exists) revert ShareClassNotFound();
        _;
    }

    constructor(address paymentToken_, address feeCollector_) {
        if (paymentToken_ == address(0)) revert ZeroAddress();
        if (feeCollector_ == address(0)) revert ZeroAddress();
        paymentToken = IPaymentToken(paymentToken_);
        issuer = msg.sender;
        feeCollector = feeCollector_;
        emit IssuerTransferred(address(0), msg.sender);
        emit FeeCollectorUpdated(address(0), feeCollector_);
    }

    // -------------------------------------------------------------------------
    // Issuer administration
    // -------------------------------------------------------------------------
    function createShareClass(
        string calldata name,
        uint256 nominalValue,
        bool transferRestricted
    ) external onlyIssuer returns (uint256 classId) {
        if (nominalValue == 0) revert InvalidNominalValue();
        classId = shareClassCount++;
        _shareClasses[classId] = ShareClass({
            name: name,
            nominalValue: nominalValue,
            transferRestricted: transferRestricted,
            buybackActive: false,
            buybackPrice: 0,
            totalSupply: 0,
            exists: true
        });
        emit ShareClassCreated(classId, name, nominalValue, transferRestricted);
    }

    function updateShareClassConfig(
        uint256 classId,
        uint256 nominalValue,
        bool transferRestricted
    ) external onlyIssuer validClass(classId) {
        if (nominalValue == 0) revert InvalidNominalValue();
        ShareClass storage sc = _shareClasses[classId];
        sc.nominalValue = nominalValue;
        sc.transferRestricted = transferRestricted;
        emit ShareClassConfigUpdated(classId, nominalValue, transferRestricted);
    }

    function setHolderApproval(
        uint256 classId,
        address holder,
        bool approved
    ) external onlyIssuer validClass(classId) {
        if (holder == address(0)) revert ZeroAddress();
        if (_approvedHolders[classId][holder] == approved) {
            if (approved) revert AlreadyApproved();
            else revert NotApproved();
        }
        _approvedHolders[classId][holder] = approved;
        emit HolderApprovalUpdated(classId, holder, approved);
    }

    function mintShares(
        uint256 classId,
        address to,
        uint256 amount
    ) external onlyIssuer validClass(classId) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        ShareClass storage sc = _shareClasses[classId];
        sc.totalSupply += amount;
        _balances[classId][to] += amount;
        emit SharesIssued(classId, to, amount);
    }

    function initiateBuyback(uint256 classId, uint256 pricePerShare)
        external
        onlyIssuer
        validClass(classId)
    {
        if (pricePerShare == 0) revert InvalidNominalValue();
        ShareClass storage sc = _shareClasses[classId];
        if (sc.buybackActive) revert BuybackActive();
        sc.buybackActive = true;
        sc.buybackPrice = pricePerShare;
        emit BuybackInitiated(classId, pricePerShare);
    }

    function cancelBuyback(uint256 classId) external onlyIssuer validClass(classId) {
        ShareClass storage sc = _shareClasses[classId];
        if (!sc.buybackActive) revert BuybackNotActive();
        sc.buybackActive = false;
        sc.buybackPrice = 0;
        emit BuybackCancelled(classId);
    }

    function fundBuyback(uint256 amount) external onlyIssuer nonReentrant {
        if (amount == 0) revert InvalidAmount();
        bool ok = paymentToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit BuybackFunded(amount);
    }

    function setFeeCollector(address newCollector) external onlyIssuer {
        if (newCollector == address(0)) revert ZeroAddress();
        address previous = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(previous, newCollector);
    }

    function transferIssuer(address newIssuer) external onlyIssuer {
        if (newIssuer == address(0)) revert ZeroAddress();
        address previous = issuer;
        issuer = newIssuer;
        emit IssuerTransferred(previous, newIssuer);
    }

    // -------------------------------------------------------------------------
    // Investor operations
    // -------------------------------------------------------------------------
    function subscribe(uint256 classId, uint256 paymentAmount)
        external
        validClass(classId)
        nonReentrant
        returns (uint256 shares)
    {
        if (paymentAmount < MIN_SUBSCRIPTION) revert BelowMinimumSubscription();
        ShareClass storage sc = _shareClasses[classId];
        if (sc.buybackActive) revert BuybackActive();

        uint256 nominalValue = sc.nominalValue;
        // Compute whole shares without divide-then-multiply precision loss.
        shares = paymentAmount / nominalValue;
        if (shares == 0) revert InvalidAmount();

        // Charge only for whole shares; remainder stays with the subscriber.
        uint256 remainder = paymentAmount % nominalValue;
        uint256 actualCost = paymentAmount - remainder;

        // Effects: update state before external interaction.
        sc.totalSupply += shares;
        _balances[classId][msg.sender] += shares;

        // Interactions: pull payment after state is committed.
        bool ok = paymentToken.transferFrom(msg.sender, address(this), actualCost);
        if (!ok) revert TransferFailed();

        emit SharesSubscribed(classId, msg.sender, shares, actualCost);
        emit SharesIssued(classId, msg.sender, shares);
    }

    function transferShares(uint256 classId, address to, uint256 amount)
        external
        validClass(classId)
        nonReentrant
        returns (bool)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (_balances[classId][msg.sender] < amount) revert InsufficientBalance();

        ShareClass storage sc = _shareClasses[classId];
        if (sc.transferRestricted) {
            if (!_approvedHolders[classId][to]) revert NotApprovedHolder();
        }

        uint256 fee = (amount * TRANSFER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netToReceiver = amount - fee;

        _balances[classId][msg.sender] -= amount;
        _balances[classId][to] += netToReceiver;
        _balances[classId][feeCollector] += fee;

        emit SharesTransferred(classId, msg.sender, to, netToReceiver, fee);
        return true;
    }

    function redeemShares(uint256 classId, uint256 shareAmount)
        external
        validClass(classId)
        nonReentrant
        returns (uint256 payout)
    {
        if (shareAmount == 0) revert InvalidAmount();
        if (_balances[classId][msg.sender] < shareAmount) revert InsufficientBalance();

        ShareClass storage sc = _shareClasses[classId];
        if (!sc.buybackActive) revert BuybackNotActive();

        payout = shareAmount * sc.buybackPrice;
        if (paymentToken.balanceOf(address(this)) < payout) revert InsufficientBalance();

        // Effects: burn shares before sending payment.
        _balances[classId][msg.sender] -= shareAmount;
        sc.totalSupply -= shareAmount;

        // Interactions: send payment after state is committed.
        bool ok = paymentToken.transfer(msg.sender, payout);
        if (!ok) revert TransferFailed();

        emit SharesRedeemed(classId, msg.sender, shareAmount, payout);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------
    function shareClass(uint256 classId)
        external
        view
        validClass(classId)
        returns (
            string memory name,
            uint256 nominalValue,
            bool transferRestricted,
            bool buybackActive,
            uint256 buybackPrice,
            uint256 totalSupply
        )
    {
        ShareClass storage sc = _shareClasses[classId];
        return (
            sc.name,
            sc.nominalValue,
            sc.transferRestricted,
            sc.buybackActive,
            sc.buybackPrice,
            sc.totalSupply
        );
    }

    function balanceOf(uint256 classId, address holder) external view validClass(classId) returns (uint256) {
        return _balances[classId][holder];
    }

    function isApprovedHolder(uint256 classId, address holder) external view validClass(classId) returns (bool) {
        return _approvedHolders[classId][holder];
    }
}
