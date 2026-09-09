// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStaking {
    // ==================== Custom Errors ====================
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquid();
    error InsufficientRewardFunding();
    error NoPendingRewards();
    error RewardRateTooHigh();
    error TransferFailed();
    error Reentrancy();

    // ==================== Constants ====================
    uint256 public constant MAX_REWARD_RATE = 10; // 10.00% annual cap (in percentage points)
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant VALIDATOR_STAKE = 32 ether;
    uint256 public constant RATE_DENOMINATOR = 100; // percentage points denominator

    // ==================== Events ====================
    event Deposit(address indexed user, uint256 ethAmount, uint256 lstMinted);
    event Withdrawal(address indexed user, uint256 lstBurned, uint256 ethWithdrawn);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardFunded(address indexed funder, uint256 amount);
    event ValidatorsStaked(address indexed operator, uint256 count, uint256 totalAmount);
    event Paused(address indexed owner);
    event Unpaused(address indexed owner);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event ImplementationUpgraded(address indexed newImplementation);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // ==================== Access Control ====================
    address public owner;
    address public operator;
    bool public paused;
    address public implementation;

    // ==================== LST Token State ====================
    string public name = "Liquid Staked Ether";
    string public symbol = "LSE";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ==================== Staking & Reward State ====================
    uint256 public totalDepositedEther;   // cumulative ETH deposited by users
    uint256 public stakedEther;           // ETH locked with validators (illiquid)
    uint256 public totalRewardsFunded;    // cumulative ETH funded for rewards
    uint256 public totalRewardsClaimed;   // cumulative rewards paid out

    uint256 public rewardRate;            // annual reward rate in percentage points (5 = 5%)
    uint256 public lastRewardTimestamp;   // last global reward update
    uint256 public rewardPerTokenStored;  // accumulated reward per LST (scaled by ACC_PRECISION)

    struct UserInfo {
        uint256 depositedEther;
        uint256 rewardDebt;
    }
    mapping(address => UserInfo) public userInfo;

    // ==================== Reentrancy Guard ====================
    uint256 private _locked = 1;

    // ==================== Modifiers ====================
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ==================== Constructor ====================
    constructor(address _operator, uint256 _initialRate) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialRate > MAX_REWARD_RATE) revert RewardRateTooHigh();

        owner = msg.sender;
        operator = _operator;
        rewardRate = _initialRate;
        lastRewardTimestamp = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit RewardRateUpdated(0, _initialRate);
    }

    // ==================== Receive ====================
    receive() external payable {
        deposit();
    }

    // ==================== User Functions ====================

    /**
     * @notice Deposit Ether to receive LST tokens at a 1:1 ratio.
     */
    function deposit() public payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        _updateReward();

        _mint(msg.sender, msg.value);
        totalDepositedEther += msg.value;
        userInfo[msg.sender].depositedEther += msg.value;
        _updateUser(msg.sender);

        emit Deposit(msg.sender, msg.value, msg.value);
    }

    /**
     * @notice Redeem LST tokens for Ether at a 1:1 ratio.
     * @param lstAmount Amount of LST to redeem.
     */
    function redeem(uint256 lstAmount) external whenNotPaused nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();
        if (lstAmount > _availableLiquid()) revert InsufficientLiquid();

        _updateReward();

        _burn(msg.sender, lstAmount);
        totalDepositedEther -= lstAmount;
        if (userInfo[msg.sender].depositedEther >= lstAmount) {
            userInfo[msg.sender].depositedEther -= lstAmount;
        }
        _updateUser(msg.sender);

        (bool ok, ) = payable(msg.sender).call{value: lstAmount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, lstAmount, lstAmount);
    }

    /**
     * @notice Claim all accrued rewards for the caller.
     */
    function claimRewards() external whenNotPaused nonReentrant {
        _updateReward();

        uint256 pending = _pendingRewards(msg.sender);
        if (pending < 1) revert NoPendingRewards();
        if (pending > _availableLiquid()) revert InsufficientLiquid();
        if (pending > totalRewardsFunded - totalRewardsClaimed) revert InsufficientRewardFunding();

        _updateUser(msg.sender);
        totalRewardsClaimed += pending;

        (bool ok, ) = payable(msg.sender).call{value: pending}("");
        if (!ok) revert TransferFailed();

        emit RewardClaimed(msg.sender, pending);
    }

    // ==================== Operator Functions ====================

    /**
     * @notice Lock Ether into validators. Each validator requires 32 Ether.
     * @param count Number of validators to stake.
     */
    function stakeValidators(uint256 count) external onlyOperator whenNotPaused {
        if (count == 0) revert ZeroAmount();
        uint256 amount = count * VALIDATOR_STAKE;
        if (amount > _availableLiquid()) revert InsufficientLiquid();

        _updateReward();
        stakedEther += amount;

        emit ValidatorsStaked(msg.sender, count, amount);
    }

    /**
     * @notice Set the annual reward rate in percentage points. Capped at 10 (10%).
     * @param newRate New rate; 5 = 5%, 10 = 10%.
     */
    function setRewardRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_REWARD_RATE) revert RewardRateTooHigh();

        _updateReward();

        uint256 oldRate = rewardRate;
        rewardRate = newRate;

        emit RewardRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Fund the rewards pool with Ether (e.g., from validator yields).
     */
    function fundRewards() external payable onlyOperator {
        if (msg.value == 0) revert ZeroAmount();
        totalRewardsFunded += msg.value;
        emit RewardFunded(msg.sender, msg.value);
    }

    // ==================== Owner Functions ====================

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Record an upgraded implementation address. In a proxy-based
     *         deployment, this would be used by the proxy admin to point to
     *         new logic. In a standalone deployment it serves as an on-chain
     *         record of the intended upgrade.
     */
    function upgradeImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        implementation = newImplementation;
        emit ImplementationUpgraded(newImplementation);
    }

    // ==================== ERC20 Functions ====================

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _updateReward();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        _updateUser(msg.sender);
        _updateUser(to);

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        _updateReward();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        _updateUser(from);
        _updateUser(to);

        emit Transfer(from, to, amount);
        return true;
    }

    // ==================== View Functions ====================

    function availableLiquid() external view returns (uint256) {
        return _availableLiquid();
    }

    function availableRewardFunding() external view returns (uint256) {
        return totalRewardsFunded - totalRewardsClaimed;
    }

    /**
     * @notice Compute a user's pending rewards that have not yet been claimed.
     */
    function pendingRewards(address account) external view returns (uint256) {
        uint256 rpt = rewardPerTokenStored;
        if (block.timestamp > lastRewardTimestamp && totalSupply > 0 && stakedEther > 0) {
            uint256 elapsed = block.timestamp - lastRewardTimestamp;
            // Multiply-before-divide: combine all numerator terms before dividing
            // to avoid precision loss from intermediate division.
            rpt += (stakedEther * rewardRate * elapsed * ACC_PRECISION) /
                   (SECONDS_PER_YEAR * RATE_DENOMINATOR * totalSupply);
        }
        uint256 computed = (balanceOf[account] * rpt) / ACC_PRECISION;
        if (computed < userInfo[account].rewardDebt) return 0;
        return computed - userInfo[account].rewardDebt;
    }

    // ==================== Internal Functions ====================

    function _availableLiquid() internal view returns (uint256) {
        return address(this).balance - stakedEther;
    }

    function _updateReward() internal {
        if (block.timestamp <= lastRewardTimestamp) return;

        if (totalSupply == 0 || stakedEther == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastRewardTimestamp;
        // Multiply-before-divide: combine all numerator terms before dividing
        // to avoid precision loss from intermediate division.
        rewardPerTokenStored += (stakedEther * rewardRate * elapsed * ACC_PRECISION) /
                                (SECONDS_PER_YEAR * RATE_DENOMINATOR * totalSupply);
        lastRewardTimestamp = block.timestamp;
    }

    function _pendingRewards(address account) internal view returns (uint256) {
        uint256 computed = (balanceOf[account] * rewardPerTokenStored) / ACC_PRECISION;
        if (computed < userInfo[account].rewardDebt) return 0;
        return computed - userInfo[account].rewardDebt;
    }

    function _updateUser(address account) internal {
        userInfo[account].rewardDebt = (balanceOf[account] * rewardPerTokenStored) / ACC_PRECISION;
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
