// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FractionalRealEstate {
    ////////////////////////////////////////////////////////////////
    //                            ERRORS                            //
    ////////////////////////////////////////////////////////////////
    error NotAuthorized();
    error ZeroAddress();
    error PropertyNotFound();
    error PropertyNotActive();
    error PropertyNotReady();
    error InsufficientUnitsAvailable();
    error InsufficientBalance();
    error InvalidAmount();
    error IncorrectPayment();
    error InsufficientContractBalance();
    error TransferFailed();
    error DuplicateProperty();
    error NameRequired();
    error TotalUnitsTooLow();
    error Reentrancy();

    ////////////////////////////////////////////////////////////////
    //                            EVENTS                           //
    ////////////////////////////////////////////////////////////////
    event PropertyAdded(
        uint256 indexed propertyId,
        string name,
        uint256 totalUnits,
        uint256 purchasePricePerUnit,
        uint256 salePricePerUnit
    );
    event PropertyConfigured(
        uint256 indexed propertyId,
        uint256 totalUnits,
        uint256 purchasePricePerUnit,
        uint256 salePricePerUnit
    );
    event PriceUpdated(
        uint256 indexed propertyId,
        uint256 newPurchasePrice,
        uint256 newSalePrice
    );
    event UnitsPurchased(
        uint256 indexed propertyId,
        address indexed buyer,
        uint256 amount,
        uint256 pricePaid,
        uint256 feePaid
    );
    event UnitsSold(
        uint256 indexed propertyId,
        address indexed seller,
        uint256 amount,
        uint256 payout,
        uint256 feePaid
    );
    event UnitsTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 feeUnits
    );
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyWithdraw(address indexed by, uint256 amount);

    ////////////////////////////////////////////////////////////////
    //                            CONSTANTS                        //
    ////////////////////////////////////////////////////////////////
    uint256 public constant FEE_BPS = 100; // 1% = 100 basis points out of 10000
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_UNITS_TO_PURCHASE = 100;

    ////////////////////////////////////////////////////////////////
    //                            STRUCTS                          //
    ////////////////////////////////////////////////////////////////
    struct Property {
        string name;
        uint256 totalUnits;
        uint256 purchasePricePerUnit;
        uint256 salePricePerUnit;
        uint256 soldUnits;
        bool active;
        bool exists;
    }

    ////////////////////////////////////////////////////////////////
    //                          STATE VARIABLES                    //
    ////////////////////////////////////////////////////////////////
    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public propertyCount;
    mapping(uint256 => Property) internal properties;
    mapping(uint256 => mapping(address => uint256)) public unitBalances; // propertyId => owner => balance
    mapping(bytes32 => bool) internal usedNameHashes;

    uint256 internal _locked = 1;

    ////////////////////////////////////////////////////////////////
    //                            MODIFIERS                        //
    ////////////////////////////////////////////////////////////////
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier validProperty(uint256 propertyId) {
        if (propertyId == 0 || propertyId > propertyCount || !properties[propertyId].exists)
            revert PropertyNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    ////////////////////////////////////////////////////////////////
    //                           CONSTRUCTOR                       //
    ////////////////////////////////////////////////////////////////
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    ////////////////////////////////////////////////////////////////
    //                  ADMINISTRATION FUNCTIONS                  //
    ////////////////////////////////////////////////////////////////
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert InsufficientContractBalance();
        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit EmergencyWithdraw(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                  OPERATOR: PROPERTY MANAGEMENT             //
    ////////////////////////////////////////////////////////////////
    function addProperty(
        string calldata name,
        uint256 totalUnits,
        uint256 purchasePricePerUnit,
        uint256 salePricePerUnit
    ) external onlyOperator returns (uint256 propertyId) {
        if (bytes(name).length == 0) revert NameRequired();
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (usedNameHashes[nameHash]) revert DuplicateProperty();
        usedNameHashes[nameHash] = true;

        if (totalUnits < MIN_UNITS_TO_PURCHASE) revert TotalUnitsTooLow();

        propertyCount += 1;
        propertyId = propertyCount;
        properties[propertyId] = Property({
            name: name,
            totalUnits: totalUnits,
            purchasePricePerUnit: purchasePricePerUnit,
            salePricePerUnit: salePricePerUnit,
            soldUnits: 0,
            active: true,
            exists: true
        });

        emit PropertyAdded(propertyId, name, totalUnits, purchasePricePerUnit, salePricePerUnit);
    }

    function setPropertyUnits(uint256 propertyId, uint256 totalUnits)
        external
        onlyOperator
        validProperty(propertyId)
    {
        Property storage prop = properties[propertyId];
        if (totalUnits < prop.soldUnits) revert InsufficientUnitsAvailable();
        prop.totalUnits = totalUnits;
        if (totalUnits < MIN_UNITS_TO_PURCHASE) {
            prop.active = false;
        }
        emit PropertyConfigured(propertyId, totalUnits, prop.purchasePricePerUnit, prop.salePricePerUnit);
    }

    function setPrices(
        uint256 propertyId,
        uint256 purchasePricePerUnit,
        uint256 salePricePerUnit
    ) external onlyOperator validProperty(propertyId) {
        Property storage prop = properties[propertyId];
        prop.purchasePricePerUnit = purchasePricePerUnit;
        prop.salePricePerUnit = salePricePerUnit;
        emit PriceUpdated(propertyId, purchasePricePerUnit, salePricePerUnit);
    }

    function setPropertyActive(uint256 propertyId, bool active)
        external
        onlyOperator
        validProperty(propertyId)
    {
        Property storage prop = properties[propertyId];
        if (active) {
            if (prop.totalUnits < MIN_UNITS_TO_PURCHASE) revert PropertyNotReady();
            if (prop.purchasePricePerUnit == 0 || prop.salePricePerUnit == 0) revert PropertyNotReady();
        }
        prop.active = active;
    }

    ////////////////////////////////////////////////////////////////
    //                    USER: PURCHASE UNITS                     //
    ////////////////////////////////////////////////////////////////
    function purchaseUnits(uint256 propertyId, uint256 amount)
        external
        payable
        nonReentrant
        validProperty(propertyId)
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();

        Property storage prop = properties[propertyId];
        if (!prop.active) revert PropertyNotActive();
        if (prop.totalUnits < MIN_UNITS_TO_PURCHASE) revert PropertyNotReady();
        if (prop.soldUnits + amount > prop.totalUnits) revert InsufficientUnitsAvailable();

        uint256 subtotal = prop.purchasePricePerUnit * amount;
        uint256 fee = (subtotal * FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalDue = subtotal + fee;

        if (msg.value < totalDue) revert IncorrectPayment();

        // effects
        prop.soldUnits += amount;
        unitBalances[propertyId][msg.sender] += amount;

        // refund excess
        if (msg.value > totalDue) {
            uint256 refund = msg.value - totalDue;
            (bool refundOk, ) = payable(msg.sender).call{value: refund}("");
            if (!refundOk) revert TransferFailed();
        }

        emit UnitsPurchased(propertyId, msg.sender, amount, subtotal, fee);
        emit UnitsTransferred(propertyId, address(0), msg.sender, amount, 0);
        return amount;
    }

    ////////////////////////////////////////////////////////////////
    //                    USER: TRANSFER UNITS                     //
    ////////////////////////////////////////////////////////////////
    function transferUnits(uint256 propertyId, address to, uint256 amount)
        external
        validProperty(propertyId)
        returns (uint256)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 senderBalance = unitBalances[propertyId][msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        // 1% fee on transfers, taken in units from sender
        uint256 feeUnits = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 toReceive = amount - feeUnits;

        // effects
        unitBalances[propertyId][msg.sender] = senderBalance - amount;
        unitBalances[propertyId][to] += toReceive;
        if (feeUnits > 0) {
            unitBalances[propertyId][feeRecipient] += feeUnits;
            emit UnitsTransferred(propertyId, msg.sender, feeRecipient, feeUnits, feeUnits);
        }

        emit UnitsTransferred(propertyId, msg.sender, to, toReceive, feeUnits);
        return toReceive;
    }

    ////////////////////////////////////////////////////////////////
    //                    USER: SELL UNITS BACK                   //
    ////////////////////////////////////////////////////////////////
    function sellUnitsBack(uint256 propertyId, uint256 amount)
        external
        nonReentrant
        validProperty(propertyId)
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();

        Property storage prop = properties[propertyId];
        if (!prop.active) revert PropertyNotActive();

        uint256 sellerBalance = unitBalances[propertyId][msg.sender];
        if (sellerBalance < amount) revert InsufficientBalance();

        uint256 subtotal = prop.salePricePerUnit * amount;
        uint256 fee = (subtotal * FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = subtotal - fee;

        if (address(this).balance < payout) revert InsufficientContractBalance();

        // effects
        unitBalances[propertyId][msg.sender] = sellerBalance - amount;
        prop.soldUnits -= amount;

        // interactions
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();

        if (fee > 0) {
            (bool feeOk, ) = payable(feeRecipient).call{value: fee}("");
            if (!feeOk) revert TransferFailed();
        }

        emit UnitsSold(propertyId, msg.sender, amount, payout, fee);
        emit UnitsTransferred(propertyId, msg.sender, address(0), amount, 0);
        return payout;
    }

    ////////////////////////////////////////////////////////////////
    //                       VIEW FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////
    function getProperty(uint256 propertyId)
        external
        view
        validProperty(propertyId)
        returns (
            string memory name,
            uint256 totalUnits,
            uint256 purchasePricePerUnit,
            uint256 salePricePerUnit,
            uint256 soldUnits,
            uint256 availableUnits,
            bool active
        )
    {
        Property storage prop = properties[propertyId];
        return (
            prop.name,
            prop.totalUnits,
            prop.purchasePricePerUnit,
            prop.salePricePerUnit,
            prop.soldUnits,
            prop.totalUnits - prop.soldUnits,
            prop.active
        );
    }

    function balanceOf(uint256 propertyId, address account)
        external
        view
        validProperty(propertyId)
        returns (uint256)
    {
        return unitBalances[propertyId][account];
    }

    function quotePurchase(uint256 propertyId, uint256 amount)
        external
        view
        validProperty(propertyId)
        returns (uint256 subtotal, uint256 fee, uint256 total)
    {
        Property storage prop = properties[propertyId];
        subtotal = prop.purchasePricePerUnit * amount;
        fee = (subtotal * FEE_BPS) / BPS_DENOMINATOR;
        total = subtotal + fee;
    }

    function quoteSale(uint256 propertyId, uint256 amount)
        external
        view
        validProperty(propertyId)
        returns (uint256 subtotal, uint256 fee, uint256 payout)
    {
        Property storage prop = properties[propertyId];
        subtotal = prop.salePricePerUnit * amount;
        fee = (subtotal * FEE_BPS) / BPS_DENOMINATOR;
        payout = subtotal - fee;
    }

    function isPropertyNameUsed(string calldata name) external view returns (bool) {
        return usedNameHashes[keccak256(abi.encodePacked(name))];
    }

    ////////////////////////////////////////////////////////////////
    //                       RECEIVE ETHER                         //
    ////////////////////////////////////////////////////////////////
    receive() external payable {}
}
