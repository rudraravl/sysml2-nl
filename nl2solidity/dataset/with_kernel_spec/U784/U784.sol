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
    function withdraw(uint256 amount) external returns (uint256);
    function balanceOf() external view returns (uint256);
}

contract YieldAggregator {
    IERC20 public immutable baseToken;
    address public owner;
    address public treasury;
    bool public paused;

    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant WITHDRAWAL_FEE = 50; // 0.5% in basis points
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 private constant ACC_PRECISION = 1e18;
    uint256 public constant MAX_AMOUNT = type(uint256).max / 1e4;

    uint256 private _status = 1;

    struct Strategy {
        bool active;
        uint256 allocationPercentage; // in basis points (0–10000)
        uint256 totalDeposited;       // principal deployed into this strategy
    }

    mapping(address => Strategy) public strategies;
    address[] public activeStrategies;
    uint256 public totalAllocation; // sum of active allocation percentages

    uint256 public totalPrincipal;    // sum of all user principal
    uint256 public totalInStrategies; // principal currently deployed
    uint256 public yieldReserve;     // harvested yield held in contract for claims
    uint256 public accYieldPerShare;  // accumulated yield per unit principal

    mapping(address => uint256) public userPrincipal;
    mapping(address => uint256) public userYieldDebt;

    event Deposited(address indexed user, uint256 amount, address indexed strategy);
    event Withdrawn(address indexed user, uint256 amount, address indexed strategy);
    event YieldClaimed(address indexed user, uint256 amount, address indexed strategy);
    event StrategyAdded(address indexed strategy, uint256 allocationPercentage);
    event StrategyRemoved(address indexed strategy);
    event AllocationUpdated(address indexed strategy, uint256 oldAllocation, uint256 newAllocation);
    event Paused();
    event Unpaused();
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Harvested(uint256 totalYield);

    error OnlyOwner();
    error PausedError();
    error ZeroAddress();
    error MaxStrategiesReached();
    error StrategyNotActive();
    error StrategyAlreadyActive();
    error InvalidAllocation();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error ZeroAmount();
    error AmountTooLarge();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier nonReentrant() {
        if (_status != 1) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _baseToken, address _treasury) {
        if (_baseToken == address(0) || _treasury == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        treasury = _treasury;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
    }

    // -------------------------------------------------------------------------
    // User functions
    // -------------------------------------------------------------------------

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_AMOUNT) revert AmountTooLarge();

        _harvest();
        _settleYield(msg.sender);

        require(baseToken.transferFrom(msg.sender, address(this), amount), "deposit transfer failed");

        _allocate(amount);

        userPrincipal[msg.sender] += amount;
        totalPrincipal += amount;
        userYieldDebt[msg.sender] = (userPrincipal[msg.sender] * accYieldPerShare) / ACC_PRECISION;

        emit Deposited(msg.sender, amount, address(0));
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userPrincipal[msg.sender] < amount) revert InsufficientBalance();

        _harvest();
        _settleYield(msg.sender);

        _deallocate(amount);

        uint256 fee = (amount * WITHDRAWAL_FEE) / FEE_DENOMINATOR;
        uint256 userAmount = amount - fee;

        if (baseToken.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        userPrincipal[msg.sender] -= amount;
        totalPrincipal -= amount;
        userYieldDebt[msg.sender] = (userPrincipal[msg.sender] * accYieldPerShare) / ACC_PRECISION;

        require(baseToken.transfer(treasury, fee), "fee transfer failed");
        require(baseToken.transfer(msg.sender, userAmount), "withdraw transfer failed");

        emit Withdrawn(msg.sender, amount, address(0));
    }

    function claimYield() external nonReentrant {
        _harvest();
        uint256 pending = _pendingYield(msg.sender);
        if (pending == 0) revert ZeroAmount();

        userYieldDebt[msg.sender] = (userPrincipal[msg.sender] * accYieldPerShare) / ACC_PRECISION;
        yieldReserve -= pending;
        require(baseToken.transfer(msg.sender, pending), "claim transfer failed");

        emit YieldClaimed(msg.sender, pending, address(0));
    }

    function harvest() external nonReentrant {
        _harvest();
    }

    // -------------------------------------------------------------------------
    // View helpers
    // -------------------------------------------------------------------------

    function pendingYield(address user) external view returns (uint256) {
        return _pendingYield(user);
    }

    function strategyCount() external view returns (uint256) {
        return activeStrategies.length;
    }

    function getActiveStrategies() external view returns (address[] memory) {
        return activeStrategies;
    }

    function getStrategy(address strategy)
        external
        view
        returns (bool active, uint256 allocationPercentage, uint256 totalDeposited)
    {
        Strategy memory s = strategies[strategy];
        return (s.active, s.allocationPercentage, s.totalDeposited);
    }

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    function addStrategy(address strategy, uint256 allocationPercentage) external onlyOwner {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategies[strategy].active) revert StrategyAlreadyActive();
        if (activeStrategies.length >= MAX_STRATEGIES) revert MaxStrategiesReached();
        if (allocationPercentage > 10000) revert InvalidAllocation();

        strategies[strategy] = Strategy({
            active: true,
            allocationPercentage: allocationPercentage,
            totalDeposited: 0
        });
        activeStrategies.push(strategy);
        totalAllocation += allocationPercentage;

        emit StrategyAdded(strategy, allocationPercentage);
    }

    function removeStrategy(address strategy) external onlyOwner nonReentrant {
        if (!strategies[strategy].active) revert StrategyNotActive();

        uint256 deposited = strategies[strategy].totalDeposited;
        if (deposited > 0) {
            strategies[strategy].totalDeposited = 0;
            totalInStrategies -= deposited;
            IStrategy(strategy).withdraw(deposited);
        }

        totalAllocation -= strategies[strategy].allocationPercentage;
        strategies[strategy].active = false;
        strategies[strategy].allocationPercentage = 0;

        uint256 len = activeStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (activeStrategies[i] == strategy) {
                activeStrategies[i] = activeStrategies[len - 1];
                activeStrategies.pop();
                break;
            }
        }

        emit StrategyRemoved(strategy);
    }

    function updateAllocation(address strategy, uint256 newAllocation) external onlyOwner {
        if (!strategies[strategy].active) revert StrategyNotActive();
        if (newAllocation > 10000) revert InvalidAllocation();

        uint256 oldAllocation = strategies[strategy].allocationPercentage;
        totalAllocation = totalAllocation - oldAllocation + newAllocation;
        strategies[strategy].allocationPercentage = newAllocation;

        emit AllocationUpdated(strategy, oldAllocation, newAllocation);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    function _pendingYield(address user) internal view returns (uint256) {
        return (userPrincipal[user] * accYieldPerShare) / ACC_PRECISION - userYieldDebt[user];
    }

    function _settleYield(address user) internal {
        uint256 pending = _pendingYield(user);
        if (pending > 0) {
            userYieldDebt[user] = (userPrincipal[user] * accYieldPerShare) / ACC_PRECISION;
            yieldReserve -= pending;
            require(baseToken.transfer(user, pending), "settle yield transfer failed");
            emit YieldClaimed(user, pending, address(0));
        }
    }

    function _harvest() internal {
        uint256 totalYield = 0;
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            address strat = activeStrategies[i];
            uint256 bal = IStrategy(strat).balanceOf();
            uint256 principal = strategies[strat].totalDeposited;
            if (bal > principal) {
                uint256 yieldAmount = bal - principal;
                uint256 got = IStrategy(strat).withdraw(yieldAmount);
                totalYield += got;
            }
        }
        if (totalYield > 0) {
            yieldReserve += totalYield;
            if (totalPrincipal > 0) {
                accYieldPerShare += (totalYield * ACC_PRECISION) / totalPrincipal;
            }
            emit Harvested(totalYield);
        }
    }

    function _allocate(uint256 amount) internal {
        if (totalAllocation == 0 || activeStrategies.length == 0) {
            return;
        }
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            address strat = activeStrategies[i];
            uint256 allocPct = strategies[strat].allocationPercentage;
            if (allocPct == 0) continue;
            uint256 stratAmount = (amount * allocPct) / totalAllocation;
            if (stratAmount == 0) continue;
            require(baseToken.approve(strat, stratAmount), "approve failed");
            IStrategy(strat).deposit(stratAmount);
            strategies[strat].totalDeposited += stratAmount;
            totalInStrategies += stratAmount;
        }
    }

    function _deallocate(uint256 amount) internal {
        uint256 freePrincipal = totalPrincipal - totalInStrategies;
        uint256 fromContract = amount < freePrincipal ? amount : freePrincipal;
        uint256 fromStrategies = amount - fromContract;

        if (fromStrategies > 0 && totalInStrategies > 0) {
            uint256 totalStrats = totalInStrategies;
            uint256 withdrawnFromStrats = 0;
            address lastStrat = address(0);

            for (uint256 i = 0; i < activeStrategies.length; i++) {
                address strat = activeStrategies[i];
                uint256 stratDeposited = strategies[strat].totalDeposited;
                if (stratDeposited == 0) continue;
                lastStrat = strat;
                uint256 stratWithdraw = (fromStrategies * stratDeposited) / totalStrats;
                if (stratWithdraw == 0) continue;
                uint256 got = IStrategy(strat).withdraw(stratWithdraw);
                strategies[strat].totalDeposited -= got;
                withdrawnFromStrats += got;
            }

            // Pull any rounding remainder from the last non-zero strategy
            if (withdrawnFromStrats < fromStrategies && lastStrat != address(0)) {
                uint256 remainder = fromStrategies - withdrawnFromStrats;
                uint256 lastDeposited = strategies[lastStrat].totalDeposited;
                if (remainder > lastDeposited) remainder = lastDeposited;
                if (remainder > 0) {
                    uint256 gotRemainder = IStrategy(lastStrat).withdraw(remainder);
                    strategies[lastStrat].totalDeposited -= gotRemainder;
                    withdrawnFromStrats += gotRemainder;
                }
            }

            totalInStrategies -= withdrawnFromStrats;
        }
    }
}
