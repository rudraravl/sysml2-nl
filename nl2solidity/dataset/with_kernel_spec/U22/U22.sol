// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function rebalance() external;
}

contract YieldVault {
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientAssets();
    error AllowanceInsufficient();
    error DepositCapExceeded();
    error Unauthorized();
    error TransferFailed();
    error Reentrancy();
    error StrategyNotSet();

    event Deposit(address indexed depositor, uint256 amount, uint256 shares);
    event Withdraw(address indexed withdrawer, uint256 amount, uint256 shares, uint256 fee);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event StrategySet(address indexed oldStrategy, address indexed newStrategy);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event RebalanceInitiated(address indexed caller, uint256 yieldRealized);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 value);

    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public immutable DEPOSIT_CAP;

    IERC20 public immutable baseAsset;
    IStrategy public strategy;
    address public owner;
    address public operator;

    uint256 public totalDeposited;
    uint256 public totalShares;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool private locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    constructor(address _baseAsset, address _strategy, address _operator) {
        if (_baseAsset == address(0)) revert ZeroAddress();

        baseAsset = IERC20(_baseAsset);
        DEPOSIT_CAP = 1_000_000 * (10 ** uint256(IERC20(_baseAsset).decimals()));
        strategy = IStrategy(_strategy);
        operator = _operator;
        owner = msg.sender;

        emit StrategySet(address(0), _strategy);
        emit OperatorSet(address(0), _operator);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, newOperator);
        operator = newOperator;
    }

    function setStrategy(address newStrategy) external onlyOwner {
        emit StrategySet(address(strategy), newStrategy);
        strategy = IStrategy(newStrategy);
    }

    function totalAssets() public view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }

    function convertToShares(uint256 amount) public view returns (uint256) {
        if (totalShares > 0 && totalDeposited > 0) {
            return (amount * totalShares) / totalDeposited;
        }
        return amount;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalShares > 0 && totalDeposited > 0) {
            return (shares * totalDeposited) / totalShares;
        }
        return 0;
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();
        if (amount > DEPOSIT_CAP) revert DepositCapExceeded();

        shares = convertToShares(amount);
        if (shares < 1) revert ZeroShares();

        // Effects: update state before external call (checks-effects-interactions)
        totalDeposited += amount;
        totalShares += shares;
        balanceOf[msg.sender] += shares;

        // Interactions: pull base asset from depositor
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 assets) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (assets > totalDeposited) revert InsufficientAssets();

        shares = convertToShares(assets);
        if (shares < 1) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        _redeem(shares, assets, msg.sender);
    }

    function redeem(uint256 shares) external nonReentrant returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        assets = convertToAssets(shares);
        if (assets < 1) revert ZeroAmount();

        _redeem(shares, assets, msg.sender);
    }

    function _redeem(uint256 shares, uint256 assets, address from) internal {
        uint256 fee = (assets * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = assets - fee;

        // Effects: update state before external calls
        totalShares -= shares;
        totalDeposited -= assets;
        balanceOf[from] -= shares;

        // Interactions: transfer net assets to user and fee to owner
        if (!baseAsset.transfer(from, net)) revert TransferFailed();
        if (fee > 0) {
            if (!baseAsset.transfer(owner, fee)) revert TransferFailed();
        }

        emit Withdraw(from, assets, shares, fee);
    }

    function rebalance() external onlyOperator nonReentrant {
        if (address(strategy) == address(0)) revert StrategyNotSet();

        uint256 balanceBefore = baseAsset.balanceOf(address(this));
        strategy.rebalance();
        uint256 balanceAfter = baseAsset.balanceOf(address(this));

        uint256 yieldRealized = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;

        if (totalShares > 0) {
            totalDeposited = balanceAfter;
        }

        emit RebalanceInitiated(msg.sender, yieldRealized);
    }

    function approve(address spender, uint256 shares) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = shares;
        emit Approval(msg.sender, spender, shares);
        return true;
    }

    function transfer(address to, uint256 shares) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        balanceOf[msg.sender] -= shares;
        balanceOf[to] += shares;

        emit Transfer(msg.sender, to, shares);
        return true;
    }

    function transferFrom(address from, address to, uint256 shares) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < shares) revert InsufficientShares();

        if (msg.sender != from) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if (allowed < shares) revert AllowanceInsufficient();
                allowance[from][msg.sender] = allowed - shares;
            }
        }

        balanceOf[from] -= shares;
        balanceOf[to] += shares;

        emit Transfer(from, to, shares);
        return true;
    }
}
