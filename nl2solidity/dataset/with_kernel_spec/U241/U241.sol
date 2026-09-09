// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract YieldBoostVault {
    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error MaxAssetsReached();
    error AssetHasDeposits();
    error ErrPaused();
    error ErrNotPaused();
    error Unauthorized();
    error InsufficientBalance();
    error InvalidSchedule();
    error InvalidFee();
    error NothingToClaim();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 totalUserDeposits);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 fee, uint256 received);
    event RewardClaimed(address indexed user, uint256 amount);
    event DelegateChanged(address indexed user, address indexed previousDelegatee, address indexed newDelegatee);
    event RewardScheduleUpdated(uint256 startBlock, uint256 endBlock, uint256 rewardPerBlock);
    event FeeUpdated(uint256 oldFeeBp, uint256 newFeeBp);
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);
    event PausedState(address indexed caller);
    event UnpausedState(address indexed caller);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event RewardTokenUpdated(address indexed previousToken, address indexed newToken);
    event EmergencyTokenRescue(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_ASSETS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_WITHDRAWAL_FEE_BP = 50; // 0.5%
    uint256 public constant MAX_FEE_BP = 1000;             // 10% cap
    uint256 private constant ACC_PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Access & Configuration
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;
    address public rewardToken;
    bool   public paused;
    uint256 public withdrawalFeeBp;

    // ---------------------------------------------------------------------
    // Asset Registry
    // ---------------------------------------------------------------------
    address[] public assetList;
    mapping(address => bool) public isSupportedAsset;

    // ---------------------------------------------------------------------
    // Deposit Accounting
    // ---------------------------------------------------------------------
    mapping(address => mapping(address => uint256)) public userBalances;     // user => asset => amount
    mapping(address => uint256) public userTotalDeposits;                    // user => total across all assets
    mapping(address => uint256) public totalAssetDeposits;                   // asset => total
    uint256 public grandTotalDeposits;                                        // sum across all assets

    // ---------------------------------------------------------------------
    // Reward Accounting
    // ---------------------------------------------------------------------
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;          // accumulated reward per share (1e18 precision)
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public rewardPerBlock;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public userUnclaimedRewards;

    // ---------------------------------------------------------------------
    // Delegation
    // ---------------------------------------------------------------------
    mapping(address => address) public delegation;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier supportedAsset(address asset) {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address _feeRecipient, address _rewardToken) {
        if (_operator == address(0))      revert ZeroAddress();
        if (_feeRecipient == address(0))  revert ZeroAddress();
        if (_rewardToken == address(0))   revert ZeroAddress();

        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        rewardToken = _rewardToken;
        withdrawalFeeBp = DEFAULT_WITHDRAWAL_FEE_BP;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit RewardTokenUpdated(address(0), _rewardToken);
        emit FeeUpdated(0, DEFAULT_WITHDRAWAL_FEE_BP);
    }

    // ---------------------------------------------------------------------
    // Owner Administration
    // ---------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function setRewardToken(address newRewardToken) external onlyOwner {
        if (newRewardToken == address(0)) revert ZeroAddress();
        emit RewardTokenUpdated(rewardToken, newRewardToken);
        rewardToken = newRewardToken;
    }

    function addAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (isSupportedAsset[asset]) revert AssetAlreadySupported();
        if (assetList.length >= MAX_ASSETS) revert MaxAssetsReached();

        isSupportedAsset[asset] = true;
        assetList.push(asset);
        emit AssetAdded(asset);
    }

    function removeAsset(address asset) external onlyOwner {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        if (totalAssetDeposits[asset] > 0) revert AssetHasDeposits();

        isSupportedAsset[asset] = false;
        uint256 len = assetList.length;
        for (uint256 i = 0; i < len; i++) {
            if (assetList[i] == asset) {
                assetList[i] = assetList[len - 1];
                assetList.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }

    function pause() external onlyOwner {
        if (paused) revert ErrPaused();
        paused = true;
        emit PausedState(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert ErrNotPaused();
        paused = false;
        emit UnpausedState(msg.sender);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit EmergencyTokenRescue(token, to, amount);
    }

    // ---------------------------------------------------------------------
    // Operator Administration
    // ---------------------------------------------------------------------
    function updateRewardSchedule(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardPerBlock
    ) external onlyOperator {
        if (_endBlock <= _startBlock) revert InvalidSchedule();
        if (_rewardPerBlock == 0) revert ZeroAmount();

        _updateReward();

        startBlock = _startBlock;
        endBlock = _endBlock;
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;

        emit RewardScheduleUpdated(_startBlock, _endBlock, _rewardPerBlock);
    }

    function setFeePercentage(uint256 newFeeBp) external onlyOperator {
        if (newFeeBp > MAX_FEE_BP) revert InvalidFee();
        emit FeeUpdated(withdrawalFeeBp, newFeeBp);
        withdrawalFeeBp = newFeeBp;
    }

    // ---------------------------------------------------------------------
    // User Actions
    // ---------------------------------------------------------------------
    function deposit(address asset, uint256 amount)
        external
        whenNotPaused
        supportedAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        _updateReward();

        uint256 debtAddition = (amount * accRewardPerShare) / ACC_PRECISION;
        userBalances[msg.sender][asset] += amount;
        userTotalDeposits[msg.sender] += amount;
        totalAssetDeposits[asset] += amount;
        grandTotalDeposits += amount;
        userRewardDebt[msg.sender] += debtAddition;

        if (!IERC20(asset).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, asset, amount, userTotalDeposits[msg.sender]);
    }

    function withdraw(address asset, uint256 amount)
        external
        whenNotPaused
        supportedAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();
        if (userBalances[msg.sender][asset] < amount) revert InsufficientBalance();

        _updateReward();

        // Settle pending rewards to unclaimed so they are not forfeited on withdrawal.
        uint256 pending = (userTotalDeposits[msg.sender] * accRewardPerShare) / ACC_PRECISION;
        if (pending > userRewardDebt[msg.sender]) {
            userUnclaimedRewards[msg.sender] += pending - userRewardDebt[msg.sender];
        }

        // Effects
        userBalances[msg.sender][asset] -= amount;
        userTotalDeposits[msg.sender] -= amount;
        totalAssetDeposits[asset] -= amount;
        grandTotalDeposits -= amount;
        userRewardDebt[msg.sender] = (userTotalDeposits[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        uint256 fee = (amount * withdrawalFeeBp) / FEE_DENOMINATOR;
        uint256 received = amount - fee;

        // Interactions
        if (fee > 0) {
            if (!IERC20(asset).transfer(feeRecipient, fee)) revert TransferFailed();
        }
        if (received > 0) {
            if (!IERC20(asset).transfer(msg.sender, received)) revert TransferFailed();
        }

        emit Withdraw(msg.sender, asset, amount, fee, received);
    }

    function claimRewards() external {
        _updateReward();

        uint256 accrued = (userTotalDeposits[msg.sender] * accRewardPerShare) / ACC_PRECISION;
        uint256 pending = userUnclaimedRewards[msg.sender];
        if (accrued > userRewardDebt[msg.sender]) {
            pending += accrued - userRewardDebt[msg.sender];
        }

        if (pending < 1) revert NothingToClaim();

        // Effects
        userUnclaimedRewards[msg.sender] = 0;
        userRewardDebt[msg.sender] = accrued;

        // Interaction
        if (!IERC20(rewardToken).transfer(msg.sender, pending)) revert TransferFailed();

        emit RewardClaimed(msg.sender, pending);
    }

    function delegate(address delegatee) external {
        if (delegatee == address(0)) revert ZeroAddress();
        address previous = delegation[msg.sender];
        delegation[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, previous, delegatee);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function pendingRewards(address user) external view returns (uint256) {
        uint256 pending = userUnclaimedRewards[user];
        if (userTotalDeposits[user] == 0) {
            return pending;
        }

        uint256 currentAcc = accRewardPerShare;
        if (block.number > lastRewardBlock && grandTotalDeposits > 0) {
            uint256 blockReward = _getBlockRewardView();
            if (blockReward > 0) {
                currentAcc += (blockReward * ACC_PRECISION) / grandTotalDeposits;
            }
        }

        uint256 accrued = (userTotalDeposits[user] * currentAcc) / ACC_PRECISION;
        if (accrued > userRewardDebt[user]) {
            pending += accrued - userRewardDebt[user];
        }
        return pending;
    }

    function getVotingPower(address user) external view returns (uint256) {
        return userTotalDeposits[user];
    }

    function getDelegatee(address user) external view returns (address) {
        address d = delegation[user];
        return d == address(0) ? user : d;
    }

    function getAssetCount() external view returns (uint256) {
        return assetList.length;
    }

    function getAssetList() external view returns (address[] memory) {
        return assetList;
    }

    function userBalance(address user, address asset) external view returns (uint256) {
        return userBalances[user][asset];
    }

    // ---------------------------------------------------------------------
    // Internal Reward Logic
    // ---------------------------------------------------------------------
    function _updateReward() internal {
        if (block.number <= lastRewardBlock) return;

        if (grandTotalDeposits == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blockReward = _getBlockRewardView();
        if (blockReward > 0) {
            accRewardPerShare += (blockReward * ACC_PRECISION) / grandTotalDeposits;
        }
        lastRewardBlock = block.number;
    }

    function _getBlockRewardView() internal view returns (uint256) {
        if (rewardPerBlock == 0) return 0;
        if (block.number < startBlock) return 0;
        if (lastRewardBlock >= endBlock) return 0;

        uint256 start = lastRewardBlock < startBlock ? startBlock : lastRewardBlock;
        uint256 end = block.number < endBlock ? block.number : endBlock;
        if (end <= start) return 0;

        return (end - start) * rewardPerBlock;
    }
}
