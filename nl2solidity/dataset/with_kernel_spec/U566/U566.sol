// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LaunchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public immutable owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        owner = _owner;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
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
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    error OnlyOwner();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
}

contract Pool {
    address public immutable token;
    address public immutable creator;
    address public immutable launchpad;

    uint256 public constant VIRTUAL_BASE = 10 ether;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000_000 * 1e18;

    uint256 public tokenReserve;
    uint256 public baseReserve;
    uint256 public k;

    bool private locked;

    event Swap(
        address indexed user,
        address indexed pool,
        uint256 baseAmount,
        uint256 tokenAmount,
        bool baseToToken
    );
    event FeeDistributed(uint256 creatorAmount, uint256 bidWallAmount, uint256 platformAmount);

    error ZeroInput();
    error ZeroOutput();
    error InsufficientLiquidity();
    error ReentrantCall();
    error EthTransferFailed();
    error TransferFailed();

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor(address _token, address _creator) {
        token = _token;
        creator = _creator;
        launchpad = msg.sender;
        tokenReserve = INITIAL_TOKEN_SUPPLY;
        baseReserve = 0;
        k = tokenReserve * VIRTUAL_BASE;
    }

    function swapBaseForToken() external payable nonReentrant returns (uint256 tokensOut) {
        uint256 baseIn = msg.value;
        if (baseIn == 0) revert ZeroInput();

        uint256 feeBps = Launchpad(launchpad).platformFeeBps();
        uint256 fee = (baseIn * feeBps) / 10000;
        uint256 baseInNet = baseIn - fee;

        uint256 oldEffBase = baseReserve + VIRTUAL_BASE;
        uint256 newEffBase = oldEffBase + baseInNet;
        uint256 newTokenReserve = k / newEffBase;
        tokensOut = tokenReserve - newTokenReserve;
        if (tokensOut == 0) revert ZeroOutput();

        tokenReserve = newTokenReserve;
        baseReserve += baseInNet;

        if (!LaunchToken(token).transfer(msg.sender, tokensOut)) revert TransferFailed();
        _distributeFee(fee);

        emit Swap(msg.sender, address(this), baseIn, tokensOut, true);
    }

    function swapTokenForBase(uint256 tokenIn) external nonReentrant returns (uint256 baseOut) {
        if (tokenIn == 0) revert ZeroInput();

        if (!LaunchToken(token).transferFrom(msg.sender, address(this), tokenIn)) revert TransferFailed();

        uint256 oldEffBase = baseReserve + VIRTUAL_BASE;
        uint256 newTokenReserve = tokenReserve + tokenIn;
        uint256 newEffBase = k / newTokenReserve;
        if (newEffBase < VIRTUAL_BASE) revert InsufficientLiquidity();

        baseOut = oldEffBase - newEffBase;
        if (baseOut == 0) revert ZeroOutput();

        uint256 feeBps = Launchpad(launchpad).platformFeeBps();
        uint256 fee = (baseOut * feeBps) / 10000;
        uint256 baseOutNet = baseOut - fee;

        tokenReserve = newTokenReserve;
        baseReserve -= baseOut;

        _sendETH(msg.sender, baseOutNet);
        _distributeFee(fee);

        emit Swap(msg.sender, address(this), baseOut, tokenIn, false);
    }

    function getReserves() external view returns (uint256 _tokenReserve, uint256 _baseReserve) {
        return (tokenReserve, baseReserve);
    }

    function _distributeFee(uint256 feeAmount) internal {
        if (feeAmount == 0) {
            emit FeeDistributed(0, 0, 0);
            return;
        }
        (
            uint256 creatorBps,
            uint256 bidWallBps,
            uint256 platformBps,
            address bidWall,
            address platform
        ) = Launchpad(launchpad).feeConfig();

        uint256 creatorAmt = (feeAmount * creatorBps) / 10000;
        uint256 bidWallAmt = (feeAmount * bidWallBps) / 10000;
        uint256 platformAmt = (feeAmount * platformBps) / 10000;

        _sendETH(creator, creatorAmt);
        _sendETH(bidWall, bidWallAmt);
        _sendETH(platform, platformAmt);

        emit FeeDistributed(creatorAmt, bidWallAmt, platformAmt);
    }

    function _sendETH(address to, uint256 amount) internal {
        if (amount == 0 || to == address(0)) return;
        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }

    receive() external payable {}
}

contract Launchpad {
    address public admin;

    uint256 public platformFeeBps;

    uint256 public creatorShareBps;
    uint256 public bidWallShareBps;
    uint256 public platformShareBps;
    address public bidWallAddress;
    address public platformAddress;

    mapping(address token => address pool) public poolOf;
    mapping(address pool => address token) public tokenOf;
    address[] public allPools;

    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant MAX_FEE_BPS = 10000;

    event TokenLaunched(
        address indexed token,
        address indexed pool,
        address indexed creator,
        string name,
        string symbol
    );
    event FeeDistributionUpdated(
        uint256 creatorShareBps,
        uint256 bidWallShareBps,
        uint256 platformShareBps
    );
    event PlatformFeeUpdated(uint256 platformFeeBps);
    event BidWallAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event PlatformAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error OnlyAdmin();
    error InvalidFeeBps();
    error InvalidDistribution();
    error ZeroAddress();
    error EmptyString();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    constructor(address _bidWall, address _platform) {
        if (_bidWall == address(0) || _platform == address(0)) revert ZeroAddress();
        admin = msg.sender;
        bidWallAddress = _bidWall;
        platformAddress = _platform;
        platformFeeBps = 100;
        creatorShareBps = 5000;
        bidWallShareBps = 2500;
        platformShareBps = 2500;
    }

    function feeConfig()
        external
        view
        returns (uint256 creatorBps, uint256 bidWallBps, uint256 platformBps, address bidWall, address platform)
    {
        return (creatorShareBps, bidWallShareBps, platformShareBps, bidWallAddress, platformAddress);
    }

    function launchToken(string calldata name, string calldata symbol)
        external
        returns (address token, address pool)
    {
        if (bytes(name).length == 0) revert EmptyString();
        if (bytes(symbol).length == 0) revert EmptyString();

        LaunchToken t = new LaunchToken(name, symbol, address(this));
        Pool p = new Pool(address(t), msg.sender);
        token = address(t);
        pool = address(p);

        poolOf[token] = pool;
        tokenOf[pool] = token;
        allPools.push(pool);

        t.mint(pool, INITIAL_TOKEN_SUPPLY);

        emit TokenLaunched(token, pool, msg.sender, name, symbol);
    }

    function setPlatformFeeBps(uint256 _bps) external onlyAdmin {
        if (_bps > MAX_FEE_BPS) revert InvalidFeeBps();
        platformFeeBps = _bps;
        emit PlatformFeeUpdated(_bps);
    }

    function setFeeDistribution(
        uint256 _creatorBps,
        uint256 _bidWallBps,
        uint256 _platformBps
    ) external onlyAdmin {
        if (_creatorBps + _bidWallBps + _platformBps != MAX_FEE_BPS) revert InvalidDistribution();
        creatorShareBps = _creatorBps;
        bidWallShareBps = _bidWallBps;
        platformShareBps = _platformBps;
        emit FeeDistributionUpdated(_creatorBps, _bidWallBps, _platformBps);
    }

    function setBidWallAddress(address _bidWall) external onlyAdmin {
        if (_bidWall == address(0)) revert ZeroAddress();
        address old = bidWallAddress;
        bidWallAddress = _bidWall;
        emit BidWallAddressUpdated(old, _bidWall);
    }

    function setPlatformAddress(address _platform) external onlyAdmin {
        if (_platform == address(0)) revert ZeroAddress();
        address old = platformAddress;
        platformAddress = _platform;
        emit PlatformAddressUpdated(old, _platform);
    }

    function setAdmin(address _admin) external onlyAdmin {
        if (_admin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = _admin;
        emit AdminUpdated(old, _admin);
    }

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    function getPool(address token) external view returns (address) {
        return poolOf[token];
    }

    function getToken(address pool) external view returns (address) {
        return tokenOf[pool];
    }
}
