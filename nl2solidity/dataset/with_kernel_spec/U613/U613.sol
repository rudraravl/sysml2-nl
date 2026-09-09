// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalAssets() external view returns (uint256);
}

contract StablecoinYieldVault {
    // ---------- Errors ----------
    error NotOwner();
    error ZeroAddress();
    error DepositsPaused();
    error BelowMinimumDeposit();
    error InsufficientBalance();
    error InvalidYieldRate();
    error TransferFailed();
    error NothingToClaim();
    error ZeroAmount();
    error ApproveFailed();

    // ---------- Events ----------
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event YieldClaimed(address indexed user, uint256 amount);
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event DepositsPausedChanged(bool paused);
    event FeeCollected(address indexed treasury, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EtherRescued(address indexed to, uint256 amount);

    // ---------- Constants ----------
    uint256 public constant MINIMUM_DEPOSIT = 100 * 10 ** 18;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 private constant ACC_PRECISION = 1e18;
    uint256 private constant BLOCKS_PER_YEAR = 2_100_000;

    // ---------- State ----------
    IERC20 public immutable stablecoin;
    address public owner;
    address public feeTreasury;

    IYieldStrategy public yieldStrategy;
    uint256 public yieldRate; // annual yield rate in basis points

    uint256 public totalDeposited;
    bool public depositsPaused;

    struct UserInfo {
        uint256 deposited;
        uint256 rewardDebt;
        uint256 pendingYield;
    }

    mapping(address => UserInfo) public users;

    uint256 public accYieldPerShare;
    uint256 public lastRewardBlock;

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier notPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    modifier nonReentrant() {
        assembly {
            if tload(0) { revert(0, 0) }
            tstore(0, 1)
        }
        _;
        assembly {
            tstore(0, 0)
        }
    }

    // ---------- Constructor ----------
    constructor(address _stablecoin, address _feeTreasury, uint256 _yieldRate) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_feeTreasury == address(0)) revert ZeroAddress();
        if (_yieldRate > BPS_DENOMINATOR) revert InvalidYieldRate();

        stablecoin = IERC20(_stablecoin);
        feeTreasury = _feeTreasury;
        owner = msg.sender;
        yieldRate = _yieldRate;
        lastRewardBlock = block.number;

        emit OwnershipTransferred(address(0), msg.sender);
        emit YieldRateUpdated(0, _yieldRate);
    }

    // ---------- Owner functions ----------
    function setYieldStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        address old = address(yieldStrategy);
        yieldStrategy = IYieldStrategy(_strategy);
        emit StrategyUpdated(old, _strategy);
    }

    function setYieldRate(uint256 _rate) external onlyOwner {
        if (_rate > BPS_DENOMINATOR) revert InvalidYieldRate();
        _updatePool();
        uint256 old = yieldRate;
        yieldRate = _rate;
        emit YieldRateUpdated(old, _rate);
    }

    function setDepositsPaused(bool _paused) external onlyOwner {
        depositsPaused = _paused;
        emit DepositsPausedChanged(_paused);
    }

    function setFeeTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        feeTreasury = _treasury;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function rescueToken(address _token, uint256 _amount) external onlyOwner {
        if (_amount == 0) revert ZeroAmount();
        if (_token == address(stablecoin)) {
            uint256 excess = stablecoin.balanceOf(address(this)) - totalDeposited;
            if (_amount > excess) revert InsufficientBalance();
        }
        if (!IERC20(_token).transfer(msg.sender, _amount)) revert TransferFailed();
    }

    function rescueEther(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        uint256 bal = address(this).balance;
        if (_amount > bal) revert InsufficientBalance();
        (bool ok, ) = payable(_to).call{value: _amount}("");
        if (!ok) revert TransferFailed();
        emit EtherRescued(_to, _amount);
    }

    // ---------- Yield accounting ----------
    function _updatePool() internal {
        if (totalDeposited == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocksElapsed = block.number - lastRewardBlock;
        // Multiply first, then divide to avoid precision loss.
        uint256 accrued = (totalDeposited * yieldRate * blocksElapsed) /
            (BPS_DENOMINATOR * BLOCKS_PER_YEAR);

        accYieldPerShare += (accrued * ACC_PRECISION) / totalDeposited;
        lastRewardBlock = block.number;
    }

    function _pendingYield(address _user) internal view returns (uint256) {
        UserInfo storage info = users[_user];
        if (totalDeposited == 0) return info.pendingYield;

        uint256 blocksElapsed = block.number - lastRewardBlock;
        // Multiply first, then divide to avoid precision loss.
        uint256 accrued = (totalDeposited * yieldRate * blocksElapsed) /
            (BPS_DENOMINATOR * BLOCKS_PER_YEAR);
        uint256 currentAccPerShare = accYieldPerShare +
            (accrued * ACC_PRECISION) / totalDeposited;

        uint256 owed = (info.deposited * currentAccPerShare) / ACC_PRECISION;
        return owed - info.rewardDebt + info.pendingYield;
    }

    // ---------- User functions ----------
    function deposit(uint256 _amount) external notPaused nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (_amount < MINIMUM_DEPOSIT) revert BelowMinimumDeposit();

        _updatePool();

        UserInfo storage info = users[msg.sender];

        if (info.deposited > 0) {
            uint256 owed = (info.deposited * accYieldPerShare) / ACC_PRECISION - info.rewardDebt;
            info.pendingYield += owed;
        }

        // Effects: update state before interactions.
        info.deposited += _amount;
        totalDeposited += _amount;
        info.rewardDebt = (info.deposited * accYieldPerShare) / ACC_PRECISION;

        // Interactions
        if (!stablecoin.transferFrom(msg.sender, address(this), _amount)) revert TransferFailed();

        if (address(yieldStrategy) != address(0)) {
            if (!stablecoin.approve(address(yieldStrategy), _amount)) revert ApproveFailed();
            yieldStrategy.deposit(_amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        UserInfo storage info = users[msg.sender];
        if (_amount > info.deposited) revert InsufficientBalance();

        _updatePool();

        uint256 owed = (info.deposited * accYieldPerShare) / ACC_PRECISION - info.rewardDebt;
        info.pendingYield += owed;

        uint256 fee = (_amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 toUser = _amount - fee;

        // Effects: update state before interactions.
        info.deposited -= _amount;
        totalDeposited -= _amount;
        info.rewardDebt = (info.deposited * accYieldPerShare) / ACC_PRECISION;

        // Interactions
        if (address(yieldStrategy) != address(0)) {
            yieldStrategy.withdraw(_amount);
        }

        if (!stablecoin.transfer(msg.sender, toUser)) revert TransferFailed();
        if (fee > 0) {
            if (!stablecoin.transfer(feeTreasury, fee)) revert TransferFailed();
            emit FeeCollected(feeTreasury, fee);
        }

        emit Withdraw(msg.sender, _amount, fee);
    }

    function claimYield() external nonReentrant {
        _updatePool();

        UserInfo storage info = users[msg.sender];
        uint256 owed = (info.deposited * accYieldPerShare) / ACC_PRECISION - info.rewardDebt;
        uint256 claimable = owed + info.pendingYield;

        if (claimable == 0) revert NothingToClaim();

        // Effects: update state before interactions.
        info.pendingYield = 0;
        info.rewardDebt = (info.deposited * accYieldPerShare) / ACC_PRECISION;

        // Interactions
        uint256 contractBal = stablecoin.balanceOf(address(this));
        if (contractBal < claimable && address(yieldStrategy) != address(0)) {
            yieldStrategy.withdraw(claimable - contractBal);
        }

        if (!stablecoin.transfer(msg.sender, claimable)) revert TransferFailed();

        emit YieldClaimed(msg.sender, claimable);
    }

    // ---------- View functions ----------
    function pendingYield(address _user) external view returns (uint256) {
        return _pendingYield(_user);
    }

    function userDeposited(address _user) external view returns (uint256) {
        return users[_user].deposited;
    }

    function userPendingYield(address _user) external view returns (uint256) {
        return users[_user].pendingYield;
    }

    receive() external payable {
        // Accept ETH only so that forced transfers (e.g. via selfdestruct) do not
        // lock funds permanently; owner can rescue via rescueEther.
    }
}
