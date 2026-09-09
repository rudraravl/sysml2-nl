// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialTokenSystem {
    uint256 public constant FEE_PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_PERCENTAGE = 500;       // 5%
    uint256 public constant DEFAULT_FEE_PERCENTAGE = 50;    // 0.5%

    uint256 public constant BASE_PRICE = 0.001 ether;
    uint256 public constant SLOPE = 0.0001 ether;

    address public operator;
    uint256 public feePercentage; // in basis points
    bool public tradingPaused;
    uint256 public nextTokenId;

    struct SocialToken {
        address issuer;
        uint256 totalSupply;
        uint256 accumulatedFeePerShare;
        bool exists;
    }

    mapping(uint256 => SocialToken) public socialTokens;
    mapping(uint256 => mapping(address => uint256)) public balances;
    mapping(uint256 => mapping(address => uint256)) public feeDebt;

    uint256 private locked = 1;

    event TokenCreated(uint256 indexed tokenId, address indexed issuer);
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 amount, uint256 pricePaid, uint256 fee);
    event Sold(uint256 indexed tokenId, address indexed seller, uint256 amount, uint256 returnAmount, uint256 fee);
    event RewardsClaimed(uint256 indexed tokenId, address indexed user, uint256 amount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event TradingPaused();
    event TradingUnpaused();
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error TokenDoesNotExist();
    error TradingIsPaused();
    error ZeroAmount();
    error InsufficientPayment();
    error InsufficientBalance();
    error FeeExceedsMax();
    error TransferFailed();
    error ReentrantCall();
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (tradingPaused) revert TradingIsPaused();
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        if (!socialTokens[tokenId].exists) revert TokenDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert ReentrantCall();
        locked = 2;
        _;
        locked = 1;
    }

    constructor() {
        operator = msg.sender;
        feePercentage = DEFAULT_FEE_PERCENTAGE;
        nextTokenId = 1;
    }

    function createToken() external notPaused returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        socialTokens[tokenId] = SocialToken({
            issuer: msg.sender,
            totalSupply: 0,
            accumulatedFeePerShare: 0,
            exists: true
        });
        emit TokenCreated(tokenId, msg.sender);
    }

    function buy(uint256 tokenId, uint256 amount)
        external
        payable
        tokenExists(tokenId)
        notPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        SocialToken storage token = socialTokens[tokenId];
        uint256 price = _getBuyPrice(token.totalSupply, amount);
        if (msg.value < price) revert InsufficientPayment();

        uint256 fee = (price * feePercentage) / BASIS_POINTS;

        _distributeFee(tokenId, fee);

        _updateFeeDebt(tokenId, msg.sender, token.accumulatedFeePerShare);

        token.totalSupply += amount;
        balances[tokenId][msg.sender] += amount;

        feeDebt[tokenId][msg.sender] =
            (token.accumulatedFeePerShare * balances[tokenId][msg.sender]) /
            FEE_PRECISION;

        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool ok, ) = msg.sender.call{value: excess}("");
            if (!ok) revert TransferFailed();
        }

        emit Bought(tokenId, msg.sender, amount, price, fee);
    }

    function sell(uint256 tokenId, uint256 amount)
        external
        tokenExists(tokenId)
        notPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        SocialToken storage token = socialTokens[tokenId];
        uint256 userBalance = balances[tokenId][msg.sender];
        if (userBalance < amount) revert InsufficientBalance();

        uint256 grossReturn = _getSellPrice(token.totalSupply, amount);
        uint256 fee = (grossReturn * feePercentage) / BASIS_POINTS;
        uint256 netReturn = grossReturn - fee;

        _distributeFee(tokenId, fee);

        _updateFeeDebt(tokenId, msg.sender, token.accumulatedFeePerShare);

        token.totalSupply -= amount;
        balances[tokenId][msg.sender] -= amount;

        feeDebt[tokenId][msg.sender] =
            (token.accumulatedFeePerShare * balances[tokenId][msg.sender]) /
            FEE_PRECISION;

        (bool ok, ) = msg.sender.call{value: netReturn}("");
        if (!ok) revert TransferFailed();

        emit Sold(tokenId, msg.sender, amount, netReturn, fee);
    }

    function claimRewards(uint256 tokenId)
        external
        tokenExists(tokenId)
        nonReentrant
    {
        SocialToken storage token = socialTokens[tokenId];
        uint256 userBalance = balances[tokenId][msg.sender];

        uint256 pending =
            (token.accumulatedFeePerShare * userBalance) / FEE_PRECISION -
            feeDebt[tokenId][msg.sender];

        if (pending == 0) return;

        feeDebt[tokenId][msg.sender] =
            (token.accumulatedFeePerShare * userBalance) /
            FEE_PRECISION;

        (bool ok, ) = msg.sender.call{value: pending}("");
        if (!ok) revert TransferFailed();

        emit RewardsClaimed(tokenId, msg.sender, pending);
    }

    function setFeePercentage(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE_PERCENTAGE) revert FeeExceedsMax();
        uint256 oldFee = feePercentage;
        feePercentage = newFee;
        emit FeePercentageUpdated(oldFee, newFee);
    }

    function setTradingPaused(bool _paused) external onlyOperator {
        tradingPaused = _paused;
        if (_paused) emit TradingPaused();
        else emit TradingUnpaused();
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getBuyPrice(uint256 tokenId, uint256 amount)
        external
        view
        tokenExists(tokenId)
        returns (uint256)
    {
        return _getBuyPrice(socialTokens[tokenId].totalSupply, amount);
    }

    function getSellPrice(uint256 tokenId, uint256 amount)
        external
        view
        tokenExists(tokenId)
        returns (uint256)
    {
        return _getSellPrice(socialTokens[tokenId].totalSupply, amount);
    }

    function getClaimableRewards(uint256 tokenId, address user)
        external
        view
        tokenExists(tokenId)
        returns (uint256)
    {
        SocialToken storage token = socialTokens[tokenId];
        uint256 userBalance = balances[tokenId][user];
        return
            (token.accumulatedFeePerShare * userBalance) / FEE_PRECISION -
            feeDebt[tokenId][user];
    }

    function getTokenInfo(uint256 tokenId)
        external
        view
        tokenExists(tokenId)
        returns (address issuer, uint256 totalSupply, uint256 accumulatedFeePerShare)
    {
        SocialToken storage token = socialTokens[tokenId];
        return (token.issuer, token.totalSupply, token.accumulatedFeePerShare);
    }

    function getUserShare(uint256 tokenId, address user)
        external
        view
        tokenExists(tokenId)
        returns (uint256 shareBps)
    {
        uint256 supply = socialTokens[tokenId].totalSupply;
        if (supply == 0) return 0;
        return (balances[tokenId][user] * BASIS_POINTS) / supply;
    }

    function _distributeFee(uint256 tokenId, uint256 fee) internal {
        SocialToken storage token = socialTokens[tokenId];
        if (fee > 0 && token.totalSupply > 0) {
            token.accumulatedFeePerShare +=
                (fee * FEE_PRECISION) /
                token.totalSupply;
        }
    }

    function _updateFeeDebt(uint256 tokenId, address user, uint256 accPerShare) internal {
        feeDebt[tokenId][user] =
            (accPerShare * balances[tokenId][user]) /
            FEE_PRECISION;
    }

    function _getBuyPrice(uint256 supply, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return
            amount * BASE_PRICE +
            SLOPE * (supply * amount + (amount * amount) / 2);
    }

    function _getSellPrice(uint256 supply, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return
            amount * BASE_PRICE +
            SLOPE * (supply * amount - (amount * amount) / 2);
    }

    receive() external payable {}
}
