// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

error NotOwner();
error ZeroAddress();
error ZeroAmount();
error InsufficientBalance();
error StablecoinNotSet();
error RewardRateExceedsCap();
error TransferFailed();
error TransferFromFailed();

/**
 * @title StableValueVault
 * @notice A vault that issues a stable-value token (SVT) backed 1:1 by a designated stablecoin.
 *         SVT can be staked to receive a yield-bearing staked token (sSVT) whose value relative
 *         to SVT appreciates over time according to a configurable annual reward rate capped at 5%.
 */
contract StableValueVault {
    // ---------- Access Control ----------
    address public owner;

    // ---------- Token ----------
    IERC20 public stablecoin;

    // ---------- Constants ----------
    uint256 public constant RATE_CAP_BPS = 500; // 5% annually in basis points
    uint256 public constant YEAR = 365 days;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ---------- Supplies ----------
    uint256 public totalSupply; // SVT total supply
    uint256 public totalStakedSupply; // sSVT total supply

    // ---------- Balances ----------
    mapping(address => uint256) public balances; // SVT balances
    mapping(address => uint256) public stakedBalances; // sSVT balances

    // ---------- Exchange Rate ----------
    /// @notice How many SVT (1e18 precision) per 1 sSVT (1e18 precision).
    uint256 public exchangeRate;
    uint256 public rewardRateBps; // annual reward rate in basis points
    uint256 public lastAccrualTime;

    // ---------- Events ----------
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StablecoinUpdated(address indexed previousStablecoin, address indexed newStablecoin);
    event RewardRateUpdated(uint256 oldRateBps, uint256 newRateBps);
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _owner, address _stablecoin, uint256 _rewardRateBps) {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
        if (_stablecoin != address(0)) {
            stablecoin = IERC20(_stablecoin);
        }
        if (_rewardRateBps > RATE_CAP_BPS) revert RewardRateExceedsCap();
        rewardRateBps = _rewardRateBps;
        exchangeRate = PRECISION;
        lastAccrualTime = block.timestamp;
        emit OwnershipTransferred(address(0), _owner);
        emit StablecoinUpdated(address(0), _stablecoin);
        emit RewardRateUpdated(0, _rewardRateBps);
    }

    // ---------- Owner Functions ----------

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setStablecoin(address _stablecoin) external onlyOwner {
        if (_stablecoin == address(0)) revert ZeroAddress();
        address prev = address(stablecoin);
        stablecoin = IERC20(_stablecoin);
        emit StablecoinUpdated(prev, _stablecoin);
    }

    function setRewardRate(uint256 _rateBps) external onlyOwner {
        if (_rateBps > RATE_CAP_BPS) revert RewardRateExceedsCap();
        _accrueRewards();
        uint256 old = rewardRateBps;
        rewardRateBps = _rateBps;
        emit RewardRateUpdated(old, _rateBps);
    }

    // ---------- Internal ERC20 Helpers ----------
    // Uses msg.sender as the from address to prevent arbitrary token transfers.

    function _safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert TransferFromFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ---------- Internal Reward Accrual ----------

    function _accrueRewards() internal {
        if (block.timestamp <= lastAccrualTime) return;
        uint256 elapsed = block.timestamp - lastAccrualTime;
        lastAccrualTime = block.timestamp;
        if (totalStakedSupply < 1 || rewardRateBps < 1) return;
        // exchangeRate *= (1 + rewardRateBps * elapsed / (YEAR * BPS_DENOMINATOR))
        uint256 factor = PRECISION + (rewardRateBps * elapsed * PRECISION) / (YEAR * BPS_DENOMINATOR);
        exchangeRate = (exchangeRate * factor) / PRECISION;
    }

    // ---------- User Functions ----------

    /**
     * @notice Deposits stablecoin and mints SVT 1:1 to the caller.
     * @param amount The amount of stablecoin to deposit.
     */
    function deposit(uint256 amount) external {
        if (address(stablecoin) == address(0)) revert StablecoinNotSet();
        if (amount < 1) revert ZeroAmount();
        _safeTransferFrom(stablecoin, address(this), amount);
        totalSupply += amount;
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Burns SVT and withdraws the underlying stablecoin to the caller.
     * @param amount The amount of SVT to burn.
     */
    function withdraw(uint256 amount) external {
        if (amount < 1) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        if (address(stablecoin) == address(0)) revert StablecoinNotSet();
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        _safeTransfer(stablecoin, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Stakes SVT to receive yield-bearing sSVT. Rewards accrue before minting.
     * @param amount The amount of SVT to stake.
     */
    function stake(uint256 amount) external {
        if (amount < 1) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        _accrueRewards();
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        // sSVT minted = amount * PRECISION / exchangeRate
        uint256 sAmount = (amount * PRECISION) / exchangeRate;
        if (sAmount < 1) revert ZeroAmount();
        stakedBalances[msg.sender] += sAmount;
        totalStakedSupply += sAmount;
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstakes sSVT to redeem SVT. Rewards accrue before burning.
     * @param sAmount The amount of sSVT to unstake.
     */
    function unstake(uint256 sAmount) external {
        if (sAmount < 1) revert ZeroAmount();
        if (stakedBalances[msg.sender] < sAmount) revert InsufficientBalance();
        _accrueRewards();
        stakedBalances[msg.sender] -= sAmount;
        totalStakedSupply -= sAmount;
        // SVT returned = sAmount * exchangeRate / PRECISION
        uint256 amount = (sAmount * exchangeRate) / PRECISION;
        balances[msg.sender] += amount;
        totalSupply += amount;
        emit Unstaked(msg.sender, amount);
    }

    // ---------- View Functions ----------

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function stakedBalanceOf(address account) external view returns (uint256) {
        return stakedBalances[account];
    }

    function previewExchangeRate() external view returns (uint256) {
        if (totalStakedSupply < 1 || rewardRateBps < 1) return exchangeRate;
        if (block.timestamp <= lastAccrualTime) return exchangeRate;
        uint256 elapsed = block.timestamp - lastAccrualTime;
        uint256 factor = PRECISION + (rewardRateBps * elapsed * PRECISION) / (YEAR * BPS_DENOMINATOR);
        return (exchangeRate * factor) / PRECISION;
    }

    function stablecoinReserve() external view returns (uint256) {
        if (address(stablecoin) == address(0)) return 0;
        return stablecoin.balanceOf(address(this));
    }
}
