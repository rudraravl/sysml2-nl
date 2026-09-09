// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Receiver {
    function onFractionalReceived(
        address operator,
        address from,
        uint256 propertyId,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4);
}

contract TokenizedRealEstate {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOperator();
    error PropertyNotFound();
    error PropertyNotActive();
    error PropertyAlreadyLiquidated();
    error ExceedsMaxSupply();
    error InsufficientBalance();
    error InsufficientPayment();
    error ZeroAmount();
    error ZeroAddress();
    error SupplyAlreadySet();
    error NotLiquidatable();
    error NothingToRedeem();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PropertyListed(uint256 indexed propertyId, string metadataURI, uint256 maxSupply, uint256 pricePerToken);
    event SupplySet(uint256 indexed propertyId, uint256 totalSupply);
    event TokensPurchased(uint256 indexed propertyId, address indexed buyer, uint256 amount, uint256 payment);
    event TokensTransferred(uint256 indexed propertyId, address indexed from, address indexed to, uint256 amount, uint256 fee);
    event PropertyLiquidated(uint256 indexed propertyId, uint256 redemptionPool, uint256 timestamp);
    event TokensRedeemed(uint256 indexed propertyId, address indexed holder, uint256 amount, uint256 payout);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event MetadataUpdated(uint256 indexed propertyId, string metadataURI);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_SUPPLY_PER_PROPERTY = 1_000_000;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Property {
        uint256 id;
        string metadataURI;
        uint256 totalSupply;
        uint256 maxSupply;
        uint256 pricePerToken;
        bool supplySet;
        bool active;
        bool liquidated;
        uint256 liquidationPool;
        uint256 redeemedSupply;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARS
    //////////////////////////////////////////////////////////////*/
    address public operator;
    uint256 public nextPropertyId;
    uint256 public accumulatedFees;

    mapping(uint256 => Property) internal _properties;
    mapping(uint256 => mapping(address => uint256)) internal _balances;
    uint256[] internal _propertyIds;
    mapping(uint256 => address[]) internal _holders;
    mapping(uint256 => mapping(address => bool)) internal _isHolder;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        if (_properties[propertyId].id == 0) revert PropertyNotFound();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address initialOperator) {
        if (initialOperator == address(0)) revert ZeroAddress();
        operator = initialOperator;
        nextPropertyId = 1;
        emit OperatorUpdated(address(0), initialOperator);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function listProperty(
        string calldata metadataURI,
        uint256 maxSupply,
        uint256 pricePerToken
    ) external onlyOperator returns (uint256 propertyId) {
        if (maxSupply == 0 || maxSupply > MAX_SUPPLY_PER_PROPERTY) revert ExceedsMaxSupply();
        if (pricePerToken == 0) revert ZeroAmount();

        propertyId = nextPropertyId++;
        Property storage p = _properties[propertyId];
        p.id = propertyId;
        p.metadataURI = metadataURI;
        p.maxSupply = maxSupply;
        p.pricePerToken = pricePerToken;
        p.active = true;
        p.supplySet = false;

        _propertyIds.push(propertyId);

        emit PropertyListed(propertyId, metadataURI, maxSupply, pricePerToken);
    }

    function setSupply(uint256 propertyId, uint256 totalSupply) external onlyOperator propertyExists(propertyId) {
        Property storage p = _properties[propertyId];
        if (p.liquidated) revert PropertyAlreadyLiquidated();
        if (p.supplySet) revert SupplyAlreadySet();
        if (totalSupply == 0 || totalSupply > p.maxSupply) revert ExceedsMaxSupply();

        p.totalSupply = totalSupply;
        p.supplySet = true;

        emit SupplySet(propertyId, totalSupply);
    }

    function updateMetadata(uint256 propertyId, string calldata metadataURI) external onlyOperator propertyExists(propertyId) {
        Property storage p = _properties[propertyId];
        if (p.liquidated) revert PropertyAlreadyLiquidated();
        p.metadataURI = metadataURI;
        emit MetadataUpdated(propertyId, metadataURI);
    }

    function liquidateProperty(uint256 propertyId) external payable onlyOperator propertyExists(propertyId) {
        Property storage p = _properties[propertyId];
        if (p.liquidated) revert PropertyAlreadyLiquidated();
        if (!p.supplySet) revert NotLiquidatable();

        p.liquidated = true;
        p.active = false;
        p.liquidationPool += msg.value;

        emit PropertyLiquidated(propertyId, p.liquidationPool, block.timestamp);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function withdrawFees(address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeeWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          PURCHASE LOGIC
    //////////////////////////////////////////////////////////////*/
    function purchaseTokens(uint256 propertyId, uint256 amount) external payable propertyExists(propertyId) {
        Property storage p = _properties[propertyId];
        if (!p.active) revert PropertyNotActive();
        if (p.liquidated) revert PropertyAlreadyLiquidated();
        if (!p.supplySet) revert SupplyAlreadySet();
        if (amount == 0) revert ZeroAmount();

        uint256 newTotal = p.totalSupply + amount;
        if (newTotal > p.maxSupply) revert ExceedsMaxSupply();

        uint256 cost = amount * p.pricePerToken;
        if (msg.value < cost) revert InsufficientPayment();

        p.totalSupply = newTotal;

        _balances[propertyId][msg.sender] += amount;
        _addHolder(propertyId, msg.sender);

        if (msg.value > cost) {
            uint256 refund = msg.value - cost;
            (bool ok, ) = msg.sender.call{value: refund}("");
            if (!ok) revert TransferFailed();
        }

        emit TokensPurchased(propertyId, msg.sender, amount, cost);
        emit TokensTransferred(propertyId, address(0), msg.sender, amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferTokens(uint256 propertyId, address to, uint256 amount) public propertyExists(propertyId) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        Property storage p = _properties[propertyId];
        if (p.liquidated) revert PropertyAlreadyLiquidated();

        uint256 senderBalance = _balances[propertyId][msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        _balances[propertyId][msg.sender] = senderBalance - amount;
        _balances[propertyId][to] += netAmount;

        if (fee > 0) {
            _balances[propertyId][operator] += fee;
            _addHolder(propertyId, operator);
        }

        _addHolder(propertyId, to);

        emit TokensTransferred(propertyId, msg.sender, to, netAmount, fee);
        if (fee > 0) {
            emit TokensTransferred(propertyId, msg.sender, operator, fee, 0);
        }
    }

    function safeTransferTokens(
        uint256 propertyId,
        address to,
        uint256 amount,
        bytes calldata data
    ) external propertyExists(propertyId) {
        transferTokens(propertyId, to, amount);
        if (to.code.length > 0) {
            try IERC20Receiver(to).onFractionalReceived(msg.sender, msg.sender, propertyId, amount, data) returns (bytes4 retval) {
                if (retval != IERC20Receiver.onFractionalReceived.selector) revert TransferFailed();
            } catch {
                revert TransferFailed();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function redeemTokens(uint256 propertyId, uint256 amount) external propertyExists(propertyId) {
        Property storage p = _properties[propertyId];
        if (!p.liquidated) revert NotLiquidatable();
        if (amount == 0) revert ZeroAmount();

        uint256 holderBalance = _balances[propertyId][msg.sender];
        if (holderBalance < amount) revert InsufficientBalance();

        uint256 unredeemed = p.totalSupply - p.redeemedSupply;
        if (unredeemed == 0) revert NothingToRedeem();

        uint256 payout = (p.liquidationPool * amount) / unredeemed;

        _balances[propertyId][msg.sender] = holderBalance - amount;
        p.redeemedSupply += amount;
        p.liquidationPool -= payout;

        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();

        emit TokensRedeemed(propertyId, msg.sender, amount, payout);
        emit TokensTransferred(propertyId, msg.sender, address(0), amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getProperty(uint256 propertyId) external view propertyExists(propertyId) returns (
        string memory metadataURI,
        uint256 totalSupply,
        uint256 maxSupply,
        uint256 pricePerToken,
        bool active,
        bool liquidated,
        uint256 liquidationPool,
        uint256 redeemedSupply
    ) {
        Property storage p = _properties[propertyId];
        return (
            p.metadataURI,
            p.totalSupply,
            p.maxSupply,
            p.pricePerToken,
            p.active,
            p.liquidated,
            p.liquidationPool,
            p.redeemedSupply
        );
    }

    function balanceOf(uint256 propertyId, address account) external view propertyExists(propertyId) returns (uint256) {
        return _balances[propertyId][account];
    }

    function totalSupplyOf(uint256 propertyId) external view propertyExists(propertyId) returns (uint256) {
        return _properties[propertyId].totalSupply;
    }

    function allPropertyIds() external view returns (uint256[] memory) {
        return _propertyIds;
    }

    function getHolders(uint256 propertyId) external view propertyExists(propertyId) returns (address[] memory) {
        return _holders[propertyId];
    }

    function isHolder(uint256 propertyId, address account) external view propertyExists(propertyId) returns (bool) {
        return _isHolder[propertyId][account];
    }

    function propertyCount() external view returns (uint256) {
        return _propertyIds.length;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _addHolder(uint256 propertyId, address account) internal {
        if (!_isHolder[propertyId][account]) {
            _isHolder[propertyId][account] = true;
            _holders[propertyId].push(account);
        }
    }

    receive() external payable {
        accumulatedFees += msg.value;
    }
}
