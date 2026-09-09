// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainBridge {
    error NotOperator();
    error ContractPaused();
    error ContractNotPaused();
    error AssetNotSupported();
    error AssetAlreadyRegistered();
    error AmountExceedsCap();
    error InsufficientBalance();
    error ZeroAmount();
    error ZeroAddress();

    event Deposit(
        address indexed sourceAsset,
        address indexed depositor,
        uint256 grossAmount,
        uint256 netAmount,
        uint256 fee,
        uint256 sourceChainId
    );
    event Withdrawal(
        address indexed sourceAsset,
        address indexed withdrawer,
        uint256 grossAmount,
        uint256 netAmount,
        uint256 fee,
        uint256 destinationChainId
    );
    event AssetMappingRegistered(
        address indexed sourceAsset,
        address wrappedToken,
        uint256 sourceChainId
    );
    event AssetMappingRemoved(address indexed sourceAsset);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesClaimed(address indexed sourceAsset, address indexed operator, uint256 amount);

    uint256 public constant FEE_BASIS_POINTS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_TRANSFER_AMOUNT = 1_000_000;

    address public operator;
    bool public paused;

    struct AssetMapping {
        address wrappedToken;
        uint256 sourceChainId;
        bool active;
    }

    mapping(address => AssetMapping) public assetMapping;
    mapping(address => mapping(address => uint256)) public wrappedBalanceOf;
    mapping(address => uint256) public wrappedTotalSupply;
    mapping(address => uint256) public pendingFees;
    address[] public registeredAssets;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function registerAssetMapping(
        address sourceAsset,
        address wrappedToken,
        uint256 sourceChainId
    ) external onlyOperator {
        if (sourceAsset == address(0)) revert ZeroAddress();
        if (wrappedToken == address(0)) revert ZeroAddress();
        if (assetMapping[sourceAsset].active) revert AssetAlreadyRegistered();
        assetMapping[sourceAsset] = AssetMapping({
            wrappedToken: wrappedToken,
            sourceChainId: sourceChainId,
            active: true
        });
        registeredAssets.push(sourceAsset);
        emit AssetMappingRegistered(sourceAsset, wrappedToken, sourceChainId);
    }

    function removeAssetMapping(address sourceAsset) external onlyOperator {
        if (!assetMapping[sourceAsset].active) revert AssetNotSupported();
        delete assetMapping[sourceAsset];
        emit AssetMappingRemoved(sourceAsset);
    }

    function pause() external onlyOperator {
        if (paused) revert ContractPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert ContractNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function deposit(address sourceAsset, uint256 amount) external whenNotPaused {
        AssetMapping memory m = assetMapping[sourceAsset];
        if (!m.active) revert AssetNotSupported();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_TRANSFER_AMOUNT) revert AmountExceedsCap();

        uint256 fee = (amount * FEE_BASIS_POINTS) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        wrappedBalanceOf[sourceAsset][msg.sender] += netAmount;
        wrappedTotalSupply[sourceAsset] += amount;
        pendingFees[sourceAsset] += fee;

        emit Deposit(sourceAsset, msg.sender, amount, netAmount, fee, m.sourceChainId);
    }

    function withdraw(
        address sourceAsset,
        uint256 amount,
        uint256 destinationChainId
    ) external whenNotPaused {
        AssetMapping memory m = assetMapping[sourceAsset];
        if (!m.active) revert AssetNotSupported();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_TRANSFER_AMOUNT) revert AmountExceedsCap();
        if (wrappedBalanceOf[sourceAsset][msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BASIS_POINTS) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        wrappedBalanceOf[sourceAsset][msg.sender] -= amount;
        wrappedTotalSupply[sourceAsset] -= netAmount;
        pendingFees[sourceAsset] += fee;

        emit Withdrawal(sourceAsset, msg.sender, amount, netAmount, fee, destinationChainId);
    }

    function claimFees(address sourceAsset) external onlyOperator {
        uint256 amount = pendingFees[sourceAsset];
        if (amount == 0) revert ZeroAmount();
        pendingFees[sourceAsset] = 0;
        wrappedBalanceOf[sourceAsset][operator] += amount;
        emit FeesClaimed(sourceAsset, operator, amount);
    }

    function registeredAssetsLength() external view returns (uint256) {
        return registeredAssets.length;
    }

    function isAssetSupported(address sourceAsset) external view returns (bool) {
        return assetMapping[sourceAsset].active;
    }

    function getAssetMapping(address sourceAsset)
        external
        view
        returns (address wrappedToken, uint256 sourceChainId, bool active)
    {
        AssetMapping memory m = assetMapping[sourceAsset];
        return (m.wrappedToken, m.sourceChainId, m.active);
    }
}
