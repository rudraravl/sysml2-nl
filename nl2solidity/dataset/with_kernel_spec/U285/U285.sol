// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721Minimal {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract WrappedTokenBasket {
    enum AssetType { None, ERC20, ERC721 }

    struct CollateralAsset {
        address token;
        AssetType assetType;
        uint256 amount;       // used when assetType == ERC20
        uint256[] tokenIds;   // used when assetType == ERC721
    }

    struct WrappedToken {
        address owner;
        uint256 totalValue;
        CollateralAsset[] collateral;
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event WrappedTokenCreated(uint256 indexed wrappedId, address indexed owner, uint256 totalValue, uint256 fee);
    event WrappedTokenTransferred(uint256 indexed wrappedId, address indexed from, address indexed to);
    event WrappedTokenRedeemed(uint256 indexed wrappedId, address indexed owner);
    event CollateralTypeSet(address indexed token, AssetType assetType, uint256 pricePerUnit);
    event CollateralTypeRemoved(address indexed token);
    event FeeRateUpdated(uint256 oldRateBps, uint256 newRateBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error ZeroAddress();
    error EmptyCollateral();
    error CollateralNotSupported(address token);
    error AssetTypeMismatch(address token, AssetType expected, AssetType provided);
    error ZeroAmount();
    error EmptyTokenIds();
    error TokenDoesNotExist(uint256 wrappedId);
    error NotTokenOwner(uint256 wrappedId, address caller);
    error FeeRateTooHigh(uint256 provided, uint256 max);
    error TransferFailed(address token);
    error ReentrantCall();

    /*//////////////////////////////////////////////////////////////
                          CONFIG STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_FEE_BPS = 50; // 0.5%

    address public operator;
    IERC20Minimal public immutable feeToken;
    uint256 public feeRateBps;

    mapping(address => AssetType) public collateralTypeOf;
    mapping(address => uint256) public collateralPricePerUnit; // price per unit, denominated in feeToken

    /*//////////////////////////////////////////////////////////////
                       WRAPPED TOKEN STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => WrappedToken) private _wrappedTokens;
    mapping(address => uint256) public balanceOf;
    uint256 public nextWrappedId = 1;
    uint256 public totalWrappedSupply;

    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator, address _feeToken) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeToken == address(0)) revert ZeroAddress();
        operator = _operator;
        feeToken = IERC20Minimal(_feeToken);
        feeRateBps = MAX_FEE_BPS;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRateUpdated(0, MAX_FEE_BPS);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR ADMIN
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRate(uint256 rateBps) external onlyOperator {
        if (rateBps > MAX_FEE_BPS) revert FeeRateTooHigh(rateBps, MAX_FEE_BPS);
        emit FeeRateUpdated(feeRateBps, rateBps);
        feeRateBps = rateBps;
    }

    function addCollateralType(address token, AssetType assetType, uint256 pricePerUnit) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (assetType == AssetType.None) revert CollateralNotSupported(token);
        collateralTypeOf[token] = assetType;
        collateralPricePerUnit[token] = pricePerUnit;
        emit CollateralTypeSet(token, assetType, pricePerUnit);
    }

    function removeCollateralType(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        collateralTypeOf[token] = AssetType.None;
        collateralPricePerUnit[token] = 0;
        emit CollateralTypeRemoved(token);
    }

    /*//////////////////////////////////////////////////////////////
                       WRAPPED TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function createWrappedToken(CollateralAsset[] calldata assets) external nonReentrant returns (uint256 wrappedId) {
        uint256 len = assets.length;
        if (len == 0) revert EmptyCollateral();

        uint256 totalValue = 0;
        for (uint256 i = 0; i < len; i++) {
            address token = assets[i].token;
            AssetType supported = collateralTypeOf[token];
            if (supported == AssetType.None) revert CollateralNotSupported(token);
            if (supported != assets[i].assetType) revert AssetTypeMismatch(token, supported, assets[i].assetType);

            uint256 price = collateralPricePerUnit[token];
            if (assets[i].assetType == AssetType.ERC20) {
                if (assets[i].amount == 0) revert ZeroAmount();
                totalValue += assets[i].amount * price;
            } else {
                if (assets[i].tokenIds.length == 0) revert EmptyTokenIds();
                totalValue += assets[i].tokenIds.length * price;
            }
        }

        uint256 fee = (totalValue * feeRateBps) / 10000;

        // Effects: record all state before any external calls
        wrappedId = nextWrappedId++;
        WrappedToken storage wt = _wrappedTokens[wrappedId];
        wt.owner = msg.sender;
        wt.totalValue = totalValue;
        wt.exists = true;

        unchecked {
            balanceOf[msg.sender] += 1;
            totalWrappedSupply += 1;
        }

        for (uint256 i = 0; i < len; i++) {
            wt.collateral.push(CollateralAsset({
                token: assets[i].token,
                assetType: assets[i].assetType,
                amount: assets[i].amount,
                tokenIds: assets[i].tokenIds
            }));
        }

        // Interactions: pull collateral from caller
        for (uint256 i = 0; i < len; i++) {
            address token = assets[i].token;
            AssetType at = assets[i].assetType;

            if (at == AssetType.ERC20) {
                bool ok = IERC20Minimal(token).transferFrom(msg.sender, address(this), assets[i].amount);
                if (!ok) revert TransferFailed(token);
            } else {
                uint256[] calldata ids = assets[i].tokenIds;
                for (uint256 j = 0; j < ids.length; j++) {
                    IERC721Minimal(token).transferFrom(msg.sender, address(this), ids[j]);
                }
            }
        }

        if (fee > 0) {
            bool ok = feeToken.transferFrom(msg.sender, operator, fee);
            if (!ok) revert TransferFailed(address(feeToken));
        }

        emit WrappedTokenCreated(wrappedId, msg.sender, totalValue, fee);
    }

    function transferWrappedToken(uint256 wrappedId, address to) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        WrappedToken storage wt = _wrappedTokens[wrappedId];
        if (!wt.exists) revert TokenDoesNotExist(wrappedId);
        if (wt.owner != msg.sender) revert NotTokenOwner(wrappedId, msg.sender);

        address from = wt.owner;
        wt.owner = to;
        unchecked {
            balanceOf[from] -= 1;
            balanceOf[to] += 1;
        }

        emit WrappedTokenTransferred(wrappedId, from, to);
    }

    function redeemWrappedToken(uint256 wrappedId) external nonReentrant {
        WrappedToken storage wt = _wrappedTokens[wrappedId];
        if (!wt.exists) revert TokenDoesNotExist(wrappedId);
        if (wt.owner != msg.sender) revert NotTokenOwner(wrappedId, msg.sender);

        address owner = wt.owner;
        uint256 collateralLen = wt.collateral.length;

        // Copy collateral data to memory before clearing storage
        address[] memory tokens = new address[](collateralLen);
        AssetType[] memory types = new AssetType[](collateralLen);
        uint256[] memory amounts = new uint256[](collateralLen);
        uint256[][] memory allTokenIds = new uint256[][](collateralLen);

        for (uint256 i = 0; i < collateralLen; i++) {
            CollateralAsset storage asset = wt.collateral[i];
            tokens[i] = asset.token;
            types[i] = asset.assetType;
            amounts[i] = asset.amount;
            uint256 idsLen = asset.tokenIds.length;
            uint256[] memory idsCopy = new uint256[](idsLen);
            for (uint256 j = 0; j < idsLen; j++) {
                idsCopy[j] = asset.tokenIds[j];
            }
            allTokenIds[i] = idsCopy;
        }

        // Effects: clear all state before external calls
        wt.owner = address(0);
        wt.exists = false;
        delete wt.collateral;
        delete _wrappedTokens[wrappedId];

        unchecked {
            balanceOf[owner] -= 1;
            totalWrappedSupply -= 1;
        }

        // Interactions: return collateral to owner
        for (uint256 i = 0; i < collateralLen; i++) {
            if (types[i] == AssetType.ERC20) {
                bool ok = IERC20Minimal(tokens[i]).transfer(owner, amounts[i]);
                if (!ok) revert TransferFailed(tokens[i]);
            } else {
                uint256[] memory ids = allTokenIds[i];
                for (uint256 j = 0; j < ids.length; j++) {
                    IERC721Minimal(tokens[i]).safeTransferFrom(address(this), owner, ids[j]);
                }
            }
        }

        emit WrappedTokenRedeemed(wrappedId, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function ownerOf(uint256 wrappedId) external view returns (address) {
        if (!_wrappedTokens[wrappedId].exists) revert TokenDoesNotExist(wrappedId);
        return _wrappedTokens[wrappedId].owner;
    }

    function getWrappedToken(uint256 wrappedId) external view returns (address owner, uint256 totalValue) {
        if (!_wrappedTokens[wrappedId].exists) revert TokenDoesNotExist(wrappedId);
        return (_wrappedTokens[wrappedId].owner, _wrappedTokens[wrappedId].totalValue);
    }

    function getCollateralCount(uint256 wrappedId) external view returns (uint256) {
        if (!_wrappedTokens[wrappedId].exists) revert TokenDoesNotExist(wrappedId);
        return _wrappedTokens[wrappedId].collateral.length;
    }

    function getCollateralAsset(uint256 wrappedId, uint256 index)
        external
        view
        returns (address token, AssetType assetType, uint256 amount, uint256[] memory tokenIds)
    {
        if (!_wrappedTokens[wrappedId].exists) revert TokenDoesNotExist(wrappedId);
        CollateralAsset storage asset = _wrappedTokens[wrappedId].collateral[index];
        return (asset.token, asset.assetType, asset.amount, asset.tokenIds);
    }

    function isSupportedCollateral(address token) external view returns (bool) {
        return collateralTypeOf[token] != AssetType.None;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
