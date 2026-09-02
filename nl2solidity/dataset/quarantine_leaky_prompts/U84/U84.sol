// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title FluidDex
 * @notice A decentralized exchange pool combining vault-style liquidity provisioning
 *         with a constant-product automated market maker.
 * @dev Core Mechanism:
 *
 *      Liquidity providers deposit either token0 or token1 and receive pool credits
 *      denominated in 1e18 units. The value of each credit is derived from the pool's
 *      reserves and total outstanding credits via an exchange price:
 *
 *          exchangePrice = reserve * 1e18 / totalCredits
 *
 *      Swap fees are retained inside the pool: the full input amount (including the
 *      fee portion) is added to the input reserve while the output is calculated from
 *      the fee-adjusted input. This causes the exchange price to grow over time,
 *      allowing liquidity providers to accrue value without per-position bookkeeping.
 *
 *      The constant-product invariant x * y = k governs swap pricing. A protocol fee
 *      is deducted from the input before computing the output amount. All state-changing
 *      entry points follow the checks-effects-interactions pattern and are guarded
 *      against reentrancy.
 */
contract FluidDex {
    error Unauthorized();
    error ZeroAmount();
    error InvalidToken();
    error InvalidFee();
    error InsufficientLiquidity();
    error InsufficientCredits();
    error SlippageExceeded();
    error TransferFailed();
    error ReentrantCall();

    event Supply(address indexed caller, address indexed token, uint256 amount, uint256 creditsMinted);
    event Withdraw(address indexed caller, address indexed token, uint256 creditsBurned, uint256 amountOut);
    event Swap(
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeApplied
    );
    event FeeUpdated(address indexed admin, uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousAdmin, address indexed newAdmin);

    uint256 public constant WAD = 1e18;
    uint256 public constant FEE_DENOMINATOR = 1_000_000;
    uint256 public constant MAX_FEE_BPS = 100_000;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    address public admin;
    uint256 public feeBps;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalCredits0;
    uint256 public totalCredits1;

    uint256 public exchangePrice0;
    uint256 public exchangePrice1;

    mapping(address => uint256) public credits0Of;
    mapping(address => uint256) public credits1Of;

    uint256 private _locked = 1;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address token0_, address token1_, uint256 feeBps_) {
        if (token0_ == address(0) || token1_ == address(0)) revert InvalidToken();
        if (token0_ == token1_) revert InvalidToken();
        if (feeBps_ > MAX_FEE_BPS) revert InvalidFee();

        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        admin = msg.sender;
        feeBps = feeBps_;

        exchangePrice0 = WAD;
        exchangePrice1 = WAD;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(msg.sender, old, newFeeBps);
    }

    function transferOwnership(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidToken();
        address previous = admin;
        admin = newAdmin;
        emit OwnershipTransferred(previous, newAdmin);
    }

    function supply0(uint256 amount0) external nonReentrant returns (uint256 creditsMinted) {
        if (amount0 == 0) revert ZeroAmount();

        creditsMinted = (amount0 * WAD) / exchangePrice0;

        // Effects: update state before external calls
        reserve0 += amount0;
        totalCredits0 += creditsMinted;
        credits0Of[msg.sender] += creditsMinted;
        exchangePrice0 = (reserve0 * WAD) / totalCredits0;

        // Interactions
        _safeTransferFrom(address(token0), msg.sender, address(this), amount0);

        emit Supply(msg.sender, address(token0), amount0, creditsMinted);
    }

    function supply1(uint256 amount1) external nonReentrant returns (uint256 creditsMinted) {
        if (amount1 == 0) revert ZeroAmount();

        creditsMinted = (amount1 * WAD) / exchangePrice1;

        // Effects: update state before external calls
        reserve1 += amount1;
        totalCredits1 += creditsMinted;
        credits1Of[msg.sender] += creditsMinted;
        exchangePrice1 = (reserve1 * WAD) / totalCredits1;

        // Interactions
        _safeTransferFrom(address(token1), msg.sender, address(this), amount1);

        emit Supply(msg.sender, address(token1), amount1, creditsMinted);
    }

    function withdraw0(uint256 creditsToBurn) external nonReentrant returns (uint256 amountOut) {
        if (creditsToBurn == 0) revert ZeroAmount();

        uint256 userCredits = credits0Of[msg.sender];
        if (creditsToBurn > userCredits) revert InsufficientCredits();

        amountOut = (creditsToBurn * exchangePrice0) / WAD;
        if (amountOut > reserve0) revert InsufficientLiquidity();

        // Effects
        credits0Of[msg.sender] = userCredits - creditsToBurn;
        totalCredits0 -= creditsToBurn;
        reserve0 -= amountOut;

        if (totalCredits0 != 0) {
            exchangePrice0 = (reserve0 * WAD) / totalCredits0;
        } else {
            exchangePrice0 = WAD;
        }

        // Interactions
        _safeTransfer(address(token0), msg.sender, amountOut);

        emit Withdraw(msg.sender, address(token0), creditsToBurn, amountOut);
    }

    function withdraw1(uint256 creditsToBurn) external nonReentrant returns (uint256 amountOut) {
        if (creditsToBurn == 0) revert ZeroAmount();

        uint256 userCredits = credits1Of[msg.sender];
        if (creditsToBurn > userCredits) revert InsufficientCredits();

        amountOut = (creditsToBurn * exchangePrice1) / WAD;
        if (amountOut > reserve1) revert InsufficientLiquidity();

        // Effects
        credits1Of[msg.sender] = userCredits - creditsToBurn;
        totalCredits1 -= creditsToBurn;
        reserve1 -= amountOut;

        if (totalCredits1 != 0) {
            exchangePrice1 = (reserve1 * WAD) / totalCredits1;
        } else {
            exchangePrice1 = WAD;
        }

        // Interactions
        _safeTransfer(address(token1), msg.sender, amountOut);

        emit Withdraw(msg.sender, address(token1), creditsToBurn, amountOut);
    }

    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1)) revert InvalidToken();

        (uint256 reserveIn, uint256 reserveOut) =
            tokenIn == address(token0) ? (reserve0, reserve1) : (reserve1, reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        // Avoid divide-before-multiply: keep fee factor scaled in both
        // numerator and denominator so only a single final division occurs.
        uint256 amountInNet = amountIn * (FEE_DENOMINATOR - feeBps);
        uint256 numerator = amountInNet * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInNet;
        return numerator / denominator;
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1)) revert InvalidToken();

        bool inIsToken0 = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = inIsToken0 ? (reserve0, reserve1) : (reserve1, reserve0);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = getAmountOut(tokenIn, amountIn);
        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut > reserveOut) revert InsufficientLiquidity();

        // Effects: update all state before any external calls
        if (inIsToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
            if (totalCredits0 != 0) {
                exchangePrice0 = (reserve0 * WAD) / totalCredits0;
            }
            if (totalCredits1 != 0) {
                exchangePrice1 = (reserve1 * WAD) / totalCredits1;
            }
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
            if (totalCredits1 != 0) {
                exchangePrice1 = (reserve1 * WAD) / totalCredits1;
            }
            if (totalCredits0 != 0) {
                exchangePrice0 = (reserve0 * WAD) / totalCredits0;
            }
        }

        // Interactions
        address tokenOutAddr = inIsToken0 ? address(token1) : address(token0);
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOutAddr, msg.sender, amountOut);

        uint256 feeApplied = (amountIn * feeBps) / FEE_DENOMINATOR;
        emit Swap(msg.sender, tokenIn, tokenOutAddr, amountIn, amountOut, feeApplied);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function creditsOf(address provider) external view returns (uint256, uint256) {
        return (credits0Of[provider], credits1Of[provider]);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function getExchangePrices() external view returns (uint256, uint256) {
        return (exchangePrice0, exchangePrice1);
    }

    function getTotalCredits() external view returns (uint256, uint256) {
        return (totalCredits0, totalCredits1);
    }
}
