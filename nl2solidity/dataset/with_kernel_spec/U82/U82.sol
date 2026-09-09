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

contract MemeToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _maxSupply;
        balanceOf[msg.sender] = _maxSupply;
        emit Transfer(address(0), msg.sender, _maxSupply);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "MemeToken: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "MemeToken: insufficient balance");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

contract MemeLaunchpad {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint40 public constant BONDING_DURATION = 24 hours;
    uint256 public constant SWAP_FEE_BPS = 30;
    uint256 public constant CREATOR_FEE_SHARE_BPS = 1430;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant BPS_DENOMINATOR_SQUARED = 100_000_000;

    enum Phase { Bonding, Sealed }

    struct TokenLaunch {
        address creator;
        uint256 basePrice;
        uint256 slope;
        uint40 startTime;
        uint40 endTime;
        uint256 totalKub;
        uint256 totalTokensAllocated;
        uint256 totalClaimed;
        uint256 poolKub;
        uint256 poolToken;
        uint256 lpTotalSupply;
        uint256 creatorFeeKub;
        uint256 creatorFeeToken;
    }

    address public operator;
    uint256 public launchCount;
    address[] public allLaunches;

    mapping(address => TokenLaunch) internal _launches;
    mapping(address => bool) public isLaunched;
    mapping(address => mapping(address => uint256)) public lpShares;
    mapping(address => mapping(address => uint256)) public tokensOwed;

    mapping(address => Phase) internal _phase;

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "Reentrant call");
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    event LaunchStarted(
        uint256 indexed launchId,
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 basePrice,
        uint256 slope,
        uint40 startTime,
        uint40 endTime
    );

    event Contributed(
        address indexed token,
        address indexed contributor,
        uint256 kubAmount,
        uint256 tokensAllocated,
        uint256 totalKub
    );

    event LiquiditySealed(
        address indexed token,
        uint256 poolKub,
        uint256 poolToken,
        uint256 lpTotalSupply
    );

    event TokensClaimed(address indexed token, address indexed user, uint256 amount);

    event LiquidityWithdrawn(
        address indexed token,
        address indexed user,
        uint256 shares,
        uint256 kubOut,
        uint256 tokenOut
    );

    event Swap(
        address indexed token,
        address indexed user,
        bool kubToToken,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount,
        uint256 creatorFee
    );

    event CreatorFeesClaimed(
        address indexed token,
        address indexed creator,
        uint256 kubAmount,
        uint256 tokenAmount
    );

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error OnlyOperator();
    error TokenNotLaunched();
    error AlreadySealed();
    error NotBondingPhase();
    error BondingPhaseEnded();
    error BondingNotEnded();
    error NotSealed();
    error ZeroAmount();
    error ZeroContribution();
    error BasePriceZero();
    error ExceedsMaxSupply();
    error InsufficientShares();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error NotCreator();
    error ZeroAddress();
    error TransferFailed();

    constructor() {
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function launchToken(
        string memory name_,
        string memory symbol_,
        address creator,
        uint256 basePrice,
        uint256 slope
    ) external onlyOperator returns (address token) {
        if (creator == address(0)) revert ZeroAddress();
        if (basePrice == 0) revert BasePriceZero();

        MemeToken newToken = new MemeToken(name_, symbol_, MAX_SUPPLY);
        token = address(newToken);

        TokenLaunch storage l = _launches[token];
        l.creator = creator;
        l.basePrice = basePrice;
        l.slope = slope;
        l.startTime = uint40(block.timestamp);
        l.endTime = uint40(block.timestamp) + BONDING_DURATION;

        _phase[token] = Phase.Bonding;
        isLaunched[token] = true;
        allLaunches.push(token);

        uint256 id = launchCount++;
        emit LaunchStarted(id, token, creator, name_, symbol_, basePrice, slope, l.startTime, l.endTime);
    }

    function contribute(address token) external payable nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (_phase[token] != Phase.Bonding) revert NotBondingPhase();
        if (block.timestamp >= l.endTime) revert BondingPhaseEnded();
        if (msg.value == 0) revert ZeroContribution();

        uint256 tokens = _computeTokensForKub(l, msg.value);
        if (tokens == 0) revert ZeroContribution();

        uint256 newAllocated = l.totalTokensAllocated + tokens;
        if (newAllocated > MAX_SUPPLY) revert ExceedsMaxSupply();

        l.totalTokensAllocated = newAllocated;
        l.totalKub += msg.value;
        tokensOwed[token][msg.sender] += tokens;
        lpShares[token][msg.sender] += msg.value;

        emit Contributed(token, msg.sender, msg.value, tokens, l.totalKub);
    }

    function claimTokens(address token) external nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (block.timestamp < l.endTime) revert BondingNotEnded();

        uint256 owed = tokensOwed[token][msg.sender];
        if (owed == 0) revert ZeroAmount();

        tokensOwed[token][msg.sender] = 0;
        l.totalClaimed += owed;

        _safeTransfer(token, msg.sender, owed);
        emit TokensClaimed(token, msg.sender, owed);
    }

    function sealLiquidity(address token) external onlyOperator nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (_phase[token] != Phase.Bonding) revert AlreadySealed();
        if (block.timestamp < l.endTime) revert BondingNotEnded();
        if (l.totalKub == 0) revert ZeroContribution();

        _phase[token] = Phase.Sealed;
        l.poolKub = l.totalKub;
        l.poolToken = MAX_SUPPLY - l.totalTokensAllocated;
        l.lpTotalSupply = l.totalKub;

        emit LiquiditySealed(token, l.poolKub, l.poolToken, l.lpTotalSupply);
    }

    function withdrawLiquidity(address token, uint256 shares) external nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (_phase[token] != Phase.Sealed) revert NotSealed();
        if (shares == 0) revert ZeroAmount();
        if (lpShares[token][msg.sender] < shares) revert InsufficientShares();
        if (l.lpTotalSupply == 0) revert InsufficientLiquidity();

        uint256 kubOut = (l.poolKub * shares) / l.lpTotalSupply;
        uint256 tokenOut = (l.poolToken * shares) / l.lpTotalSupply;

        lpShares[token][msg.sender] -= shares;
        l.lpTotalSupply -= shares;
        l.poolKub -= kubOut;
        l.poolToken -= tokenOut;

        if (kubOut > 0) {
            _safeTransferKub(msg.sender, kubOut);
        }
        if (tokenOut > 0) {
            _safeTransfer(token, msg.sender, tokenOut);
        }

        emit LiquidityWithdrawn(token, msg.sender, shares, kubOut, tokenOut);
    }

    function swapKubForToken(address token, uint256 minTokensOut) external payable nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (_phase[token] != Phase.Sealed) revert NotSealed();
        if (msg.value == 0) revert ZeroAmount();
        if (l.poolKub == 0 || l.poolToken == 0) revert InsufficientLiquidity();

        uint256 feeAmount = (msg.value * SWAP_FEE_BPS) / BPS_DENOMINATOR;
        uint256 creatorFee = (msg.value * SWAP_FEE_BPS * CREATOR_FEE_SHARE_BPS) / BPS_DENOMINATOR_SQUARED;
        uint256 netIn = msg.value - feeAmount;
        uint256 lpFee = feeAmount - creatorFee;

        uint256 amountOut = (netIn * l.poolToken) / (l.poolKub + netIn);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut < minTokensOut) revert SlippageExceeded();

        l.poolKub += netIn + lpFee;
        l.poolToken -= amountOut;
        l.creatorFeeKub += creatorFee;

        _safeTransfer(token, msg.sender, amountOut);
        emit Swap(token, msg.sender, true, msg.value, amountOut, feeAmount, creatorFee);
    }

    function swapTokenForKub(address token, uint256 amountIn, uint256 minKubOut) external nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (_phase[token] != Phase.Sealed) revert NotSealed();
        if (amountIn == 0) revert ZeroAmount();
        if (l.poolKub == 0 || l.poolToken == 0) revert InsufficientLiquidity();

        uint256 feeAmount = (amountIn * SWAP_FEE_BPS) / BPS_DENOMINATOR;
        uint256 creatorFee = (amountIn * SWAP_FEE_BPS * CREATOR_FEE_SHARE_BPS) / BPS_DENOMINATOR_SQUARED;
        uint256 netIn = amountIn - feeAmount;
        uint256 lpFee = feeAmount - creatorFee;

        uint256 amountOut = (netIn * l.poolKub) / (l.poolToken + netIn);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut < minKubOut) revert SlippageExceeded();

        l.poolToken += netIn + lpFee;
        l.poolKub -= amountOut;
        l.creatorFeeToken += creatorFee;

        _safeTransferFrom(token, msg.sender, address(this), amountIn);
        _safeTransferKub(msg.sender, amountOut);
        emit Swap(token, msg.sender, false, amountIn, amountOut, feeAmount, creatorFee);
    }

    function claimCreatorFees(address token) external nonReentrant {
        if (!isLaunched[token]) revert TokenNotLaunched();
        TokenLaunch storage l = _launches[token];
        if (msg.sender != l.creator) revert NotCreator();

        uint256 kubFee = l.creatorFeeKub;
        uint256 tokenFee = l.creatorFeeToken;
        l.creatorFeeKub = 0;
        l.creatorFeeToken = 0;

        if (kubFee > 0) {
            _safeTransferKub(msg.sender, kubFee);
        }
        if (tokenFee > 0) {
            _safeTransfer(token, msg.sender, tokenFee);
        }

        emit CreatorFeesClaimed(token, msg.sender, kubFee, tokenFee);
    }

    function getLaunchPhase(address token) external view returns (uint8) {
        return uint8(_phase[token]);
    }

    function getLaunchCreator(address token) external view returns (address) {
        return _launches[token].creator;
    }

    function getLaunchTimes(address token) external view returns (uint40 startTime, uint40 endTime) {
        TokenLaunch storage l = _launches[token];
        return (l.startTime, l.endTime);
    }

    function getLaunchPricing(address token) external view returns (uint256 basePrice, uint256 slope) {
        TokenLaunch storage l = _launches[token];
        return (l.basePrice, l.slope);
    }

    function getLaunchBondingStats(address token) external view returns (uint256 totalKub, uint256 totalTokensAllocated, uint256 totalClaimed) {
        TokenLaunch storage l = _launches[token];
        return (l.totalKub, l.totalTokensAllocated, l.totalClaimed);
    }

    function getLaunchPoolStats(address token) external view returns (uint256 poolKub, uint256 poolToken, uint256 lpTotalSupply) {
        TokenLaunch storage l = _launches[token];
        return (l.poolKub, l.poolToken, l.lpTotalSupply);
    }

    function getLaunchFees(address token) external view returns (uint256 creatorFeeKub, uint256 creatorFeeToken) {
        TokenLaunch storage l = _launches[token];
        return (l.creatorFeeKub, l.creatorFeeToken);
    }

    function getAllLaunches() external view returns (address[] memory) {
        return allLaunches;
    }

    function getCurrentPrice(address token) external view returns (uint256) {
        TokenLaunch storage l = _launches[token];
        return l.basePrice + (l.slope * l.totalTokensAllocated) / 1e18;
    }

    function getTokensForContribution(address token, uint256 kubAmount) external view returns (uint256) {
        TokenLaunch storage l = _launches[token];
        return _computeTokensForKub(l, kubAmount);
    }

    function getClaimableTokens(address token, address user) external view returns (uint256) {
        return tokensOwed[token][user];
    }

    function getUserLpShares(address token, address user) external view returns (uint256) {
        return lpShares[token][user];
    }

    function getPoolReserves(address token) external view returns (uint256 kubReserve, uint256 tokenReserve) {
        TokenLaunch storage l = _launches[token];
        return (l.poolKub, l.poolToken);
    }

    function getBondingTimeRemaining(address token) external view returns (uint40) {
        TokenLaunch storage l = _launches[token];
        if (block.timestamp >= l.endTime) return 0;
        return l.endTime - uint40(block.timestamp);
    }

    function _computeTokensForKub(TokenLaunch storage l, uint256 kubAmount) internal view returns (uint256) {
        uint256 price = l.basePrice + (l.slope * l.totalTokensAllocated) / 1e18;
        if (price == 0) return 0;
        return (kubAmount * 1e18) / price;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferKub(address to, uint256 amount) internal {
        if (address(this).balance < amount) revert TransferFailed();
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
