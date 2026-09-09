// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFromSender(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

/**
 * @title CrossChainAssetWrapper
 * @notice Custody contract that holds original ERC-20 and ERC-721 tokens to back wrapped
 *         representations on a different blockchain. Users deposit tokens to mint wrapped
 *         assets on the destination chain and burn wrapped assets to withdraw originals here.
 *         A configurable fee (default 0.5%) is charged on every unwrap operation.
 */
contract CrossChainAssetWrapper {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error Unauthorized();
    error ContractPaused();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFeePercentage();
    error MaxERC20TypesReached();
    error ERC20NotRegistered();
    error NFTNotRegistered();
    error InsufficientWrappedBalance();
    error NotNFTOwner();
    error NotApprovedOrOwner();
    error InsufficientFee();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant MAX_ERC20_TYPES = 100;
    uint256 public constant MAX_FEE_PERCENTAGE = 1000; // 10%
    uint256 public constant NFT_FEE_BASE = 1 ether;
    uint256 public constant BASIS_POINTS = 10000;

    // -------------------------------------------------------------------------
    // State variables
    // -------------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeCollector;
    uint256 public feePercentage; // in basis points, default 50 = 0.5%
    bool public paused;

    uint256 public erc20TypeCount;
    mapping(address => bool) public erc20Registered;
    mapping(address => bool) public nftRegistered;

    // Wrapped ERC-20 accounting: token => (holder => balance)
    mapping(address => mapping(address => uint256)) public erc20WrappedBalance;
    // Total wrapped supply per ERC-20 token
    mapping(address => uint256) public erc20WrappedSupply;

    // Wrapped ERC-721 accounting: token => tokenId => owner
    mapping(address => mapping(uint256 => address)) public nftOwner;
    // Total wrapped NFT supply per collection
    mapping(address => uint256) public nftWrappedSupply;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event DepositERC20(address indexed token, address indexed from, address indexed to, uint256 amount);
    event WithdrawERC20(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 fee);
    event DepositNFT(address indexed token, address indexed from, address indexed to, uint256 tokenId);
    event WithdrawNFT(address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 fee);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event ERC20Registered(address indexed token);
    event NFTRegistered(address indexed token);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address _owner, address _operator, address _feeCollector, uint256 _feePercentage) {
        if (_owner == address(0) || _operator == address(0) || _feeCollector == address(0)) revert ZeroAddress();
        if (_feePercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        owner = _owner;
        operator = _operator;
        feeCollector = _feeCollector;
        feePercentage = _feePercentage;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorUpdated(address(0), _operator);
        emit FeeCollectorUpdated(address(0), _feeCollector);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeCollector(address newCollector) external onlyOwner {
        if (newCollector == address(0)) revert ZeroAddress();
        address old = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(old, newCollector);
    }

    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        if (newFeePercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        uint256 old = feePercentage;
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(old, newFeePercentage);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -------------------------------------------------------------------------
    // ERC-20 wrapping / unwrapping
    // -------------------------------------------------------------------------
    function wrapERC20(address token, uint256 amount, address to) external whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (!erc20Registered[token]) {
            if (erc20TypeCount >= MAX_ERC20_TYPES) revert MaxERC20TypesReached();
            erc20Registered[token] = true;
            erc20TypeCount += 1;
            emit ERC20Registered(token);
        }

        // Take custody of the underlying ERC-20 tokens from the caller
        SafeERC20.safeTransferFromSender(IERC20(token), address(this), amount);

        // Effects: credit wrapped balance
        erc20WrappedBalance[token][to] += amount;
        erc20WrappedSupply[token] += amount;

        emit DepositERC20(token, msg.sender, to, amount);
    }

    function unwrapERC20(address token, uint256 amount, address to) external whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!erc20Registered[token]) revert ERC20NotRegistered();

        uint256 balance = erc20WrappedBalance[token][msg.sender];
        if (balance < amount) revert InsufficientWrappedBalance();

        uint256 fee = (amount * feePercentage) / BASIS_POINTS;
        uint256 out = amount - fee;

        // Effects
        erc20WrappedBalance[token][msg.sender] = balance - amount;
        erc20WrappedSupply[token] -= amount;

        // Interactions
        if (out > 0) {
            SafeERC20.safeTransfer(IERC20(token), to, out);
        }
        if (fee > 0) {
            SafeERC20.safeTransfer(IERC20(token), feeCollector, fee);
        }

        emit WithdrawERC20(token, msg.sender, to, out, fee);
    }

    // -------------------------------------------------------------------------
    // ERC-721 wrapping / unwrapping
    // -------------------------------------------------------------------------
    function wrapNFT(address token, uint256 tokenId, address to) external whenNotPaused {
        if (to == address(0)) revert ZeroAddress();

        if (!nftRegistered[token]) {
            nftRegistered[token] = true;
            emit NFTRegistered(token);
        }

        // Verify caller is owner or approved
        address tokenOwner = IERC721(token).ownerOf(tokenId);
        if (
            tokenOwner != msg.sender &&
            !IERC721(token).isApprovedForAll(tokenOwner, msg.sender) &&
            IERC721(token).getApproved(tokenId) != msg.sender
        ) {
            revert NotApprovedOrOwner();
        }

        // Take custody of the NFT
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        // Effects
        nftOwner[token][tokenId] = to;
        nftWrappedSupply[token] += 1;

        emit DepositNFT(token, msg.sender, to, tokenId);
    }

    function unwrapNFT(address token, uint256 tokenId, address to) external payable whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (!nftRegistered[token]) revert NFTNotRegistered();
        if (nftOwner[token][tokenId] != msg.sender) revert NotNFTOwner();

        uint256 fee = (NFT_FEE_BASE * feePercentage) / BASIS_POINTS;
        if (msg.value < fee) revert InsufficientFee();

        // Effects
        nftOwner[token][tokenId] = address(0);
        nftWrappedSupply[token] -= 1;

        // Interactions: release NFT
        IERC721(token).transferFrom(address(this), to, tokenId);

        // Send fee in native ETH to fee collector
        if (fee > 0) {
            (bool sent, ) = payable(feeCollector).call{value: fee}("");
            if (!sent) revert TransferFailed();
        }

        // Refund excess ETH
        uint256 refund = msg.value - fee;
        if (refund > 0) {
            (bool refunded, ) = payable(msg.sender).call{value: refund}("");
            if (!refunded) revert TransferFailed();
        }

        emit WithdrawNFT(token, msg.sender, to, tokenId, fee);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------
    function erc20Balance(address token, address account) external view returns (uint256) {
        return erc20WrappedBalance[token][account];
    }

    function getNFTOwner(address token, uint256 tokenId) external view returns (address) {
        return nftOwner[token][tokenId];
    }

    function isERC20Registered(address token) external view returns (bool) {
        return erc20Registered[token];
    }

    function isNFTRegistered(address token) external view returns (bool) {
        return nftRegistered[token];
    }

    // -------------------------------------------------------------------------
    // ERC-721 receiver support
    // -------------------------------------------------------------------------
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // -------------------------------------------------------------------------
    // Receive ETH (for NFT unwrap fees)
    // -------------------------------------------------------------------------
    receive() external payable {}
}
