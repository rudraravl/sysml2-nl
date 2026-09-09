// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract NFTVaultMarket {
    error NotVaultOwner();
    error VaultDoesNotExist();
    error InsufficientDeposit();
    error InsufficientVaultBalance();
    error FeeExceedsMaximum();
    error NotAuthorizedRelayer();
    error InvalidSignature();
    error CollectionNotApproved();
    error BidExpired();
    error BidAlreadyFilled();
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();

    event VaultCreated(uint256 indexed vaultId, address indexed owner, uint256 initialDeposit);
    event Deposited(uint256 indexed vaultId, address indexed from, bool isWeth, uint256 amount);
    event Withdrawn(uint256 indexed vaultId, address indexed to, bool isWeth, uint256 amount);
    event FeeUpdated(uint256 newFeeBps);
    event RelayerUpdated(address indexed newRelayer);
    event CollectionApprovalUpdated(address indexed collection, bool approved);
    event BidFilled(
        bytes32 indexed bidHash,
        uint256 indexed buyerVaultId,
        uint256 indexed sellerVaultId,
        address collection,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );

    uint256 public constant MAX_FEE_BPS = 200; // 2%
    uint256 public constant MIN_INITIAL_DEPOSIT = 0.01 ether;
    uint256 private constant _BIPS_DENOMINATOR = 10_000;

    address public owner;
    address public trustedRelayer;
    uint256 public tradingFeeBps;

    IWETH public immutable weth;

    struct Vault {
        address owner;
        uint256 ethBalance;
        uint256 wethBalance;
        bool exists;
    }

    struct Bid {
        uint256 buyerVaultId;
        uint256 sellerVaultId;
        address collection;
        uint256 tokenId;
        uint256 price;
        bool useWeth;
        uint256 expiry;
        uint256 nonce;
    }

    mapping(uint256 => Vault) public vaults;
    mapping(address => bool) public approvedCollections;
    mapping(bytes32 => bool) public filledBids;

    uint256 public nextVaultId;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotVaultOwner();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != trustedRelayer) revert NotAuthorizedRelayer();
        _;
    }

    modifier onlyVaultOwner(uint256 vaultId) {
        Vault storage v = vaults[vaultId];
        if (!v.exists) revert VaultDoesNotExist();
        if (v.owner != msg.sender) revert NotVaultOwner();
        _;
    }

    constructor(address _weth, address _relayer, uint256 _initialFeeBps) {
        if (_weth == address(0) || _relayer == address(0)) revert ZeroAddress();
        if (_initialFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        owner = msg.sender;
        weth = IWETH(_weth);
        trustedRelayer = _relayer;
        tradingFeeBps = _initialFeeBps;
        nextVaultId = 1;
        emit RelayerUpdated(_relayer);
        emit FeeUpdated(_initialFeeBps);
    }

    function setTradingFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        tradingFeeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setTrustedRelayer(address _relayer) external onlyOwner {
        if (_relayer == address(0)) revert ZeroAddress();
        trustedRelayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    function setCollectionApproval(address collection, bool approved) external onlyOwner {
        if (collection == address(0)) revert ZeroAddress();
        approvedCollections[collection] = approved;
        emit CollectionApprovalUpdated(collection, approved);
    }

    function createVault() external payable returns (uint256 vaultId) {
        if (msg.value < MIN_INITIAL_DEPOSIT) revert InsufficientDeposit();
        vaultId = nextVaultId++;
        vaults[vaultId] = Vault({
            owner: msg.sender,
            ethBalance: msg.value,
            wethBalance: 0,
            exists: true
        });
        emit VaultCreated(vaultId, msg.sender, msg.value);
        emit Deposited(vaultId, msg.sender, false, msg.value);
    }

    function depositEth(uint256 vaultId) external payable onlyVaultOwner(vaultId) {
        if (msg.value == 0) revert ZeroAmount();
        vaults[vaultId].ethBalance += msg.value;
        emit Deposited(vaultId, msg.sender, false, msg.value);
    }

    function depositWeth(uint256 vaultId, uint256 amount) external onlyVaultOwner(vaultId) {
        if (amount == 0) revert ZeroAmount();
        vaults[vaultId].wethBalance += amount;
        if (!weth.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Deposited(vaultId, msg.sender, true, amount);
    }

    function withdrawEth(uint256 vaultId, uint256 amount) external onlyVaultOwner(vaultId) {
        if (amount == 0) revert ZeroAmount();
        Vault storage v = vaults[vaultId];
        if (v.ethBalance < amount) revert InsufficientVaultBalance();
        v.ethBalance -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(vaultId, msg.sender, false, amount);
    }

    function withdrawWeth(uint256 vaultId, uint256 amount) external onlyVaultOwner(vaultId) {
        if (amount == 0) revert ZeroAmount();
        Vault storage v = vaults[vaultId];
        if (v.wethBalance < amount) revert InsufficientVaultBalance();
        v.wethBalance -= amount;
        if (!weth.transfer(msg.sender, amount)) revert TransferFailed();
        emit Withdrawn(vaultId, msg.sender, true, amount);
    }

    function hashBid(Bid calldata bid) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bid.buyerVaultId,
                bid.sellerVaultId,
                bid.collection,
                bid.tokenId,
                bid.price,
                bid.useWeth,
                bid.expiry,
                bid.nonce
            )
        );
    }

    function fillBid(Bid calldata bid, bytes calldata signature) external onlyRelayer {
        if (block.timestamp > bid.expiry) revert BidExpired();
        if (!approvedCollections[bid.collection]) revert CollectionNotApproved();

        bytes32 bidHash = hashBid(bid);
        if (filledBids[bidHash]) revert BidAlreadyFilled();
        filledBids[bidHash] = true;

        bytes32 ethSignedHash = _toEthSignedMessageHash(bidHash);
        address signer = _recover(ethSignedHash, signature);

        Vault storage buyerVault = vaults[bid.buyerVaultId];
        Vault storage sellerVault = vaults[bid.sellerVaultId];
        if (!buyerVault.exists || !sellerVault.exists) revert VaultDoesNotExist();
        if (signer != buyerVault.owner) revert InvalidSignature();

        uint256 fee = (bid.price * tradingFeeBps) / _BIPS_DENOMINATOR;
        uint256 totalCost = bid.price + fee;

        if (bid.useWeth) {
            if (buyerVault.wethBalance < totalCost) revert InsufficientVaultBalance();
            buyerVault.wethBalance -= totalCost;
            sellerVault.wethBalance += bid.price;
            if (fee > 0) {
                if (!weth.transfer(owner, fee)) revert TransferFailed();
            }
        } else {
            if (buyerVault.ethBalance < totalCost) revert InsufficientVaultBalance();
            buyerVault.ethBalance -= totalCost;
            sellerVault.ethBalance += bid.price;
            if (fee > 0) {
                (bool ok, ) = payable(owner).call{value: fee}("");
                if (!ok) revert TransferFailed();
            }
        }

        IERC721(bid.collection).safeTransferFrom(sellerVault.owner, buyerVault.owner, bid.tokenId);

        emit BidFilled(
            bidHash,
            bid.buyerVaultId,
            bid.sellerVaultId,
            bid.collection,
            bid.tokenId,
            bid.price,
            fee
        );
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function _recover(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        return ecrecover(hash, v, r, s);
    }

    receive() external payable {}
}
