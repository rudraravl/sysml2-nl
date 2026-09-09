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

/**
 * @title CrossChainBridge
 * @notice Holds deposited ERC20 tokens on the source chain until a corresponding
 *         withdrawal is initiated and finalised by a designated relayer on the
 *         destination chain. Tracks per-user deposits, wrapped token supply,
 *         wrapped balances, accrued fees and withdrawal request state.
 */
contract CrossChainBridge {
    // ----------------------------------------------------------- Errors
    error NotOwner();
    error NotRelayer();
    error ZeroAddress();
    error UnsupportedToken();
    error TokenAlreadySupported();
    error DepositTooSmall();
    error InsufficientDeposit();
    error InsufficientWrappedBalance();
    error InvalidAmount();
    error InvalidRequestId();
    error NotRequestOwner();
    error NotFinalized();
    error AlreadyFinalized();
    error AlreadyClaimed();
    error ReentrantCall();
    error TransferFailed();

    // ----------------------------------------------------------- Constants
    uint256 public constant MIN_DEPOSIT = 10;
    uint256 public constant FEE_BASIS_POINTS = 10; // 0.1%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    // ----------------------------------------------------------- State
    address public owner;
    address public relayer;
    uint256 private reentrancyStatus;
    uint256 private requestNonce;

    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens;

    // user => token => deposited amount held on the source chain
    mapping(address => mapping(address => uint256)) public userDeposits;

    // token => total wrapped supply minted on the destination chain
    mapping(address => uint256) public wrappedTotalSupply;
    // user => token => wrapped balance on the destination chain
    mapping(address => mapping(address => uint256)) public wrappedBalances;

    // token => accumulated fees awaiting owner collection
    mapping(address => uint256) public accruedFees;

    struct WithdrawalRequest {
        address user;
        address token;
        uint256 grossAmount;
        uint256 netAmount;
        uint256 fee;
        bool finalized;
        bool claimed;
        uint256 createdAt;
    }
    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;

    // ----------------------------------------------------------- Events
    event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);
    event TokenSupported(address indexed token);
    event TokenRemoved(address indexed token);
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event WithdrawalInitiated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed token,
        uint256 grossAmount,
        uint256 fee
    );
    event WithdrawalFinalized(
        bytes32 indexed requestId,
        address indexed user,
        address indexed token,
        uint256 netAmount,
        uint256 fee
    );
    event WrappedMinted(address indexed token, address indexed to, uint256 amount);
    event WrappedBurned(address indexed token, address indexed from, uint256 amount);
    event TokensClaimed(bytes32 indexed requestId, address indexed user, address indexed token, uint256 amount);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    // ----------------------------------------------------------- Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    modifier supported(address token) {
        if (!isSupportedToken[token]) revert UnsupportedToken();
        _;
    }

    modifier nonReentrant() {
        if (reentrancyStatus == ENTERED) revert ReentrantCall();
        reentrancyStatus = ENTERED;
        _;
        reentrancyStatus = NOT_ENTERED;
    }

    // ----------------------------------------------------------- Constructor
    constructor(address _relayer) {
        if (_relayer == address(0)) revert ZeroAddress();
        owner = msg.sender;
        relayer = _relayer;
        reentrancyStatus = NOT_ENTERED;
        emit OwnerUpdated(address(0), msg.sender);
        emit RelayerUpdated(address(0), _relayer);
    }

    // ----------------------------------------------------------- Admin
    function setOwner(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = _owner;
        emit OwnerUpdated(prev, _owner);
    }

    function setRelayer(address _relayer) external onlyOwner {
        if (_relayer == address(0)) revert ZeroAddress();
        address prev = relayer;
        relayer = _relayer;
        emit RelayerUpdated(prev, _relayer);
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isSupportedToken[token]) revert TokenAlreadySupported();
        isSupportedToken[token] = true;
        supportedTokens.push(token);
        emit TokenSupported(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!isSupportedToken[token]) revert UnsupportedToken();
        isSupportedToken[token] = false;
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (supportedTokens[i] == token) {
                if (i != len - 1) {
                    supportedTokens[i] = supportedTokens[len - 1];
                }
                supportedTokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    // ----------------------------------------------------------- Deposit (source chain)
    function deposit(address token, uint256 amount) external supported(token) nonReentrant {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall();

        // Effects: update internal accounting before the external token transfer
        // (checks-effects-interactions). If the transfer fails the entire call
        // reverts, undoing this state change.
        userDeposits[msg.sender][token] += amount;

        // Interactions: pull tokens from the user. Uses a safe low-level call that
        // tolerates non-standard ERC20 tokens (missing return data) without reading
        // balances before/after the call, avoiding stale-balance reentrancy issues.
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount);
    }

    // ----------------------------------------------------------- Initiate withdrawal (source -> destination)
    function initiateWithdrawal(address token, uint256 amount) external supported(token) nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 available = userDeposits[msg.sender][token];
        if (available < amount) revert InsufficientDeposit();

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 net = amount - fee;

        userDeposits[msg.sender][token] = available - amount;
        accruedFees[token] += fee;

        bytes32 requestId = keccak256(
            abi.encodePacked(msg.sender, token, amount, block.timestamp, block.chainid, requestNonce)
        );
        requestNonce++;

        withdrawalRequests[requestId] = WithdrawalRequest({
            user: msg.sender,
            token: token,
            grossAmount: amount,
            netAmount: net,
            fee: fee,
            finalized: false,
            claimed: false,
            createdAt: block.timestamp
        });

        emit WithdrawalInitiated(requestId, msg.sender, token, amount, fee);
    }

    // ----------------------------------------------------------- Relayer: finalise withdrawal
    function finalizeWithdrawal(bytes32 requestId) external onlyRelayer {
        WithdrawalRequest storage r = withdrawalRequests[requestId];
        if (r.user == address(0)) revert InvalidRequestId();
        if (r.finalized) revert AlreadyFinalized();

        r.finalized = true;

        emit WithdrawalFinalized(requestId, r.user, r.token, r.netAmount, r.fee);
    }

    // ----------------------------------------------------------- User: claim wrapped tokens on destination chain
    function claimWrappedTokens(bytes32 requestId) external nonReentrant {
        WithdrawalRequest storage r = withdrawalRequests[requestId];
        if (r.user == address(0)) revert InvalidRequestId();
        if (r.user != msg.sender) revert NotRequestOwner();
        if (!r.finalized) revert NotFinalized();
        if (r.claimed) revert AlreadyClaimed();

        r.claimed = true;
        wrappedBalances[msg.sender][r.token] += r.netAmount;
        wrappedTotalSupply[r.token] += r.netAmount;

        emit WrappedMinted(r.token, msg.sender, r.netAmount);
        emit TokensClaimed(requestId, msg.sender, r.token, r.netAmount);
    }

    // ----------------------------------------------------------- Relayer: manual mint
    function mintWrapped(address token, address to, uint256 amount) external onlyRelayer supported(token) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        wrappedBalances[to][token] += amount;
        wrappedTotalSupply[token] += amount;

        emit WrappedMinted(token, to, amount);
    }

    // ----------------------------------------------------------- Relayer: manual burn
    function burnWrapped(address token, address from, uint256 amount) external onlyRelayer supported(token) {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 bal = wrappedBalances[from][token];
        if (bal < amount) revert InsufficientWrappedBalance();

        wrappedBalances[from][token] = bal - amount;
        wrappedTotalSupply[token] -= amount;

        emit WrappedBurned(token, from, amount);
    }

    // ----------------------------------------------------------- Owner: withdraw accrued fees
    function withdrawFees(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees[token];
        if (amount == 0) revert InvalidAmount();

        accruedFees[token] = 0;

        _safeTransfer(token, to, amount);

        emit FeesWithdrawn(token, to, amount);
    }

    // ----------------------------------------------------------- Internal safe transfer helpers
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert TransferFailed();
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert TransferFailed();
        }
    }

    // ----------------------------------------------------------- Views
    function getDeposit(address user, address token) external view returns (uint256) {
        return userDeposits[user][token];
    }

    function getWrappedBalance(address user, address token) external view returns (uint256) {
        return wrappedBalances[user][token];
    }

    function getWrappedTotalSupply(address token) external view returns (uint256) {
        return wrappedTotalSupply[token];
    }

    function getAccruedFees(address token) external view returns (uint256) {
        return accruedFees[token];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    function getWithdrawalRequest(bytes32 requestId) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }
}
