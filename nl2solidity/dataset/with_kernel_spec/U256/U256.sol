// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IMintableToken {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(amount == 0 || token.allowance(address(this), spender) == 0, "SafeERC20: approve from non-zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount();
    error OwnableInvalidOwner();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner();
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount();
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner();
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
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

contract BondingCurveLauncher is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant FEE_BPS = 50;
    uint256 public constant HARD_CAP = 10_000_000 * 1e18;
    uint256 public constant PRECISION = 1e18;

    struct Launch {
        address token;
        address collateral;
        address creator;
        uint256 basePrice;
        uint256 slope;
        uint256 collateralDeposited;
        uint256 tokensMinted;
        bool approved;
        bool concluded;
        bool exists;
    }

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public purchased;
    uint256 public launchCount;

    address public operator;
    address public treasury;

    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event LaunchRequested(uint256 indexed launchId, address indexed creator, address token, address collateral);
    event LaunchApproved(uint256 indexed launchId, address indexed operator, uint256 basePrice, uint256 slope);
    event LaunchConcluded(uint256 indexed launchId);
    event Deposited(uint256 indexed launchId, address indexed depositor, uint256 tokenAmount, uint256 collateralCost, uint256 fee);
    event Claimed(uint256 indexed launchId, address indexed claimant, uint256 amount);

    error ZeroAddress();
    error NotOperator();
    error LaunchNotFound();
    error LaunchNotApproved();
    error LaunchAlreadyApproved();
    error LaunchAlreadyConcluded();
    error ZeroAmount();
    error ExceedsHardCap();
    error InsufficientPurchased();
    error LaunchNotConcluded();
    error InvalidCurveParams();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier launchExists(uint256 launchId) {
        if (!launches[launchId].exists) revert LaunchNotFound();
        _;
    }

    constructor(address _operator, address _treasury) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function requestLaunch(address token, address collateral)
        external
        nonReentrant
        returns (uint256 launchId)
    {
        if (token == address(0)) revert ZeroAddress();
        if (collateral == address(0)) revert ZeroAddress();

        launchId = launchCount++;
        Launch storage l = launches[launchId];
        l.token = token;
        l.collateral = collateral;
        l.creator = msg.sender;
        l.exists = true;

        emit LaunchRequested(launchId, msg.sender, token, collateral);
    }

    function approveLaunch(uint256 launchId, uint256 basePrice, uint256 slope)
        external
        launchExists(launchId)
        onlyOperator
    {
        Launch storage l = launches[launchId];
        if (l.approved) revert LaunchAlreadyApproved();
        if (basePrice == 0 && slope == 0) revert InvalidCurveParams();

        l.basePrice = basePrice;
        l.slope = slope;
        l.approved = true;

        emit LaunchApproved(launchId, msg.sender, basePrice, slope);
    }

    function concludeLaunch(uint256 launchId) external launchExists(launchId) {
        Launch storage l = launches[launchId];
        if (!l.approved) revert LaunchNotApproved();
        if (l.concluded) revert LaunchAlreadyConcluded();
        if (msg.sender != l.creator && msg.sender != operator) revert NotOperator();
        l.concluded = true;
        emit LaunchConcluded(launchId);
    }

    function deposit(uint256 launchId, uint256 tokenAmount)
        external
        launchExists(launchId)
        nonReentrant
    {
        if (tokenAmount == 0) revert ZeroAmount();

        Launch storage l = launches[launchId];
        if (!l.approved) revert LaunchNotApproved();
        if (l.concluded) revert LaunchAlreadyConcluded();
        if (l.tokensMinted + tokenAmount > HARD_CAP) revert ExceedsHardCap();

        uint256 cost = _computeCost(l.basePrice, l.slope, l.tokensMinted, tokenAmount);
        if (cost == 0) revert ZeroAmount();

        uint256 fee = (cost * FEE_BPS) / BPS;
        uint256 net = cost - fee;

        // Effects: update state before external interactions
        l.collateralDeposited += net;
        l.tokensMinted += tokenAmount;
        purchased[launchId][msg.sender] += tokenAmount;

        // Interactions
        IERC20(l.collateral).safeTransferFrom(msg.sender, address(this), cost);
        if (fee > 0) {
            IERC20(l.collateral).safeTransfer(treasury, fee);
        }

        IMintableToken(l.token).mint(address(this), tokenAmount);

        emit Deposited(launchId, msg.sender, tokenAmount, cost, fee);
    }

    function claim(uint256 launchId) external launchExists(launchId) nonReentrant {
        Launch storage l = launches[launchId];
        if (!l.concluded) revert LaunchNotConcluded();

        uint256 amount = purchased[launchId][msg.sender];
        if (amount == 0) revert InsufficientPurchased();

        // Effects: update state before external interaction
        purchased[launchId][msg.sender] = 0;

        // Interactions
        IERC20(l.token).safeTransfer(msg.sender, amount);

        emit Claimed(launchId, msg.sender, amount);
    }

    function _computeCost(
        uint256 basePrice,
        uint256 slope,
        uint256 currentSupply,
        uint256 tokenAmount
    ) internal pure returns (uint256) {
        // cost = integral from s to s+a of (basePrice/PRECISION + slope * x / PRECISION^2) dx
        //      = (basePrice * a) / PRECISION + (slope * a * (2*s + a)) / (2 * PRECISION^2)
        //      = (basePrice * a) / PRECISION + (slope * a * (end + s)) / (2 * PRECISION^2)
        // Perform all multiplications before divisions to avoid precision loss.
        uint256 linearPart = (basePrice * tokenAmount) / PRECISION;

        uint256 end = currentSupply + tokenAmount;
        uint256 curvePart = (slope * tokenAmount * (end + currentSupply)) / (2 * PRECISION * PRECISION);

        return linearPart + curvePart;
    }

    function getLaunch(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (
            address token,
            address collateral,
            address creator,
            uint256 basePrice,
            uint256 slope,
            uint256 collateralDeposited,
            uint256 tokensMinted,
            bool approved,
            bool concluded
        )
    {
        Launch storage l = launches[launchId];
        return (
            l.token,
            l.collateral,
            l.creator,
            l.basePrice,
            l.slope,
            l.collateralDeposited,
            l.tokensMinted,
            l.approved,
            l.concluded
        );
    }

    function getPurchased(uint256 launchId, address account) external view returns (uint256) {
        return purchased[launchId][account];
    }

    function getCurrentPrice(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (uint256)
    {
        Launch storage l = launches[launchId];
        if (!l.approved) revert LaunchNotApproved();
        return l.basePrice + (l.slope * l.tokensMinted) / PRECISION;
    }

    function getCostForAmount(uint256 launchId, uint256 tokenAmount)
        external
        view
        launchExists(launchId)
        returns (uint256)
    {
        Launch storage l = launches[launchId];
        if (!l.approved) revert LaunchNotApproved();
        if (tokenAmount == 0) revert ZeroAmount();
        if (l.tokensMinted + tokenAmount > HARD_CAP) revert ExceedsHardCap();
        return _computeCost(l.basePrice, l.slope, l.tokensMinted, tokenAmount);
    }
}
