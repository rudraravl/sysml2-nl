// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title TradingCardVault
 * @notice Manages issuance and ownership of digital collectible tokens that
 *         represent physical trading cards held in custody. Supports pack
 *         opening, transfers, redemption, and sell-back of tokens.
 */
contract TradingCardVault {
    /* ============================================================= //
                               EVENTS
    // ============================================================= */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed tokenOwner, address indexed operator, bool approved);
    event PackOpened(address indexed opener, uint256 indexed tokenId);
    event TokenRedeemed(address indexed owner, uint256 indexed tokenId);
    event TokenSoldBack(address indexed seller, uint256 indexed tokenId, uint256 payout);
    event CardStatusUpdated(uint256 indexed tokenId, CardStatus status);
    event PackOpeningFeeUpdated(uint256 oldFee, uint256 newFee);
    event SellbackPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    /* ============================================================= //
                               ERRORS
    // ============================================================= */
    error Unauthorized();
    error ZeroAddress();
    error NotMinted();
    error NotAuthorized();
    error IncorrectPayment();
    error MaxSupplyExceeded();
    error AlreadyRedeemed();
    error TokenLocked();
    error InsufficientBalance();
    error TransferFailed();
    error UnsafeRecipient();
    error InvalidAmount();

    /* ============================================================= //
                               TYPES
    // ============================================================= */
    enum CardStatus {
        Vaulted,
        Redeemed
    }

    /* ============================================================= //
                             METADATA
    // ============================================================= */
    string public constant name = "Physical Trading Card Vault";
    string public constant symbol = "PTCV";
    uint256 public constant MAX_SUPPLY = 10_000;

    /* ============================================================= //
                       ACCESS CONTROL STORAGE
    // ============================================================= */
    address public owner;
    address public operator;

    /* ============================================================= //
                          CONFIG STORAGE
    // ============================================================= */
    uint256 public packOpeningFee;
    uint256 public sellbackPrice;

    /* ============================================================= //
                    ERC721 BALANCE / OWNER STORAGE
    // ============================================================= */
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /* ============================================================= //
                    CARD STATUS STORAGE
    // ============================================================= */
    mapping(uint256 => CardStatus) public cardStatus;

    /* ============================================================= //
                        SUPPLY TRACKING
    // ============================================================= */
    uint256 public totalMinted;
    uint256 internal _nextTokenId;

    /* ============================================================= //
                            MODIFIERS
    // ============================================================= */
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /* ============================================================= //
                            CONSTRUCTOR
    // ============================================================= */
    constructor(address _owner, address _operator) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        owner = _owner;
        operator = _operator;
        packOpeningFee = 0.05 ether;
        sellbackPrice = 0.03 ether;
        _nextTokenId = 1;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorUpdated(address(0), _operator);
    }

    /* ============================================================= //
                       OWNER ADMIN FUNCTIONS
    // ============================================================= */

    /**
     * @notice Updates the fee required to open a digital pack.
     * @param newFee The new fee in wei.
     */
    function setPackOpeningFee(uint256 newFee) external onlyOwner {
        emit PackOpeningFeeUpdated(packOpeningFee, newFee);
        packOpeningFee = newFee;
    }

    /**
     * @notice Updates the payout a user receives when selling a token back.
     * @param newPrice The new sell-back price in wei.
     */
    function setSellbackPrice(uint256 newPrice) external onlyOwner {
        emit SellbackPriceUpdated(sellbackPrice, newPrice);
        sellbackPrice = newPrice;
    }

    /**
     * @notice Transfers contract ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Sets a new operator who can mint packs and update card status.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Withdraws accumulated native currency from the contract.
     * @param to The recipient address.
     * @param amount The amount to withdraw in wei.
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /* ============================================================= //
                       OPERATOR FUNCTIONS
    // ============================================================= */

    /**
     * @notice Mints a new digital pack token to a specified address.
     * @param to The recipient of the newly minted token.
     */
    function mintPack(address to) external onlyOperator returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (totalMinted >= MAX_SUPPLY) revert MaxSupplyExceeded();

        tokenId = _nextTokenId++;
        _ownerOf[tokenId] = to;
        unchecked {
            _balanceOf[to] += 1;
        }
        cardStatus[tokenId] = CardStatus.Vaulted;
        totalMinted += 1;

        emit Transfer(address(0), to, tokenId);
        emit PackOpened(to, tokenId);
    }

    /**
     * @notice Updates the physical card inventory status for a token.
     * @param tokenId The token whose status is being updated.
     * @param status The new card status.
     */
    function updateCardStatus(uint256 tokenId, CardStatus status) external onlyOperator {
        if (_ownerOf[tokenId] == address(0)) revert NotMinted();
        cardStatus[tokenId] = status;
        emit CardStatusUpdated(tokenId, status);
    }

    /* ============================================================= //
                         PACK OPENING
    // ============================================================= */

    /**
     * @notice Opens a digital pack by paying the required fee. A new token
     *         is minted and assigned to the caller.
     * @return tokenId The ID of the token received.
     */
    function openPack() external payable returns (uint256 tokenId) {
        if (msg.value != packOpeningFee) revert IncorrectPayment();
        if (totalMinted >= MAX_SUPPLY) revert MaxSupplyExceeded();

        tokenId = _nextTokenId++;
        address to = msg.sender;

        _ownerOf[tokenId] = to;
        unchecked {
            _balanceOf[to] += 1;
        }
        cardStatus[tokenId] = CardStatus.Vaulted;
        totalMinted += 1;

        emit Transfer(address(0), to, tokenId);
        emit PackOpened(to, tokenId);
    }

    /* ============================================================= //
                      ERC721 VIEW FUNCTIONS
    // ============================================================= */

    function ownerOf(uint256 tokenId) public view returns (address tokenOwner) {
        tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert NotMinted();
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balanceOf[account];
    }

    function totalSupply() external view returns (uint256) {
        return totalMinted;
    }

    /**
     * @notice Returns the physical card status for a given token.
     */
    function getCardStatus(uint256 tokenId) external view returns (CardStatus) {
        if (_ownerOf[tokenId] == address(0)) revert NotMinted();
        return cardStatus[tokenId];
    }

    /**
     * @notice Returns whether a token's physical card has been redeemed.
     */
    function isRedeemed(uint256 tokenId) external view returns (bool) {
        if (_ownerOf[tokenId] == address(0)) revert NotMinted();
        return cardStatus[tokenId] == CardStatus.Redeemed;
    }

    /* ============================================================= //
                    ERC721 APPROVAL FUNCTIONS
    // ============================================================= */

    function approve(address spender, uint256 tokenId) public {
        address tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert NotMinted();
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) {
            revert NotAuthorized();
        }
        getApproved[tokenId] = spender;
        emit Approval(tokenOwner, spender, tokenId);
    }

    function setApprovalForAll(address operatorAddress, bool approved) public {
        isApprovedForAll[msg.sender][operatorAddress] = approved;
        emit ApprovalForAll(msg.sender, operatorAddress, approved);
    }

    /* ============================================================= //
                    ERC721 TRANSFER FUNCTIONS
    // ============================================================= */

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (_ownerOf[tokenId] != from) revert NotAuthorized();
        if (to == address(0)) revert ZeroAddress();
        if (cardStatus[tokenId] == CardStatus.Redeemed) revert TokenLocked();
        _checkAuthorized(from, msg.sender, tokenId);
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        _safeTransferFrom(from, to, tokenId, data);
    }

    /* ============================================================= //
                           REDEEM
    // ============================================================= */

    /**
     * @notice Redeems a token for its physical trading card. The token remains
     *         owned by the caller but is locked from further transfers or
     *         sell-back. Only the operator can subsequently update the status.
     * @param tokenId The token to redeem.
     */
    function redeem(uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != msg.sender) revert NotAuthorized();
        if (cardStatus[tokenId] == CardStatus.Redeemed) revert AlreadyRedeemed();

        cardStatus[tokenId] = CardStatus.Redeemed;
        delete getApproved[tokenId];

        emit TokenRedeemed(msg.sender, tokenId);
    }

    /* ============================================================= //
                          SELL BACK
    // ============================================================= */

    /**
     * @notice Sells a token back to the contract in exchange for the sell-back
     *         price. The token is burned and its card status is reset to Vaulted
     *         so the physical inventory returns to custody.
     * @param tokenId The token to sell back.
     */
    function sellBack(uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != msg.sender) revert NotAuthorized();
        if (cardStatus[tokenId] == CardStatus.Redeemed) revert TokenLocked();

        uint256 payout = sellbackPrice;
        if (address(this).balance < payout) revert InsufficientBalance();

        delete getApproved[tokenId];
        _burn(tokenId);

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed();

        emit TokenSoldBack(msg.sender, tokenId, payout);
    }

    /* ============================================================= //
                           ERC165
    // ============================================================= */

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd;   // ERC721
    }

    /* ============================================================= //
                      INTERNAL FUNCTIONS
    // ============================================================= */

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        unchecked {
            _balanceOf[from] -= 1;
            _balanceOf[to] += 1;
        }
        _ownerOf[tokenId] = to;
        delete getApproved[tokenId];
        emit Transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address tokenOwner = _ownerOf[tokenId];
        unchecked {
            _balanceOf[tokenOwner] -= 1;
        }
        delete _ownerOf[tokenId];
        delete getApproved[tokenId];
        cardStatus[tokenId] = CardStatus.Vaulted;
        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _checkAuthorized(
        address tokenOwner,
        address spender,
        uint256 tokenId
    ) internal view {
        if (tokenOwner == spender) return;
        if (isApprovedForAll[tokenOwner][spender]) return;
        if (getApproved[tokenId] == spender) return;
        revert NotAuthorized();
    }

    function _checkOnERC721Received(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length == 0) return;
        try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
            if (retval != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
        } catch {
            revert UnsafeRecipient();
        }
    }

    /* ============================================================= //
                           RECEIVE
    // ============================================================= */
    receive() external payable {}
}
