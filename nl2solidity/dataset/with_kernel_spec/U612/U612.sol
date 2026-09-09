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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _update(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _update(from, to, amount);
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            require(fromBalance >= value, "ERC20: insufficient balance");
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");
        _update(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        _update(from, address(0), amount);
    }
}

contract SimpleAMM is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    ////////////////////////////////////////////////////////////////
    //                          ERRORS
    ////////////////////////////////////////////////////////////////
    error SimpleAMM__IdenticalAddresses();
    error SimpleAMM__ZeroAddress();
    error SimpleAMM__InsufficientLiquidityMinted();
    error SimpleAMM__InsufficientLiquidityBurned();
    error SimpleAMM__InsufficientInputAmount();
    error SimpleAMM__InsufficientOutputAmount();
    error SimpleAMM__InsufficientLiquidity();
    error SimpleAMM__InvalidToken();
    error SimpleAMM__MaxLiquidityProvidersReached();
    error SimpleAMM__Paused();
    error SimpleAMM__NotOperator();
    error SimpleAMM__InvalidFee();
    error SimpleAMM__SlippageExceeded();

    ////////////////////////////////////////////////////////////////
    //                          EVENTS
    ////////////////////////////////////////////////////////////////
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityBurned);
    event Swap(
        address indexed sender,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event PausedStateChanged(bool paused);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    ////////////////////////////////////////////////////////////////
    //                       CONSTANTS
    ////////////////////////////////////////////////////////////////
    uint256 public constant MAX_LIQUIDITY_PROVIDERS = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 30; // 0.3%
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    ////////////////////////////////////////////////////////////////
    //                      STATE VARIABLES
    ////////////////////////////////////////////////////////////////
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public tradingFee;
    bool public paused;

    address public operator;
    uint256 public liquidityProviderCount;

    mapping(address => bool) private _isLiquidityProvider;

    ////////////////////////////////////////////////////////////////
    //                        MODIFIERS
    ////////////////////////////////////////////////////////////////
    modifier whenNotPaused() {
        if (paused) revert SimpleAMM__Paused();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert SimpleAMM__NotOperator();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR
    ////////////////////////////////////////////////////////////////
    constructor(
        address _tokenA,
        address _tokenB,
        address _operator,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_tokenA == _tokenB) revert SimpleAMM__IdenticalAddresses();
        if (_tokenA == address(0) || _tokenB == address(0)) revert SimpleAMM__ZeroAddress();
        if (_operator == address(0)) revert SimpleAMM__ZeroAddress();

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        operator = _operator;
        tradingFee = DEFAULT_FEE;
        paused = false;

        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, DEFAULT_FEE);
    }

    ////////////////////////////////////////////////////////////////
    //                    EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Adds liquidity to the pool proportionally to current reserves.
     * @param amountADesired Desired amount of tokenA to deposit.
     * @param amountBDesired Desired amount of tokenB to deposit.
     * @param amountAMin Minimum amount of tokenA to deposit (slippage protection).
     * @param amountBMin Minimum amount of tokenB to deposit (slippage protection).
     */
    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (amountADesired == 0 || amountBDesired == 0) revert SimpleAMM__InsufficientInputAmount();

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;

        if (_reserveA == 0 && _reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
            liquidity = _sqrt(amountA * amountB);
            if (liquidity <= MINIMUM_LIQUIDITY) revert SimpleAMM__InsufficientLiquidityMinted();
            // Effects
            _mint(address(this), MINIMUM_LIQUIDITY); // permanently locked
            liquidity -= MINIMUM_LIQUIDITY;
            _registerLiquidityProvider(msg.sender);
            _mint(msg.sender, liquidity);
            reserveA = amountA;
            reserveB = amountB;
            // Interactions
            tokenA.safeTransferFrom(msg.sender, address(this), amountA);
            tokenB.safeTransferFrom(msg.sender, address(this), amountB);
        } else {
            uint256 amountBOptimal = (amountADesired * _reserveB) / _reserveA;
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert SimpleAMM__SlippageExceeded();
                (amountA, amountB) = (amountADesired, amountBOptimal);
                // Use the exact (non-truncated) amountA for liquidity calc to avoid divide-before-multiply
                uint256 _totalSupply = totalSupply();
                liquidity = (amountADesired * _totalSupply) / _reserveA;
            } else {
                uint256 amountAOptimal = (amountBDesired * _reserveA) / _reserveB;
                if (amountAOptimal > amountADesired || amountAOptimal < amountAMin)
                    revert SimpleAMM__SlippageExceeded();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
                // Use the exact (non-truncated) amountB for liquidity calc to avoid divide-before-multiply
                uint256 _totalSupply = totalSupply();
                liquidity = (amountBDesired * _totalSupply) / _reserveB;
            }
            if (liquidity == 0) revert SimpleAMM__InsufficientLiquidityMinted();

            // Effects
            _registerLiquidityProvider(msg.sender);
            _mint(msg.sender, liquidity);
            reserveA = _reserveA + amountA;
            reserveB = _reserveB + amountB;

            // Interactions
            tokenA.safeTransferFrom(msg.sender, address(this), amountA);
            tokenB.safeTransferFrom(msg.sender, address(this), amountB);
        }

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @notice Removes liquidity from the pool, returning proportional token amounts.
     * @param liquidity Amount of LP tokens to burn.
     * @param amountAMin Minimum amount of tokenA to receive.
     * @param amountBMin Minimum amount of tokenB to receive.
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert SimpleAMM__InsufficientLiquidityBurned();
        if (balanceOf(msg.sender) < liquidity) revert SimpleAMM__InsufficientLiquidityBurned();

        uint256 _totalSupply = totalSupply();
        amountA = (liquidity * reserveA) / _totalSupply;
        amountB = (liquidity * reserveB) / _totalSupply;
        if (amountA < amountAMin || amountB < amountBMin) revert SimpleAMM__SlippageExceeded();
        if (amountA == 0 && amountB == 0) revert SimpleAMM__InsufficientLiquidityBurned();

        // Effects
        _burn(msg.sender, liquidity);
        reserveA -= amountA;
        reserveB -= amountB;
        _deregisterLiquidityProvider(msg.sender);

        // Interactions
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible.
     * @param inputToken Address of the token being swapped in (must be tokenA or tokenB).
     * @param outputToken Address of the token being received (must be the other token).
     * @param inputAmount Exact amount of input token to swap.
     * @param minOutputAmount Minimum amount of output token to receive.
     */
    function swap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 minOutputAmount
    ) external nonReentrant whenNotPaused returns (uint256 outputAmount) {
        if (inputAmount == 0) revert SimpleAMM__InsufficientInputAmount();

        bool isAForB = (inputToken == address(tokenA) && outputToken == address(tokenB));
        bool isBForA = (inputToken == address(tokenB) && outputToken == address(tokenA));
        if (!isAForB && !isBForA) revert SimpleAMM__InvalidToken();

        (uint256 inputReserve, uint256 outputReserve) = isAForB
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        outputAmount = _getOutputAmount(inputAmount, inputReserve, outputReserve);
        if (outputAmount < minOutputAmount) revert SimpleAMM__InsufficientOutputAmount();
        if (outputAmount >= outputReserve) revert SimpleAMM__InsufficientLiquidity();

        // Effects: update reserves before external calls
        if (isAForB) {
            reserveA += inputAmount;
            reserveB -= outputAmount;
        } else {
            reserveB += inputAmount;
            reserveA -= outputAmount;
        }

        // Interactions
        if (isAForB) {
            tokenA.safeTransferFrom(msg.sender, address(this), inputAmount);
            tokenB.safeTransfer(msg.sender, outputAmount);
        } else {
            tokenB.safeTransferFrom(msg.sender, address(this), inputAmount);
            tokenA.safeTransfer(msg.sender, outputAmount);
        }

        emit Swap(msg.sender, inputToken, outputToken, inputAmount, outputAmount);
    }

    ////////////////////////////////////////////////////////////////
    //                    OPERATOR FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Updates the trading fee (in basis points). Max 10%.
     * @param newFee New fee value (e.g. 30 = 0.3%).
     */
    function setTradingFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert SimpleAMM__InvalidFee();
        uint256 oldFee = tradingFee;
        tradingFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Pauses or unpauses trading and liquidity operations.
     * @param _paused New paused state.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /**
     * @notice Sets a new operator address.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert SimpleAMM__ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    ////////////////////////////////////////////////////////////////
    //                       VIEW FUNCTIONS
    ////////////////////////////////////////////////////////////////

    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    function getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external view returns (uint256) {
        return _getOutputAmount(inputAmount, inputReserve, outputReserve);
    }

    function getInputAmount(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external view returns (uint256) {
        return _getInputAmount(outputAmount, inputReserve, outputReserve);
    }

    function isLiquidityProvider(address account) external view returns (bool) {
        return _isLiquidityProvider[account];
    }

    ////////////////////////////////////////////////////////////////
    //                      INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////

    function _getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal view returns (uint256) {
        if (inputAmount == 0 || inputReserve == 0 || outputReserve == 0)
            revert SimpleAMM__InsufficientLiquidity();
        uint256 amountInWithFee = inputAmount * (FEE_DENOMINATOR - tradingFee);
        uint256 numerator = amountInWithFee * outputReserve;
        uint256 denominator = (inputReserve * FEE_DENOMINATOR) + amountInWithFee;
        return numerator / denominator;
    }

    function _getInputAmount(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal view returns (uint256) {
        if (outputAmount == 0 || inputReserve == 0 || outputReserve == 0)
            revert SimpleAMM__InsufficientLiquidity();
        if (outputAmount >= outputReserve) revert SimpleAMM__InsufficientLiquidity();
        uint256 numerator = (inputReserve * outputAmount) * FEE_DENOMINATOR;
        uint256 denominator = (outputReserve - outputAmount) * (FEE_DENOMINATOR - tradingFee);
        return (numerator / denominator) + 1;
    }

    function _registerLiquidityProvider(address account) internal {
        if (!_isLiquidityProvider[account]) {
            if (liquidityProviderCount >= MAX_LIQUIDITY_PROVIDERS)
                revert SimpleAMM__MaxLiquidityProvidersReached();
            _isLiquidityProvider[account] = true;
            liquidityProviderCount += 1;
        }
    }

    function _deregisterLiquidityProvider(address account) internal {
        if (_isLiquidityProvider[account] && balanceOf(account) == 0) {
            _isLiquidityProvider[account] = false;
            if (liquidityProviderCount > 0) liquidityProviderCount -= 1;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    ////////////////////////////////////////////////////////////////
    //                 HOOKS FOR LP TRACKING
    ////////////////////////////////////////////////////////////////

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        // Track liquidity provider status on transfers of LP tokens.
        if (from != address(0) && from != address(this) && balanceOf(from) == 0 && _isLiquidityProvider[from]) {
            _isLiquidityProvider[from] = false;
            if (liquidityProviderCount > 0) liquidityProviderCount -= 1;
        }
        if (to != address(0) && to != address(this) && balanceOf(to) != 0 && !_isLiquidityProvider[to]) {
            if (liquidityProviderCount >= MAX_LIQUIDITY_PROVIDERS)
                revert SimpleAMM__MaxLiquidityProvidersReached();
            _isLiquidityProvider[to] = true;
            liquidityProviderCount += 1;
        }
    }
}
