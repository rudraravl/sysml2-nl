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

interface IStakingProvider {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external returns (uint256);
    function claimRewards() external returns (uint256);
}

contract ERC20 {
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner_][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _allowances[owner_][spender] = currentAllowance - amount;
            }
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
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
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: token operation failed");
        }
    }
}

contract LiquidStakingToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AmountZero();
    error InsufficientIdleBalance();
    error InsufficientStakedBalance();
    error InsufficientReceiptBalance();
    error FeeExceedsMaximum();
    error NotOperator();
    error NoPendingRewards();
    error InvalidShares();

    event Deposit(address indexed depositor, address indexed receiver, uint256 assetsDeposited, uint256 receiptsMinted);
    event Redeem(address indexed caller, address indexed receiver, address indexed tokenOwner, uint256 receiptsBurned, uint256 assetsReturned, uint256 fee);
    event Staked(address indexed operator, uint256 amount);
    event Unstaked(address indexed operator, uint256 amountRequested, uint256 amountReceived);
    event RewardsClaimed(address indexed operator, uint256 rewardsAmount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event RedemptionFeeUpdated(uint256 previousFeeBps, uint256 newFeeBps);

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 100; // 1%
    uint256 public constant INITIAL_REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;

    IERC20 public immutable baseAsset;
    IStakingProvider public immutable stakingProvider;

    address public operator;
    uint256 public redemptionFeeBps;
    uint256 public totalIdle;
    uint256 public stakedWithProvider;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address _baseAsset,
        address _stakingProvider,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_baseAsset == address(0) || _stakingProvider == address(0)) revert ZeroAddress();
        baseAsset = IERC20(_baseAsset);
        stakingProvider = IStakingProvider(_stakingProvider);
        operator = msg.sender;
        redemptionFeeBps = INITIAL_REDEMPTION_FEE_BPS;
        emit OperatorUpdated(address(0), msg.sender);
        emit RedemptionFeeUpdated(0, INITIAL_REDEMPTION_FEE_BPS);
    }

    function totalAssets() public view returns (uint256) {
        return totalIdle + stakedWithProvider;
    }

    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 receipts) {
        if (assets < 1) revert AmountZero();
        if (receiver == address(0)) revert ZeroAddress();

        baseAsset.safeTransferFrom(msg.sender, address(this), assets);

        uint256 supply = totalSupply();
        uint256 currentAssets = totalAssets();
        if (supply < 1 || currentAssets < 1) {
            receipts = assets;
        } else {
            receipts = (assets * supply) / currentAssets;
        }
        if (receipts < 1) revert InvalidShares();

        totalIdle += assets;
        _mint(receiver, receipts);

        emit Deposit(msg.sender, receiver, assets, receipts);
    }

    function redeem(uint256 receipts, address receiver, address tokenOwner) external nonReentrant returns (uint256 assetsOut) {
        if (receipts < 1) revert AmountZero();
        if (receiver == address(0)) revert ZeroAddress();

        uint256 supply = totalSupply();
        if (supply < 1) revert InvalidShares();
        if (balanceOf(tokenOwner) < receipts) revert InsufficientReceiptBalance();

        if (msg.sender != tokenOwner) {
            _spendAllowance(tokenOwner, msg.sender, receipts);
        }

        uint256 currentAssets = totalAssets();
        uint256 proportional = receipts * currentAssets;
        uint256 fee = (proportional * redemptionFeeBps) / (supply * FEE_DENOMINATOR);
        uint256 grossAssets = proportional / supply;
        assetsOut = grossAssets - fee;

        if (totalIdle < assetsOut) revert InsufficientIdleBalance();

        _burn(tokenOwner, receipts);
        totalIdle -= assetsOut;

        baseAsset.safeTransfer(receiver, assetsOut);

        emit Redeem(msg.sender, receiver, tokenOwner, receipts, assetsOut, fee);
    }

    function stake(uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert AmountZero();
        if (totalIdle < amount) revert InsufficientIdleBalance();

        totalIdle -= amount;
        stakedWithProvider += amount;

        baseAsset.safeIncreaseAllowance(address(stakingProvider), amount);
        stakingProvider.stake(amount);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert AmountZero();
        if (stakedWithProvider < amount) revert InsufficientStakedBalance();

        stakedWithProvider -= amount;
        uint256 received = stakingProvider.unstake(amount);
        totalIdle += received;

        emit Unstaked(msg.sender, amount, received);
    }

    function claimRewards() external onlyOperator nonReentrant returns (uint256 rewards) {
        rewards = stakingProvider.claimRewards();
        if (rewards < 1) revert NoPendingRewards();

        totalIdle += rewards;

        emit RewardsClaimed(msg.sender, rewards);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setRedemptionFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_REDEMPTION_FEE_BPS) revert FeeExceedsMaximum();
        emit RedemptionFeeUpdated(redemptionFeeBps, _feeBps);
        redemptionFeeBps = _feeBps;
    }

    function exchangeRate() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply < 1) return EXCHANGE_RATE_PRECISION;
        return (totalAssets() * EXCHANGE_RATE_PRECISION) / supply;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 currentAssets = totalAssets();
        if (supply < 1 || currentAssets < 1) return assets;
        return (assets * supply) / currentAssets;
    }

    function previewRedeem(uint256 receipts) external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply < 1) return 0;
        uint256 currentAssets = totalAssets();
        uint256 proportional = receipts * currentAssets;
        uint256 fee = (proportional * redemptionFeeBps) / (supply * FEE_DENOMINATOR);
        uint256 gross = proportional / supply;
        return gross - fee;
    }
}
