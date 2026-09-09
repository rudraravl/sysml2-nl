// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function transfer(address to, uint256 amount) external virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
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
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

contract LaunchToken is ERC20 {
    address public immutable launchpad;
    bool public tradable;

    error OnlyLaunchpad();
    error NotTradable();

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        launchpad = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != launchpad) revert OnlyLaunchpad();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != launchpad) revert OnlyLaunchpad();
        _burn(from, amount);
    }

    function setTradable() external {
        if (msg.sender != launchpad) revert OnlyLaunchpad();
        tradable = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        if (!tradable) revert NotTradable();
        super._transfer(from, to, amount);
    }
}

contract TokenLaunchpad {
    uint256 public constant SCALE = 1e18;
    uint256 public constant MAX_PROTOCOL_CUT_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public operator;
    uint256 public baseFee;
    uint256 public protocolCutBps;
    uint256 public accumulatedFees;

    struct TokenInfo {
        address token;
        address creator;
        uint256 liquidity;
        uint256 supply;
        bool finalized;
    }

    mapping(uint256 => TokenInfo) public tokens;
    mapping(uint256 => mapping(address => uint256)) public curveBalance;
    uint256 public tokenCount;

    uint256 private _status = 1;

    event TokenCreated(
        uint256 indexed tokenId,
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialNative,
        uint256 initialSupply
    );
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 nativeIn, uint256 tokensOut);
    event Sold(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 tokensIn,
        uint256 nativeOut,
        uint256 protocolCut
    );
    event Finalized(uint256 indexed tokenId, address indexed creator, uint256 nativeReleased);
    event BaseFeeUpdated(uint256 oldFee, uint256 newFee);
    event ProtocolCutUpdated(uint256 oldCutBps, uint256 newCutBps);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed operator, uint256 amount);

    error OnlyOperator();
    error OnlyCreator();
    error ZeroAmount();
    error ZeroAddress();
    error TokenNotFound();
    error TokenFinalized();
    error ProtocolCutTooHigh(uint256 requested, uint256 max);
    error InsufficientPayment(uint256 provided, uint256 required);
    error ExceedsCurveSupply(uint256 supply, uint256 requested);
    error InsufficientTokenBalance(uint256 available, uint256 needed);
    error NativeTransferFailed();
    error NoFeeBalance();
    error ReentrantCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor() {
        operator = msg.sender;
        baseFee = 0.1 ether;
        protocolCutBps = 0;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setBaseFee(uint256 newFee) external onlyOperator {
        emit BaseFeeUpdated(baseFee, newFee);
        baseFee = newFee;
    }

    function setProtocolCut(uint256 newCutBps) external onlyOperator {
        if (newCutBps > MAX_PROTOCOL_CUT_BPS) revert ProtocolCutTooHigh(newCutBps, MAX_PROTOCOL_CUT_BPS);
        emit ProtocolCutUpdated(protocolCutBps, newCutBps);
        protocolCutBps = newCutBps;
    }

    function createToken(
        string calldata name_,
        string calldata symbol_,
        uint256 initialNative
    ) external payable nonReentrant returns (uint256 tokenId) {
        if (initialNative == 0) revert ZeroAmount();
        uint256 required = baseFee + initialNative;
        if (msg.value < required) revert InsufficientPayment(msg.value, required);

        tokenId = ++tokenCount;
        LaunchToken token = new LaunchToken(name_, symbol_);

        uint256 initialSupply = _sqrt(initialNative * SCALE);
        token.mint(msg.sender, initialSupply);

        tokens[tokenId] = TokenInfo({
            token: address(token),
            creator: msg.sender,
            liquidity: initialNative,
            supply: initialSupply,
            finalized: false
        });
        curveBalance[tokenId][msg.sender] = initialSupply;

        accumulatedFees += baseFee;

        if (msg.value > required) {
            uint256 refund = msg.value - required;
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert NativeTransferFailed();
        }

        emit TokenCreated(tokenId, address(token), msg.sender, name_, symbol_, initialNative, initialSupply);
    }

    function buy(uint256 tokenId) external payable nonReentrant returns (uint256 tokensOut) {
        TokenInfo storage t = tokens[tokenId];
        if (t.token == address(0)) revert TokenNotFound();
        if (t.finalized) revert TokenFinalized();
        if (msg.value == 0) revert ZeroAmount();

        uint256 newSupply = _sqrt(t.supply * t.supply + msg.value * SCALE);
        tokensOut = newSupply - t.supply;
        if (tokensOut == 0) revert ZeroAmount();

        t.supply = newSupply;
        t.liquidity += msg.value;
        curveBalance[tokenId][msg.sender] += tokensOut;

        LaunchToken(t.token).mint(msg.sender, tokensOut);

        emit Bought(tokenId, msg.sender, msg.value, tokensOut);
    }

    function sell(uint256 tokenId, uint256 tokensIn) external nonReentrant returns (uint256 nativeOut) {
        TokenInfo storage t = tokens[tokenId];
        if (t.token == address(0)) revert TokenNotFound();
        if (t.finalized) revert TokenFinalized();
        if (tokensIn == 0) revert ZeroAmount();
        if (tokensIn > t.supply) revert ExceedsCurveSupply(t.supply, tokensIn);

        LaunchToken token = LaunchToken(t.token);
        uint256 sellerBalance = token.balanceOf(msg.sender);
        if (sellerBalance < tokensIn) revert InsufficientTokenBalance(sellerBalance, tokensIn);

        uint256 newSupply = t.supply - tokensIn;
        uint256 numerator = t.supply * t.supply - newSupply * newSupply;
        nativeOut = numerator / SCALE;
        if (nativeOut > t.liquidity) nativeOut = t.liquidity;

        uint256 cut = (numerator * protocolCutBps) / (SCALE * BPS_DENOMINATOR);
        if (cut > nativeOut) cut = nativeOut;
        uint256 sellerAmount = nativeOut - cut;

        t.supply = newSupply;
        t.liquidity -= nativeOut;
        curveBalance[tokenId][msg.sender] -= tokensIn;
        accumulatedFees += cut;

        token.burn(msg.sender, tokensIn);

        (bool ok, ) = payable(msg.sender).call{value: sellerAmount}("");
        if (!ok) revert NativeTransferFailed();

        emit Sold(tokenId, msg.sender, tokensIn, nativeOut, cut);
    }

    function finalize(uint256 tokenId) external nonReentrant {
        TokenInfo storage t = tokens[tokenId];
        if (t.token == address(0)) revert TokenNotFound();
        if (t.finalized) revert TokenFinalized();
        if (t.creator != msg.sender) revert OnlyCreator();

        t.finalized = true;
        uint256 released = t.liquidity;
        t.liquidity = 0;

        LaunchToken(t.token).setTradable();

        if (released > 0) {
            (bool ok, ) = payable(t.creator).call{value: released}("");
            if (!ok) revert NativeTransferFailed();
        }

        emit Finalized(tokenId, t.creator, released);
    }

    function withdrawFees() external onlyOperator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeeBalance();
        accumulatedFees = 0;
        (bool ok, ) = payable(operator).call{value: amount}("");
        if (!ok) revert NativeTransferFailed();
        emit FeesWithdrawn(operator, amount);
    }

    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (address token, address creator, uint256 liquidity, uint256 supply, bool finalized)
    {
        TokenInfo storage t = tokens[tokenId];
        return (t.token, t.creator, t.liquidity, t.supply, t.finalized);
    }

    function getCurveBalance(uint256 tokenId, address user) external view returns (uint256) {
        return curveBalance[tokenId][user];
    }

    function getBuyAmount(uint256 tokenId, uint256 nativeIn) external view returns (uint256) {
        TokenInfo storage t = tokens[tokenId];
        if (t.token == address(0) || t.finalized || nativeIn == 0) return 0;
        uint256 newSupply = _sqrt(t.supply * t.supply + nativeIn * SCALE);
        return newSupply - t.supply;
    }

    function getSellAmount(uint256 tokenId, uint256 tokensIn) external view returns (uint256) {
        TokenInfo storage t = tokens[tokenId];
        if (t.token == address(0) || t.finalized || tokensIn == 0 || tokensIn > t.supply) return 0;
        uint256 newSupply = t.supply - tokensIn;
        uint256 out = (t.supply * t.supply - newSupply * newSupply) / SCALE;
        if (out > t.liquidity) out = t.liquidity;
        return out;
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
