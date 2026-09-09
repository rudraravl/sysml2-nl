// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract TrustlessExchange {
    error NotOwner();
    error Reentrancy();
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidToken();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InvalidFee();
    error TransferFailed();

    string public constant name = "Trustless Exchange LP";
    string public constant symbol = "TELP";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint256 public feeRate;
    address public owner;

    uint256 private unlocked = 1;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    modifier lock() {
        if (unlocked != 1) revert Reentrancy();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _token0, address _token1) {
        if (_token0 == _token1) revert InvalidToken();
        if (_token0 == address(0) || _token1 == address(0)) revert InvalidToken();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        owner = msg.sender;
        feeRate = 30;
    }

    function getReserves()
        public
        view
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _mint(address to, uint256 amount) private {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) private {
        if (balanceOf[from] < amount) revert InsufficientLiquidityBurned();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) private {
        allowance[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (balanceOf[from] < amount) revert InsufficientLiquidityBurned();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientLiquidityBurned();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) private {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) private {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert InsufficientLiquidity();
        }
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += (uint256(_reserve1) * 1e18 / uint256(_reserve0)) * timeElapsed;
            price1CumulativeLast += (uint256(_reserve0) * 1e18 / uint256(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
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

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external lock returns (uint256 liquidity) {
        if (amount0Desired == 0 || amount1Desired == 0) revert InsufficientInputAmount();

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        uint256 amount0;
        uint256 amount1;

        if (_reserve0 == 0 && _reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * _reserve1) / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                amount0 = (amount1Desired * _reserve0) / _reserve1;
                amount1 = amount1Desired;
            }
        }

        if (amount0 < amount0Min || amount1 < amount1Min) revert InsufficientLiquidityMinted();

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            uint256 initialLiquidity = _sqrt(amount0 * amount1);
            if (initialLiquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            liquidity = initialLiquidity - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint256 l0 = (amount0 * _totalSupply) / _reserve0;
            uint256 l1 = (amount1 * _totalSupply) / _reserve1;
            liquidity = l0 < l1 ? l0 : l1;
        }

        if (liquidity == 0) revert InsufficientLiquidityMinted();

        _mint(msg.sender, liquidity);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            _reserve0,
            _reserve1
        );

        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external lock returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert InsufficientInputAmount();

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 _totalSupply = totalSupply;

        amount0 = (liquidity * _reserve0) / _totalSupply;
        amount1 = (liquidity * _reserve1) / _totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();
        if (amount0 < amount0Min || amount1 < amount1Min) revert InsufficientLiquidityBurned();

        _burn(msg.sender, liquidity);

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            _reserve0,
            _reserve1
        );

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external lock returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (to == address(0)) revert InvalidToken();

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        bool zeroForOne = tokenIn == address(token0);
        if (!zeroForOne && tokenIn != address(token1)) revert InvalidToken();

        uint112 reserveIn = zeroForOne ? _reserve0 : _reserve1;
        uint112 reserveOut = zeroForOne ? _reserve1 : _reserve0;

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        _safeTransferFrom(zeroForOne ? token0 : token1, msg.sender, address(this), amountIn);

        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - feeRate)) / FEE_DENOMINATOR;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut == 0 || amountOut < minAmountOut) revert InsufficientOutputAmount();

        _safeTransfer(zeroForOne ? token1 : token0, to, amountOut);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            _reserve0,
            _reserve1
        );

        emit Swap(msg.sender, tokenIn, zeroForOne ? address(token1) : address(token0), amountIn, amountOut, to);
    }

    function sync() external lock {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            _reserve0,
            _reserve1
        );
    }

    function setFee(uint256 _feeRate) external onlyOwner {
        if (_feeRate > 1000) revert InvalidFee();
        uint256 oldFee = feeRate;
        feeRate = _feeRate;
        emit FeeUpdated(oldFee, _feeRate);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidToken();
        owner = newOwner;
    }
}
