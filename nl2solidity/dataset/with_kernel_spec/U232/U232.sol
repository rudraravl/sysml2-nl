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

contract ReserveCurrencyProtocol {
    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // -----------------------------------------------------------------------
    // Native protocol token (ERC-20)
    // -----------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // -----------------------------------------------------------------------
    // Access control
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;

    // -----------------------------------------------------------------------
    // Stablecoin asset registry
    // -----------------------------------------------------------------------
    uint256 public constant MAX_ASSETS = 5;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10% cap

    uint256 public redemptionFeeBps = 50; // 0.5%

    address[] public supportedAssets;
    mapping(address => bool) public isSupported;
    mapping(address => uint256) public oraclePrice; // native tokens per 1 stablecoin, 1e18 precision
    mapping(address => uint256) public treasuryBalance; // global custody balance per asset
    mapping(address => mapping(address => uint256)) public userStableBalance; // user => asset => deposited

    // -----------------------------------------------------------------------
    // Staking (Synthetix-style)
    // -----------------------------------------------------------------------
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;

    uint256 public rewardRate;
    uint256 public rewardsDuration = 7 days;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Minted(address indexed user, address indexed asset, uint256 stableAmount, uint256 nativeAmount);
    event Burned(address indexed user, address indexed asset, uint256 nativeAmount, uint256 stableAmount, uint256 fee);
    event StableDeposited(address indexed user, address indexed asset, uint256 amount);
    event StableRedeemed(address indexed user, address indexed asset, uint256 amount);

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);

    event AssetAdded(address indexed asset, uint256 price);
    event OracleUpdated(address indexed asset, uint256 newPrice);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Recovered(address indexed token, uint256 amount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error MaxAssetsExceeded();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidPrice();
    error RewardPeriodNotFinished();
    error LengthMismatch();
    error FeeTooHigh();
    error TransferFailed();
    error CannotRecoverSupportedAsset();
    error Reentrancy();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        string memory _name,
        string memory _symbol,
        address _operator,
        address[] memory _initialAssets,
        uint256[] memory _initialPrices
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialAssets.length != _initialPrices.length) revert LengthMismatch();

        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = _operator;
        _status = _NOT_ENTERED;

        for (uint256 i = 0; i < _initialAssets.length; i++) {
            _addAsset(_initialAssets[i], _initialPrices[i]);
        }

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // ERC-20 implementation
    // -----------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        _balances[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Asset management (operator)
    // -----------------------------------------------------------------------
    function _addAsset(address asset, uint256 price) internal {
        if (asset == address(0)) revert ZeroAddress();
        if (isSupported[asset]) revert AssetAlreadySupported();
        if (supportedAssets.length >= MAX_ASSETS) revert MaxAssetsExceeded();
        if (price == 0) revert InvalidPrice();

        isSupported[asset] = true;
        supportedAssets.push(asset);
        oraclePrice[asset] = price;
        emit AssetAdded(asset, price);
    }

    function addAsset(address asset, uint256 price) external onlyOperator {
        _addAsset(asset, price);
    }

    function updateOraclePrice(address asset, uint256 newPrice) external onlyOperator {
        if (!isSupported[asset]) revert AssetNotSupported();
        if (newPrice == 0) revert InvalidPrice();
        oraclePrice[asset] = newPrice;
        emit OracleUpdated(asset, newPrice);
    }

    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFee, newFeeBps);
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function supportedAssetCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    // -----------------------------------------------------------------------
    // Deposit stablecoins -> mint native tokens
    // -----------------------------------------------------------------------
    function deposit(address asset, uint256 amount) external nonReentrant {
        if (!isSupported[asset]) revert AssetNotSupported();
        if (amount == 0) revert ZeroAmount();

        uint256 price = oraclePrice[asset];
        if (price == 0) revert InvalidPrice();

        uint256 nativeAmount = (amount * price) / PRICE_PRECISION;
        if (nativeAmount == 0) revert ZeroAmount();

        // Effects
        treasuryBalance[asset] += amount;
        userStableBalance[msg.sender][asset] += amount;
        _mint(msg.sender, nativeAmount);

        emit StableDeposited(msg.sender, asset, amount);
        emit Minted(msg.sender, asset, amount, nativeAmount);

        // Interaction
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // Burn native tokens -> redeem stablecoins
    // -----------------------------------------------------------------------
    function redeem(address asset, uint256 nativeAmount) external nonReentrant {
        if (!isSupported[asset]) revert AssetNotSupported();
        if (nativeAmount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < nativeAmount) revert InsufficientBalance();

        uint256 price = oraclePrice[asset];
        if (price == 0) revert InvalidPrice();

        uint256 stableAmount = (nativeAmount * PRICE_PRECISION) / price;
        if (stableAmount == 0) revert ZeroAmount();
        if (treasuryBalance[asset] < stableAmount) revert InsufficientBalance();

        // Compute fee directly from nativeAmount in a single division to avoid
        // divide-before-multiply precision loss.
        uint256 fee = (nativeAmount * redemptionFeeBps * PRICE_PRECISION) / (price * BPS_DENOMINATOR);
        uint256 payout = stableAmount - fee;

        // Effects
        _burn(msg.sender, nativeAmount);
        treasuryBalance[asset] -= payout; // fee remains in custody

        emit StableRedeemed(msg.sender, asset, payout);
        emit Burned(msg.sender, asset, nativeAmount, stableAmount, fee);

        // Interaction
        bool ok = IERC20(asset).transfer(msg.sender, payout);
        if (!ok) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // Staking
    // -----------------------------------------------------------------------
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18
            + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();

        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;
        _balances[msg.sender] += amount;

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            _mint(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external updateReward(msg.sender) {
        uint256 staked = stakedBalance[msg.sender];
        if (staked > 0) {
            totalStaked -= staked;
            stakedBalance[msg.sender] = 0;
            _balances[msg.sender] += staked;
            emit Unstaked(msg.sender, staked);
        }

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            _mint(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyOperator updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint256 duration) external onlyOperator {
        if (block.timestamp < periodFinish) revert RewardPeriodNotFinished();
        rewardsDuration = duration;
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    // -----------------------------------------------------------------------
    // Recover non-supported tokens sent by accident
    // -----------------------------------------------------------------------
    function recoverERC20(address token, uint256 amount) external onlyOwner nonReentrant {
        if (isSupported[token]) revert CannotRecoverSupportedAsset();
        bool ok = IERC20(token).transfer(owner, amount);
        if (!ok) revert TransferFailed();
        emit Recovered(token, amount);
    }
}
