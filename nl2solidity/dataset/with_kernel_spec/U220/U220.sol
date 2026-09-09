// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract ReserveCurrencyProtocol {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error AssetNotApproved();
    error AssetAlreadyApproved();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientStake();
    error AmountZero();
    error InflationCapExceeded();
    error NoPendingReward();
    error InvalidParam();
    error TransferFailed();
    error ReentrantCall();
    error CapacityExceeded();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value, uint256 fee);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, address indexed asset, uint256 assetAmount, uint256 minted);
    event Stake(address indexed staker, uint256 amount);
    event Unstake(address indexed staker, uint256 amount);
    event RewardPaid(address indexed staker, uint256 reward);
    event ReserveAssetAdded(address indexed asset, uint256 rate, uint256 capacity);
    event ReserveAssetRemoved(address indexed asset);
    event ReserveAssetUpdated(address indexed asset, uint256 rate, uint256 capacity);
    event BondingTermsUpdated(uint256 bondDiscountBps, uint256 bondVestingPeriod);
    event TreasuryDisbursement(address indexed asset, address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event InflationWindowRolledOver(uint256 newStartSupply, uint256 newStartTimestamp);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant TRANSFER_FEE_BPS = 50;          // 0.5%
    uint256 public constant MAX_INFLATION_BPS = 1000;       // 10% annual cap
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Stablecoin metadata
    // ---------------------------------------------------------------------
    string public constant name = "Reserve Stablecoin";
    string public constant symbol = "RUSD";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ---------------------------------------------------------------------
    // Access control
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;

    // ---------------------------------------------------------------------
    // Reentrancy
    // ---------------------------------------------------------------------
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Staking
    // ---------------------------------------------------------------------
    struct StakeData {
        uint256 amount;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
    }

    uint256 public totalStaked;
    mapping(address => StakeData) public stakes;

    uint256 public rewardRate;            // reward tokens per second (total, not per token)
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    // ---------------------------------------------------------------------
    // Reserve assets
    // ---------------------------------------------------------------------
    struct ReserveAsset {
        bool approved;
        uint256 rate;      // RUSD minted per 1 unit of asset (1e18 base)
        uint256 capacity;  // max reserve asset amount accepted
        uint256 deposited; // current reserve asset amount held
    }
    mapping(address => ReserveAsset) public reserveAssets;
    address[] public reserveAssetList;

    // ---------------------------------------------------------------------
    // Bonding terms
    // ---------------------------------------------------------------------
    uint256 public bondDiscountBps;   // discount applied when minting via bonds
    uint256 public bondVestingPeriod;  // vesting period in seconds

    // ---------------------------------------------------------------------
    // Inflation tracking
    // ---------------------------------------------------------------------
    uint256 public inflationStartTimestamp;
    uint256 public inflationStartSupply;
    uint256 public mintedSinceInflationStart;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            stakes[account].rewards = earned(account);
            stakes[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        inflationStartTimestamp = block.timestamp;
        inflationStartSupply = 0;
        mintedSinceInflationStart = 0;
        lastUpdateTime = block.timestamp;
    }

    // ---------------------------------------------------------------------
    // ERC20 view functions
    // ---------------------------------------------------------------------
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address ownerAddr, address spender) external view returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    // ---------------------------------------------------------------------
    // ERC20 transfer with 0.5% fee
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external nonReentrant returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        if (ownerAddr == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (_balances[from] < amount) revert InsufficientBalance();

        uint256 fee = (amount * TRANSFER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 sendAmount = amount - fee;

        _balances[from] -= amount;
        _balances[to] += sendAmount;
        // fee credited to owner (treasury)
        _balances[owner] += fee;

        emit Transfer(from, to, sendAmount, fee);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount, 0);
    }

    // ---------------------------------------------------------------------
    // Inflation cap
    // ---------------------------------------------------------------------
    function _checkInflationCap(uint256 additionalMint) internal {
        _rolloverInflationWindowIfNeeded();
        uint256 maxAllowed = (inflationStartSupply * MAX_INFLATION_BPS) / BPS_DENOMINATOR;
        if (mintedSinceInflationStart + additionalMint > maxAllowed) revert InflationCapExceeded();
        mintedSinceInflationStart += additionalMint;
    }

    function _rolloverInflationWindowIfNeeded() internal {
        if (block.timestamp >= inflationStartTimestamp + SECONDS_PER_YEAR) {
            inflationStartTimestamp = block.timestamp;
            inflationStartSupply = _totalSupply;
            mintedSinceInflationStart = 0;
            emit InflationWindowRolledOver(inflationStartSupply, inflationStartTimestamp);
        }
    }

    function rolloverInflationWindow() external {
        if (block.timestamp < inflationStartTimestamp + SECONDS_PER_YEAR) revert InvalidParam();
        _rolloverInflationWindowIfNeeded();
    }

    // ---------------------------------------------------------------------
    // Minting via reserve assets
    // ---------------------------------------------------------------------
    function mintWithReserve(address asset, uint256 assetAmount)
        external
        nonReentrant
        updateReward(address(0))
        returns (uint256 minted)
    {
        ReserveAsset storage ra = reserveAssets[asset];
        if (!ra.approved) revert AssetNotApproved();
        if (assetAmount == 0) revert AmountZero();
        if (ra.deposited + assetAmount > ra.capacity) revert CapacityExceeded();

        // Compute gross mint amount in full precision (assetAmount * rate)
        uint256 gross = assetAmount * ra.rate;

        // Apply bond discount in a single expression to avoid divide-before-multiply:
        // minted = gross * (BPS_DENOMINATOR - bondDiscountBps) / (PRECISION * BPS_DENOMINATOR)
        if (bondDiscountBps > 0) {
            minted = (gross * (BPS_DENOMINATOR - bondDiscountBps)) / (PRECISION * BPS_DENOMINATOR);
        } else {
            minted = gross / PRECISION;
        }

        if (minted == 0) revert AmountZero();

        // Effects: update all state before external interactions
        ra.deposited += assetAmount;
        _checkInflationCap(minted);
        _mint(msg.sender, minted);

        // Interactions: pull reserve asset from minter into this contract (treasury)
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), assetAmount);
        if (!ok) revert TransferFailed();

        emit Mint(msg.sender, asset, assetAmount, minted);
    }

    // ---------------------------------------------------------------------
    // Staking
    // ---------------------------------------------------------------------
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (
            (block.timestamp - lastUpdateTime) * rewardRate * PRECISION
        ) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        StakeData memory s = stakes[account];
        return (s.amount * (rewardPerToken() - s.rewardPerTokenPaid)) / PRECISION + s.rewards;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert AmountZero();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        totalStaked += amount;
        stakes[msg.sender].amount += amount;

        emit Stake(msg.sender, amount);
        emit Transfer(msg.sender, address(this), amount, 0);
    }

    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        StakeData storage s = stakes[msg.sender];
        if (amount == 0) revert AmountZero();
        if (s.amount < amount) revert InsufficientStake();

        s.amount -= amount;
        totalStaked -= amount;
        _balances[msg.sender] += amount;

        emit Unstake(msg.sender, amount);
        emit Transfer(address(this), msg.sender, amount, 0);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = stakes[msg.sender].rewards;
        if (reward == 0) revert NoPendingReward();

        stakes[msg.sender].rewards = 0;
        _checkInflationCap(reward);
        _mint(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
        emit Transfer(address(0), msg.sender, reward, 0);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------
    function addReserveAsset(address asset, uint256 rate, uint256 capacity) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (rate == 0) revert InvalidParam();
        if (capacity == 0) revert InvalidParam();
        if (reserveAssets[asset].approved) revert AssetAlreadyApproved();

        reserveAssets[asset] = ReserveAsset({
            approved: true,
            rate: rate,
            capacity: capacity,
            deposited: 0
        });
        reserveAssetList.push(asset);

        emit ReserveAssetAdded(asset, rate, capacity);
    }

    function removeReserveAsset(address asset) external onlyOperator {
        if (!reserveAssets[asset].approved) revert AssetNotApproved();

        reserveAssets[asset].approved = false;
        reserveAssets[asset].rate = 0;
        reserveAssets[asset].capacity = 0;

        uint256 len = reserveAssetList.length;
        for (uint256 i = 0; i < len; i++) {
            if (reserveAssetList[i] == asset) {
                reserveAssetList[i] = reserveAssetList[len - 1];
                reserveAssetList.pop();
                break;
            }
        }

        emit ReserveAssetRemoved(asset);
    }

    function updateReserveAsset(address asset, uint256 rate, uint256 capacity) external onlyOperator {
        if (!reserveAssets[asset].approved) revert AssetNotApproved();
        if (rate == 0) revert InvalidParam();
        if (capacity == 0) revert InvalidParam();
        if (reserveAssets[asset].deposited > capacity) revert InvalidParam();

        reserveAssets[asset].rate = rate;
        reserveAssets[asset].capacity = capacity;

        emit ReserveAssetUpdated(asset, rate, capacity);
    }

    function setBondingTerms(uint256 discountBps, uint256 vestingPeriod) external onlyOperator {
        if (discountBps > BPS_DENOMINATOR) revert InvalidParam();
        bondDiscountBps = discountBps;
        bondVestingPeriod = vestingPeriod;
        emit BondingTermsUpdated(discountBps, vestingPeriod);
    }

    function setRewardRate(uint256 newRate) external onlyOperator updateReward(address(0)) {
        uint256 old = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(old, newRate);
    }

    function treasuryDisbursement(address asset, address recipient, uint256 amount) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        ReserveAsset storage ra = reserveAssets[asset];
        if (ra.approved) {
            if (ra.deposited < amount) revert InsufficientBalance();
            ra.deposited -= amount;
        }

        bool ok = IERC20(asset).transfer(recipient, amount);
        if (!ok) revert TransferFailed();

        emit TreasuryDisbursement(asset, recipient, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function reserveAssetCount() external view returns (uint256) {
        return reserveAssetList.length;
    }

    function isReserveAsset(address asset) external view returns (bool) {
        return reserveAssets[asset].approved;
    }

    function getReserveAssetList() external view returns (address[] memory) {
        return reserveAssetList;
    }

    function getReserveAssetData(address asset)
        external
        view
        returns (bool approved, uint256 rate, uint256 capacity, uint256 deposited)
    {
        ReserveAsset memory ra = reserveAssets[asset];
        return (ra.approved, ra.rate, ra.capacity, ra.deposited);
    }

    function getStakeData(address account) external view returns (uint256 amount, uint256 pendingReward) {
        amount = stakes[account].amount;
        pendingReward = earned(account);
    }

    function getInflationStatus()
        external
        view
        returns (uint256 startTimestamp, uint256 startSupply, uint256 mintedSinceStart, uint256 maxAllowed)
    {
        startTimestamp = inflationStartTimestamp;
        startSupply = inflationStartSupply;
        mintedSinceStart = mintedSinceInflationStart;
        maxAllowed = (inflationStartSupply * MAX_INFLATION_BPS) / BPS_DENOMINATOR;
    }
}
