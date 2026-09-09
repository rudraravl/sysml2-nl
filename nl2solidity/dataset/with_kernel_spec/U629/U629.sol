// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract ProjectToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        minter = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Not minter");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == minter, "Not minter");
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "Insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
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
        require(_status == NOT_ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract BondingCurveLaunchpad is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable baseToken;
    address public admin;
    uint256 public launchFeeBps = 50; // 0.5%
    uint256 public accumulatedFees;

    uint256 public constant GRADUATION_THRESHOLD = 100 * 1e18;
    uint256 public constant BASE_PRICE = 1e16; // 0.01 base tokens
    uint256 public constant SLOPE = 2e14; // 0.0002 base tokens per token
    uint256 public constant PRECISION = 1e18;

    struct Project {
        ProjectToken token;
        address creator;
        uint256 totalBaseDeposited;
        uint256 totalProjectMinted;
        uint256 reserveBase;
        bool graduated;
        bool exists;
        uint256 graduationPrice;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    event ProjectLaunched(uint256 indexed projectId, address indexed creator, address token, uint256 initialTokens, uint256 cost);
    event Bought(uint256 indexed projectId, address indexed buyer, uint256 amount, uint256 cost);
    event Sold(uint256 indexed projectId, address indexed seller, uint256 amount, uint256 refund);
    event Graduated(uint256 indexed projectId, uint256 totalBaseDeposited, uint256 graduationPrice);
    event FeeUpdated(uint256 newBps);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error NotAdmin();
    error ZeroAmount();
    error ProjectNotFound();
    error ProjectGraduated();
    error ProjectNotGraduated();
    error InsufficientReserve();
    error InsufficientBalance();
    error FeeTooHigh();
    error ZeroAddress();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address _baseToken, address _admin) {
        if (_baseToken == address(0) || _admin == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        admin = _admin;
    }

    function setLaunchFee(uint256 _bps) external onlyAdmin {
        if (_bps > 1000) revert FeeTooHigh(); // max 10%
        launchFeeBps = _bps;
        emit FeeUpdated(_bps);
    }

    function withdrawFees(address to, uint256 amount) external onlyAdmin nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientReserve();
        
        accumulatedFees -= amount;
        baseToken.safeTransfer(to, amount);
        
        emit FeesWithdrawn(to, amount);
    }

    function getCost(uint256 currentSupply, uint256 amount) public pure returns (uint256) {
        uint256 linearPart = BASE_PRICE * amount;
        uint256 quadraticNumerator = 2 * currentSupply * amount + amount * amount;
        uint256 quadraticPart = (quadraticNumerator * SLOPE) / (2 * PRECISION);
        return linearPart + quadraticPart;
    }

    function getRefund(uint256 currentSupply, uint256 amount) public pure returns (uint256) {
        if (amount > currentSupply) revert InsufficientBalance();
        uint256 linearPart = BASE_PRICE * amount;
        uint256 quadraticNumerator = 2 * currentSupply * amount - amount * amount;
        uint256 quadraticPart = (quadraticNumerator * SLOPE) / (2 * PRECISION);
        return linearPart + quadraticPart;
    }

    function getPrice(uint256 projectId) public view returns (uint256) {
        Project storage p = projects[projectId];
        if (!p.exists) revert ProjectNotFound();
        if (p.graduated) return p.graduationPrice;
        return BASE_PRICE + (p.totalProjectMinted * SLOPE) / PRECISION;
    }

    function launch(string memory name, string memory symbol, uint256 initialTokens) external nonReentrant returns (uint256) {
        if (initialTokens == 0) revert ZeroAmount();

        uint256 cost = getCost(0, initialTokens);
        uint256 fee = (cost * launchFeeBps) / 10000;
        uint256 totalDeposit = cost + fee;

        accumulatedFees += fee;

        uint256 projectId = projectCount++;
        ProjectToken token = new ProjectToken(name, symbol);

        projects[projectId] = Project({
            token: token,
            creator: msg.sender,
            totalBaseDeposited: cost,
            totalProjectMinted: initialTokens,
            reserveBase: cost,
            graduated: false,
            exists: true,
            graduationPrice: 0
        });

        baseToken.safeTransferFrom(msg.sender, address(this), totalDeposit);
        token.mint(msg.sender, initialTokens);

        emit ProjectLaunched(projectId, msg.sender, address(token), initialTokens, cost);

        if (cost >= GRADUATION_THRESHOLD) {
            _graduate(projectId);
        }

        return projectId;
    }

    function buy(uint256 projectId, uint256 amount) external nonReentrant {
        Project storage p = projects[projectId];
        if (!p.exists) revert ProjectNotFound();
        if (p.graduated) revert ProjectGraduated();
        if (amount == 0) revert ZeroAmount();

        uint256 cost = getCost(p.totalProjectMinted, amount);

        p.totalBaseDeposited += cost;
        p.reserveBase += cost;
        p.totalProjectMinted += amount;

        baseToken.safeTransferFrom(msg.sender, address(this), cost);
        p.token.mint(msg.sender, amount);

        emit Bought(projectId, msg.sender, amount, cost);

        if (p.totalBaseDeposited >= GRADUATION_THRESHOLD) {
            _graduate(projectId);
        }
    }

    function sell(uint256 projectId, uint256 amount) external nonReentrant {
        Project storage p = projects[projectId];
        if (!p.exists) revert ProjectNotFound();
        if (p.graduated) revert ProjectGraduated();
        if (amount == 0) revert ZeroAmount();
        if (amount > p.totalProjectMinted) revert InsufficientBalance();
        if (p.token.balanceOf(msg.sender) < amount) revert InsufficientBalance();

        uint256 refund = getRefund(p.totalProjectMinted, amount);

        p.totalProjectMinted -= amount;
        p.reserveBase -= refund;
        p.totalBaseDeposited -= refund;

        p.token.burn(msg.sender, amount);
        baseToken.safeTransfer(msg.sender, refund);

        emit Sold(projectId, msg.sender, amount, refund);
    }

    function claim(uint256 projectId, uint256 amount) external nonReentrant {
        Project storage p = projects[projectId];
        if (!p.exists) revert ProjectNotFound();
        if (!p.graduated) revert ProjectNotGraduated();
        if (amount == 0) revert ZeroAmount();
        if (p.token.balanceOf(msg.sender) < amount) revert InsufficientBalance();

        uint256 payout = (amount * p.graduationPrice) / PRECISION;
        if (payout == 0) revert ZeroAmount();
        if (payout > p.reserveBase) revert InsufficientReserve();

        p.reserveBase -= payout;

        p.token.burn(msg.sender, amount);
        baseToken.safeTransfer(msg.sender, payout);

        emit Sold(projectId, msg.sender, amount, payout);
    }

    function _graduate(uint256 projectId) internal {
        Project storage p = projects[projectId];
        if (p.graduated) revert ProjectGraduated();
        
        p.graduationPrice = BASE_PRICE + (p.totalProjectMinted * SLOPE) / PRECISION;
        p.graduated = true;
        
        emit Graduated(projectId, p.totalBaseDeposited, p.graduationPrice);
    }
}
