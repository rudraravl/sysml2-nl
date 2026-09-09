// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract AssetAccountManager {
    enum TokenType {
        Fungible,
        NonFungible
    }

    error NotAuthorized();
    error ReentrantCall();
    error Paused();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error NFTLimitExceeded(uint256 current, uint256 limit);
    error NotOwnerOfNFT();
    error TransferFailed();
    error AmountExceedsFee();

    event Deposit(
        address indexed user,
        address indexed token,
        TokenType tokenType,
        uint256 amountOrId
    );
    event InternalTransfer(
        address indexed from,
        address indexed to,
        address indexed token,
        TokenType tokenType,
        uint256 amountOrId
    );
    event Withdrawal(
        address indexed user,
        address indexed recipient,
        address indexed token,
        TokenType tokenType,
        uint256 amountOrId,
        uint256 fee
    );
    event PausedStateChanged(bool paused);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OperatorUpdated(address oldOperator, address newOperator);

    uint256 public constant MAX_NFTS_PER_USER = 100;

    address public operator;
    address public treasury;
    bool public paused;

    uint256 private _status; // 1 = idle, 2 = locked

    mapping(address => mapping(address => uint256)) public fungibleBalance;
    mapping(address => mapping(address => uint256[])) internal _nftList;
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _nftIndex;
    mapping(address => mapping(address => uint256)) public nftCount;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        operator = msg.sender;
        treasury = _treasury;
        _status = 1;
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function getFungibleBalance(address user, address token) external view returns (uint256) {
        return fungibleBalance[user][token];
    }

    function getNFTList(address user, address token) external view returns (uint256[] memory) {
        return _nftList[user][token];
    }

    function getNFTCount(address user, address token) external view returns (uint256) {
        return nftCount[user][token];
    }

    function ownsNFT(address user, address token, uint256 tokenId) external view returns (bool) {
        return _ownsNFT(user, token, tokenId);
    }

    function depositFungible(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert ZeroAddress();

        fungibleBalance[msg.sender][token] += amount;
        _pullERC20(token, msg.sender, amount);

        emit Deposit(msg.sender, token, TokenType.Fungible, amount);
    }

    function transferFungible(address to, address token, uint256 amount) external whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();

        uint256 bal = fungibleBalance[msg.sender][token];
        if (bal < amount) revert InsufficientBalance(bal, amount);

        fungibleBalance[msg.sender][token] = bal - amount;
        fungibleBalance[to][token] += amount;

        emit InternalTransfer(msg.sender, to, token, TokenType.Fungible, amount);
    }

    function withdrawFungible(address token, uint256 amount, address recipient) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = _calculateFee(token);
        if (amount <= fee) revert AmountExceedsFee();

        uint256 bal = fungibleBalance[msg.sender][token];
        if (bal < amount) revert InsufficientBalance(bal, amount);

        fungibleBalance[msg.sender][token] = bal - amount;

        uint256 payout = amount - fee;
        _sendERC20(token, recipient, payout);
        _sendERC20(token, treasury, fee);

        emit Withdrawal(msg.sender, recipient, token, TokenType.Fungible, amount, fee);
    }

    function depositNFT(address token, uint256 tokenId) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();

        uint256 count = nftCount[msg.sender][token];
        if (count >= MAX_NFTS_PER_USER) revert NFTLimitExceeded(count, MAX_NFTS_PER_USER);

        _addNFT(msg.sender, token, tokenId);
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        emit Deposit(msg.sender, token, TokenType.NonFungible, tokenId);
    }

    function transferNFT(address to, address token, uint256 tokenId) external whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (!_ownsNFT(msg.sender, token, tokenId)) revert NotOwnerOfNFT();

        uint256 toCount = nftCount[to][token];
        if (toCount >= MAX_NFTS_PER_USER) revert NFTLimitExceeded(toCount, MAX_NFTS_PER_USER);

        _removeNFT(msg.sender, token, tokenId);
        _addNFT(to, token, tokenId);

        emit InternalTransfer(msg.sender, to, token, TokenType.NonFungible, tokenId);
    }

    function withdrawNFT(address token, uint256 tokenId, address recipient) external nonReentrant whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (!_ownsNFT(msg.sender, token, tokenId)) revert NotOwnerOfNFT();

        _removeNFT(msg.sender, token, tokenId);
        IERC721(token).transferFrom(address(this), recipient, tokenId);

        emit Withdrawal(msg.sender, recipient, token, TokenType.NonFungible, tokenId, 0);
    }

    function _ownsNFT(address user, address token, uint256 tokenId) internal view returns (bool) {
        uint256 count = nftCount[user][token];
        if (count == 0) return false;
        uint256 idx = _nftIndex[user][token][tokenId];
        if (idx >= count) return false;
        return _nftList[user][token][idx] == tokenId;
    }

    function _addNFT(address user, address token, uint256 tokenId) internal {
        uint256 count = nftCount[user][token];
        _nftList[user][token].push(tokenId);
        _nftIndex[user][token][tokenId] = count;
        nftCount[user][token] = count + 1;
    }

    function _removeNFT(address user, address token, uint256 tokenId) internal {
        uint256 count = nftCount[user][token];
        require(count > 0, "AssetAccountManager: empty nft list");
        uint256 idx = _nftIndex[user][token][tokenId];
        require(idx < count && _nftList[user][token][idx] == tokenId, "AssetAccountManager: not owned");
        uint256 lastIdx = count - 1;

        if (idx != lastIdx) {
            uint256 lastId = _nftList[user][token][lastIdx];
            _nftList[user][token][idx] = lastId;
            _nftIndex[user][token][lastId] = idx;
        }

        _nftList[user][token].pop();
        delete _nftIndex[user][token][tokenId];
        nftCount[user][token] = count - 1;
    }

    function _calculateFee(address token) internal view returns (uint256) {
        uint8 decimals = 18;
        try IERC20(token).decimals() returns (uint8 d) {
            decimals = d;
        } catch {}
        if (decimals < 2) return 1;
        if (decimals > 30) decimals = 30;
        return 10 ** (decimals - 2);
    }

    function _pullERC20(address token, address from, uint256 amount) internal {
        bool success = IERC20(token).transferFrom(from, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function _sendERC20(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert TransferFailed();
    }
}
