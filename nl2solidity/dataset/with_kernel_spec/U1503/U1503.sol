// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract DecentralizedExchange {
    error ZeroAddress();
    error IdenticalAddresses();
    error InsufficientInputAmount();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InvalidFee();
    error NoFeesToWithdraw();
    error InvariantViolation();
    error NotOwner();
    error ReentrantCall();
    error TransferFailed();
    error InsufficientAllowance();
    error InsufficientBalance();

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed owner, uint256 amount0, uint256 amount1);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant INVARIANT_NUMERATOR = 997;
    uint256 public constant INVARIANT_DENOMINATOR = 1000;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public feeBps;
    uint256 public accumulatedFee0;
    uint256 public accumulatedFee1;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    uint256 private _status = 1;

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _token0, address _token1) {
        if (_token0 == address(0) || _token1 == address(0)) revert ZeroAddress();
        if (_token0 == _token1) revert IdenticalAddresses();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeBps = 30;
        owner = msg.sender;
        name = "DecentralizedExchange LP";
        symbol = "DEX-LP";
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function totalLiquidity() public view returns (uint256) {
        return totalSupply;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant returns (uint256 liquidity) {
        if (amount0Desired == 0 || amount1Desired == 0) revert InsufficientInputAmount();
        if (amount0Desired < amount0Min || amount1Desired < amount1Min) revert SlippageExceeded();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0Desired * amount1Desired);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            _mint(address(0xdead), MINIMUM_LIQUIDITY);
            liquidity -= MINIMUM_LIQUIDITY;
        } else {
            uint256 liquidity0 = (amount0Desired * _totalSupply) / _reserve0;
            uint256 liquidity1 = (amount1Desired * _totalSupply) / _reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            if (liquidity == 0) revert InsufficientLiquidityMinted();
        }

        _mint(msg.sender, liquidity);
        reserve0 = _reserve0 + amount0Desired;
        reserve1 = _reserve1 + amount1Desired;

        _safeTransferFrom(address(token0), msg.sender, address(this), amount0Desired);
        _safeTransferFrom(address(token1), msg.sender, address(this), amount1Desired);

        emit LiquidityAdded(msg.sender, amount0Desired, amount1Desired, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert InsufficientLiquidityBurned();
        if (balanceOf[msg.sender] < liquidity) revert InsufficientLiquidityBurned();

        uint256 _totalSupply = totalSupply;
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        amount0 = (liquidity * _reserve0) / _totalSupply;
        amount1 = (liquidity * _reserve1) / _totalSupply;

        if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();
        if (amount0 == 0 && amount1 == 0) revert InsufficientLiquidity();

        _burn(msg.sender, liquidity);
        reserve0 = _reserve0 - amount0;
        reserve1 = _reserve1 - amount1;

        if (amount0 > 0) _safeTransfer(address(token0), msg.sender, amount0);
        if (amount1 > 0) _safeTransfer(address(token1), msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        bool zeroForOne
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();

        address inputTokenAddr = zeroForOne ? address(token0) : address(token1);
        address outputTokenAddr = zeroForOne ? address(token1) : address(token0);
        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        uint256 fee = (amountIn * feeBps) / BPS_DENOMINATOR;
        uint256 amountInNet = amountIn - fee;

        amountOut = (amountInNet * reserveOut) / (reserveIn + amountInNet);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        uint256 newReserveIn = reserveIn + amountInNet;
        uint256 newReserveOut = reserveOut - amountOut;

        if (
            newReserveIn * newReserveOut * INVARIANT_DENOMINATOR <
            reserveIn * reserveOut * INVARIANT_NUMERATOR
        ) {
            revert InvariantViolation();
        }

        if (zeroForOne) {
            reserve0 = newReserveIn;
            reserve1 = newReserveOut;
            accumulatedFee0 += fee;
        } else {
            reserve1 = newReserveIn;
            reserve0 = newReserveOut;
            accumulatedFee1 += fee;
        }

        _safeTransferFrom(inputTokenAddr, msg.sender, address(this), amountIn);
        _safeTransfer(outputTokenAddr, msg.sender, amountOut);

        emit Swap(msg.sender, inputTokenAddr, outputTokenAddr, amountIn, amountOut, fee);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(oldFeeBps, newFeeBps);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount0 = accumulatedFee0;
        uint256 amount1 = accumulatedFee1;
        if (amount0 == 0 && amount1 == 0) revert NoFeesToWithdraw();

        accumulatedFee0 = 0;
        accumulatedFee1 = 0;

        address recipient = owner;
        if (amount0 > 0) _safeTransfer(address(token0), recipient, amount0);
        if (amount1 > 0) _safeTransfer(address(token1), recipient, amount1);

        emit FeesWithdrawn(recipient, amount0, amount1);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address oldOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
