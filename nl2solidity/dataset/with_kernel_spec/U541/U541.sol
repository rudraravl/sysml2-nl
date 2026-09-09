// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(32, returndata), mload(returndata))
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

abstract contract ERC721 is Context, IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function name() public view virtual returns (string memory) { return _name; }
    function symbol() public view virtual returns (string memory) { return _symbol; }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()), "ERC721: approve caller is not owner nor approved for all");
        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        require(operator != _msgSender(), "ERC721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        _approve(address(0), tokenId);
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == address(0), "ERC721: token already minted");
        unchecked {
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        _approve(address(0), tokenId);
        unchecked {
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) revert("ERC721: transfer to non ERC721Receiver implementer");
            assembly { revert(add(32, reason), mload(reason)) }
        }
    }
}

contract DecentralizedLottery is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidEntryCount();
    error MaxEntriesReached();
    error NoEntriesSold();
    error NotOperator();
    error PriceExceedsMaximum();
    error InvalidPrice();
    error NoCommitment();
    error InvalidReveal();
    error CommitmentAlreadySet();
    error CommitmentTooRecent();

    event LotteryRoundStarted(uint256 indexed round, uint256 jackpot);
    event WinnerSelected(uint256 indexed round, address indexed winner, uint256 jackpot, uint256 winningTicketId);
    event EntryPurchased(uint256 indexed round, uint256 indexed ticketId, address indexed purchaser, uint256 count);
    event EntryPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event OperatorUpdated(address indexed operator, bool status);
    event DrawCommitted(uint256 indexed round, bytes32 commitment, uint256 commitBlock);

    IERC20 public immutable stablecoin;

    uint256 public constant MAX_ENTRIES_PER_ROUND = 1000;
    uint256 public constant MAX_ENTRY_PRICE = 10 * 10 ** 18;
    uint256 public constant DECIMALS = 10 ** 18;
    uint256 public constant MIN_COMMIT_DELAY = 1;

    uint256 public entryPrice;
    uint256 public jackpot;
    uint256 public currentRound;
    uint256 public entriesSold;

    mapping(uint256 => address) public ticketPurchaser;
    mapping(uint256 => uint256) public ticketRound;
    mapping(uint256 => uint256) public roundStartTicketId;
    mapping(address => bool) public operators;
    mapping(uint256 => bytes32) public roundCommitment;
    mapping(uint256 => uint256) public roundCommitBlock;

    uint256 private _nextTicketId;

    constructor(
        address stablecoin_,
        address owner_,
        uint256 initialJackpot
    ) ERC721("Decentralized Lottery Ticket", "DLT") Ownable(owner_) ReentrancyGuard() {
        if (stablecoin_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();

        stablecoin = IERC20(stablecoin_);
        entryPrice = 10 * DECIMALS;
        currentRound = 1;
        roundStartTicketId[currentRound] = _nextTicketId;

        if (initialJackpot > 0) {
            stablecoin.safeTransferFrom(msg.sender, address(this), initialJackpot);
            jackpot = initialJackpot;
        }

        emit LotteryRoundStarted(currentRound, jackpot);
        emit EntryPriceUpdated(0, entryPrice);
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    function setEntryPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidPrice();
        if (newPrice > MAX_ENTRY_PRICE) revert PriceExceedsMaximum();
        uint256 oldPrice = entryPrice;
        entryPrice = newPrice;
        emit EntryPriceUpdated(oldPrice, newPrice);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    function commitDraw(bytes32 commitment) external onlyOperator {
        if (roundCommitment[currentRound] != bytes32(0)) revert CommitmentAlreadySet();
        if (commitment == bytes32(0)) revert InvalidReveal();
        roundCommitment[currentRound] = commitment;
        roundCommitBlock[currentRound] = block.number;
        emit DrawCommitted(currentRound, commitment, block.number);
    }

    function buyEntry(uint256 numberOfEntries) external nonReentrant returns (uint256 firstTicketId) {
        if (numberOfEntries == 0) revert InvalidEntryCount();
        if (entriesSold + numberOfEntries > MAX_ENTRIES_PER_ROUND) revert MaxEntriesReached();

        uint256 totalCost = entryPrice * numberOfEntries;

        // Effects - update all state before any external interaction
        firstTicketId = _nextTicketId;
        for (uint256 i = 0; i < numberOfEntries; i++) {
            uint256 ticketId = _nextTicketId++;
            ticketPurchaser[ticketId] = msg.sender;
            ticketRound[ticketId] = currentRound;
        }
        entriesSold += numberOfEntries;
        jackpot += totalCost;

        // Interactions - external token transfer
        stablecoin.safeTransferFrom(msg.sender, address(this), totalCost);

        // Interactions - mint NFTs (may callback to receiver contracts)
        for (uint256 i = 0; i < numberOfEntries; i++) {
            _safeMint(msg.sender, firstTicketId + i);
            emit EntryPurchased(currentRound, firstTicketId + i, msg.sender, numberOfEntries);
        }
    }

    function draw(bytes32 secret, bytes32 salt) external onlyOperator nonReentrant {
        if (entriesSold == 0) revert NoEntriesSold();

        bytes32 commitment = roundCommitment[currentRound];
        if (commitment == bytes32(0)) revert NoCommitment();
        if (keccak256(abi.encodePacked(secret, salt)) != commitment) revert InvalidReveal();

        uint256 commitBlock = roundCommitBlock[currentRound];
        if (block.number <= commitBlock) revert CommitmentTooRecent();

        // Use blockhash of the commit block combined with the revealed secret.
        // The operator could not know blockhash(commitBlock) at commit time,
        // and miners cannot influence it retroactively.
        bytes32 commitBlockHash = blockhash(commitBlock);
        if (commitBlockHash == bytes32(0)) {
            // Fallback: use previous block hash if commit block hash is unavailable
            commitBlockHash = blockhash(block.number - 1);
        }

        uint256 round = currentRound;
        uint256 roundStart = roundStartTicketId[round];
        bytes32 seed = keccak256(abi.encodePacked(secret, salt, commitBlockHash, roundStart, entriesSold));
        uint256 winningTicketId = roundStart + (uint256(seed) % entriesSold);

        address winner = ticketPurchaser[winningTicketId];
        if (winner == address(0)) revert NoEntriesSold();
        uint256 prize = jackpot;

        // Effects - reset round state before external transfer
        jackpot = 0;
        entriesSold = 0;
        delete roundCommitment[round];
        delete roundCommitBlock[round];
        currentRound += 1;
        roundStartTicketId[currentRound] = _nextTicketId;

        // Interactions - transfer prize to winner
        if (prize > 0) {
            stablecoin.safeTransfer(winner, prize);
        }

        emit WinnerSelected(round, winner, prize, winningTicketId);
        emit LotteryRoundStarted(currentRound, 0);
    }

    function roundEntriesSold(uint256 round) external view returns (uint256) {
        if (round == currentRound) return entriesSold;
        uint256 nextRoundStart = roundStartTicketId[round + 1];
        if (nextRoundStart == 0) return 0;
        return nextRoundStart - roundStartTicketId[round];
    }

    function totalTicketsMinted() external view returns (uint256) {
        return _nextTicketId;
    }
}
