// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function getPrice() external view returns (uint256);
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract StablecoinSystem {
    error NotOwner();
    error NotOperator();
    error Paused();
    error ZeroAddress();
    error StablecoinNotRegistered();
    error StablecoinAlreadyRegistered();
    error CollateralNotApproved();
    error InsufficientBalance();
    error InsufficientCollateral();
    error CollateralRatioTooLow();
    error SameStablecoinSwap();
    error ZeroAmount();
    error TransferFailed();
    error InvalidPrice();
    error ReentrancyDetected();

    event StablecoinRegistered(bytes32 indexed id, string name, string symbol, address oracle, uint256 collateralRatio);
    event CollateralApproved(address indexed token, address oracle);
    event CollateralRatioUpdated(bytes32 indexed id, uint256 oldRatio, uint256 newRatio);
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateral, uint256 amount);
    event Minted(address indexed user, bytes32 indexed id, address indexed collateral, uint256 collateralAmount, uint256 stablecoinAmount);
    event Redeemed(address indexed user, bytes32 indexed id, address indexed collateral, uint256 stablecoinAmount, uint256 collateralAmount);
    event Transferred(address indexed from, address indexed to, bytes32 indexed id, uint256 amount);
    event Swapped(address indexed user, bytes32 indexed fromId, bytes32 indexed toId, uint256 amountIn, uint256 amountOut);
    event PausedStateChanged(bool mintingPaused, bool redemptionPaused);
    event OperatorSet(address indexed operator);

    uint256 public constant MIN_COLLATERAL_RATIO = 11000; // 110% in basis points
    uint256 public constant SWAP_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    struct StablecoinConfig {
        bool registered;
        string name;
        string symbol;
        IOracle oracle;
        uint256 collateralRatio; // in basis points
    }

    struct CollateralConfig {
        bool approved;
        IOracle oracle;
        uint8 decimals;
    }

    address public owner;
    address public operator;
    bool public mintingPaused;
    bool public redemptionPaused;

    mapping(bytes32 => StablecoinConfig) public stablecoins;
    bytes32[] public stablecoinIds;

    mapping(address => CollateralConfig) public collaterals;
    address[] public collateralList;

    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(bytes32 => mapping(address => uint256)) public stablecoinBalances;
    mapping(bytes32 => uint256) public totalSupply;
    mapping(address => uint256) public totalCollateral;

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenMintNotPaused() {
        if (mintingPaused) revert Paused();
        _;
    }

    modifier whenRedeemNotPaused() {
        if (redemptionPaused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _owner, address _operator) {
        if (_owner == address(0) || _operator == address(0)) revert ZeroAddress();
        owner = _owner;
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function setPaused(bool _mintingPaused, bool _redemptionPaused) external onlyOperator {
        mintingPaused = _mintingPaused;
        redemptionPaused = _redemptionPaused;
        emit PausedStateChanged(_mintingPaused, _redemptionPaused);
    }

    function registerStablecoin(
        bytes32 id,
        string calldata name,
        string calldata symbol,
        address oracle,
        uint256 collateralRatio
    ) external onlyOwner {
        if (oracle == address(0)) revert ZeroAddress();
        if (collateralRatio < MIN_COLLATERAL_RATIO) revert CollateralRatioTooLow();
        if (stablecoins[id].registered) revert StablecoinAlreadyRegistered();
        stablecoins[id] = StablecoinConfig({
            registered: true,
            name: name,
            symbol: symbol,
            oracle: IOracle(oracle),
            collateralRatio: collateralRatio
        });
        stablecoinIds.push(id);
        emit StablecoinRegistered(id, name, symbol, oracle, collateralRatio);
    }

    function approveCollateral(address token, address oracle) external onlyOwner {
        if (token == address(0) || oracle == address(0)) revert ZeroAddress();
        if (!collaterals[token].approved) {
            collateralList.push(token);
        }
        collaterals[token] = CollateralConfig({
            approved: true,
            oracle: IOracle(oracle),
            decimals: IERC20(token).decimals()
        });
        emit CollateralApproved(token, oracle);
    }

    function updateCollateralRatio(bytes32 id, uint256 newRatio) external onlyOwner {
        StablecoinConfig storage cfg = stablecoins[id];
        if (!cfg.registered) revert StablecoinNotRegistered();
        if (newRatio < MIN_COLLATERAL_RATIO) revert CollateralRatioTooLow();
        uint256 old = cfg.collateralRatio;
        cfg.collateralRatio = newRatio;
        emit CollateralRatioUpdated(id, old, newRatio);
    }

    function depositCollateral(address collateral, uint256 amount) external nonReentrant {
        CollateralConfig storage cc = collaterals[collateral];
        if (!cc.approved) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external interactions
        collateralBalances[msg.sender][collateral] += amount;
        totalCollateral[collateral] += amount;

        // Interactions
        if (!IERC20(collateral).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    function withdrawCollateral(address collateral, uint256 amount) external nonReentrant {
        CollateralConfig storage cc = collaterals[collateral];
        if (!cc.approved) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender][collateral] < amount) revert InsufficientCollateral();

        // Effects: update state before external interactions
        collateralBalances[msg.sender][collateral] -= amount;
        totalCollateral[collateral] -= amount;

        // Interactions
        if (!IERC20(collateral).transfer(msg.sender, amount)) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, collateral, amount);
    }

    function mint(bytes32 id, address collateral, uint256 collateralAmount) external whenMintNotPaused nonReentrant {
        StablecoinConfig storage sc = stablecoins[id];
        if (!sc.registered) revert StablecoinNotRegistered();
        CollateralConfig storage cc = collaterals[collateral];
        if (!cc.approved) revert CollateralNotApproved();
        if (collateralAmount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender][collateral] < collateralAmount) revert InsufficientCollateral();

        uint256 collateralPrice = cc.oracle.getPrice();
        uint256 stablecoinFxRate = sc.oracle.getPrice();
        if (collateralPrice == 0 || stablecoinFxRate == 0) revert InvalidPrice();

        // Compute stablecoin amount without divide-before-multiply:
        // stablecoinAmount = collateralAmount * collateralPrice * BPS_DENOMINATOR * PRECISION
        //                   / (10^decimals * stablecoinFxRate * collateralRatio)
        uint256 stablecoinAmount = (collateralAmount * collateralPrice * BPS_DENOMINATOR * PRECISION)
            / ((10 ** cc.decimals) * stablecoinFxRate * sc.collateralRatio);
        if (stablecoinAmount == 0) revert ZeroAmount();

        // Effects
        collateralBalances[msg.sender][collateral] -= collateralAmount;
        totalCollateral[collateral] -= collateralAmount;

        stablecoinBalances[id][msg.sender] += stablecoinAmount;
        totalSupply[id] += stablecoinAmount;

        emit Minted(msg.sender, id, collateral, collateralAmount, stablecoinAmount);
    }

    function redeem(bytes32 id, address collateral, uint256 stablecoinAmount) external whenRedeemNotPaused nonReentrant {
        StablecoinConfig storage sc = stablecoins[id];
        if (!sc.registered) revert StablecoinNotRegistered();
        CollateralConfig storage cc = collaterals[collateral];
        if (!cc.approved) revert CollateralNotApproved();
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (stablecoinBalances[id][msg.sender] < stablecoinAmount) revert InsufficientBalance();

        uint256 collateralPrice = cc.oracle.getPrice();
        uint256 stablecoinFxRate = sc.oracle.getPrice();
        if (collateralPrice == 0 || stablecoinFxRate == 0) revert InvalidPrice();

        // Compute collateral amount without divide-before-multiply:
        // collateralAmount = stablecoinAmount * stablecoinFxRate * collateralRatio * 10^decimals
        //                   / (PRECISION * BPS_DENOMINATOR * collateralPrice)
        uint256 collateralAmount = (stablecoinAmount * stablecoinFxRate * sc.collateralRatio * (10 ** cc.decimals))
            / (PRECISION * BPS_DENOMINATOR * collateralPrice);

        if (collateralAmount == 0) revert ZeroAmount();
        if (totalCollateral[collateral] < collateralAmount) revert InsufficientCollateral();

        // Effects
        stablecoinBalances[id][msg.sender] -= stablecoinAmount;
        totalSupply[id] -= stablecoinAmount;

        totalCollateral[collateral] += collateralAmount;
        collateralBalances[msg.sender][collateral] += collateralAmount;

        emit Redeemed(msg.sender, id, collateral, stablecoinAmount, collateralAmount);
    }

    function transfer(bytes32 id, address to, uint256 amount) external {
        StablecoinConfig storage sc = stablecoins[id];
        if (!sc.registered) revert StablecoinNotRegistered();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (stablecoinBalances[id][msg.sender] < amount) revert InsufficientBalance();

        stablecoinBalances[id][msg.sender] -= amount;
        stablecoinBalances[id][to] += amount;
        emit Transferred(msg.sender, to, id, amount);
    }

    function swap(bytes32 fromId, bytes32 toId, uint256 amountIn) external {
        StablecoinConfig storage scFrom = stablecoins[fromId];
        StablecoinConfig storage scTo = stablecoins[toId];
        if (!scFrom.registered || !scTo.registered) revert StablecoinNotRegistered();
        if (fromId == toId) revert SameStablecoinSwap();
        if (amountIn == 0) revert ZeroAmount();
        if (stablecoinBalances[fromId][msg.sender] < amountIn) revert InsufficientBalance();

        uint256 fromFx = scFrom.oracle.getPrice();
        uint256 toFx = scTo.oracle.getPrice();
        if (fromFx == 0 || toFx == 0) revert InvalidPrice();

        // amountOut = amountIn * fromFx * (BPS - fee) / (BPS * toFx)
        uint256 amountOut = (amountIn * fromFx * (BPS_DENOMINATOR - SWAP_FEE_BPS)) / (BPS_DENOMINATOR * toFx);
        if (amountOut == 0) revert ZeroAmount();

        stablecoinBalances[fromId][msg.sender] -= amountIn;
        totalSupply[fromId] -= amountIn;

        stablecoinBalances[toId][msg.sender] += amountOut;
        totalSupply[toId] += amountOut;

        emit Swapped(msg.sender, fromId, toId, amountIn, amountOut);
    }

    function balanceOf(bytes32 id, address user) external view returns (uint256) {
        return stablecoinBalances[id][user];
    }

    function collateralOf(address user, address collateral) external view returns (uint256) {
        return collateralBalances[user][collateral];
    }

    function getStablecoinConfig(bytes32 id)
        external
        view
        returns (string memory name, string memory symbol, address oracle, uint256 collateralRatio, bool registered)
    {
        StablecoinConfig storage sc = stablecoins[id];
        return (sc.name, sc.symbol, address(sc.oracle), sc.collateralRatio, sc.registered);
    }

    function getCollateralConfig(address token)
        external
        view
        returns (bool approved, address oracle, uint8 decimals)
    {
        CollateralConfig storage cc = collaterals[token];
        return (cc.approved, address(cc.oracle), cc.decimals);
    }

    function getStablecoinIds() external view returns (bytes32[] memory) {
        return stablecoinIds;
    }

    function getCollateralList() external view returns (address[] memory) {
        return collateralList;
    }

    function getMintableAmount(bytes32 id, address collateral, uint256 collateralAmount)
        external
        view
        returns (uint256)
    {
        StablecoinConfig storage sc = stablecoins[id];
        CollateralConfig storage cc = collaterals[collateral];
        if (!sc.registered || !cc.approved) return 0;
        uint256 collateralPrice = cc.oracle.getPrice();
        uint256 stablecoinFxRate = sc.oracle.getPrice();
        if (collateralPrice == 0 || stablecoinFxRate == 0) return 0;
        // Combined expression to avoid divide-before-multiply
        return (collateralAmount * collateralPrice * BPS_DENOMINATOR * PRECISION)
            / ((10 ** cc.decimals) * stablecoinFxRate * sc.collateralRatio);
    }

    function getRedeemableAmount(bytes32 id, address collateral, uint256 stablecoinAmount)
        external
        view
        returns (uint256)
    {
        StablecoinConfig storage sc = stablecoins[id];
        CollateralConfig storage cc = collaterals[collateral];
        if (!sc.registered || !cc.approved) return 0;
        uint256 collateralPrice = cc.oracle.getPrice();
        uint256 stablecoinFxRate = sc.oracle.getPrice();
        if (collateralPrice == 0 || stablecoinFxRate == 0) return 0;
        // Combined expression to avoid divide-before-multiply
        return (stablecoinAmount * stablecoinFxRate * sc.collateralRatio * (10 ** cc.decimals))
            / (PRECISION * BPS_DENOMINATOR * collateralPrice);
    }

    function getSwapOutput(bytes32 fromId, bytes32 toId, uint256 amountIn) external view returns (uint256) {
        StablecoinConfig storage scFrom = stablecoins[fromId];
        StablecoinConfig storage scTo = stablecoins[toId];
        if (!scFrom.registered || !scTo.registered || fromId == toId) return 0;
        uint256 fromFx = scFrom.oracle.getPrice();
        uint256 toFx = scTo.oracle.getPrice();
        if (fromFx == 0 || toFx == 0) return 0;
        return (amountIn * fromFx * (BPS_DENOMINATOR - SWAP_FEE_BPS)) / (BPS_DENOMINATOR * toFx);
    }
}
