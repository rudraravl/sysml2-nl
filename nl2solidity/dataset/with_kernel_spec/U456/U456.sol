// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function _callOptionalReturn(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        bool returnedBool;
        assembly {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            if success {
                switch returndatasize()
                case 0x20 {
                    returnedBool := mload(0)
                }
                case 0 {
                    returnedBool := iszero(iszero(extcodesize(token)))
                }
            }
        }
        return success && returnedBool;
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

contract Ownable {
    address public owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract LiquidityBookAMM is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error IdenticalTokens();
    error InvalidPrice();
    error ZeroAmount();
    error InsufficientShares();
    error NoShares();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InvalidFee();
    error EtherTransferFailed();

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MIN_FEE_BPS = 1;
    uint256 public constant MAX_FEE_BPS = 100;
    uint256 public constant DEFAULT_FEE_BPS = 25;
    uint256 public constant PRICE_SCALE = 1e18;

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint256 public immutable basePrice;
    uint256 public immutable priceStep;
    uint256 public swapFeeBps;

    struct Bin {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
    }

    mapping(int24 => Bin) public bins;
    mapping(address => mapping(int24 => uint256)) public userShares;
    int24[] public activeBins;
    mapping(int24 => uint256) private activeBinIndex;
    uint256 public reserve0;
    uint256 public reserve1;

    event Deposit(address indexed user, int24 indexed binId, uint256 amount0, uint256 amount1, uint256 shares);
    event Withdraw(address indexed user, int24 indexed binId, uint256 amount0, uint256 amount1, uint256 shares);
    event Swap(address indexed user, bool indexed zeroForOne, uint256 amountIn, uint256 amountOut, int24[] binsUsed);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event EtherRescued(address indexed to, uint256 amount);

    constructor(address token0_, address token1_, uint256 basePrice_, uint256 priceStep_) Ownable(msg.sender) {
        if (token0_ == address(0) || token1_ == address(0)) revert ZeroAddress();
        if (token0_ == token1_) revert IdenticalTokens();
        if (basePrice_ == 0 || priceStep_ == 0) revert InvalidPrice();
        if (basePrice_ > 1e30 || priceStep_ > 1e30) revert InvalidPrice();

        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        basePrice = basePrice_;
        priceStep = priceStep_;
        swapFeeBps = DEFAULT_FEE_BPS;
    }

    receive() external payable {
        revert();
    }

    function priceFromId(int24 binId) public view returns (uint256) {
        int256 signedPrice = int256(basePrice) + (int256(binId) * int256(priceStep));
        if (signedPrice <= 0) revert InvalidPrice();
        return uint256(signedPrice);
    }

    function getBin(int24 binId) external view returns (uint256 reserve0_, uint256 reserve1_, uint256 totalShares_) {
        Bin storage bin = bins[binId];
        return (bin.reserve0, bin.reserve1, bin.totalShares);
    }

    function getUserShares(address user, int24 binId) external view returns (uint256) {
        return userShares[user][binId];
    }

    function getActiveBins() external view returns (int24[] memory) {
        return activeBins;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function deposit(int24 binId, uint256 amount0Desired, uint256 amount1Desired) external nonReentrant {
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();
        uint256 price = priceFromId(binId);

        Bin storage bin = bins[binId];
        bool wasActive = bin.totalShares > 0;

        uint256 sharesToMint;
        if (!wasActive) {
            sharesToMint = amount0Desired + ((amount1Desired * PRICE_SCALE) / price);
        } else {
            uint256 value0 = bin.reserve0 + ((bin.reserve1 * PRICE_SCALE) / price);
            uint256 dValue0 = amount0Desired + ((amount1Desired * PRICE_SCALE) / price);
            sharesToMint = (dValue0 * bin.totalShares) / value0;
        }
        if (sharesToMint == 0) revert ZeroAmount();

        bin.reserve0 += amount0Desired;
        bin.reserve1 += amount1Desired;
        bin.totalShares += sharesToMint;
        userShares[msg.sender][binId] += sharesToMint;

        reserve0 += amount0Desired;
        reserve1 += amount1Desired;

        if (!wasActive) _addActiveBin(binId);

        if (amount0Desired > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amount0Desired);
        }
        if (amount1Desired > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amount1Desired);
        }

        emit Deposit(msg.sender, binId, amount0Desired, amount1Desired, sharesToMint);
    }

    function withdraw(int24 binId, uint256 sharesToBurn) external nonReentrant {
        if (sharesToBurn == 0) revert ZeroAmount();
        uint256 userBal = userShares[msg.sender][binId];
        if (userBal < sharesToBurn) revert InsufficientShares();

        Bin storage bin = bins[binId];
        if (bin.totalShares == 0) revert NoShares();

        uint256 amount0 = (bin.reserve0 * sharesToBurn) / bin.totalShares;
        uint256 amount1 = (bin.reserve1 * sharesToBurn) / bin.totalShares;

        userShares[msg.sender][binId] -= sharesToBurn;
        bin.totalShares -= sharesToBurn;
        bin.reserve0 -= amount0;
        bin.reserve1 -= amount1;

        reserve0 -= amount0;
        reserve1 -= amount1;

        if (bin.totalShares == 0) {
            _removeActiveBin(binId);
        }

        if (amount0 > 0) {
            token0.safeTransfer(msg.sender, amount0);
        }
        if (amount1 > 0) {
            token1.safeTransfer(msg.sender, amount1);
        }

        emit Withdraw(msg.sender, binId, amount0, amount1, sharesToBurn);
    }

    function swap(bool zeroForOne, uint256 amountIn, uint256 amountOutMin) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        uint256 remainingIn = amountIn;
        int24[] memory binsUsed = new int24[](activeBins.length);
        uint256 binsCount = 0;

        uint256 feeMultiplier = FEE_DENOMINATOR - swapFeeBps;

        if (zeroForOne) {
            for (uint256 i = activeBins.length; i > 0 && remainingIn > 0; i--) {
                int24 binId = activeBins[i - 1];
                Bin storage bin = bins[binId];
                if (bin.reserve1 == 0) continue;

                uint256 price = priceFromId(binId);

                uint256 numerator = price * feeMultiplier;
                uint256 denominator = PRICE_SCALE * FEE_DENOMINATOR;

                uint256 yForFullRemaining = (remainingIn * numerator) / denominator;

                uint256 x;
                uint256 y;
                if (yForFullRemaining <= bin.reserve1) {
                    x = remainingIn;
                    y = yForFullRemaining;
                } else {
                    y = bin.reserve1;
                    x = (y * denominator + numerator - 1) / numerator;
                }

                if (x == 0 || y == 0) continue;

                bin.reserve0 += x;
                bin.reserve1 -= y;
                reserve0 += x;
                reserve1 -= y;

                amountOut += y;
                remainingIn -= x;
                binsUsed[binsCount] = binId;
                binsCount++;
            }
        } else {
            for (uint256 i = 0; i < activeBins.length && remainingIn > 0; i++) {
                int24 binId = activeBins[i];
                Bin storage bin = bins[binId];
                if (bin.reserve0 == 0) continue;

                uint256 price = priceFromId(binId);

                uint256 numerator = PRICE_SCALE * feeMultiplier;
                uint256 denominator = price * FEE_DENOMINATOR;

                uint256 xForFullRemaining = (remainingIn * numerator) / denominator;

                uint256 x;
                uint256 y;
                if (xForFullRemaining <= bin.reserve0) {
                    y = remainingIn;
                    x = xForFullRemaining;
                } else {
                    x = bin.reserve0;
                    y = (x * denominator + numerator - 1) / numerator;
                }

                if (x == 0 || y == 0) continue;

                bin.reserve1 += y;
                bin.reserve0 -= x;
                reserve1 += y;
                reserve0 -= x;

                amountOut += x;
                remainingIn -= y;
                binsUsed[binsCount] = binId;
                binsCount++;
            }
        }

        if (remainingIn > 0) revert InsufficientLiquidity();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        assembly {
            mstore(binsUsed, binsCount)
        }

        if (zeroForOne) {
            token0.safeTransferFrom(msg.sender, address(this), amountIn);
            if (amountOut > 0) {
                token1.safeTransfer(msg.sender, amountOut);
            }
        } else {
            token1.safeTransferFrom(msg.sender, address(this), amountIn);
            if (amountOut > 0) {
                token0.safeTransfer(msg.sender, amountOut);
            }
        }

        emit Swap(msg.sender, zeroForOne, amountIn, amountOut, binsUsed);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps < MIN_FEE_BPS || newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = swapFeeBps;
        swapFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function rescueEther(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert EtherTransferFailed();
        emit EtherRescued(to, balance);
    }

    function _addActiveBin(int24 binId) internal {
        if (activeBinIndex[binId] != 0) return;

        uint256 len = activeBins.length;
        uint256 insertAt = len;
        for (uint256 i = 0; i < len; i++) {
            if (activeBins[i] > binId) {
                insertAt = i;
                break;
            }
        }

        activeBins.push(binId);
        for (uint256 j = activeBins.length - 1; j > insertAt; j--) {
            int24 moved = activeBins[j - 1];
            activeBins[j] = moved;
            activeBinIndex[moved] = j + 1;
        }
        activeBins[insertAt] = binId;
        activeBinIndex[binId] = insertAt + 1;
    }

    function _removeActiveBin(int24 binId) internal {
        uint256 idx = activeBinIndex[binId];
        if (idx == 0) return;

        uint256 lastIdx = activeBins.length - 1;
        if (idx - 1 != lastIdx) {
            int24 lastBin = activeBins[lastIdx];
            activeBins[idx - 1] = lastBin;
            activeBinIndex[lastBin] = idx;
        }
        activeBins.pop();
        activeBinIndex[binId] = 0;
    }
}
