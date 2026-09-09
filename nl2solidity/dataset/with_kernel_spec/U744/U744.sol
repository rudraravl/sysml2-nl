// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract GradedCollectibleVault is IERC721Receiver {
    uint256 public constant MAX_FEE_BPS = 500; // 5%

    IERC721 public immutable nftContract;
    address public operator;
    address public treasury;
    uint256 public feeBps; // fee in basis points (e.g., 250 = 2.5%)

    struct VaultedToken {
        address owner;
        uint256 price;
        bool isVaulted;
        bool isListed;
    }

    mapping(uint256 => VaultedToken) private _vault;

    event Deposited(uint256 indexed tokenId, address indexed owner);
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Unlisted(uint256 indexed tokenId, address indexed seller);
    event Purchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 fee
    );
    event Withdrawn(uint256 indexed tokenId, address indexed owner);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OperatorUpdated(address oldOperator, address newOperator);

    error ZeroAddress();
    error FeeExceedsMaximum();
    error NotAuthorized();
    error NotTokenOwner();
    error TokenNotVaulted();
    error TokenAlreadyVaulted();
    error TokenAlreadyListed();
    error TokenNotListed();
    error PriceMustBePositive();
    error InsufficientPayment();
    error CannotBuyOwnListing();
    error TransferFailed();
    error ReentrantCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    uint256 private _reentrancyStatus = 1;

    function _nonReentrantBefore() private {
        if (_reentrancyStatus != 1) revert ReentrantCall();
        _reentrancyStatus = 2;
    }

    function _nonReentrantAfter() private {
        _reentrancyStatus = 1;
    }

    constructor(
        address _nftContract,
        address _treasury,
        address _operator,
        uint256 _feeBps
    ) {
        if (_nftContract == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();

        nftContract = IERC721(_nftContract);
        treasury = _treasury;
        operator = _operator;
        feeBps = _feeBps;
    }

    function setFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        uint256 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function deposit(uint256 tokenId) external nonReentrant {
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_vault[tokenId].isVaulted) revert TokenAlreadyVaulted();

        _vault[tokenId] = VaultedToken({
            owner: msg.sender,
            price: 0,
            isVaulted: true,
            isListed: false
        });

        nftContract.transferFrom(msg.sender, address(this), tokenId);

        emit Deposited(tokenId, msg.sender);
    }

    function list(uint256 tokenId, uint256 price) external {
        VaultedToken storage v = _vault[tokenId];
        if (!v.isVaulted) revert TokenNotVaulted();
        if (v.owner != msg.sender) revert NotTokenOwner();
        if (v.isListed) revert TokenAlreadyListed();
        if (price == 0) revert PriceMustBePositive();

        v.price = price;
        v.isListed = true;

        emit Listed(tokenId, msg.sender, price);
    }

    function unlist(uint256 tokenId) external {
        VaultedToken storage v = _vault[tokenId];
        if (!v.isVaulted) revert TokenNotVaulted();
        if (v.owner != msg.sender) revert NotTokenOwner();
        if (!v.isListed) revert TokenNotListed();

        v.price = 0;
        v.isListed = false;

        emit Unlisted(tokenId, msg.sender);
    }

    function purchase(uint256 tokenId) external payable nonReentrant {
        VaultedToken storage v = _vault[tokenId];
        if (!v.isVaulted) revert TokenNotVaulted();
        if (!v.isListed) revert TokenNotListed();
        if (v.owner == msg.sender) revert CannotBuyOwnListing();

        address seller = v.owner;
        uint256 price = v.price;
        if (msg.value < price) revert InsufficientPayment();

        uint256 fee = (price * feeBps) / 10000;
        uint256 sellerProceeds = price - fee;

        // Effects: transfer ownership and clear listing
        v.owner = msg.sender;
        v.price = 0;
        v.isListed = false;

        // Interactions: transfer NFT to buyer
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        // Interactions: pay treasury and seller
        if (fee > 0) {
            (bool feeOk, ) = payable(treasury).call{value: fee}("");
            if (!feeOk) revert TransferFailed();
        }
        if (sellerProceeds > 0) {
            (bool sellerOk, ) = payable(seller).call{value: sellerProceeds}("");
            if (!sellerOk) revert TransferFailed();
        }

        // Refund excess payment
        uint256 refund = msg.value - price;
        if (refund > 0) {
            (bool refundOk, ) = payable(msg.sender).call{value: refund}("");
            if (!refundOk) revert TransferFailed();
        }

        emit Purchased(tokenId, msg.sender, seller, price, fee);
    }

    function withdraw(uint256 tokenId) external nonReentrant {
        VaultedToken storage v = _vault[tokenId];
        if (!v.isVaulted) revert TokenNotVaulted();
        if (v.owner != msg.sender) revert NotTokenOwner();
        if (v.isListed) revert TokenAlreadyListed();

        delete _vault[tokenId];

        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdrawn(tokenId, msg.sender);
    }

    function getVaultedToken(uint256 tokenId)
        external
        view
        returns (address owner, uint256 price, bool isVaulted, bool isListed)
    {
        VaultedToken storage v = _vault[tokenId];
        return (v.owner, v.price, v.isVaulted, v.isListed);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        revert("Direct ETH deposits not supported");
    }
}
