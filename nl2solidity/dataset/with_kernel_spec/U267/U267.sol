// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialTokenExchange {
    // ------------------ Errors ------------------
    error ZeroAmount();
    error TokenNotFound();
    error InsufficientBalance();
    error InsufficientReserve();
    error InsufficientPayment();
    error MaxSupplyExceeded();
    error InvalidCurve();
    error Unauthorized();
    error ZeroAddress();
    error NothingToWithdraw();
    error TransferFailed();
    error ReentrantCall();

    // ------------------ Constants ------------------
    uint256 public constant DECIMALS = 18;
    uint256 public constant ONE_TOKEN = 10 ** 18;
    uint256 public constant MAX_SUPPLY = 1_000_000 * ONE_TOKEN; // 1e24 raw units (1M tokens)
    uint256 public constant MAX_BASE_PRICE = 10 ** 30;
    uint256 public constant MAX_CURVE_NUMERATOR = 10_000;
    uint256 public constant MAX_CURVE_DENOMINATOR = 10 ** 54;
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOM = 10_000;

    // ------------------ Social Token Storage ------------------
    struct TokenData {
        address creator;
        uint256 supply;
        uint256 ethReserve;
        mapping(address => uint256) balances;
    }

    mapping(uint256 => TokenData) private _tokens;
    uint256 public nextTokenId;

    // ------------------ User & Protocol Balances ------------------
    mapping(address => uint256) public userEthBalance;
    uint256 public protocolFees;

    // ------------------ Curve Parameters ------------------
    // Price per raw unit at supply s is:
    //   p(s) = basePrice + (curveNumerator * s * s) / curveDenominator
    // The cost to mint/burn across a supply range is the integral of p(s).
    uint256 public basePrice;        // wei per raw unit
    uint256 public curveNumerator;   // quadratic coefficient numerator
    uint256 public curveDenominator; // quadratic coefficient denominator

    // ------------------ Operator ------------------
    address public operator;

    // ------------------ Reentrancy Guard ------------------
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ------------------ Events ------------------
    event TokenCreated(uint256 indexed tokenId, address indexed creator);
    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 amount, uint256 ethPaid, uint256 fee);
    event Sell(address indexed seller, uint256 indexed tokenId, uint256 amount, uint256 ethReceived, uint256 fee);
    event Withdraw(address indexed user, uint256 amount);
    event FeeWithdrawn(address indexed operator, uint256 amount);
    event CurveUpdated(uint256 basePrice, uint256 numerator, uint256 denominator);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ------------------ Modifiers ------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ------------------ Constructor ------------------
    constructor(
        uint256 _basePrice,
        uint256 _curveNumerator,
        uint256 _curveDenominator,
        address _operator
    ) {
        if (_curveDenominator == 0 || _curveDenominator > MAX_CURVE_DENOMINATOR) revert InvalidCurve();
        if (_curveNumerator > MAX_CURVE_NUMERATOR) revert InvalidCurve();
        if (_basePrice > MAX_BASE_PRICE) revert InvalidCurve();
        if (_operator == address(0)) revert ZeroAddress();

        basePrice = _basePrice;
        curveNumerator = _curveNumerator;
        curveDenominator = _curveDenominator;
        operator = _operator;
        _status = _NOT_ENTERED;

        emit CurveUpdated(_basePrice, _curveNumerator, _curveDenominator);
        emit OperatorUpdated(address(0), _operator);
    }

    // ------------------ Operator Management ------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    // ------------------ Curve Management ------------------
    function setCurve(
        uint256 _basePrice,
        uint256 _curveNumerator,
        uint256 _curveDenominator
    ) external onlyOperator {
        if (_curveDenominator == 0 || _curveDenominator > MAX_CURVE_DENOMINATOR) revert InvalidCurve();
        if (_curveNumerator > MAX_CURVE_NUMERATOR) revert InvalidCurve();
        if (_basePrice > MAX_BASE_PRICE) revert InvalidCurve();

        basePrice = _basePrice;
        curveNumerator = _curveNumerator;
        curveDenominator = _curveDenominator;

        emit CurveUpdated(_basePrice, _curveNumerator, _curveDenominator);
    }

    // ------------------ Token Creation ------------------
    function createToken() external returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _tokens[tokenId].creator = msg.sender;
        emit TokenCreated(tokenId, msg.sender);
    }

    // ------------------ Buy ------------------
    function buy(uint256 tokenId, uint256 amount) external payable {
        if (amount == 0) revert ZeroAmount();
        TokenData storage t = _tokens[tokenId];
        if (t.creator == address(0)) revert TokenNotFound();

        if (amount > MAX_SUPPLY - t.supply) revert MaxSupplyExceeded();
        uint256 newSupply = t.supply + amount;

        uint256 cost = _curveCost(t.supply, newSupply);
        uint256 fee = (cost * FEE_BPS) / BPS_DENOM;
        uint256 totalNeeded = cost + fee;

        if (msg.value < totalNeeded) revert InsufficientPayment();

        uint256 creatorFee = fee / 2;
        uint256 protocolFee = fee - creatorFee;

        // Effects
        t.supply = newSupply;
        t.ethReserve += cost;
        t.balances[msg.sender] += amount;

        userEthBalance[t.creator] += creatorFee;
        protocolFees += protocolFee;

        // Refund any overpayment to the user's withdrawable Ether balance.
        if (msg.value > totalNeeded) {
            userEthBalance[msg.sender] += (msg.value - totalNeeded);
        }

        emit Buy(msg.sender, tokenId, amount, totalNeeded, fee);
    }

    // ------------------ Sell ------------------
    function sell(uint256 tokenId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        TokenData storage t = _tokens[tokenId];
        if (t.creator == address(0)) revert TokenNotFound();
        if (t.balances[msg.sender] < amount) revert InsufficientBalance();

        uint256 newSupply = t.supply - amount;
        uint256 ret = _curveCost(newSupply, t.supply);
        if (t.ethReserve < ret) revert InsufficientReserve();

        uint256 fee = (ret * FEE_BPS) / BPS_DENOM;
        uint256 creatorFee = fee / 2;
        uint256 protocolFee = fee - creatorFee;
        uint256 userRet = ret - fee;

        // Effects
        t.supply = newSupply;
        t.ethReserve -= ret;
        t.balances[msg.sender] -= amount;

        userEthBalance[msg.sender] += userRet;
        userEthBalance[t.creator] += creatorFee;
        protocolFees += protocolFee;

        emit Sell(msg.sender, tokenId, amount, userRet, fee);
    }

    // ------------------ Withdraw User Ether ------------------
    function withdrawEth() external nonReentrant {
        uint256 amount = userEthBalance[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        userEthBalance[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit Withdraw(msg.sender, amount);
    }

    // ------------------ Withdraw Protocol Fees ------------------
    function withdrawFees() external onlyOperator nonReentrant {
        uint256 amount = protocolFees;
        if (amount == 0) revert NothingToWithdraw();
        protocolFees = 0;
        (bool sent, ) = operator.call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit FeeWithdrawn(operator, amount);
    }

    // ------------------ Curve Math ------------------
    /// @dev Integral of p(s) = basePrice + (curveNumerator * s^2) / curveDenominator
    /// from `fromSupply` to `toSupply`, in wei. Supply is in raw units (1e18 = 1 token).
    function _curveCost(uint256 fromSupply, uint256 toSupply) internal view returns (uint256) {
        uint256 linear = basePrice * (toSupply - fromSupply);

        uint256 toCubic = toSupply * toSupply * toSupply;
        uint256 fromCubic = fromSupply * fromSupply * fromSupply;
        uint256 cubic = (curveNumerator * (toCubic - fromCubic)) / (3 * curveDenominator);

        return linear + cubic;
    }

    // ------------------ Views ------------------
    function balanceOf(uint256 tokenId, address account) external view returns (uint256) {
        return _tokens[tokenId].balances[account];
    }

    function supplyOf(uint256 tokenId) external view returns (uint256) {
        return _tokens[tokenId].supply;
    }

    function ethReserveOf(uint256 tokenId) external view returns (uint256) {
        return _tokens[tokenId].ethReserve;
    }

    function creatorOf(uint256 tokenId) external view returns (address) {
        return _tokens[tokenId].creator;
    }

    function getBuyCost(uint256 tokenId, uint256 amount) external view returns (uint256 total) {
        TokenData storage t = _tokens[tokenId];
        if (t.creator == address(0)) revert TokenNotFound();
        if (amount > MAX_SUPPLY - t.supply) revert MaxSupplyExceeded();
        uint256 newSupply = t.supply + amount;
        uint256 cost = _curveCost(t.supply, newSupply);
        uint256 fee = (cost * FEE_BPS) / BPS_DENOM;
        return cost + fee;
    }

    function getSellReturn(uint256 tokenId, uint256 amount) external view returns (uint256 userReturn) {
        TokenData storage t = _tokens[tokenId];
        if (t.creator == address(0)) revert TokenNotFound();
        if (amount > t.supply) revert InsufficientBalance();
        uint256 newSupply = t.supply - amount;
        uint256 ret = _curveCost(newSupply, t.supply);
        uint256 fee = (ret * FEE_BPS) / BPS_DENOM;
        return ret - fee;
    }
}
