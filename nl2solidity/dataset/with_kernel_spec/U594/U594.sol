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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract ProjectToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public immutable factory;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply, address _factory) {
        name = _name;
        symbol = _symbol;
        factory = _factory;
        totalSupply = _initialSupply;
        balanceOf[_factory] = _initialSupply;
        emit Transfer(address(0), _factory, _initialSupply);
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
            require(allowed >= amount, "ProjectToken: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ProjectToken: insufficient balance");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

contract TokenPairFactory {
    using SafeERC20 for IERC20;
    using SafeERC20 for ProjectToken;

    error ErrNotOwner();
    error ErrZeroAddress();
    error ErrTradingPaused();
    error ErrPairNotFound();
    error ErrPairAlreadyExists();
    error ErrInsufficientBaseDeposit();
    error ErrInsufficientLiquidity();
    error ErrInsufficientShares();
    error ErrInsufficientOutput();
    error ErrFeeTooHigh();
    error ErrZeroAmount();
    error ErrReentrantCall();

    event PairCreated(
        address indexed baseToken,
        address indexed projectToken,
        address indexed creator,
        uint256 baseAmount,
        uint256 projectSupply,
        uint256 shares
    );
    event LiquidityAdded(
        address indexed projectToken,
        address indexed provider,
        uint256 baseAmount,
        uint256 projectAmount,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed projectToken,
        address indexed provider,
        uint256 baseAmount,
        uint256 projectAmount,
        uint256 shares
    );
    event Swap(
        address indexed projectToken,
        address indexed account,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event Paused(address indexed owner);
    event Unpaused(address indexed owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MIN_BASE_DEPOSIT = 100 * 10**18;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 1000; // 10%

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    address public owner;
    uint256 public feeRate = 50; // 0.5%
    bool public paused;

    struct Pair {
        IERC20 baseToken;
        ProjectToken projectToken;
        uint256 baseReserve;
        uint256 projectReserve;
        uint256 totalShares;
        bool exists;
    }

    mapping(address projectToken => Pair) public pairs;
    mapping(address projectToken => mapping(address user => uint256 shares)) public userShares;
    address[] public allProjectTokens;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrTradingPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ErrReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setFeeRate(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert ErrFeeTooHigh();
        uint256 oldFee = feeRate;
        feeRate = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function createPair(
        address baseToken,
        string calldata name,
        string calldata symbol,
        uint256 projectSupply,
        uint256 baseAmount
    ) external nonReentrant whenNotPaused returns (address projectToken) {
        if (baseToken == address(0)) revert ErrZeroAddress();
        if (baseAmount < MIN_BASE_DEPOSIT) revert ErrInsufficientBaseDeposit();
        if (projectSupply == 0) revert ErrZeroAmount();

        ProjectToken token = new ProjectToken(name, symbol, projectSupply, address(this));
        projectToken = address(token);

        if (pairs[projectToken].exists) revert ErrPairAlreadyExists();

        uint256 initialLiquidity = _sqrt(baseAmount * projectSupply);
        if (initialLiquidity <= MINIMUM_LIQUIDITY) revert ErrInsufficientLiquidity();
        uint256 shares = initialLiquidity - MINIMUM_LIQUIDITY;

        pairs[projectToken] = Pair({
            baseToken: IERC20(baseToken),
            projectToken: token,
            baseReserve: baseAmount,
            projectReserve: projectSupply,
            totalShares: initialLiquidity,
            exists: true
        });

        userShares[projectToken][msg.sender] = shares;
        allProjectTokens.push(projectToken);

        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);

        emit PairCreated(baseToken, projectToken, msg.sender, baseAmount, projectSupply, shares);
    }

    function addLiquidity(
        address projectToken,
        uint256 baseDesired,
        uint256 projectDesired,
        uint256 minShares
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        Pair storage pair = pairs[projectToken];
        if (!pair.exists) revert ErrPairNotFound();
        if (baseDesired == 0 || projectDesired == 0) revert ErrZeroAmount();

        uint256 baseReserve = pair.baseReserve;
        uint256 projectReserve = pair.projectReserve;
        uint256 _totalShares = pair.totalShares;

        uint256 baseAmount;
        uint256 projectAmount;

        if (_totalShares == 0) {
            baseAmount = baseDesired;
            projectAmount = projectDesired;
            shares = _sqrt(baseAmount * projectAmount);
            if (shares <= MINIMUM_LIQUIDITY) revert ErrInsufficientLiquidity();
            shares -= MINIMUM_LIQUIDITY;
            pair.totalShares = shares + MINIMUM_LIQUIDITY;
        } else {
            uint256 optimalProject = (baseDesired * projectReserve) / baseReserve;
            if (optimalProject <= projectDesired) {
                baseAmount = baseDesired;
                projectAmount = optimalProject;
                shares = (baseDesired * _totalShares) / baseReserve;
            } else {
                baseAmount = (projectDesired * baseReserve) / projectReserve;
                projectAmount = projectDesired;
                shares = (projectDesired * _totalShares) / projectReserve;
            }
            if (baseAmount == 0 || projectAmount == 0) revert ErrZeroAmount();
            pair.totalShares = _totalShares + shares;
        }

        if (shares < minShares) revert ErrInsufficientOutput();

        pair.baseReserve = baseReserve + baseAmount;
        pair.projectReserve = projectReserve + projectAmount;
        userShares[projectToken][msg.sender] += shares;

        IERC20(pair.baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
        pair.projectToken.safeTransferFrom(msg.sender, address(this), projectAmount);

        emit LiquidityAdded(projectToken, msg.sender, baseAmount, projectAmount, shares);
    }

    function removeLiquidity(
        address projectToken,
        uint256 shares,
        uint256 minBaseOut,
        uint256 minProjectOut
    ) external nonReentrant whenNotPaused returns (uint256 baseAmount, uint256 projectAmount) {
        Pair storage pair = pairs[projectToken];
        if (!pair.exists) revert ErrPairNotFound();
        if (shares == 0) revert ErrZeroAmount();

        uint256 userHeld = userShares[projectToken][msg.sender];
        if (userHeld < shares) revert ErrInsufficientShares();

        uint256 _totalShares = pair.totalShares;
        baseAmount = (shares * pair.baseReserve) / _totalShares;
        projectAmount = (shares * pair.projectReserve) / _totalShares;

        if (baseAmount == 0 || projectAmount == 0) revert ErrInsufficientLiquidity();
        if (baseAmount < minBaseOut || projectAmount < minProjectOut) revert ErrInsufficientOutput();

        pair.baseReserve -= baseAmount;
        pair.projectReserve -= projectAmount;
        pair.totalShares = _totalShares - shares;
        userShares[projectToken][msg.sender] = userHeld - shares;

        IERC20(pair.baseToken).safeTransfer(msg.sender, baseAmount);
        pair.projectToken.safeTransfer(msg.sender, projectAmount);

        emit LiquidityRemoved(projectToken, msg.sender, baseAmount, projectAmount, shares);
    }

    function swapBaseForProject(
        address projectToken,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        Pair storage pair = pairs[projectToken];
        if (!pair.exists) revert ErrPairNotFound();
        if (amountIn == 0) revert ErrZeroAmount();

        uint256 baseReserve = pair.baseReserve;
        uint256 projectReserve = pair.projectReserve;

        amountOut = _getAmountOut(amountIn, baseReserve, projectReserve, feeRate);
        if (amountOut == 0 || amountOut >= projectReserve) revert ErrInsufficientLiquidity();
        if (amountOut < minAmountOut) revert ErrInsufficientOutput();

        pair.baseReserve = baseReserve + amountIn;
        pair.projectReserve = projectReserve - amountOut;

        IERC20(pair.baseToken).safeTransferFrom(msg.sender, address(this), amountIn);
        pair.projectToken.safeTransfer(msg.sender, amountOut);

        emit Swap(
            projectToken,
            msg.sender,
            address(pair.baseToken),
            projectToken,
            amountIn,
            amountOut
        );
    }

    function swapProjectForBase(
        address projectToken,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        Pair storage pair = pairs[projectToken];
        if (!pair.exists) revert ErrPairNotFound();
        if (amountIn == 0) revert ErrZeroAmount();

        uint256 baseReserve = pair.baseReserve;
        uint256 projectReserve = pair.projectReserve;

        amountOut = _getAmountOut(amountIn, projectReserve, baseReserve, feeRate);
        if (amountOut == 0 || amountOut >= baseReserve) revert ErrInsufficientLiquidity();
        if (amountOut < minAmountOut) revert ErrInsufficientOutput();

        pair.projectReserve = projectReserve + amountIn;
        pair.baseReserve = baseReserve - amountOut;

        pair.projectToken.safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(pair.baseToken).safeTransfer(msg.sender, amountOut);

        emit Swap(
            projectToken,
            msg.sender,
            projectToken,
            address(pair.baseToken),
            amountIn,
            amountOut
        );
    }

    function getAmountOut(
        address projectToken,
        bool baseToProject,
        uint256 amountIn
    ) external view returns (uint256) {
        Pair storage pair = pairs[projectToken];
        if (!pair.exists) revert ErrPairNotFound();
        if (baseToProject) {
            return _getAmountOut(amountIn, pair.baseReserve, pair.projectReserve, feeRate);
        } else {
            return _getAmountOut(amountIn, pair.projectReserve, pair.baseReserve, feeRate);
        }
    }

    function getPair(address projectToken)
        external
        view
        returns (
            address baseToken,
            uint256 baseReserve,
            uint256 projectReserve,
            uint256 totalShares,
            bool exists
        )
    {
        Pair storage pair = pairs[projectToken];
        return (
            address(pair.baseToken),
            pair.baseReserve,
            pair.projectReserve,
            pair.totalShares,
            pair.exists
        );
    }

    function getUserShares(address projectToken, address user) external view returns (uint256) {
        return userShares[projectToken][user];
    }

    function allProjectTokensLength() external view returns (uint256) {
        return allProjectTokens.length;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
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
