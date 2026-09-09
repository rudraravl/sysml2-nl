// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract FractionalNFT {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant AUCTION_DURATION = 24 hours;
    uint256 public constant MIN_RESERVE_PRICE = 100;
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------
    // ERC20 metadata
    // ---------------------------------------------------------------------
    string public name;
    string public symbol;

    // ---------------------------------------------------------------------
    // Access control
    // ---------------------------------------------------------------------
    address public operator;

    // ---------------------------------------------------------------------
    // NFT state
    // ---------------------------------------------------------------------
    address public nftContract;
    uint256 public nftTokenId;
    bool public isFractionalized;

    // ---------------------------------------------------------------------
    // Fractional token state
    // ---------------------------------------------------------------------
    uint256 public reservePrice;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Auction state
    // ---------------------------------------------------------------------
    bool public auctionActive;
    bool public auctionEnded;
    uint256 public auctionStartTime;
    uint256 public auctionEndTime;
    uint256 public auctionStartPrice;
    uint256 public auctionEndPrice;
    address public auctionWinner;
    uint256 public saleProceeds;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    bool private _locked;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event NFTSet(address indexed nftContract, uint256 indexed tokenId, uint256 reservePrice);
    event Fractionalized(address indexed nftContract, uint256 indexed tokenId, address indexed depositor, uint256 fractionsMinted);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event AuctionStarted(uint256 startTime, uint256 endTime, uint256 startPrice, uint256 endPrice);
    event AuctionEnded(address indexed winner, uint256 price);
    event AuctionExpired();
    event Redeemed(address indexed account, uint256 fractionsBurned);
    event ProceedsWithdrawn(address indexed operator, uint256 amount);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error NFTAlreadySet();
    error NFTNotSet();
    error AlreadyFractionalized();
    error NotFractionalized();
    error NotNFTOwner();
    error ReservePriceTooLow(uint256 provided, uint256 minimum);
    error StartPriceBelowReserve(uint256 startPrice, uint256 reservePrice);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error AuctionActive();
    error AuctionNotActive();
    error AuctionAlreadyEnded();
    error AuctionNotEnded();
    error AuctionNotExpired();
    error AuctionInProgress();
    error BidTooLow(uint256 provided, uint256 required);
    error NoProceedsToWithdraw();
    error MustOwnAllShares();
    error TransferFailed();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, string memory _name, string memory _symbol) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        name = _name;
        symbol = _symbol;
        emit OperatorChanged(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    // Operator management
    // ---------------------------------------------------------------------
    function changeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // ---------------------------------------------------------------------
    // NFT setup
    // ---------------------------------------------------------------------
    function setNFT(address _nftContract, uint256 _tokenId, uint256 _reservePrice) external onlyOperator {
        if (nftContract != address(0)) revert NFTAlreadySet();
        if (_nftContract == address(0)) revert ZeroAddress();
        if (_reservePrice < MIN_RESERVE_PRICE) revert ReservePriceTooLow(_reservePrice, MIN_RESERVE_PRICE);

        nftContract = _nftContract;
        nftTokenId = _tokenId;
        reservePrice = _reservePrice;

        emit NFTSet(_nftContract, _tokenId, _reservePrice);
    }

    // ---------------------------------------------------------------------
    // Fractionalization (deposit the underlying NFT, mint fractional tokens)
    // ---------------------------------------------------------------------
    function depositNFT(uint256 fractionsToMint) external nonReentrant {
        if (nftContract == address(0)) revert NFTNotSet();
        if (isFractionalized) revert AlreadyFractionalized();
        if (fractionsToMint == 0) revert ZeroAmount();
        if (IERC721(nftContract).ownerOf(nftTokenId) != msg.sender) revert NotNFTOwner();

        // Effects before interactions to prevent cross-function reentrancy.
        isFractionalized = true;
        totalSupply = fractionsToMint;
        balanceOf[msg.sender] = fractionsToMint;

        // Interaction
        IERC721(nftContract).transferFrom(msg.sender, address(this), nftTokenId);

        emit Fractionalized(nftContract, nftTokenId, msg.sender, fractionsToMint);
        emit Transfer(address(0), msg.sender, fractionsToMint);
    }

    // ---------------------------------------------------------------------
    // Redeem: burn all fractional tokens to reclaim the underlying NFT.
    // Only available while the NFT is still held and no auction is active/ended.
    // ---------------------------------------------------------------------
    function redeem() external nonReentrant {
        if (!isFractionalized) revert NotFractionalized();
        if (auctionActive || auctionEnded) revert AuctionInProgress();

        uint256 callerBalance = balanceOf[msg.sender];
        if (callerBalance < totalSupply) revert MustOwnAllShares();

        address nft = nftContract;
        uint256 tokenId = nftTokenId;

        // Effects
        balanceOf[msg.sender] = 0;
        totalSupply = 0;
        isFractionalized = false;

        // Interaction
        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Transfer(msg.sender, address(0), callerBalance);
        emit Redeemed(msg.sender, callerBalance);
    }

    // ---------------------------------------------------------------------
    // ERC20-like fractional token transfers
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(allowed, amount);
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Dutch auction for the entire NFT
    // ---------------------------------------------------------------------
    function startAuction(uint256 startPrice) external onlyOperator nonReentrant {
        if (!isFractionalized) revert NotFractionalized();
        if (auctionActive) revert AuctionActive();
        if (auctionEnded) revert AuctionAlreadyEnded();
        if (startPrice < reservePrice) revert StartPriceBelowReserve(startPrice, reservePrice);

        auctionActive = true;
        auctionStartTime = block.timestamp;
        auctionEndTime = block.timestamp + AUCTION_DURATION;
        auctionStartPrice = startPrice;
        auctionEndPrice = reservePrice;

        emit AuctionStarted(auctionStartTime, auctionEndTime, startPrice, reservePrice);
    }

    function currentPrice() public view returns (uint256) {
        if (!auctionActive) return 0;
        if (block.timestamp >= auctionEndTime) return auctionEndPrice;

        uint256 elapsed = block.timestamp - auctionStartTime;
        uint256 priceDrop = ((auctionStartPrice - auctionEndPrice) * elapsed) / AUCTION_DURATION;
        return auctionStartPrice - priceDrop;
    }

    function bid() external payable nonReentrant {
        if (!auctionActive) revert AuctionNotActive();

        uint256 price = currentPrice();
        if (msg.value < price) revert BidTooLow(msg.value, price);

        // Effects
        auctionActive = false;
        auctionEnded = true;
        auctionWinner = msg.sender;
        saleProceeds = price;

        emit AuctionEnded(msg.sender, price);

        // Interaction: transfer NFT to the winner
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftTokenId);

        // Interaction: refund any excess payment
        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert TransferFailed();
        }
    }

    function expireAuction() external {
        if (!auctionActive) revert AuctionNotActive();
        if (block.timestamp < auctionEndTime) revert AuctionNotExpired();

        auctionActive = false;
        emit AuctionExpired();
    }

    // ---------------------------------------------------------------------
    // Operator proceeds withdrawal
    // ---------------------------------------------------------------------
    function withdrawProceeds() external onlyOperator nonReentrant {
        if (!auctionEnded) revert AuctionNotEnded();

        uint256 amount = saleProceeds;
        if (amount == 0) revert NoProceedsToWithdraw();

        saleProceeds = 0;
        (bool ok, ) = payable(operator).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit ProceedsWithdrawn(operator, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function auctionInfo() external view returns (
        bool active,
        bool ended,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice,
        uint256 current,
        address winner,
        uint256 proceeds
    ) {
        return (
            auctionActive,
            auctionEnded,
            auctionStartTime,
            auctionEndTime,
            auctionStartPrice,
            auctionEndPrice,
            currentPrice(),
            auctionWinner,
            saleProceeds
        );
    }
}
