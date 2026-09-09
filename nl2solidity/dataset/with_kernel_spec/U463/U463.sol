// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenizedPortfolios {
    address public operator;
    uint256 public mintFeeBps;

    struct Portfolio {
        address baseToken;
        address[] tokens;
        uint256[] weights;
        bool active;
    }

    mapping(uint256 => Portfolio) private portfolios;
    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public minDeposit;

    uint256 public nextPortfolioId;

    uint256 public constant MAX_BPS = 10000;
    uint256 public constant DEFAULT_MINT_FEE_BPS = 10; // 0.1%
    uint256 public constant MIN_MIN_DEPOSIT = 100;

    event PortfolioCreated(
        uint256 indexed portfolioId,
        address indexed caller,
        address indexed baseToken,
        address[] tokens,
        uint256[] weights
    );
    event Minted(uint256 indexed portfolioId, address indexed caller, uint256 amount);
    event Redeemed(uint256 indexed portfolioId, address indexed caller, uint256 amount);
    event Transfer(uint256 indexed portfolioId, address indexed from, address indexed to, uint256 amount);
    event MintFeeUpdated(uint256 newFeeBps);
    event MinDepositUpdated(uint256 indexed portfolioId, uint256 newMinDeposit);

    error Unauthorized();
    error ZeroAddress();
    error InvalidArrayLength();
    error InvalidWeightSum();
    error InsufficientDeposit(uint256 required, uint256 provided);
    error InsufficientBalance(uint256 available, uint256 needed);
    error MinDepositTooLow();
    error InvalidFee();
    error PortfolioNotActive();
    error PortfolioNotFound();
    error TransferFailed();
    error ZeroAmount();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier portfolioExists(uint256 portfolioId) {
        if (portfolioId >= nextPortfolioId || !portfolios[portfolioId].active) revert PortfolioNotFound();
        _;
    }

    constructor() {
        operator = msg.sender;
        mintFeeBps = DEFAULT_MINT_FEE_BPS;
    }

    function createPortfolio(
        address baseToken,
        address[] calldata tokens,
        uint256[] calldata weights
    ) external returns (uint256 portfolioId) {
        if (baseToken == address(0)) revert ZeroAddress();
        if (tokens.length != weights.length) revert InvalidArrayLength();
        if (tokens.length == 0) revert InvalidArrayLength();

        uint256 weightSum = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            weightSum += weights[i];
        }
        if (weightSum != 1e18) revert InvalidWeightSum();

        portfolioId = nextPortfolioId++;

        Portfolio storage p = portfolios[portfolioId];
        p.baseToken = baseToken;
        p.tokens = tokens;
        p.weights = weights;
        p.active = true;

        minDeposit[portfolioId] = MIN_MIN_DEPOSIT;

        emit PortfolioCreated(portfolioId, msg.sender, baseToken, tokens, weights);
    }

    function deposit(uint256 portfolioId, uint256 amount) external portfolioExists(portfolioId) {
        if (amount == 0) revert ZeroAmount();
        if (amount < minDeposit[portfolioId]) revert InsufficientDeposit(minDeposit[portfolioId], amount);

        Portfolio storage p = portfolios[portfolioId];

        uint256 fee = (amount * mintFeeBps) / MAX_BPS;
        uint256 mintAmount = amount - fee;

        balanceOf[portfolioId][msg.sender] += mintAmount;
        totalSupply[portfolioId] += mintAmount;

        if (!IERC20(p.baseToken).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        if (fee > 0) {
            if (!IERC20(p.baseToken).transfer(operator, fee)) {
                revert TransferFailed();
            }
        }

        emit Minted(portfolioId, msg.sender, mintAmount);
    }

    function redeem(uint256 portfolioId, uint256 amount) external portfolioExists(portfolioId) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[portfolioId][msg.sender] < amount) {
            revert InsufficientBalance(balanceOf[portfolioId][msg.sender], amount);
        }

        Portfolio storage p = portfolios[portfolioId];

        balanceOf[portfolioId][msg.sender] -= amount;
        totalSupply[portfolioId] -= amount;

        if (!IERC20(p.baseToken).transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

        emit Redeemed(portfolioId, msg.sender, amount);
    }

    function transfer(uint256 portfolioId, address to, uint256 amount) external portfolioExists(portfolioId) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[portfolioId][msg.sender] < amount) {
            revert InsufficientBalance(balanceOf[portfolioId][msg.sender], amount);
        }

        balanceOf[portfolioId][msg.sender] -= amount;
        balanceOf[portfolioId][to] += amount;

        emit Transfer(portfolioId, msg.sender, to, amount);
    }

    function setMintFee(uint256 _mintFeeBps) external onlyOperator {
        if (_mintFeeBps > MAX_BPS) revert InvalidFee();
        mintFeeBps = _mintFeeBps;
        emit MintFeeUpdated(_mintFeeBps);
    }

    function setMinDeposit(uint256 portfolioId, uint256 _minDeposit) external onlyOperator portfolioExists(portfolioId) {
        if (_minDeposit < MIN_MIN_DEPOSIT) revert MinDepositTooLow();
        minDeposit[portfolioId] = _minDeposit;
        emit MinDepositUpdated(portfolioId, _minDeposit);
    }

    function getPortfolio(uint256 portfolioId)
        external
        view
        returns (address baseToken, address[] memory tokens, uint256[] memory weights, bool active)
    {
        if (portfolioId >= nextPortfolioId) revert PortfolioNotFound();
        Portfolio storage p = portfolios[portfolioId];
        return (p.baseToken, p.tokens, p.weights, p.active);
    }

    function getPortfolioBalance(uint256 portfolioId, address account) external view returns (uint256) {
        return balanceOf[portfolioId][account];
    }
}
