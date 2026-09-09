// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract GameExchangeFarm {
    // ============ Access Control ============
    address public owner;
    address public operator;

    // ============ Constants ============
    uint256 public constant MAX_FEE_BIPS = 50; // 0.5%
    uint256 public constant MIN_STAKE_PERIOD = 24 hours;
    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant BIPS_DENOMINATOR = 10_000;

    // ============ Fungible Tokens ============
    address[] public supportedTokens;
    mapping(address => bool) public isTokenSupported;

    // User deposited balances (not staked)
    mapping(address => mapping(address => uint256)) public balances;

    // ============ Exchange ============
    mapping(address => mapping(address => uint256)) public exchangeRates;
    uint256 public exchangeFeeBips;

    // ============ NFT Game Items ============
    struct GameItem {
        string name;
        uint256 price;
        address priceToken;
        bool forSale;
        bool exists;
    }

    mapping(uint256 => GameItem) public items;
    mapping(uint256 => address) public itemOwner;
    uint256 public nextItemId;

    // ============ Staking ============
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
        uint256 accumulatedReward;
    }

    mapping(address => mapping(address => StakeInfo)) public stakes;
    mapping(address => uint256) public rewardRatePerToken;
    mapping(address => uint256) public totalStaked;
    address public rewardToken;

    // ============ Reentrancy Guard ============
    uint256 private _status = 1;

    modifier nonReentrant() {
        require(_status == 1, "Reentrant call");
        _status = 2;
        _;
        _status = 1;
    }

    // ============ Events ============
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);
    event ItemPurchased(address indexed buyer, uint256 indexed itemId, address priceToken, uint256 price);
    event ItemSold(address indexed seller, uint256 indexed itemId, address priceToken, uint256 price);
    event TokenExchanged(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 fromAmount,
        uint256 toAmount,
        uint256 fee
    );
    event RewardClaimed(address indexed user, address indexed token, uint256 reward);
    event Staked(address indexed user, address indexed token, uint256 amount);
    event Unstaked(address indexed user, address indexed token, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event TokenSupported(address indexed token, bool supported);
    event ExchangeRateSet(address indexed fromToken, address indexed toToken, uint256 rate);
    event ExchangeFeeUpdated(uint256 oldFee, uint256 newFee);
    event RewardRateSet(address indexed token, uint256 rate);
    event ItemMinted(uint256 indexed itemId, string name, uint256 price, address priceToken);
    event RewardTokenSet(address indexed token);
    event RewardsDeposited(address indexed token, uint256 amount);

    // ============ Custom Errors ============
    error NotOwner();
    error NotOperator();
    error TokenNotSupported();
    error InsufficientBalance();
    error ZeroAmount();
    error FeeExceedsMax();
    error StakePeriodNotMet();
    error NothingToClaim();
    error ItemNotForSale();
    error NotItemOwner();
    error ItemDoesNotExist();
    error ZeroAddress();
    error ExchangeRateNotSet();
    error SameToken();
    error NotStaking();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier tokenSupported(address token) {
        if (!isTokenSupported[token]) revert TokenNotSupported();
        _;
    }

    // ============ Constructor ============
    constructor(address _rewardToken) {
        if (_rewardToken == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = msg.sender;
        rewardToken = _rewardToken;
        nextItemId = 1;
        exchangeFeeBips = 0;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), msg.sender);
        emit RewardTokenSet(_rewardToken);
    }

    // ============ Admin / Operator Functions ============

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setSupportedToken(address token, bool supported) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        isTokenSupported[token] = supported;
        if (supported) {
            supportedTokens.push(token);
        }
        emit TokenSupported(token, supported);
    }

    function setExchangeRate(address fromToken, address toToken, uint256 rate) external onlyOperator {
        if (!isTokenSupported[fromToken] || !isTokenSupported[toToken]) revert TokenNotSupported();
        if (fromToken == toToken) revert SameToken();
        if (rate == 0) revert ZeroAmount();
        exchangeRates[fromToken][toToken] = rate;
        emit ExchangeRateSet(fromToken, toToken, rate);
    }

    function setExchangeFee(uint256 feeBips) external onlyOperator {
        if (feeBips > MAX_FEE_BIPS) revert FeeExceedsMax();
        emit ExchangeFeeUpdated(exchangeFeeBips, feeBips);
        exchangeFeeBips = feeBips;
    }

    function setRewardRate(address token, uint256 rate) external onlyOperator {
        if (!isTokenSupported[token]) revert TokenNotSupported();
        rewardRatePerToken[token] = rate;
        emit RewardRateSet(token, rate);
    }

    function setRewardToken(address _rewardToken) external onlyOperator {
        if (_rewardToken == address(0)) revert ZeroAddress();
        rewardToken = _rewardToken;
        emit RewardTokenSet(_rewardToken);
    }

    function mintItem(string calldata name, uint256 price, address priceToken) external onlyOperator {
        if (!isTokenSupported[priceToken]) revert TokenNotSupported();
        if (price == 0) revert ZeroAmount();
        uint256 itemId = nextItemId++;
        items[itemId] = GameItem({
            name: name,
            price: price,
            priceToken: priceToken,
            forSale: true,
            exists: true
        });
        itemOwner[itemId] = address(0);
        emit ItemMinted(itemId, name, price, priceToken);
    }

    function depositRewards(address token, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit RewardsDeposited(token, amount);
    }

    // ============ User Functions ============

    function deposit(address token, uint256 amount) external nonReentrant tokenSupported(token) {
        if (amount == 0) revert ZeroAmount();
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;
        emit TokenDeposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant tokenSupported(token) {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();
        balances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit TokenWithdrawn(msg.sender, token, amount);
    }

    function exchange(
        address fromToken,
        address toToken,
        uint256 amount
    ) external nonReentrant tokenSupported(fromToken) {
        if (!isTokenSupported[toToken]) revert TokenNotSupported();
        if (fromToken == toToken) revert SameToken();
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender][fromToken] < amount) revert InsufficientBalance();

        uint256 rate = exchangeRates[fromToken][toToken];
        if (rate == 0) revert ExchangeRateNotSet();

        uint256 fee = (amount * exchangeFeeBips) / BIPS_DENOMINATOR;
        uint256 effectiveAmount = amount - fee;

        uint256 toAmount = (effectiveAmount * rate) / RATE_PRECISION;
        if (toAmount == 0) revert ZeroAmount();

        balances[msg.sender][fromToken] -= amount;
        balances[msg.sender][toToken] += toAmount;

        emit TokenExchanged(msg.sender, fromToken, toToken, amount, toAmount, fee);
    }

    function purchaseItem(uint256 itemId) external nonReentrant {
        GameItem storage item = items[itemId];
        if (!item.exists) revert ItemDoesNotExist();
        if (!item.forSale) revert ItemNotForSale();
        if (balances[msg.sender][item.priceToken] < item.price) revert InsufficientBalance();

        balances[msg.sender][item.priceToken] -= item.price;
        itemOwner[itemId] = msg.sender;
        item.forSale = false;

        emit ItemPurchased(msg.sender, itemId, item.priceToken, item.price);
    }

    function sellItem(uint256 itemId) external nonReentrant {
        GameItem storage item = items[itemId];
        if (!item.exists) revert ItemDoesNotExist();
        if (itemOwner[itemId] != msg.sender) revert NotItemOwner();

        balances[msg.sender][item.priceToken] += item.price;
        itemOwner[itemId] = address(0);
        item.forSale = true;

        emit ItemSold(msg.sender, itemId, item.priceToken, item.price);
    }

    function stake(address token, uint256 amount) external nonReentrant tokenSupported(token) {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();

        StakeInfo storage stakeInfo = stakes[msg.sender][token];

        _updateReward(msg.sender, token);

        balances[msg.sender][token] -= amount;
        stakeInfo.amount += amount;
        if (stakeInfo.startTime == 0) {
            stakeInfo.startTime = block.timestamp;
        }
        stakeInfo.lastClaimTime = block.timestamp;
        totalStaked[token] += amount;

        emit Staked(msg.sender, token, amount);
    }

    function unstake(address token, uint256 amount) external nonReentrant tokenSupported(token) {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];
        if (amount == 0) revert ZeroAmount();
        if (stakeInfo.amount < amount) revert InsufficientBalance();
        if (block.timestamp - stakeInfo.startTime < MIN_STAKE_PERIOD) revert StakePeriodNotMet();

        _updateReward(msg.sender, token);

        stakeInfo.amount -= amount;
        balances[msg.sender][token] += amount;
        totalStaked[token] -= amount;

        if (stakeInfo.amount == 0) {
            stakeInfo.startTime = 0;
            stakeInfo.lastClaimTime = 0;
        }

        emit Unstaked(msg.sender, token, amount);
    }

    function claimReward(address token) external nonReentrant tokenSupported(token) {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];

        _updateReward(msg.sender, token);

        uint256 reward = stakeInfo.accumulatedReward;
        if (reward == 0) revert NothingToClaim();

        if (stakeInfo.amount > 0 && block.timestamp - stakeInfo.startTime < MIN_STAKE_PERIOD) {
            revert StakePeriodNotMet();
        }

        stakeInfo.accumulatedReward = 0;

        IERC20(rewardToken).transfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, token, reward);
    }

    // ============ Internal Functions ============

    function _updateReward(address user, address token) internal {
        StakeInfo storage stakeInfo = stakes[user][token];
        if (stakeInfo.amount == 0) return;

        uint256 timeElapsed = block.timestamp - stakeInfo.lastClaimTime;
        if (timeElapsed == 0) return;

        uint256 newReward = (stakeInfo.amount * rewardRatePerToken[token] * timeElapsed) / RATE_PRECISION;
        stakeInfo.accumulatedReward += newReward;
        stakeInfo.lastClaimTime = block.timestamp;
    }

    // ============ View Functions ============

    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }

    function getPendingReward(address user, address token) external view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user][token];
        if (stakeInfo.amount == 0) return stakeInfo.accumulatedReward;

        uint256 timeElapsed = block.timestamp - stakeInfo.lastClaimTime;
        uint256 newReward = (stakeInfo.amount * rewardRatePerToken[token] * timeElapsed) / RATE_PRECISION;
        return stakeInfo.accumulatedReward + newReward;
    }

    function getStakeInfo(address user, address token)
        external
        view
        returns (uint256 amount, uint256 startTime, uint256 lastClaimTime, uint256 accumulatedReward)
    {
        StakeInfo storage s = stakes[user][token];
        return (s.amount, s.startTime, s.lastClaimTime, s.accumulatedReward);
    }

    function getItemInfo(uint256 itemId)
        external
        view
        returns (string memory name, uint256 price, address priceToken, bool forSale, bool exists)
    {
        GameItem storage item = items[itemId];
        return (item.name, item.price, item.priceToken, item.forSale, item.exists);
    }

    function getItemOwner(uint256 itemId) external view returns (address) {
        return itemOwner[itemId];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getSupportedTokensCount() external view returns (uint256) {
        return supportedTokens.length;
    }

    function getRewardTokenBalance() external view returns (uint256) {
        return IERC20(rewardToken).balanceOf(address(this));
    }
}
