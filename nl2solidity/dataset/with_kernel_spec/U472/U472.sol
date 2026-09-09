// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    constructor() {
        _status = NOT_ENTERED;
    }
}

contract StableSwap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PRICE_PRECISION = 1e18;
    uint16 public constant BPS_DENOM = 10000;
    uint16 public constant MAX_DEVIATION_BPS = 50;
    uint16 public constant FEE_BPS = 10;
    uint256 private constant MIN_OUTPUT = 1;

    address public operator;
    address public treasury;
    bool public paused;

    struct StableToken {
        address reserveToken;
        bool supported;
    }

    mapping(address => StableToken) public stableTokens;
    mapping(address => address) public reserveTokenOf;

    address[] internal _supportedTokens;
    mapping(address => uint256) internal _tokenIndex;

    struct PairConfig {
        uint256 targetPrice;
        uint16 deviationTolerance;
        bool exists;
    }

    mapping(address => mapping(address => PairConfig)) public pairConfigs;

    mapping(address => mapping(address => uint256)) public userDeposits;

    event Exchange(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event LiquidityAdded(
        address indexed sender,
        address indexed stableToken,
        address indexed reserveToken,
        uint256 amount
    );
    event LiquidityWithdrawn(
        address indexed sender,
        address indexed stableToken,
        address indexed reserveToken,
        uint256 amount
    );
    event StableTokenAdded(address indexed token, address indexed reserveToken);
    event PairConfigUpdated(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 targetPrice,
        uint16 deviationTolerance
    );
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error ContractIsPaused();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);
    error PairNotSupported(address tokenIn, address tokenOut);
    error InvalidTargetPrice();
    error InvalidDeviationTolerance(uint16 tolerance);
    error DeviationExceeded(uint256 deviation, uint16 tolerance);
    error InsufficientOutput(uint256 amountOut, uint256 minAmountOut);
    error InsufficientLiquidity();
    error InsufficientDepositBalance(uint256 available, uint256 requested);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    constructor(address _operator, address _treasury) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (!stableTokens[tokenIn].supported) revert TokenNotSupported(tokenIn);
        if (!stableTokens[tokenOut].supported) revert TokenNotSupported(tokenOut);

        PairConfig memory cfg = pairConfigs[tokenIn][tokenOut];
        if (!cfg.exists) revert PairNotSupported(tokenIn, tokenOut);

        uint256 reserveOut = IERC20(tokenOut).balanceOf(address(this));

        uint256 inputScaled = amountIn * cfg.targetPrice;
        uint256 denominator = reserveOut * PRICE_PRECISION + inputScaled;
        uint256 grossOut = (inputScaled * reserveOut) / denominator;

        if (grossOut < MIN_OUTPUT) revert InsufficientLiquidity();

        uint256 deviation = (inputScaled * BPS_DENOM) / denominator;
        if (deviation > MAX_DEVIATION_BPS) {
            revert DeviationExceeded(deviation, MAX_DEVIATION_BPS);
        }
        if (deviation > cfg.deviationTolerance) {
            revert DeviationExceeded(deviation, cfg.deviationTolerance);
        }

        uint256 fee = (grossOut * FEE_BPS) / BPS_DENOM;
        amountOut = grossOut - fee;

        if (amountOut < minAmountOut) {
            revert InsufficientOutput(amountOut, minAmountOut);
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        if (fee > 0) {
            IERC20(tokenOut).safeTransfer(treasury, fee);
        }

        emit Exchange(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    function deposit(address stableToken, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (!stableTokens[stableToken].supported) revert TokenNotSupported(stableToken);

        address reserveToken = stableTokens[stableToken].reserveToken;
        IERC20(reserveToken).safeTransferFrom(msg.sender, address(this), amount);
        userDeposits[msg.sender][reserveToken] += amount;

        emit LiquidityAdded(msg.sender, stableToken, reserveToken, amount);
    }

    function withdraw(address stableToken, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!stableTokens[stableToken].supported) revert TokenNotSupported(stableToken);

        address reserveToken = stableTokens[stableToken].reserveToken;
        uint256 available = userDeposits[msg.sender][reserveToken];
        if (amount > available) revert InsufficientDepositBalance(available, amount);

        userDeposits[msg.sender][reserveToken] = available - amount;

        IERC20(reserveToken).safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, stableToken, reserveToken, amount);
    }

    function addStableToken(address token, address reserveToken)
        external
        onlyOperator
    {
        if (token == address(0)) revert ZeroAddress();
        if (reserveToken == address(0)) revert ZeroAddress();
        if (stableTokens[token].supported) revert TokenAlreadySupported(token);

        stableTokens[token] = StableToken({reserveToken: reserveToken, supported: true});
        reserveTokenOf[token] = reserveToken;
        _tokenIndex[token] = _supportedTokens.length;
        _supportedTokens.push(token);

        emit StableTokenAdded(token, reserveToken);
    }

    function addPair(
        address tokenIn,
        address tokenOut,
        uint256 targetPrice,
        uint16 deviationTolerance
    ) external onlyOperator {
        if (!stableTokens[tokenIn].supported) revert TokenNotSupported(tokenIn);
        if (!stableTokens[tokenOut].supported) revert TokenNotSupported(tokenOut);
        if (targetPrice == 0) revert InvalidTargetPrice();
        if (deviationTolerance > MAX_DEVIATION_BPS) {
            revert InvalidDeviationTolerance(deviationTolerance);
        }

        pairConfigs[tokenIn][tokenOut] =
            PairConfig({targetPrice: targetPrice, deviationTolerance: deviationTolerance, exists: true});

        emit PairConfigUpdated(tokenIn, tokenOut, targetPrice, deviationTolerance);
    }

    function updatePair(
        address tokenIn,
        address tokenOut,
        uint256 targetPrice,
        uint16 deviationTolerance
    ) external onlyOperator {
        if (!stableTokens[tokenIn].supported) revert TokenNotSupported(tokenIn);
        if (!stableTokens[tokenOut].supported) revert TokenNotSupported(tokenOut);
        if (!pairConfigs[tokenIn][tokenOut].exists) revert PairNotSupported(tokenIn, tokenOut);
        if (targetPrice == 0) revert InvalidTargetPrice();
        if (deviationTolerance > MAX_DEVIATION_BPS) {
            revert InvalidDeviationTolerance(deviationTolerance);
        }

        PairConfig storage cfg = pairConfigs[tokenIn][tokenOut];
        cfg.targetPrice = targetPrice;
        cfg.deviationTolerance = deviationTolerance;

        emit PairConfigUpdated(tokenIn, tokenOut, targetPrice, deviationTolerance);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function supportedTokenCount() external view returns (uint256) {
        return _supportedTokens.length;
    }

    function supportedTokens() external view returns (address[] memory) {
        return _supportedTokens;
    }

    function getReserveToken(address stableToken) external view returns (address) {
        return stableTokens[stableToken].reserveToken;
    }

    function getPairConfig(address tokenIn, address tokenOut)
        external
        view
        returns (uint256 targetPrice, uint16 deviationTolerance, bool exists)
    {
        PairConfig memory cfg = pairConfigs[tokenIn][tokenOut];
        return (cfg.targetPrice, cfg.deviationTolerance, cfg.exists);
    }

    function getReserveBalance(address stableToken) external view returns (uint256) {
        address reserveToken = stableTokens[stableToken].reserveToken;
        if (reserveToken == address(0)) return 0;
        return IERC20(reserveToken).balanceOf(address(this));
    }

    function getDeposit(address provider, address stableToken) external view returns (uint256) {
        address reserveToken = stableTokens[stableToken].reserveToken;
        if (reserveToken == address(0)) return 0;
        return userDeposits[provider][reserveToken];
    }
}
