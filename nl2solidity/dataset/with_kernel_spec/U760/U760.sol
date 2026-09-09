// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256 rewardAmount);
    function balanceOf() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(from == msg.sender, "SafeERC20: from != caller");
        require(token.transferFrom(from, to, amount), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(token.approve(spender, amount), "SafeERC20: approve failed");
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract CuratedVaultManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e12;
    uint256 public constant MIN_MIN_DEPOSIT = 100;
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    struct Vault {
        IERC20 underlying;
        IStrategy strategy;
        uint256 minDepositAmount;
        bool isPaused;
        uint256 totalDeposits;
        uint256 accRewardPerToken;
        uint256 rewardBalance;
    }

    struct UserInfo {
        uint256 deposited;
        uint256 rewardDebt;
    }

    Vault[] public vaults;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    address public operator;
    address public treasury;
    uint256 public withdrawalFeeBps = 50;

    event VaultAdded(uint256 indexed vaultId, address indexed underlying, address indexed strategy, uint256 minDepositAmount);
    event Deposit(uint256 indexed vaultId, address indexed user, uint256 amount);
    event Withdraw(uint256 indexed vaultId, address indexed user, uint256 amount, uint256 fee, uint256 reward);
    event RewardsClaimed(uint256 indexed vaultId, address indexed user, uint256 amount);
    event Harvest(uint256 indexed vaultId, uint256 rewardAmount);
    event StrategyUpdated(uint256 indexed vaultId, address oldStrategy, address newStrategy);
    event StrategyRolledOver(uint256 indexed vaultId, address oldStrategy, address newStrategy);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event TreasurySet(address indexed oldTreasury, address indexed newTreasury);
    event WithdrawalFeeSet(uint256 oldFeeBps, uint256 newFeeBps);
    event VaultPaused(uint256 indexed vaultId);
    event VaultUnpaused(uint256 indexed vaultId);
    event MinDepositAmountUpdated(uint256 indexed vaultId, uint256 newMin);

    error InvalidVault();
    error VaultIsPaused();
    error InsufficientDeposit();
    error InsufficientBalance();
    error ZeroAddress();
    error FeeTooHigh();
    error NotOperator();
    error NothingToHarvest();
    error AmountZero();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier validVault(uint256 vaultId) {
        if (vaultId >= vaults.length) revert InvalidVault();
        _;
    }

    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        operator = msg.sender;
    }

    function addVault(
        address _underlying,
        address _strategy,
        uint256 _minDepositAmount
    ) external onlyOwner {
        if (_underlying == address(0) || _strategy == address(0)) revert ZeroAddress();
        if (_minDepositAmount < MIN_MIN_DEPOSIT) revert InsufficientDeposit();

        vaults.push(
            Vault({
                underlying: IERC20(_underlying),
                strategy: IStrategy(_strategy),
                minDepositAmount: _minDepositAmount,
                isPaused: false,
                totalDeposits: 0,
                accRewardPerToken: 0,
                rewardBalance: 0
            })
        );

        emit VaultAdded(vaults.length - 1, _underlying, _strategy, _minDepositAmount);
    }

    function pauseVault(uint256 vaultId) external onlyOwner validVault(vaultId) {
        vaults[vaultId].isPaused = true;
        emit VaultPaused(vaultId);
    }

    function unpauseVault(uint256 vaultId) external onlyOwner validVault(vaultId) {
        vaults[vaultId].isPaused = false;
        emit VaultUnpaused(vaultId);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = _operator;
        emit OperatorSet(oldOperator, _operator);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasurySet(oldTreasury, _treasury);
    }

    function setWithdrawalFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeTooHigh();
        uint256 oldFee = withdrawalFeeBps;
        withdrawalFeeBps = _feeBps;
        emit WithdrawalFeeSet(oldFee, _feeBps);
    }

    function setMinDepositAmount(uint256 vaultId, uint256 _newMin) external onlyOwner validVault(vaultId) {
        if (_newMin < MIN_MIN_DEPOSIT) revert InsufficientDeposit();
        vaults[vaultId].minDepositAmount = _newMin;
        emit MinDepositAmountUpdated(vaultId, _newMin);
    }

    function harvest(uint256 vaultId) external onlyOperator validVault(vaultId) nonReentrant {
        Vault storage vault = vaults[vaultId];
        IStrategy strat = vault.strategy;

        uint256 rewardAmount = strat.harvest();
        if (rewardAmount == 0) revert NothingToHarvest();

        vault.rewardBalance += rewardAmount;

        if (vault.totalDeposits > 0) {
            vault.accRewardPerToken += (rewardAmount * PRECISION) / vault.totalDeposits;
        }

        emit Harvest(vaultId, rewardAmount);
    }

    function updateStrategy(uint256 vaultId, address _newStrategy) external onlyOperator validVault(vaultId) {
        if (_newStrategy == address(0)) revert ZeroAddress();
        Vault storage vault = vaults[vaultId];
        address oldStrategy = address(vault.strategy);
        vault.strategy = IStrategy(_newStrategy);
        emit StrategyUpdated(vaultId, oldStrategy, _newStrategy);
    }

    function rollover(uint256 vaultId, address _newStrategy) external onlyOperator validVault(vaultId) nonReentrant {
        if (_newStrategy == address(0)) revert ZeroAddress();
        Vault storage vault = vaults[vaultId];
        IStrategy oldStrategy = vault.strategy;
        uint256 total = vault.totalDeposits;

        uint256 rewardAmount = oldStrategy.harvest();
        if (rewardAmount > 0) {
            vault.rewardBalance += rewardAmount;
            if (total > 0) {
                vault.accRewardPerToken += (rewardAmount * PRECISION) / total;
            }
            emit Harvest(vaultId, rewardAmount);
        }

        vault.strategy = IStrategy(_newStrategy);

        if (total > 0) {
            oldStrategy.withdraw(total);
            vault.underlying.safeApprove(_newStrategy, total);
            IStrategy(_newStrategy).deposit(total);
        }

        emit StrategyRolledOver(vaultId, address(oldStrategy), _newStrategy);
    }

    function deposit(uint256 vaultId, uint256 amount) external nonReentrant validVault(vaultId) {
        if (amount == 0) revert AmountZero();
        Vault storage vault = vaults[vaultId];
        if (vault.isPaused) revert VaultIsPaused();
        if (amount < vault.minDepositAmount) revert InsufficientDeposit();

        uint256 pendingReward = _claimPendingReward(vaultId, msg.sender, vault);

        userInfo[vaultId][msg.sender].deposited += amount;
        vault.totalDeposits += amount;
        userInfo[vaultId][msg.sender].rewardDebt += (amount * vault.accRewardPerToken) / PRECISION;

        vault.underlying.safeTransferFrom(msg.sender, address(this), amount);
        vault.underlying.safeApprove(address(vault.strategy), amount);
        vault.strategy.deposit(amount);

        if (pendingReward > 0) {
            vault.underlying.safeTransfer(msg.sender, pendingReward);
            emit RewardsClaimed(vaultId, msg.sender, pendingReward);
        }

        emit Deposit(vaultId, msg.sender, amount);
    }

    function withdraw(uint256 vaultId, uint256 amount) external nonReentrant validVault(vaultId) {
        if (amount == 0) revert AmountZero();
        Vault storage vault = vaults[vaultId];
        UserInfo storage user = userInfo[vaultId][msg.sender];
        if (user.deposited < amount) revert InsufficientBalance();

        uint256 pendingReward = _claimPendingReward(vaultId, msg.sender, vault);

        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        user.deposited -= amount;
        vault.totalDeposits -= amount;

        vault.strategy.withdraw(amount);

        vault.underlying.safeTransfer(msg.sender, netAmount);
        if (fee > 0) {
            vault.underlying.safeTransfer(treasury, fee);
        }
        if (pendingReward > 0) {
            vault.underlying.safeTransfer(msg.sender, pendingReward);
            emit RewardsClaimed(vaultId, msg.sender, pendingReward);
        }

        emit Withdraw(vaultId, msg.sender, amount, fee, pendingReward);
    }

    function claimRewards(uint256 vaultId) external nonReentrant validVault(vaultId) {
        Vault storage vault = vaults[vaultId];
        uint256 pendingReward = _claimPendingReward(vaultId, msg.sender, vault);
        if (pendingReward > 0) {
            vault.underlying.safeTransfer(msg.sender, pendingReward);
            emit RewardsClaimed(vaultId, msg.sender, pendingReward);
        }
    }

    function vaultCount() external view returns (uint256) {
        return vaults.length;
    }

    function pendingReward(uint256 vaultId, address user) external view validVault(vaultId) returns (uint256) {
        Vault storage vault = vaults[vaultId];
        UserInfo storage u = userInfo[vaultId][user];
        if (u.deposited == 0) return 0;
        uint256 accumulated = (u.deposited * vault.accRewardPerToken) / PRECISION;
        return accumulated > u.rewardDebt ? accumulated - u.rewardDebt : 0;
    }

    function getVault(uint256 vaultId) external view validVault(vaultId) returns (Vault memory) {
        return vaults[vaultId];
    }

    function getUserInfo(uint256 vaultId, address user) external view validVault(vaultId) returns (UserInfo memory) {
        return userInfo[vaultId][user];
    }

    function _claimPendingReward(uint256 vaultId, address user, Vault storage vault) internal returns (uint256 pending) {
        UserInfo storage u = userInfo[vaultId][user];
        if (u.deposited > 0) {
            uint256 accumulated = (u.deposited * vault.accRewardPerToken) / PRECISION;
            if (accumulated > u.rewardDebt) {
                pending = accumulated - u.rewardDebt;
                if (pending > vault.rewardBalance) {
                    pending = vault.rewardBalance;
                }
                if (pending > 0) {
                    vault.rewardBalance -= pending;
                }
            }
        }
        u.rewardDebt = (u.deposited * vault.accRewardPerToken) / PRECISION;
    }
}
