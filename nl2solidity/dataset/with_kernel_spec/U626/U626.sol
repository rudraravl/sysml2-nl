// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LiquidityPoolFactory {
    error NotAdmin();
    error Paused();
    error PoolNotFound();
    error ZeroAddress();
    error InvalidGoal();
    error InvalidAmount();
    error EmptyComment();
    error PoolAlreadyFunded();
    error PoolNotFunded();
    error NoContribution();
    error AlreadyClaimed();
    error NotCreator();
    error NoFeesToClaim();
    error InvalidFee();
    error TransferFailed();
    error ReentrancyDetected();

    event PoolCreated(
        uint256 indexed poolId,
        address indexed creator,
        address indexed baseToken,
        address projectToken,
        uint256 fundingGoal,
        uint256 projectTokenSupply
    );
    event Contributed(
        uint256 indexed poolId,
        address indexed contributor,
        uint256 amount,
        uint256 totalDeposited
    );
    event PoolFunded(
        uint256 indexed poolId,
        uint256 totalDeposited,
        uint256 feeAmount
    );
    event CommentPosted(
        uint256 indexed poolId,
        address indexed author,
        string content,
        uint256 commentId,
        uint256 timestamp
    );
    event ProjectTokensClaimed(
        uint256 indexed poolId,
        address indexed contributor,
        uint256 amount
    );
    event BaseTokensClaimed(
        uint256 indexed poolId,
        address indexed creator,
        uint256 amount
    );
    event FeesClaimed(address indexed admin, address indexed token, uint256 amount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event PausedChanged(bool paused);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    uint256 public constant MIN_GOAL = 100;
    uint256 public constant MAX_GOAL = 1_000_000;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%

    address public admin;
    uint256 public feePercentage; // in basis points
    bool public paused;
    uint256 public poolCount;

    struct Comment {
        address author;
        string content;
        uint256 timestamp;
    }

    struct Pool {
        address creator;
        address baseToken;
        address projectToken;
        uint256 fundingGoal;
        uint256 totalDeposited;
        uint256 projectTokenSupply;
        bool funded;
        bool creatorClaimed;
        mapping(address => uint256) contributions;
        mapping(address => bool) claimed;
        Comment[] comments;
    }

    mapping(uint256 => Pool) private pools;
    mapping(address => uint256) public pendingFees; // token => accumulated fee

    uint256 private _locked = 1;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (poolId >= poolCount) revert PoolNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        admin = msg.sender;
        feePercentage = DEFAULT_FEE_BPS;
        emit FeePercentageUpdated(0, DEFAULT_FEE_BPS);
    }

    function createPool(
        address baseToken,
        address projectToken,
        uint256 fundingGoal,
        uint256 projectTokenAmount,
        uint256 initialBaseContribution
    ) external whenNotPaused nonReentrant returns (uint256 poolId) {
        if (baseToken == address(0) || projectToken == address(0)) revert ZeroAddress();
        if (fundingGoal < MIN_GOAL || fundingGoal > MAX_GOAL) revert InvalidGoal();
        if (projectTokenAmount == 0) revert InvalidAmount();
        if (initialBaseContribution > fundingGoal) revert InvalidAmount();

        poolId = poolCount++;
        Pool storage p = pools[poolId];
        p.creator = msg.sender;
        p.baseToken = baseToken;
        p.projectToken = projectToken;
        p.fundingGoal = fundingGoal;
        p.projectTokenSupply = projectTokenAmount;

        // Effects before interactions: record initial contribution state prior to external transfers.
        if (initialBaseContribution > 0) {
            p.contributions[msg.sender] += initialBaseContribution;
            p.totalDeposited += initialBaseContribution;

            if (p.totalDeposited >= p.fundingGoal) {
                p.funded = true;
                uint256 feeAmount = (p.totalDeposited * feePercentage) / FEE_DENOMINATOR;
                pendingFees[baseToken] += feeAmount;
                emit PoolFunded(poolId, p.totalDeposited, feeAmount);
            }

            emit Contributed(poolId, msg.sender, initialBaseContribution, p.totalDeposited);
        }

        // Interactions: pull project tokens and base tokens from creator.
        if (!IERC20(projectToken).transferFrom(msg.sender, address(this), projectTokenAmount)) {
            revert TransferFailed();
        }

        if (initialBaseContribution > 0) {
            if (!IERC20(baseToken).transferFrom(msg.sender, address(this), initialBaseContribution)) {
                revert TransferFailed();
            }
        }

        emit PoolCreated(poolId, msg.sender, baseToken, projectToken, fundingGoal, projectTokenAmount);
    }

    function contribute(uint256 poolId, uint256 amount) external poolExists(poolId) whenNotPaused nonReentrant {
        Pool storage p = pools[poolId];
        if (p.funded) revert PoolAlreadyFunded();
        if (amount == 0) revert InvalidAmount();

        uint256 remaining = p.fundingGoal - p.totalDeposited;
        if (amount > remaining) {
            amount = remaining;
        }

        // Effects before interactions.
        p.contributions[msg.sender] += amount;
        p.totalDeposited += amount;

        if (p.totalDeposited >= p.fundingGoal) {
            p.funded = true;
            uint256 feeAmount = (p.totalDeposited * feePercentage) / FEE_DENOMINATOR;
            pendingFees[p.baseToken] += feeAmount;
            emit PoolFunded(poolId, p.totalDeposited, feeAmount);
        }

        emit Contributed(poolId, msg.sender, amount, p.totalDeposited);

        // Interaction.
        if (!IERC20(p.baseToken).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }
    }

    function claim(uint256 poolId) external poolExists(poolId) nonReentrant {
        Pool storage p = pools[poolId];
        if (!p.funded) revert PoolNotFunded();
        if (p.claimed[msg.sender]) revert AlreadyClaimed();

        uint256 contribution = p.contributions[msg.sender];
        if (contribution == 0) revert NoContribution();

        // Effects before interactions.
        p.claimed[msg.sender] = true;
        p.contributions[msg.sender] = 0;

        uint256 share = (contribution * p.projectTokenSupply) / p.fundingGoal;

        // Interaction.
        if (!IERC20(p.projectToken).transfer(msg.sender, share)) revert TransferFailed();
        emit ProjectTokensClaimed(poolId, msg.sender, share);
    }

    function claimBaseTokens(uint256 poolId) external poolExists(poolId) nonReentrant {
        Pool storage p = pools[poolId];
        if (msg.sender != p.creator) revert NotCreator();
        if (!p.funded) revert PoolNotFunded();
        if (p.creatorClaimed) revert AlreadyClaimed();

        // Effects before interactions.
        p.creatorClaimed = true;

        uint256 feeAmount = (p.totalDeposited * feePercentage) / FEE_DENOMINATOR;
        uint256 payout = p.totalDeposited - feeAmount;

        // Interaction.
        if (!IERC20(p.baseToken).transfer(p.creator, payout)) revert TransferFailed();
        emit BaseTokensClaimed(poolId, p.creator, payout);
    }

    function postComment(uint256 poolId, string calldata content) external poolExists(poolId) {
        if (bytes(content).length == 0) revert EmptyComment();
        Pool storage p = pools[poolId];
        uint256 commentId = p.comments.length;
        p.comments.push(Comment({author: msg.sender, content: content, timestamp: block.timestamp}));
        emit CommentPosted(poolId, msg.sender, content, commentId, block.timestamp);
    }

    function setFeePercentage(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > FEE_DENOMINATOR) revert InvalidFee();
        uint256 old = feePercentage;
        feePercentage = newFeeBps;
        emit FeePercentageUpdated(old, newFeeBps);
    }

    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
        emit PausedChanged(_paused);
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminUpdated(old, newAdmin);
    }

    function claimFees(address token) external onlyAdmin nonReentrant {
        uint256 amount = pendingFees[token];
        if (amount == 0) revert NoFeesToClaim();
        // Effects before interactions.
        pendingFees[token] = 0;
        if (!IERC20(token).transfer(admin, amount)) revert TransferFailed();
        emit FeesClaimed(admin, token, amount);
    }

    function getPool(uint256 poolId)
        external
        view
        poolExists(poolId)
        returns (
            address creator,
            address baseToken,
            address projectToken,
            uint256 fundingGoal,
            uint256 totalDeposited,
            uint256 projectTokenSupply,
            bool funded,
            bool creatorClaimed,
            uint256 commentCount
        )
    {
        Pool storage p = pools[poolId];
        return (
            p.creator,
            p.baseToken,
            p.projectToken,
            p.fundingGoal,
            p.totalDeposited,
            p.projectTokenSupply,
            p.funded,
            p.creatorClaimed,
            p.comments.length
        );
    }

    function getContribution(uint256 poolId, address contributor) external view poolExists(poolId) returns (uint256) {
        return pools[poolId].contributions[contributor];
    }

    function hasClaimed(uint256 poolId, address contributor) external view poolExists(poolId) returns (bool) {
        return pools[poolId].claimed[contributor];
    }

    function getComment(uint256 poolId, uint256 index)
        external
        view
        poolExists(poolId)
        returns (address author, string memory content, uint256 timestamp)
    {
        Comment storage c = pools[poolId].comments[index];
        return (c.author, c.content, c.timestamp);
    }

    function getCommentCount(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return pools[poolId].comments.length;
    }

    function projectTokenBalance(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return IERC20(pools[poolId].projectToken).balanceOf(address(this));
    }
}
