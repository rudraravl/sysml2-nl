// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error Unauthorized();
    error BelowMinimumDeposit();
    error ZeroAmount();
    error InsufficientLSTBalance();
    error InsufficientEther();
    error InsufficientBalance();
    error NoRewards();
    error NoSharesMinted();
    error TransferFailed();
    error InvalidAddress();
    error ReentrancyGuard();
    error DirectEtherTransferNotAllowed();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant FEE_BPS = 1000; // 10% in basis points
    uint256 private constant SCALE = 1e18;

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------

    address public owner;
    address public operator;
    address public treasury;

    uint256 public totalPooledEther; // global pool backing LST (available + staked)
    uint256 public availableEther;   // Ether not yet delegated to validators
    uint256 public stakedEther;      // Ether delegated to validators
    uint256 public totalLSTSupply;   // total liquid staking tokens minted
    uint256 public totalRewardsPool; // Ether reserved for unclaimed rewards
    uint256 public rewardIndex;      // accumulated rewards per LST (scaled by SCALE)

    mapping(address => uint256) public depositedEther;    // record of user's deposited Ether
    mapping(address => uint256) public lstBalance;       // user LST balances
    mapping(address => uint256) public userRewardIndex;   // last reward index applied to user
    mapping(address => uint256) public userAccruedRewards; // unclaimed rewards per user

    uint256 private _locked = 1;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposited(address indexed user, uint256 etherAmount, uint256 lstMinted);
    event Redeemed(address indexed user, uint256 lstBurned, uint256 etherAmount);
    event RewardsClaimed(address indexed user, uint256 etherAmount);
    event RewardsDistributed(uint256 totalReward, uint256 feeAmount, uint256 netReward);
    event StakedToValidator(address indexed caller, uint256 amount);
    event UnstakedFromValidator(address indexed caller, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event Recovered(address indexed token, uint256 amount);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address _operator, address _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert InvalidAddress();
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    // -----------------------------------------------------------------------
    // Receive
    // -----------------------------------------------------------------------

    receive() external payable {
        revert DirectEtherTransferNotAllowed();
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _etherToLST(uint256 etherAmount) internal view returns (uint256) {
        if (totalLSTSupply == 0 || totalPooledEther == 0) {
            return etherAmount;
        }
        return (etherAmount * totalLSTSupply) / totalPooledEther;
    }

    function _lstToEther(uint256 lstAmount) internal view returns (uint256) {
        if (totalLSTSupply == 0) return 0;
        return (lstAmount * totalPooledEther) / totalLSTSupply;
    }

    function _updateReward(address user) internal {
        uint256 balance = lstBalance[user];
        uint256 index = userRewardIndex[user];
        if (balance > 0 && rewardIndex > index) {
            userAccruedRewards[user] += (balance * (rewardIndex - index)) / SCALE;
        }
        userRewardIndex[user] = rewardIndex;
    }

    // -----------------------------------------------------------------------
    // User actions
    // -----------------------------------------------------------------------

    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert BelowMinimumDeposit();

        uint256 lstToMint = _etherToLST(msg.value);
        if (lstToMint == 0) revert ZeroAmount();

        _updateReward(msg.sender);

        depositedEther[msg.sender] += msg.value;
        lstBalance[msg.sender] += lstToMint;
        totalLSTSupply += lstToMint;
        totalPooledEther += msg.value;
        availableEther += msg.value;
        userRewardIndex[msg.sender] = rewardIndex;

        emit Deposited(msg.sender, msg.value, lstToMint);
    }

    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (lstBalance[msg.sender] < lstAmount) revert InsufficientLSTBalance();

        uint256 etherToReturn = _lstToEther(lstAmount);
        if (etherToReturn == 0) revert ZeroAmount();
        if (availableEther < etherToReturn) revert InsufficientEther();

        _updateReward(msg.sender);

        // Effects
        totalLSTSupply -= lstAmount;
        lstBalance[msg.sender] -= lstAmount;
        totalPooledEther -= etherToReturn;
        availableEther -= etherToReturn;

        if (depositedEther[msg.sender] >= etherToReturn) {
            depositedEther[msg.sender] -= etherToReturn;
        } else {
            depositedEther[msg.sender] = 0;
        }

        userRewardIndex[msg.sender] = rewardIndex;

        // Interaction
        (bool ok, ) = payable(msg.sender).call{value: etherToReturn}("");
        if (!ok) revert TransferFailed();

        emit Redeemed(msg.sender, lstAmount, etherToReturn);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);

        uint256 rewards = userAccruedRewards[msg.sender];
        if (rewards == 0) revert NoRewards();
        if (totalRewardsPool < rewards) revert InsufficientEther();

        // Effects
        userAccruedRewards[msg.sender] = 0;
        userRewardIndex[msg.sender] = rewardIndex;
        totalRewardsPool -= rewards;

        // Interaction
        (bool ok, ) = payable(msg.sender).call{value: rewards}("");
        if (!ok) revert TransferFailed();

        emit RewardsClaimed(msg.sender, rewards);
    }

    // -----------------------------------------------------------------------
    // Operator actions
    // -----------------------------------------------------------------------

    function stake(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (availableEther < amount) revert InsufficientEther();

        availableEther -= amount;
        stakedEther += amount;

        emit StakedToValidator(msg.sender, amount);
    }

    function unstake(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedEther < amount) revert InsufficientEther();

        stakedEther -= amount;
        availableEther += amount;

        emit UnstakedFromValidator(msg.sender, amount);
    }

    function distributeRewards() external payable onlyOperator nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (totalLSTSupply == 0) revert NoSharesMinted();

        uint256 fee = (msg.value * FEE_BPS) / 10000;
        uint256 netReward = msg.value - fee;

        // Effects
        totalRewardsPool += netReward;
        rewardIndex += (netReward * SCALE) / totalLSTSupply;

        // Interaction
        if (fee > 0) {
            (bool ok, ) = payable(treasury).call{value: fee}("");
            if (!ok) revert TransferFailed();
        }

        emit RewardsDistributed(msg.value, fee, netReward);
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        bool ok = IERC20(token).transfer(treasury, amount);
        if (!ok) revert TransferFailed();

        emit Recovered(token, amount);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    function pendingRewards(address user) external view returns (uint256) {
        uint256 balance = lstBalance[user];
        uint256 index = userRewardIndex[user];
        uint256 accrued = userAccruedRewards[user];
        if (balance > 0 && rewardIndex > index) {
            accrued += (balance * (rewardIndex - index)) / SCALE;
        }
        return accrued;
    }

    function exchangeRate() external view returns (uint256) {
        if (totalLSTSupply == 0) return SCALE;
        return (totalPooledEther * SCALE) / totalLSTSupply;
    }

    function contractEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
