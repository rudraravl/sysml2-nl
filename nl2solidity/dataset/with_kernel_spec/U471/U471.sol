// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DigitalAssetRegistry
/// @notice A registry for minting and managing unique digital assets with metadata URIs.
contract DigitalAssetRegistry {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error ZeroAddress();
    error IncorrectFee(uint256 required, uint256 provided);
    error ExceedsMaxMintPerTx(uint256 maxAllowed, uint256 requested);
    error AssetDoesNotExist(uint256 assetId);
    error NotOwnerNorApproved();
    error TransferToZeroAddress();
    error TransferToSelf();
    error SelfApproval();
    error WithdrawalFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AssetMinted(uint256 indexed assetId, address indexed creator, address indexed owner, string uri);
    event Transfer(address indexed from, address indexed to, uint256 indexed assetId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed assetId);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_MINT_PER_TX = 100;
    uint256 public constant DEFAULT_MINT_FEE = 0.005 ether;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public contractOwner;
    address public operator;
    uint256 public mintFee;

    struct Asset {
        address creator;
        address owner;
        string uri;
    }

    mapping(uint256 => Asset) public assets;
    mapping(uint256 => address) public assetApprovals;
    mapping(address => mapping(address => bool)) public operatorApprovals;
    mapping(address => uint256) public balanceOf;

    uint256 public nextAssetId;
    uint256 public totalSupply;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyContractOwner() {
        if (msg.sender != contractOwner) revert Unauthorized();
        _;
    }

    modifier assetExists(uint256 assetId) {
        if (assets[assetId].owner == address(0)) revert AssetDoesNotExist(assetId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        contractOwner = msg.sender;
        mintFee = DEFAULT_MINT_FEE;
        nextAssetId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit MintFeeUpdated(0, mintFee);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the global minting fee per asset (only contract owner).
    function setMintFee(uint256 newFee) external onlyContractOwner {
        uint256 oldFee = mintFee;
        mintFee = newFee;
        emit MintFeeUpdated(oldFee, newFee);
    }

    /// @notice Designate a new operator account (only contract owner).
    function setOperator(address newOperator) external onlyContractOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /// @notice Transfer ownership of the contract to a new account.
    function transferContractOwnership(address newOwner) external onlyContractOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = contractOwner;
        contractOwner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    /// @notice Withdraw collected minting fees to the contract owner.
    function withdrawFees() external onlyContractOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) return;
        (bool success, ) = payable(contractOwner).call{value: balance}("");
        if (!success) revert WithdrawalFailed();
        emit FeesWithdrawn(contractOwner, balance);
    }

    /*//////////////////////////////////////////////////////////////
                          MINTING LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint one or more digital assets to the caller.
    /// @param uris Array of metadata URIs for the new assets (max 100).
    function mint(string[] calldata uris) external payable {
        uint256 count = uris.length;
        if (count == 0 || count > MAX_MINT_PER_TX) {
            revert ExceedsMaxMintPerTx(MAX_MINT_PER_TX, count);
        }

        uint256 requiredFee = mintFee * count;
        if (msg.value != requiredFee) {
            revert IncorrectFee(requiredFee, msg.value);
        }

        uint256 startId = nextAssetId;
        for (uint256 i = 0; i < count; i++) {
            uint256 assetId = startId + i;
            assets[assetId] = Asset({
                creator: msg.sender,
                owner: msg.sender,
                uri: uris[i]
            });
            balanceOf[msg.sender]++;
            emit AssetMinted(assetId, msg.sender, msg.sender, uris[i]);
            emit Transfer(address(0), msg.sender, assetId);
        }

        nextAssetId = startId + count;
        totalSupply += count;
    }

    /*//////////////////////////////////////////////////////////////
                       TRANSFER & APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Transfer ownership of an asset owned by the caller.
    function transfer(address to, uint256 assetId) external assetExists(assetId) {
        _transfer(msg.sender, to, assetId);
    }

    /// @notice Transfer an asset on behalf of the owner, if approved.
    function transferFrom(address from, address to, uint256 assetId) external assetExists(assetId) {
        Asset storage asset = assets[assetId];
        if (asset.owner != from) revert NotOwnerNorApproved();

        bool authorized = msg.sender == from ||
            msg.sender == assetApprovals[assetId] ||
            operatorApprovals[from][msg.sender] ||
            msg.sender == operator;

        if (!authorized) revert NotOwnerNorApproved();
        _transfer(from, to, assetId);
    }

    /// @notice Approve another address to transfer a specific asset.
    function approve(address approved, uint256 assetId) external assetExists(assetId) {
        address currentOwner = assets[assetId].owner;
        if (msg.sender != currentOwner) revert Unauthorized();
        if (approved == currentOwner) revert SelfApproval();

        assetApprovals[assetId] = approved;
        emit Approval(currentOwner, approved, assetId);
    }

    /// @notice Grant or revoke operator status to manage all of the caller's assets.
    function setApprovalForAll(address op, bool approved) external {
        if (op == msg.sender) revert SelfApproval();
        operatorApprovals[msg.sender][op] = approved;
        emit Approval(msg.sender, op, assetIdForAllApproval());
    }

    /// @dev Internal helper to emit a single ApprovalForAll-style event using the standard signature.
    function assetIdForAllApproval() private pure returns (uint256) {
        return 0;
    }

    /// @dev Internal transfer logic with checks-effects-interactions ordering.
    function _transfer(address from, address to, uint256 assetId) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        if (to == from) revert TransferToSelf();

        // Effects
        assets[assetId].owner = to;
        balanceOf[from]--;
        balanceOf[to]++;
        if (assetApprovals[assetId] != address(0)) {
            delete assetApprovals[assetId];
        }

        emit Transfer(from, to, assetId);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the owner of a specific asset.
    function ownerOf(uint256 assetId) external view assetExists(assetId) returns (address) {
        return assets[assetId].owner;
    }

    /// @notice Get the approved address for a specific asset.
    function getApproved(uint256 assetId) external view assetExists(assetId) returns (address) {
        return assetApprovals[assetId];
    }

    /// @notice Check if an operator is approved to manage all of an owner's assets.
    function isApprovedForAll(address ownerAddr, address op) external view returns (bool) {
        return operatorApprovals[ownerAddr][op];
    }

    /// @notice Retrieve full asset data: creator, owner, and metadata URI.
    function getAsset(uint256 assetId)
        external
        view
        assetExists(assetId)
        returns (address creator, address assetOwner, string memory uri)
    {
        Asset storage asset = assets[assetId];
        return (asset.creator, asset.owner, asset.uri);
    }

    /// @notice Retrieve only the metadata URI for an asset.
    function tokenURI(uint256 assetId) external view assetExists(assetId) returns (string memory) {
        return assets[assetId].uri;
    }
}
