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

library SafeERC20 {
    error SafeTransferFailed();
    error SafeTransferFromFailed();
    error SafeApproveFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeTransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeTransferFromFailed();
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool ok = token.approve(spender, amount);
        if (!ok) revert SafeApproveFailed();
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

abstract contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view virtual override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < subtractedValue) revert ERC20InsufficientAllowance(spender, currentAllowance, subtractedValue);
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));
        _update(from, to, amount);
    }

    function _update(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _totalSupply += amount;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < amount) revert ERC20InsufficientBalance(from, fromBalance, amount);
            unchecked {
                _balances[from] = fromBalance - amount;
            }
        }
        if (to == address(0)) {
            unchecked {
                _totalSupply -= amount;
            }
        } else {
            unchecked {
                _balances[to] += amount;
            }
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(address(0));
        _update(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(address(0));
        _update(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        if (owner_ == address(0)) revert ERC20InvalidApprover(address(0));
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner_, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            unchecked {
                _approve(owner_, spender, currentAllowance - amount);
            }
        }
    }
}

/// @title TokenBasket
/// @notice An ERC-20 basket token backed by a diversified portfolio of underlying ERC-20 tokens.
/// Users deposit supported tokens to mint basket shares, withdraw underlying tokens by burning
/// shares, and claim reward tokens distributed proportionally to basket holdings. A designated
/// rebalancer adjusts composition when actual weights deviate from targets beyond a threshold.
contract TokenBasket is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%
    uint256 public constant DEFAULT_REBALANCE_THRESHOLD = 100; // 1%
    uint256 private constant REWARD_PRECISION = 1e18;

    // ============ Structs ============
    struct TokenInfo {
        bool supported;
        uint256 targetWeight; // in basis points
    }

    // ============ State Variables ============
    mapping(address => TokenInfo) public tokenInfo;
    address[] public supportedTokensList;
    uint256 public totalTargetWeight;

    uint256 public rebalanceThreshold;
    address public rebalancer;

    IERC20 public rewardToken;
    uint256 public rewardRate; // reward tokens per second
    uint256 public lastRewardTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // ============ Events ============
    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 sharesMinted);
    event Withdrawn(address indexed user, address indexed basketBurned, uint256 totalFeeCollected);
    event RewardsClaimed(address indexed user, uint256 amount);
    event BasketCompositionChanged(address indexed token, uint256 newBalance, uint256 targetWeight);
    event RebalanceThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RebalancerUpdated(address indexed oldRebalancer, address indexed newRebalancer);
    event TokenAdded(address indexed token, uint256 targetWeight);
    event TokenRemoved(address indexed token);
    event TargetWeightUpdated(address indexed token, uint256 oldWeight, uint256 newWeight);
    event Rebalanced(address indexed rebalancer);

    // ============ Custom Errors ============
    error ZeroAddress();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientContractBalance();
    error InvalidWeight();
    error WeightSumExceedsMax();
    error NotRebalancer();
    error RebalanceFailed();
    error ArrayLengthMismatch();
    error NoPendingRewards();
    error InvalidThreshold();
    error CannotRecoverSupportedToken();

    // ============ Modifiers ============
    modifier onlyRebalancerRole() {
        if (msg.sender != rebalancer) revert NotRebalancer();
        _;
    }

    // ============ Constructor ============
    constructor(
        string memory name_,
        string memory symbol_,
        address rewardToken_,
        address rebalancer_,
        uint256 rewardRate_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (rewardToken_ == address(0)) revert ZeroAddress();
        if (rebalancer_ == address(0)) revert ZeroAddress();
        rewardToken = IERC20(rewardToken_);
        rebalancer = rebalancer_;
        rewardRate = rewardRate_;
        rebalanceThreshold = DEFAULT_REBALANCE_THRESHOLD;
        lastRewardTime = block.timestamp;
        emit RebalancerUpdated(address(0), rebalancer_);
        emit RewardRateUpdated(0, rewardRate_);
        emit RebalanceThresholdUpdated(0, rebalanceThreshold);
    }

    // ============ Reward Logic ============

    function _rewardPerToken() internal view returns (uint256) {
        if (totalSupply() == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((block.timestamp - lastRewardTime) * rewardRate * REWARD_PRECISION) / totalSupply();
    }

    function _earned(address account) internal view returns (uint256) {
        return (balanceOf(account) * (_rewardPerToken() - userRewardPerTokenPaid[account])) / REWARD_PRECISION + rewards[account];
    }

    function _updateRewardState(address from, address to) internal {
        rewardPerTokenStored = _rewardPerToken();
        lastRewardTime = block.timestamp;
        if (from != address(0) && from != to) {
            rewards[from] = _earned(from);
            userRewardPerTokenPaid[from] = rewardPerTokenStored;
        }
        if (to != address(0) && from != to) {
            rewards[to] = _earned(to);
            userRewardPerTokenPaid[to] = rewardPerTokenStored;
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        _updateRewardState(from, to);
        super._update(from, to, value);
    }

    function pendingRewards(address user) external view returns (uint256) {
        return _earned(user);
    }

    function claimRewards() external nonReentrant {
        rewardPerTokenStored = _rewardPerToken();
        lastRewardTime = block.timestamp;
        uint256 reward = _earned(msg.sender);
        if (reward == 0) revert NoPendingRewards();
        rewards[msg.sender] = 0;
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        rewardToken.safeTransfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    // ============ View: Total Assets & Weights ============

    function getTotalAssets() public view returns (uint256 total) {
        uint256 len = supportedTokensList.length;
        for (uint256 i = 0; i < len; ) {
            total += IERC20(supportedTokensList[i]).balanceOf(address(this));
            unchecked { ++i; }
        }
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokensList;
    }

    function getTokenWeight(address token) public view returns (uint256 actualWeight, uint256 deviation) {
        uint256 totalAssets = getTotalAssets();
        if (totalAssets == 0) return (0, 0);
        uint256 balance = IERC20(token).balanceOf(address(this));
        actualWeight = (balance * BPS_DENOMINATOR) / totalAssets;
        uint256 target = tokenInfo[token].targetWeight;
        deviation = actualWeight > target ? actualWeight - target : target - actualWeight;
    }

    function maxDeviationBps() public view returns (uint256 maxDev) {
        uint256 len = supportedTokensList.length;
        for (uint256 i = 0; i < len; ) {
            (, uint256 dev) = getTokenWeight(supportedTokensList[i]);
            if (dev > maxDev) maxDev = dev;
            unchecked { ++i; }
        }
    }

    function canRebalance() public view returns (bool) {
        if (supportedTokensList.length == 0) return false;
        return maxDeviationBps() > rebalanceThreshold;
    }

    // ============ Deposit ============

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!tokenInfo[token].supported) revert TokenNotSupported();
        if (amount == 0) revert AmountZero();

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert AmountZero();

        uint256 shares;
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            shares = received;
        } else {
            uint256 totalAssetsBefore = getTotalAssets() - received;
            if (totalAssetsBefore == 0) revert AmountZero();
            shares = (received * totalSupply_) / totalAssetsBefore;
        }
        if (shares == 0) revert AmountZero();

        _mint(msg.sender, shares);
        emit Deposited(msg.sender, token, received, shares);
        emit BasketCompositionChanged(token, IERC20(token).balanceOf(address(this)), tokenInfo[token].targetWeight);
    }

    // ============ Withdraw ============

    function withdraw(uint256 basketAmount) external nonReentrant {
        if (basketAmount == 0) revert AmountZero();
        if (balanceOf(msg.sender) < basketAmount) revert InsufficientBalance();

        uint256 totalSupply_ = totalSupply();
        uint256 totalFee = 0;
        uint256 len = supportedTokensList.length;

        for (uint256 i = 0; i < len; ) {
            address token = supportedTokensList[i];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            if (tokenBalance > 0) {
                uint256 tokenAmount = (basketAmount * tokenBalance) / totalSupply_;
                if (tokenAmount > 0) {
                    uint256 fee = (tokenAmount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
                    uint256 netSend = tokenAmount - fee;
                    totalFee += fee;
                    if (netSend > 0) {
                        IERC20(token).safeTransfer(msg.sender, netSend);
                    }
                    emit BasketCompositionChanged(token, tokenBalance - netSend, tokenInfo[token].targetWeight);
                }
            }
            unchecked { ++i; }
        }

        _burn(msg.sender, basketAmount);
        emit Withdrawn(msg.sender, basketAmount, totalFee);
    }

    // ============ Rebalance ============

    function rebalance(
        address[] calldata tokensToAdjust,
        uint256[] calldata targetBalances
    ) external nonReentrant onlyRebalancerRole {
        if (tokensToAdjust.length != targetBalances.length) revert ArrayLengthMismatch();

        uint256 len = tokensToAdjust.length;
        for (uint256 i = 0; i < len; ) {
            address token = tokensToAdjust[i];
            uint256 target = targetBalances[i];
            if (!tokenInfo[token].supported) revert TokenNotSupported();

            uint256 current = IERC20(token).balanceOf(address(this));
            if (target > current) {
                uint256 diff = target - current;
                IERC20(token).safeTransferFrom(msg.sender, address(this), diff);
            } else if (target < current) {
                uint256 diff = current - target;
                IERC20(token).safeTransfer(msg.sender, diff);
            }
            emit BasketCompositionChanged(token, target, tokenInfo[token].targetWeight);
            unchecked { ++i; }
        }

        if (maxDeviationBps() > rebalanceThreshold) revert RebalanceFailed();
        emit Rebalanced(msg.sender);
    }

    // ============ Owner: Token Management ============

    function addToken(address token, uint256 targetWeight) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (tokenInfo[token].supported) revert TokenAlreadySupported();
        if (targetWeight == 0) revert InvalidWeight();
        if (totalTargetWeight + targetWeight > BPS_DENOMINATOR) revert WeightSumExceedsMax();

        tokenInfo[token] = TokenInfo({supported: true, targetWeight: targetWeight});
        supportedTokensList.push(token);
        totalTargetWeight += targetWeight;

        emit TokenAdded(token, targetWeight);
        emit BasketCompositionChanged(token, IERC20(token).balanceOf(address(this)), targetWeight);
    }

    function removeToken(address token) external onlyOwner {
        if (!tokenInfo[token].supported) revert TokenNotSupported();

        uint256 weight = tokenInfo[token].targetWeight;
        tokenInfo[token].supported = false;
        tokenInfo[token].targetWeight = 0;
        totalTargetWeight -= weight;

        uint256 len = supportedTokensList.length;
        for (uint256 i = 0; i < len; ) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[len - 1];
                supportedTokensList.pop();
                break;
            }
            unchecked { ++i; }
        }

        emit TokenRemoved(token);
    }

    function setTargetWeight(address token, uint256 newWeight) external onlyOwner {
        if (!tokenInfo[token].supported) revert TokenNotSupported();
        if (newWeight == 0) revert InvalidWeight();

        uint256 oldWeight = tokenInfo[token].targetWeight;
        uint256 newTotal = totalTargetWeight - oldWeight + newWeight;
        if (newTotal > BPS_DENOMINATOR) revert WeightSumExceedsMax();

        tokenInfo[token].targetWeight = newWeight;
        totalTargetWeight = newTotal;

        emit TargetWeightUpdated(token, oldWeight, newWeight);
        emit BasketCompositionChanged(token, IERC20(token).balanceOf(address(this)), newWeight);
    }

    // ============ Owner: Configuration ============

    function setRebalanceThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0 || newThreshold > BPS_DENOMINATOR) revert InvalidThreshold();
        uint256 old = rebalanceThreshold;
        rebalanceThreshold = newThreshold;
        emit RebalanceThresholdUpdated(old, newThreshold);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardPerTokenStored = _rewardPerToken();
        lastRewardTime = block.timestamp;
        uint256 old = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(old, newRate);
    }

    function setRebalancer(address newRebalancer) external onlyOwner {
        if (newRebalancer == address(0)) revert ZeroAddress();
        address old = rebalancer;
        rebalancer = newRebalancer;
        emit RebalancerUpdated(old, newRebalancer);
    }

    function recoverToken(address token, uint256 amount) external onlyOwner {
        if (tokenInfo[token].supported) revert CannotRecoverSupportedToken();
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
