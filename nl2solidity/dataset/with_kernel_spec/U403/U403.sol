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
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract AssetVault is IERC721Receiver {
    // ------------------------------------------------------------
    //                         Custom Errors
    // ------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error NotAuthorized();
    error WithdrawalsPaused();
    error InsufficientBalance();
    error ExceedsMaxNFTs();
    error InvalidFeeRate();
    error NotDelegate();
    error NFTNotDeposited();
    error TransferFailed();
    error ReentrantCall();
    error NFTAlreadyDeposited();

    // ------------------------------------------------------------
    //                          Constants
    // ------------------------------------------------------------
    uint256 public constant MAX_NFTS_PER_USER = 100;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_RATE = 1000;
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC721_RECEIVER_INTERFACE_ID = 0x150b7a02;

    // ------------------------------------------------------------
    //                           Events
    // ------------------------------------------------------------
    event ERC20Deposited(address indexed user, address indexed token, uint256 amount, uint256 timestamp);
    event ERC721Deposited(address indexed user, address indexed token, uint256 tokenId, uint256 timestamp);
    event ERC20Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 fee, uint256 timestamp);
    event ERC721Withdrawn(address indexed user, address indexed token, uint256 tokenId, uint256 timestamp);
    event DelegationSet(address indexed owner, address indexed delegate, address indexed token, bool approved);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event WithdrawalPauseUpdated(bool paused);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesClaimed(address indexed token, address indexed to, uint256 amount);

    // ------------------------------------------------------------
    //                           Types
    // ------------------------------------------------------------
    enum TxType {
        DepositERC20,
        DepositERC721,
        WithdrawERC20,
        WithdrawERC721
    }

    struct Transaction {
        TxType txType;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    // ------------------------------------------------------------
    //                          Storage
    // ------------------------------------------------------------
    address public operator;
    uint256 public withdrawalFeeRate;
    bool public withdrawalsPaused;

    mapping(address => mapping(address => uint256)) internal _erc20Balances;
    mapping(address => mapping(address => mapping(uint256 => bool))) internal _depositedNFTs;
    mapping(address => uint256) internal _userNFTCount;
    mapping(address => mapping(address => mapping(address => bool))) internal _delegations;
    mapping(address => uint256) internal _accumulatedFees;
    mapping(address => Transaction[]) internal _transactionHistory;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ------------------------------------------------------------
    //                         Modifiers
    // ------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ------------------------------------------------------------
    //                        Constructor
    // ------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        withdrawalFeeRate = 10; // 0.1% default fee
        _status = _NOT_ENTERED;
    }

    // ------------------------------------------------------------
    //                    ERC20 Deposit / Withdraw
    // ------------------------------------------------------------
    /// @notice Deposits ERC20 tokens from the caller into the vault.
    /// @dev The return value of `transferFrom` is checked; for standard
    ///      ERC20 tokens a successful call guarantees `amount` was moved.
    ///      A reentrancy guard is applied as defense-in-depth.
    function depositERC20(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Interaction: pull tokens from the caller. Reverts on failure.
        _safeTransferFrom(token, msg.sender, address(this), amount);

        // Effects: credit the deposited amount directly.
        _erc20Balances[msg.sender][token] += amount;
        _transactionHistory[msg.sender].push(
            Transaction({txType: TxType.DepositERC20, token: token, amount: amount, timestamp: block.timestamp})
        );
        emit ERC20Deposited(msg.sender, token, amount, block.timestamp);
    }

    /// @notice Withdraws ERC20 tokens belonging to the caller. A withdrawal
    ///         fee (`withdrawalFeeRate` bps) is retained by the vault.
    function withdrawERC20(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (_erc20Balances[msg.sender][token] < amount) revert InsufficientBalance();

        uint256 fee = (amount * withdrawalFeeRate) / FEE_DENOMINATOR;
        uint256 payout = amount - fee;

        // Effects.
        _erc20Balances[msg.sender][token] -= amount;
        _accumulatedFees[token] += fee;

        // Interactions.
        _safeTransfer(token, msg.sender, payout);

        _transactionHistory[msg.sender].push(
            Transaction({txType: TxType.WithdrawERC20, token: token, amount: amount, timestamp: block.timestamp})
        );
        emit ERC20Withdrawn(msg.sender, token, amount, fee, block.timestamp);
    }

    // ------------------------------------------------------------
    //                    ERC721 Deposit / Withdraw
    // ------------------------------------------------------------
    /// @notice Deposits an ERC721 token from the caller into the vault.
    function depositERC721(address token, uint256 tokenId) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (_userNFTCount[msg.sender] >= MAX_NFTS_PER_USER) revert ExceedsMaxNFTs();
        if (_depositedNFTs[msg.sender][token][tokenId]) revert NFTAlreadyDeposited();

        // Effects first (rolled back if transfer reverts).
        _depositedNFTs[msg.sender][token][tokenId] = true;
        _userNFTCount[msg.sender] += 1;

        // Interaction.
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        _transactionHistory[msg.sender].push(
            Transaction({txType: TxType.DepositERC721, token: token, amount: tokenId, timestamp: block.timestamp})
        );
        emit ERC721Deposited(msg.sender, token, tokenId, block.timestamp);
    }

    /// @notice Withdraws an ERC721 token previously deposited by the caller.
    function withdrawERC721(address token, uint256 tokenId) external nonReentrant whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (!_depositedNFTs[msg.sender][token][tokenId]) revert NFTNotDeposited();

        // Effects.
        _depositedNFTs[msg.sender][token][tokenId] = false;
        _userNFTCount[msg.sender] -= 1;

        // Interaction.
        IERC721(token).safeTransferFrom(address(this), msg.sender, tokenId);

        _transactionHistory[msg.sender].push(
            Transaction({txType: TxType.WithdrawERC721, token: token, amount: tokenId, timestamp: block.timestamp})
        );
        emit ERC721Withdrawn(msg.sender, token, tokenId, block.timestamp);
    }

    // ------------------------------------------------------------
    //              Delegated Withdrawals (Spending)
    // ------------------------------------------------------------
    /// @notice Allows a delegate to withdraw ERC20 tokens on behalf of `owner`.
    function withdrawERC20For(address owner, address token, uint256 amount) external nonReentrant whenNotPaused {
        if (owner == address(0) || token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (owner != msg.sender && !_delegations[owner][msg.sender][token]) revert NotDelegate();
        if (_erc20Balances[owner][token] < amount) revert InsufficientBalance();

        uint256 fee = (amount * withdrawalFeeRate) / FEE_DENOMINATOR;
        uint256 payout = amount - fee;

        // Effects.
        _erc20Balances[owner][token] -= amount;
        _accumulatedFees[token] += fee;

        // Interaction.
        _safeTransfer(token, msg.sender, payout);

        _transactionHistory[owner].push(
            Transaction({txType: TxType.WithdrawERC20, token: token, amount: amount, timestamp: block.timestamp})
        );
        emit ERC20Withdrawn(owner, token, amount, fee, block.timestamp);
    }

    /// @notice Allows a delegate to withdraw an ERC721 token on behalf of `owner`.
    function withdrawERC721For(address owner, address token, uint256 tokenId) external nonReentrant whenNotPaused {
        if (owner == address(0) || token == address(0)) revert ZeroAddress();
        if (owner != msg.sender && !_delegations[owner][msg.sender][token]) revert NotDelegate();
        if (!_depositedNFTs[owner][token][tokenId]) revert NFTNotDeposited();

        // Effects.
        _depositedNFTs[owner][token][tokenId] = false;
        _userNFTCount[owner] -= 1;

        // Interaction.
        IERC721(token).safeTransferFrom(address(this), msg.sender, tokenId);

        _transactionHistory[owner].push(
            Transaction({txType: TxType.WithdrawERC721, token: token, amount: tokenId, timestamp: block.timestamp})
        );
        emit ERC721Withdrawn(owner, token, tokenId, block.timestamp);
    }

    // ------------------------------------------------------------
    //                        Delegation
    // ------------------------------------------------------------
    /// @notice Grants or revokes withdrawal authority over a specific token
    ///         contract to `delegate`.
    function setDelegation(address delegate, address token, bool approved) external {
        if (delegate == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        _delegations[msg.sender][delegate][token] = approved;
        emit DelegationSet(msg.sender, delegate, token, approved);
    }

    /// @notice Returns whether `delegate` is authorized to withdraw `token`
    ///         on behalf of `owner`.
    function isDelegate(address owner, address delegate, address token) external view returns (bool) {
        return _delegations[owner][delegate][token];
    }

    // ------------------------------------------------------------
    //                       Operator Admin
    // ------------------------------------------------------------
    /// @notice Sets the global withdrawal fee rate, capped at `MAX_FEE_RATE` bps.
    function setWithdrawalFeeRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_FEE_RATE) revert InvalidFeeRate();
        uint256 old = withdrawalFeeRate;
        withdrawalFeeRate = newRate;
        emit FeeRateUpdated(old, newRate);
    }

    /// @notice Pauses or unpauses all withdrawal operations.
    function setWithdrawalsPaused(bool paused) external onlyOperator {
        withdrawalsPaused = paused;
        emit WithdrawalPauseUpdated(paused);
    }

    /// @notice Transfers operator privileges to a new address.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Allows the operator to claim accumulated withdrawal fees.
    function claimFees(address token, address to, uint256 amount) external onlyOperator nonReentrant {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > _accumulatedFees[token]) revert InsufficientBalance();

        // Effects.
        _accumulatedFees[token] -= amount;

        // Interaction.
        _safeTransfer(token, to, amount);

        emit FeesClaimed(token, to, amount);
    }

    // ------------------------------------------------------------
    //                          Views
    // ------------------------------------------------------------
    function getERC20Balance(address user, address token) external view returns (uint256) {
        return _erc20Balances[user][token];
    }

    function getNFTCount(address user) external view returns (uint256) {
        return _userNFTCount[user];
    }

    function isNFTDeposited(address user, address token, uint256 tokenId) external view returns (bool) {
        return _depositedNFTs[user][token][tokenId];
    }

    function getAccumulatedFees(address token) external view returns (uint256) {
        return _accumulatedFees[token];
    }

    function getTransactionCount(address user) external view returns (uint256) {
        return _transactionHistory[user].length;
    }

    function getTransactionAt(address user, uint256 index) external view returns (Transaction memory) {
        return _transactionHistory[user][index];
    }

    function getTransactions(address user, uint256 offset, uint256 limit) external view returns (Transaction[] memory) {
        uint256 total = _transactionHistory[user].length;
        if (offset >= total) {
            return new Transaction[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 count = end - offset;
        Transaction[] memory result = new Transaction[](count);
        for (uint256 i = 0; i < count; ++i) {
            result[i] = _transactionHistory[user][offset + i];
        }
        return result;
    }

    // ------------------------------------------------------------
    //                   ERC721 Receiver & ERC165
    // ------------------------------------------------------------
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return _ERC721_RECEIVER_INTERFACE_ID;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == _ERC165_INTERFACE_ID || interfaceId == _ERC721_RECEIVER_INTERFACE_ID;
    }

    // ------------------------------------------------------------
    //                       Internal Helpers
    // ------------------------------------------------------------
    /// @dev Safe ERC20 transfer that reverts on a falsy return value.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    /// @dev Safe ERC20 transferFrom that reverts on a falsy return value.
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }
}
