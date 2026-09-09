// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VirtualLandRegistry {
    // ---------------- Custom Errors ----------------
    error NotAdmin();
    error NotOperator();
    error NotAuthorized();
    error ZeroAddress();
    error PlotNotFound(uint256 plotId);
    error PlotNotForSale(uint256 plotId);
    error PlotAlreadyOwned(uint256 plotId);
    error InsufficientPayment(uint256 required, uint256 provided);
    error MaxPlotsExceeded(address account, uint256 current);
    error InvalidRoyaltyRate(uint256 rate);
    error DuplicateCoordinates(uint256 x, uint256 y);
    error SelfTransfer();
    error TransferFailed();

    // ---------------- Constants ----------------
    string public constant name = "Virtual Land";
    string public constant symbol = "VLAND";
    uint256 public constant MAX_PLOTS_PER_ACCOUNT = 100;
    uint256 public constant ROYALTY_DENOMINATOR = 10000;

    // ---------------- Structs ----------------
    struct LandPlot {
        uint256 x;
        uint256 y;
        string metadataURI;
        uint256 price;
        bool forSale;
        bool exists;
    }

    // ---------------- State Variables ----------------
    address public admin;
    address public treasury;
    uint256 public royaltyBps; // 200 = 2%
    uint256 public globalSaleActive; // 1 = active, 0 = inactive
    uint256 public nextPlotId;
    uint256 public totalMinted;

    mapping(uint256 => LandPlot) internal _plots;
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) internal _approved;
    mapping(address => mapping(address => bool)) internal _isApprovedForAll;
    mapping(address => bool) public isOperator;
    mapping(uint256 => bool) internal _secondaryListed;
    mapping(uint256 => uint256) internal _secondaryPrice;
    mapping(bytes32 => bool) internal _coordsUsed;
    bool internal _locked;

    // ---------------- Events ----------------
    event PlotPurchased(uint256 indexed plotId, address indexed buyer, uint256 price);
    event Transfer(address indexed from, address indexed to, uint256 indexed plotId);
    event MetadataUpdated(uint256 indexed plotId, string metadataURI);
    event PlotListed(uint256 indexed plotId, uint256 x, uint256 y, uint256 price, bool forSale);
    event PlotPriceUpdated(uint256 indexed plotId, uint256 price);
    event PlotListedForSecondarySale(uint256 indexed plotId, address indexed owner, uint256 price);
    event PlotDelistedFromSecondarySale(uint256 indexed plotId, address indexed owner);
    event Approval(address indexed owner, address indexed approved, uint256 indexed plotId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event RoyaltyPaid(uint256 indexed plotId, address treasury, uint256 amount);
    event SaleConfigUpdated(uint256 royaltyBps, address treasury, bool active);
    event OperatorUpdated(address indexed operator, bool status);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    // ---------------- Modifiers ----------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    modifier plotExists(uint256 plotId) {
        if (!_plots[plotId].exists) revert PlotNotFound(plotId);
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert NotAuthorized();
        _locked = true;
        _;
        _locked = false;
    }

    // ---------------- Constructor ----------------
    constructor(address _treasury, uint256 _royaltyBps) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_royaltyBps > 1000) revert InvalidRoyaltyRate(_royaltyBps);
        admin = msg.sender;
        treasury = _treasury;
        royaltyBps = _royaltyBps;
        globalSaleActive = 1;
        nextPlotId = 1;
        isOperator[msg.sender] = true;
        emit OperatorUpdated(msg.sender, true);
        emit SaleConfigUpdated(royaltyBps, treasury, true);
    }

    // ---------------- Admin Functions ----------------
    function setOperator(address operator, bool status) external onlyAdmin {
        if (operator == address(0)) revert ZeroAddress();
        isOperator[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    function updateSaleConfig(uint256 _royaltyBps, address _treasury, bool active) external onlyAdmin {
        if (_royaltyBps > 1000) revert InvalidRoyaltyRate(_royaltyBps);
        if (_treasury == address(0)) revert ZeroAddress();
        royaltyBps = _royaltyBps;
        treasury = _treasury;
        globalSaleActive = active ? 1 : 0;
        emit SaleConfigUpdated(royaltyBps, treasury, active);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    // ---------------- Operator: Listing & Pricing ----------------
    function listPlot(
        uint256 x,
        uint256 y,
        string calldata metadataURI,
        uint256 price,
        bool forSale
    ) external onlyOperator returns (uint256 plotId) {
        bytes32 coordKey = _coordKey(x, y);
        if (_coordsUsed[coordKey]) revert DuplicateCoordinates(x, y);
        _coordsUsed[coordKey] = true;

        plotId = nextPlotId++;
        _plots[plotId] = LandPlot({
            x: x,
            y: y,
            metadataURI: metadataURI,
            price: price,
            forSale: forSale,
            exists: true
        });

        emit PlotListed(plotId, x, y, price, forSale);
    }

    function setPlotPrice(uint256 plotId, uint256 price) external onlyOperator plotExists(plotId) {
        if (_ownerOf[plotId] != address(0)) revert PlotAlreadyOwned(plotId);
        _plots[plotId].price = price;
        emit PlotPriceUpdated(plotId, price);
    }

    function setPlotForSale(uint256 plotId, bool forSale) external onlyOperator plotExists(plotId) {
        if (_ownerOf[plotId] != address(0)) revert PlotAlreadyOwned(plotId);
        _plots[plotId].forSale = forSale;
        emit PlotListed(plotId, _plots[plotId].x, _plots[plotId].y, _plots[plotId].price, forSale);
    }

    // ---------------- Primary Purchase ----------------
    function purchasePlot(uint256 plotId) external payable nonReentrant plotExists(plotId) {
        if (globalSaleActive == 0) revert PlotNotForSale(plotId);
        LandPlot storage plot = _plots[plotId];
        if (!plot.forSale) revert PlotNotForSale(plotId);
        if (_ownerOf[plotId] != address(0)) revert PlotAlreadyOwned(plotId);
        if (msg.value < plot.price) revert InsufficientPayment(plot.price, msg.value);
        if (_balanceOf[msg.sender] >= MAX_PLOTS_PER_ACCOUNT)
            revert MaxPlotsExceeded(msg.sender, _balanceOf[msg.sender]);

        // Effects
        _ownerOf[plotId] = msg.sender;
        _balanceOf[msg.sender]++;
        plot.forSale = false;
        totalMinted++;

        // Interactions
        _safeTransferETH(treasury, plot.price);
        if (msg.value > plot.price) {
            _safeTransferETH(msg.sender, msg.value - plot.price);
        }

        emit PlotPurchased(plotId, msg.sender, plot.price);
        emit Transfer(address(0), msg.sender, plotId);
    }

    // ---------------- Secondary Market ----------------
    function listForSecondarySale(uint256 plotId, uint256 salePrice) external plotExists(plotId) {
        if (_ownerOf[plotId] != msg.sender) revert NotAuthorized();
        _secondaryListed[plotId] = true;
        _secondaryPrice[plotId] = salePrice;
        emit PlotListedForSecondarySale(plotId, msg.sender, salePrice);
    }

    function delistSecondarySale(uint256 plotId) external plotExists(plotId) {
        if (_ownerOf[plotId] != msg.sender) revert NotAuthorized();
        _secondaryListed[plotId] = false;
        _secondaryPrice[plotId] = 0;
        emit PlotDelistedFromSecondarySale(plotId, msg.sender);
    }

    function buyPlot(uint256 plotId) external payable nonReentrant plotExists(plotId) {
        if (!_secondaryListed[plotId]) revert PlotNotForSale(plotId);
        address seller = _ownerOf[plotId];
        if (seller == address(0)) revert PlotNotFound(plotId);
        if (seller == msg.sender) revert SelfTransfer();

        uint256 salePrice = _secondaryPrice[plotId];
        if (msg.value < salePrice) revert InsufficientPayment(salePrice, msg.value);
        if (_balanceOf[msg.sender] >= MAX_PLOTS_PER_ACCOUNT)
            revert MaxPlotsExceeded(msg.sender, _balanceOf[msg.sender]);

        uint256 royalty = (salePrice * royaltyBps) / ROYALTY_DENOMINATOR;
        uint256 sellerProceeds = salePrice - royalty;

        // Effects
        _balanceOf[seller]--;
        _balanceOf[msg.sender]++;
        _ownerOf[plotId] = msg.sender;
        delete _approved[plotId];
        _secondaryListed[plotId] = false;
        _secondaryPrice[plotId] = 0;

        // Interactions
        if (royalty > 0) {
            _safeTransferETH(treasury, royalty);
        }
        if (sellerProceeds > 0) {
            _safeTransferETH(seller, sellerProceeds);
        }
        if (msg.value > salePrice) {
            _safeTransferETH(msg.sender, msg.value - salePrice);
        }

        emit RoyaltyPaid(plotId, treasury, royalty);
        emit PlotPurchased(plotId, msg.sender, salePrice);
        emit Transfer(seller, msg.sender, plotId);
    }

    // ---------------- Direct Transfer ----------------
    function transferPlot(uint256 plotId, address to) external plotExists(plotId) {
        if (_ownerOf[plotId] != msg.sender) revert NotAuthorized();
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert SelfTransfer();
        if (_balanceOf[to] >= MAX_PLOTS_PER_ACCOUNT)
            revert MaxPlotsExceeded(to, _balanceOf[to]);

        _balanceOf[msg.sender]--;
        _balanceOf[to]++;
        _ownerOf[plotId] = to;
        delete _approved[plotId];
        _secondaryListed[plotId] = false;
        _secondaryPrice[plotId] = 0;

        emit Transfer(msg.sender, to, plotId);
    }

    // ---------------- Approvals ----------------
    function approve(address to, uint256 plotId) external plotExists(plotId) {
        if (_ownerOf[plotId] != msg.sender) revert NotAuthorized();
        _approved[plotId] = to;
        emit Approval(msg.sender, to, plotId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == address(0)) revert ZeroAddress();
        _isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 plotId) external plotExists(plotId) {
        address owner = _ownerOf[plotId];
        if (owner != from) revert NotAuthorized();
        if (to == address(0)) revert ZeroAddress();
        if (from == to) revert SelfTransfer();

        bool authorized = (msg.sender == owner) ||
            _isApprovedForAll[owner][msg.sender] ||
            _approved[plotId] == msg.sender;
        if (!authorized) revert NotAuthorized();

        if (_balanceOf[to] >= MAX_PLOTS_PER_ACCOUNT)
            revert MaxPlotsExceeded(to, _balanceOf[to]);

        _balanceOf[from]--;
        _balanceOf[to]++;
        _ownerOf[plotId] = to;
        delete _approved[plotId];
        _secondaryListed[plotId] = false;
        _secondaryPrice[plotId] = 0;

        emit Transfer(from, to, plotId);
    }

    // ---------------- Metadata ----------------
    function updateMetadata(uint256 plotId, string calldata metadataURI) external plotExists(plotId) {
        address owner = _ownerOf[plotId];
        if (owner != msg.sender && !isOperator[msg.sender]) revert NotAuthorized();
        _plots[plotId].metadataURI = metadataURI;
        emit MetadataUpdated(plotId, metadataURI);
    }

    // ---------------- Views ----------------
    function ownerOf(uint256 plotId) external view plotExists(plotId) returns (address) {
        return _ownerOf[plotId];
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf[account];
    }

    function getPlot(uint256 plotId)
        external
        view
        plotExists(plotId)
        returns (
            uint256 x,
            uint256 y,
            string memory metadataURI,
            uint256 price,
            bool forSale,
            address owner
        )
    {
        LandPlot storage plot = _plots[plotId];
        return (plot.x, plot.y, plot.metadataURI, plot.price, plot.forSale, _ownerOf[plotId]);
    }

    function getApproved(uint256 plotId) external view plotExists(plotId) returns (address) {
        return _approved[plotId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _isApprovedForAll[owner][operator];
    }

    function isSecondaryListed(uint256 plotId) external view returns (bool) {
        return _secondaryListed[plotId];
    }

    function getSecondaryPrice(uint256 plotId) external view returns (uint256) {
        return _secondaryPrice[plotId];
    }

    function totalSupply() external view returns (uint256) {
        return totalMinted;
    }

    // ---------------- Internal Helpers ----------------
    function _coordKey(uint256 x, uint256 y) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(x, y));
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
