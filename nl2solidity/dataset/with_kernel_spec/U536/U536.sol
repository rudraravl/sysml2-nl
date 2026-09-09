// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
}

contract StablecoinVault {
    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable stablecoin;
    IStrategy public strategy;

    address public owner;
    address public operator;

    uint256 public totalAssets;
    uint256 public totalShares;
    mapping(address => uint256) public userShares;

    uint256 public withdrawalFeeBps;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint256 public constant WITHDRAWAL_DELAY = 24 hours;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant INITIAL_FEE_BPS = 50; // 0.5%

    struct PendingWithdrawal {
        uint256 shares;
        uint256 releaseTime;
        bool active;
    }
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    address public implementation;
    uint256 private _locked;

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event WithdrawalInitiated(address indexed user, uint256 shares, uint256 releaseTime);
    event WithdrawalCompleted(address indexed user, uint256 amountSent, uint256 fee);
    event WithdrawalCancelled(address indexed user, uint256 shares);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event Rebalanced(uint256 vaultBalance, uint256 strategyBalance, uint256 newTotalAssets);
    event Upgraded(address indexed newImplementation);
    event EtherRescued(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientShares();
    error InsufficientVaultLiquidity();
    error NoActiveWithdrawal();
    error WithdrawalStillLocked(uint256 releaseTime);
    error InvalidAmount();
    error FeeTooHigh();
    error InvalidShares();
    error InvalidShareCalculation();
    error TransferFailed();
    error ReentrantCall();
    error NoImplementation();
    error NothingToRescue();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 2) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address stablecoin_, address strategy_) {
        if (stablecoin_ == address(0)) revert ZeroAddress();
        if (strategy_ == address(0)) revert ZeroAddress();
        stablecoin = IERC20(stablecoin_);
        strategy = IStrategy(strategy_);
        owner = msg.sender;
        operator = msg.sender;
        withdrawalFeeBps = INITIAL_FEE_BPS;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / totalAssets;
        }
        if (sharesToMint == 0) revert InvalidShareCalculation();

        // Effects before interactions: update accounting prior to the external
        // transfer so a malicious token cannot observe stale vault state.
        userShares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssets += amount;

        // Interaction.
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function initiateWithdraw(uint256 shares) external {
        if (shares == 0) revert InvalidShares();
        if (userShares[msg.sender] < shares) revert InsufficientShares();
        if (pendingWithdrawals[msg.sender].active) revert NoActiveWithdrawal();

        userShares[msg.sender] -= shares;
        uint256 releaseTime = block.timestamp + WITHDRAWAL_DELAY;
        pendingWithdrawals[msg.sender] =
            PendingWithdrawal({shares: shares, releaseTime: releaseTime, active: true});

        emit WithdrawalInitiated(msg.sender, shares, releaseTime);
    }

    function completeWithdraw() external nonReentrant {
        PendingWithdrawal storage pending = pendingWithdrawals[msg.sender];
        if (!pending.active) revert NoActiveWithdrawal();
        if (block.timestamp < pending.releaseTime) revert WithdrawalStillLocked(pending.releaseTime);

        uint256 shares = pending.shares;
        if (totalShares == 0) revert InvalidShareCalculation();

        // Compute the gross asset value and the fee using a single division over
        // the full-precision numerator. Performing all multiplications first and
        // only then dividing avoids the rounding loss of a divide-then-multiply
        // sequence. Realistic stablecoin magnitudes keep the product far below
        // 2^256, so overflow is not a concern here.
        uint256 grossAssets = (shares * totalAssets) / totalShares;
        uint256 fee = (shares * totalAssets * withdrawalFeeBps) / (totalShares * BPS_DENOMINATOR);
        uint256 amountToSend = grossAssets - fee;

        // Check that the vault holds enough idle stablecoin to pay out.
        if (stablecoin.balanceOf(address(this)) < amountToSend + fee) {
            revert InsufficientVaultLiquidity();
        }

        // Effects.
        totalShares -= shares;
        totalAssets -= grossAssets;
        pending.active = false;
        pending.shares = 0;
        pending.releaseTime = 0;

        // Interactions.
        if (amountToSend > 0) {
            bool ok1 = stablecoin.transfer(msg.sender, amountToSend);
            if (!ok1) revert TransferFailed();
        }
        if (fee > 0) {
            bool ok2 = stablecoin.transfer(owner, fee);
            if (!ok2) revert TransferFailed();
        }

        emit WithdrawalCompleted(msg.sender, amountToSend, fee);
    }

    function cancelWithdraw() external {
        PendingWithdrawal storage pending = pendingWithdrawals[msg.sender];
        if (!pending.active) revert NoActiveWithdrawal();

        uint256 shares = pending.shares;
        pending.active = false;
        pending.shares = 0;
        pending.releaseTime = 0;

        userShares[msg.sender] += shares;

        emit WithdrawalCancelled(msg.sender, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function rebalance(uint256 targetStrategyBalance) external onlyOperator nonReentrant {
        uint256 currentStrategy = strategy.balanceOf();
        uint256 currentVault = stablecoin.balanceOf(address(this));

        if (targetStrategyBalance > currentStrategy) {
            uint256 toDeposit = targetStrategyBalance - currentStrategy;
            if (currentVault < toDeposit) revert InsufficientVaultLiquidity();
            bool ok = stablecoin.approve(address(strategy), toDeposit);
            if (!ok) revert TransferFailed();
            strategy.deposit(toDeposit);
        } else if (targetStrategyBalance < currentStrategy) {
            uint256 toWithdraw = currentStrategy - targetStrategyBalance;
            strategy.withdraw(toWithdraw);
        }

        uint256 vaultBal = stablecoin.balanceOf(address(this));
        uint256 stratBal = strategy.balanceOf();
        totalAssets = vaultBal + stratBal;

        emit Rebalanced(vaultBal, stratBal, totalAssets);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFeeBps = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit FeeUpdated(oldFeeBps, newFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN (OWNER)
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setStrategy(address newStrategy) external onlyOwner nonReentrant {
        if (newStrategy == address(0)) revert ZeroAddress();
        address oldStrategy = address(strategy);
        uint256 currentStrategyBal = strategy.balanceOf();

        // Effect: commit the new strategy before any external interaction so a
        // reentrant call from the old strategy cannot mutate stale state.
        strategy = IStrategy(newStrategy);

        if (currentStrategyBal > 0) {
            IStrategy(oldStrategy).withdraw(currentStrategyBal);
        }

        uint256 vaultBal = stablecoin.balanceOf(address(this));
        uint256 stratBal = strategy.balanceOf();
        totalAssets = vaultBal + stratBal;

        emit StrategyUpdated(oldStrategy, newStrategy);
    }

    function upgrade(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function rescueEther(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToRescue();
        (bool ok, ) = payable(to).call{value: bal}("");
        if (!ok) revert TransferFailed();
        emit EtherRescued(to, bal);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function sharesToAmount(uint256 shares) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares * totalAssets) / totalShares;
    }

    function amountToShares(uint256 amount) external view returns (uint256) {
        if (totalShares == 0) return amount;
        return (amount * totalShares) / totalAssets;
    }

    function userBalance(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userShares[user] * totalAssets) / totalShares;
    }

    function pendingWithdrawalAmount(address user) external view returns (uint256) {
        PendingWithdrawal storage pending = pendingWithdrawals[user];
        if (!pending.active || totalShares == 0) return 0;
        return (pending.shares * totalAssets) / totalShares;
    }

    function totalVaultBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this)) + strategy.balanceOf();
    }

    function getStrategyBalance() external view returns (uint256) {
        return strategy.balanceOf();
    }

    /*//////////////////////////////////////////////////////////////
                         UPGRADEABLE FALLBACK
    //////////////////////////////////////////////////////////////*/

    fallback() external {
        address impl = implementation;
        if (impl == address(0)) revert NoImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
