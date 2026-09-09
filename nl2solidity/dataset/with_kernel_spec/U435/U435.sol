// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract LiquidStaking {
    // ===== Liquid Staking Token (LST) =====
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ===== Staking configuration =====
    IERC20 public immutable baseAsset;
    uint256 public stakingFeeBP; // basis points, 500 = 5%
    uint256 public rewardRate;    // base-asset rewards distributed per second
    uint256 public immutable minDeposit;

    address public owner;
    address public operator;
    bool public paused;

    // ===== Pool state =====
    uint256 public totalStakedBaseAsset;        // base assets held in escrow
    mapping(address => uint256) public depositedBaseAsset; // per-user deposited principal
    uint256 public accumulatedRewardFees;       // accrued fees, claimable by owner

    // ===== Reward accounting =====
    uint256 private constant ACC_PRECISION = 1e18;
    uint256 public rewardPerTokenStored;
    uint256 public lastRewardTime;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public unclaimedRewards;

    // ===== Events =====
    event Deposit(address indexed user, uint256 baseAmount, uint256 lstMinted);
    event Withdraw(address indexed user, uint256 baseAmount, uint256 lstBurned);
    event RewardClaimed(address indexed user, uint256 rewardAmount, uint256 feeAmount);
    event StakingFeeUpdated(uint256 oldFeeBP, uint256 newFeeBP);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PausedChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardFeesClaimed(address indexed to, uint256 amount);
    event TokenRecovered(address indexed token, address indexed to, uint256 amount);
    event RewardsDeposited(address indexed from, uint256 amount);

    // ===== Errors =====
    error NotOwner();
    error NotAuthorized();
    error EnforcedPause();
    error DepositTooSmall(uint256 amount, uint256 minRequired);
    error InsufficientLST(uint256 requested, uint256 available);
    error InsufficientAllowance(uint256 needed, uint256 allowed);
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error InvalidRecoverToken();
    error NothingToClaim();
    error NotEnoughRewardReserve(uint256 needed, uint256 available);
    error TransferFailed();
    error ReentrantCall();

    // ===== Modifiers =====
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != owner && msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        if (_status != _NOT_ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(
        address baseAsset_,
        string memory lstName_,
        string memory lstSymbol_,
        uint256 rewardRate_,
        address operator_
    ) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        baseAsset = IERC20(baseAsset_);
        uint8 dec = baseAsset.decimals();
        decimals = dec;
        minDeposit = dec >= 2 ? 10 ** (uint256(dec) - 2) : 1;
        name = lstName_;
        symbol = lstSymbol_;
        stakingFeeBP = 500; // 5% applied to all distributed rewards
        rewardRate = rewardRate_;
        operator = operator_;
        owner = msg.sender;
        _status = _NOT_ENTERED;
        lastRewardTime = block.timestamp;
        emit OwnershipTransferred(address(0), msg.sender);
        emit StakingFeeUpdated(0, 500);
        emit RewardRateUpdated(0, rewardRate_);
        emit OperatorUpdated(address(0), operator_);
    }

    // ===== LST ERC20 internals =====
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        _updateReward(from);
        if (from != to) _updateReward(to);
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientLST(amount, fromBal);
        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientLST(amount, fromBal);
        unchecked {
            balanceOf[from] = fromBal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // ===== LST ERC20 external =====
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(amount, allowed);
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    // ===== Reward accounting =====
    function rewardReserve() public view returns (uint256) {
        uint256 bal = baseAsset.balanceOf(address(this));
        uint256 locked = totalStakedBaseAsset + accumulatedRewardFees;
        if (bal < locked) return 0;
        return bal - locked;
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 shares = totalSupply;
        if (shares < 1) {
            return rewardPerTokenStored;
        }
        uint256 elapsed = block.timestamp - lastRewardTime;
        return rewardPerTokenStored + (elapsed * rewardRate * ACC_PRECISION) / shares;
    }

    function earned(address user) public view returns (uint256) {
        uint256 rpt = rewardPerToken();
        uint256 shares = balanceOf[user];
        uint256 accrued = (shares * (rpt - userRewardPerTokenPaid[user])) / ACC_PRECISION;
        return unclaimedRewards[user] + accrued;
    }

    function _updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastRewardTime = block.timestamp;
        if (user != address(0)) {
            uint256 accrued =
                (balanceOf[user] * (rewardPerTokenStored - userRewardPerTokenPaid[user])) / ACC_PRECISION;
            if (accrued > 0) {
                unclaimedRewards[user] += accrued;
            }
            userRewardPerTokenPaid[user] = rewardPerTokenStored;
        }
    }

    // ===== User actions (checks-effects-interactions) =====
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < minDeposit) revert DepositTooSmall(amount, minDeposit);
        _updateReward(msg.sender);

        // Effects first
        totalStakedBaseAsset += amount;
        depositedBaseAsset[msg.sender] += amount;
        _mint(msg.sender, amount);

        // Interaction last
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount, amount);
    }

    function withdraw(uint256 lstAmount) external whenNotPaused nonReentrant {
        if (lstAmount < 1) revert ZeroAmount();
        uint256 userLST = balanceOf[msg.sender];
        if (userLST < lstAmount) revert InsufficientLST(lstAmount, userLST);

        // Effects first
        _updateReward(msg.sender);
        _burn(msg.sender, lstAmount);
        totalStakedBaseAsset -= lstAmount;
        if (depositedBaseAsset[msg.sender] > lstAmount) {
            depositedBaseAsset[msg.sender] -= lstAmount;
        } else {
            depositedBaseAsset[msg.sender] = 0;
        }

        // Interaction last
        if (!baseAsset.transfer(msg.sender, lstAmount)) revert TransferFailed();

        emit Withdraw(msg.sender, lstAmount, lstAmount);
    }

    function claimRewards() external whenNotPaused nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = unclaimedRewards[msg.sender];
        if (reward < 1) revert NothingToClaim();

        // Effects
        unclaimedRewards[msg.sender] = 0;
        uint256 fee = (reward * stakingFeeBP) / 10000;
        uint256 payout = reward - fee;

        uint256 reserve = rewardReserve();
        if (reserve < payout) revert NotEnoughRewardReserve(payout, reserve);

        if (fee > 0) {
            accumulatedRewardFees += fee;
        }

        // Interaction last
        if (!baseAsset.transfer(msg.sender, payout)) revert TransferFailed();

        emit RewardClaimed(msg.sender, payout, fee);
    }

    function depositRewards(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        // No stale balance reads; trust the returned bool of a standard ERC20 transferFrom.
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit RewardsDeposited(msg.sender, amount);
    }

    // ===== Owner / admin =====
    function setStakingFee(uint256 feeBP) external onlyOwner {
        if (feeBP > 10000) revert InvalidFee();
        uint256 old = stakingFeeBP;
        stakingFeeBP = feeBP;
        emit StakingFeeUpdated(old, feeBP);
    }

    function setRewardRate(uint256 rate) external onlyOwner {
        _updateReward(address(0));
        uint256 old = rewardRate;
        rewardRate = rate;
        emit RewardRateUpdated(old, rate);
    }

    function setOperator(address operator_) external onlyOwner {
        if (operator_ == address(0)) revert ZeroAddress();
        address old = operator;
        operator = operator_;
        emit OperatorUpdated(old, operator_);
    }

    function setPaused(bool paused_) external onlyAuthorized {
        paused = paused_;
        emit PausedChanged(paused_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    function claimRewardFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedRewardFees;
        if (amount < 1) revert NothingToClaim();
        // Effects
        accumulatedRewardFees = 0;
        // Interaction
        if (!baseAsset.transfer(to, amount)) revert TransferFailed();
        emit RewardFeesClaimed(to, amount);
    }

    function recoverToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(baseAsset)) revert InvalidRecoverToken();
        if (token == address(this)) revert InvalidRecoverToken();
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit TokenRecovered(token, to, amount);
    }
}
