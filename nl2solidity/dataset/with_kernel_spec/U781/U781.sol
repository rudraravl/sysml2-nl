// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) return false;

        uint256 lastIndex = set._values.length;
        if (valueIndex != lastIndex) {
            address lastValue = set._values[lastIndex - 1];
            set._values[valueIndex - 1] = lastValue;
            set._indexes[lastValue] = valueIndex;
        }
        set._values.pop();
        delete set._indexes[value];
        return true;
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

contract LendingPool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_DEPOSIT = 100_000 * 10 ** 18;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant MAX_SPREAD_BPS = 10_000;

    // ---------------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------------
    IERC20 public immutable stablecoin;
    IERC20 public immutable governanceToken;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public operator;
    address public treasury;
    bool public paused;
    uint256 public interestRateSpreadBps; // protocol take from yield distributions

    uint256 public totalDeposits;
    mapping(address => uint256) public userDeposits;

    // Yield (stablecoin) reward accounting
    uint256 public accYieldPerShare;
    mapping(address => uint256) public userYieldDebt;
    mapping(address => uint256) public pendingYield;

    // Governance token reward accounting
    uint256 public accGovPerShare;
    mapping(address => uint256) public userGovDebt;
    mapping(address => uint256) public pendingGov;

    EnumerableSet.AddressSet private approvedStrategies;

    // Reentrancy guard
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error Unauthorized();
    error ContractPaused();
    error ZeroAmount();
    error ZeroAddress();
    error ExceedsMaxDeposit();
    error InsufficientBalance();
    error NoPendingTokens();
    error NoActiveDeposits();
    error StrategyAlreadyApproved();
    error StrategyNotApproved();
    error InvalidSpread();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 principal, uint256 yieldAmount, uint256 fee);
    event YieldDistributed(address indexed distributor, uint256 amount, uint256 protocolFee);
    event GovernanceTokensDistributed(address indexed distributor, uint256 amount);
    event GovernanceTokensClaimed(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event InterestRateSpreadUpdated(uint256 oldSpread, uint256 newSpread);
    event PausedStateChanged(bool isPaused);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier onlyAuthorizedDistributor() {
        if (msg.sender != operator && !approvedStrategies.contains(msg.sender)) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address _stablecoin,
        address _governanceToken,
        address _treasury,
        address _operator,
        uint256 _initialSpreadBps
    ) {
        if (_stablecoin == address(0) || _governanceToken == address(0) || _treasury == address(0) || _operator == address(0))
            revert ZeroAddress();
        if (_initialSpreadBps > MAX_SPREAD_BPS) revert InvalidSpread();

        stablecoin = IERC20(_stablecoin);
        governanceToken = IERC20(_governanceToken);
        treasury = _treasury;
        operator = _operator;
        interestRateSpreadBps = _initialSpreadBps;

        emit OperatorChanged(address(0), _operator);
        emit TreasuryChanged(address(0), _treasury);
        emit InterestRateSpreadUpdated(0, _initialSpreadBps);
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userDeposits[msg.sender] + amount > MAX_DEPOSIT) revert ExceedsMaxDeposit();

        // Effects: update rewards based on current deposit, then update deposit state
        _updateUserRewards(msg.sender);

        userDeposits[msg.sender] += amount;
        totalDeposits += amount;

        userYieldDebt[msg.sender] = (userDeposits[msg.sender] * accYieldPerShare) / ACC_PRECISION;
        userGovDebt[msg.sender] = (userDeposits[msg.sender] * accGovPerShare) / ACC_PRECISION;

        // Interactions
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userDeposits[msg.sender] < amount) revert InsufficientBalance();

        // Effects
        _updateUserRewards(msg.sender);

        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;

        userYieldDebt[msg.sender] = (userDeposits[msg.sender] * accYieldPerShare) / ACC_PRECISION;
        userGovDebt[msg.sender] = (userDeposits[msg.sender] * accGovPerShare) / ACC_PRECISION;

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Interactions
        stablecoin.safeTransfer(msg.sender, netAmount);
        if (fee > 0) {
            stablecoin.safeTransfer(treasury, fee);
        }

        emit Withdraw(msg.sender, amount, 0, fee);
    }

    function claimYield() external whenNotPaused nonReentrant {
        _updateUserRewards(msg.sender);
        uint256 amount = pendingYield[msg.sender];
        if (amount == 0) revert NoPendingTokens();

        // Effects
        pendingYield[msg.sender] = 0;

        // Interactions
        stablecoin.safeTransfer(msg.sender, amount);

        emit YieldClaimed(msg.sender, amount);
    }

    function claimGovernanceTokens() external whenNotPaused nonReentrant {
        _updateUserRewards(msg.sender);
        uint256 amount = pendingGov[msg.sender];
        if (amount == 0) revert NoPendingTokens();

        // Effects
        pendingGov[msg.sender] = 0;

        // Interactions
        governanceToken.safeTransfer(msg.sender, amount);

        emit GovernanceTokensClaimed(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Distribution functions
    // ---------------------------------------------------------------------

    function distributeYield(uint256 amount) external onlyAuthorizedDistributor nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalDeposits == 0) revert NoActiveDeposits();

        // Interactions: pull tokens first
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        // Effects
        uint256 protocolFee = (amount * interestRateSpreadBps) / BPS_DENOMINATOR;
        uint256 netYield = amount - protocolFee;

        if (protocolFee > 0) {
            stablecoin.safeTransfer(treasury, protocolFee);
        }

        accYieldPerShare += (netYield * ACC_PRECISION) / totalDeposits;

        emit YieldDistributed(msg.sender, amount, protocolFee);
    }

    function distributeGovernanceTokens(uint256 amount) external onlyAuthorizedDistributor nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalDeposits == 0) revert NoActiveDeposits();

        // Interactions: pull tokens first
        governanceToken.safeTransferFrom(msg.sender, address(this), amount);

        // Effects
        accGovPerShare += (amount * ACC_PRECISION) / totalDeposits;

        emit GovernanceTokensDistributed(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    function addStrategy(address strategy) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (!approvedStrategies.add(strategy)) revert StrategyAlreadyApproved();
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!approvedStrategies.remove(strategy)) revert StrategyNotApproved();
        emit StrategyRemoved(strategy);
    }

    function setInterestRateSpread(uint256 newSpreadBps) external onlyOperator {
        if (newSpreadBps > MAX_SPREAD_BPS) revert InvalidSpread();
        uint256 oldSpread = interestRateSpreadBps;
        interestRateSpreadBps = newSpreadBps;
        emit InterestRateSpreadUpdated(oldSpread, newSpreadBps);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryChanged(old, newTreasury);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    function isApprovedStrategy(address strategy) external view returns (bool) {
        return approvedStrategies.contains(strategy);
    }

    function getApprovedStrategies() external view returns (address[] memory) {
        return approvedStrategies.values();
    }

    function getApprovedStrategyCount() external view returns (uint256) {
        return approvedStrategies.length();
    }

    function pendingYieldOf(address user) external view returns (uint256) {
        uint256 accrued = (userDeposits[user] * accYieldPerShare) / ACC_PRECISION;
        if (accrued <= userYieldDebt[user]) return pendingYield[user];
        return pendingYield[user] + (accrued - userYieldDebt[user]);
    }

    function pendingGovernanceTokensOf(address user) external view returns (uint256) {
        uint256 accrued = (userDeposits[user] * accGovPerShare) / ACC_PRECISION;
        if (accrued <= userGovDebt[user]) return pendingGov[user];
        return pendingGov[user] + (accrued - userGovDebt[user]);
    }

    // ---------------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------------

    function _updateUserRewards(address user) internal {
        uint256 depositAmount = userDeposits[user];

        if (depositAmount > 0) {
            uint256 yieldAccrued = (depositAmount * accYieldPerShare) / ACC_PRECISION;
            if (yieldAccrued > userYieldDebt[user]) {
                pendingYield[user] += yieldAccrued - userYieldDebt[user];
            }

            uint256 govAccrued = (depositAmount * accGovPerShare) / ACC_PRECISION;
            if (govAccrued > userGovDebt[user]) {
                pendingGov[user] += govAccrued - userGovDebt[user];
            }
        }

        userYieldDebt[user] = (depositAmount * accYieldPerShare) / ACC_PRECISION;
        userGovDebt[user] = (depositAmount * accGovPerShare) / ACC_PRECISION;
    }
}
