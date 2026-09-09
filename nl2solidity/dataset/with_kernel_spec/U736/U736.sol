// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
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

contract StableSwap is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error InvalidToken();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error MinimumReserveViolation();
    error FeeTooHigh();
    error Paused();

    event Deposit(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Withdraw(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event PausedStateChanged(bool paused);
    event Sync(uint256 reserve0, uint256 reserve1);

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public swapFee;
    uint256 public constant MINIMUM_RESERVE = 1000;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;

    bool public paused;

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_token0 == address(0) || _token1 == address(0)) revert InvalidToken();
        if (_token0 == _token1) revert InvalidToken();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        swapFee = 5; // 0.05%
    }

    function deposit(uint256 amount0, uint256 amount1) external nonReentrant returns (uint256 liquidity) {
        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1);
            if (liquidity <= MINIMUM_RESERVE) revert InsufficientLiquidityMinted();
            liquidity -= MINIMUM_RESERVE;
        } else {
            uint256 liquidity0 = (amount0 * _totalSupply) / _reserve0;
            uint256 liquidity1 = (amount1 * _totalSupply) / _reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        if (liquidity == 0) revert InsufficientLiquidityMinted();

        // Effects: update state before interactions
        if (_totalSupply == 0) {
            _mint(address(0), MINIMUM_RESERVE); // permanently lock minimum liquidity
        }
        _mint(msg.sender, liquidity);

        reserve0 = _reserve0 + amount0;
        reserve1 = _reserve1 + amount1;

        // Interactions: transfer tokens after state updates
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        emit Deposit(msg.sender, amount0, amount1, liquidity);
        emit Sync(reserve0, reserve1);
    }

    function withdraw(uint256 liquidity) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < liquidity) revert InsufficientLiquidityBurned();

        uint256 _totalSupply = totalSupply;
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        amount0 = (liquidity * _reserve0) / _totalSupply;
        amount1 = (liquidity * _reserve1) / _totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        if (_reserve0 - amount0 < MINIMUM_RESERVE || _reserve1 - amount1 < MINIMUM_RESERVE) {
            revert MinimumReserveViolation();
        }

        // Effects: update state before interactions
        _burn(msg.sender, liquidity);

        reserve0 = _reserve0 - amount0;
        reserve1 = _reserve1 - amount1;

        // Interactions: transfer tokens after state updates
        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);

        emit Withdraw(msg.sender, amount0, amount1, liquidity);
        emit Sync(reserve0, reserve1);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 amountOutMin) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1)) revert InvalidToken();

        bool isToken0 = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // Avoid divide-before-multiply: keep fee scaling in numerator until final division
        // amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee)
        // amountOut = (reserveOut * amountInWithFee) / (reserveIn * FEE_DENOMINATOR + amountInWithFee)
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        amountOut = (reserveOut * amountInWithFee) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut == 0) revert InsufficientOutputAmount();
        if (amountOut < amountOutMin) revert InsufficientOutputAmount();
        if (reserveOut - amountOut < MINIMUM_RESERVE) revert MinimumReserveViolation();

        // Effects: update state before interactions
        if (isToken0) {
            reserve0 = reserveIn + amountIn;
            reserve1 = reserveOut - amountOut;
        } else {
            reserve1 = reserveIn + amountIn;
            reserve0 = reserveOut - amountOut;
        }

        // Interactions: transfer tokens after state updates
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        address tokenOut = isToken0 ? address(token1) : address(token0);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        emit Sync(reserve0, reserve1);
    }

    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        uint256 oldFee = swapFee;
        swapFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function sync() external {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
        emit Sync(reserve0, reserve1);
    }

    function skim(address to) external {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        if (balance0 > reserve0) {
            token0.safeTransfer(to, balance0 - reserve0);
        }
        if (balance1 > reserve1) {
            token1.safeTransfer(to, balance1 - reserve1);
        }
    }

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        return (reserve0, reserve1);
    }

    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1)) revert InvalidToken();

        bool isToken0 = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        amountOut = (reserveOut * amountInWithFee) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
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
}
