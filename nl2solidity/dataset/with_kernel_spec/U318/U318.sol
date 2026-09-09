// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalAssets() external view returns (uint256);
}

library AddressSet {
    struct Set {
        address[] items;
        mapping(address => uint256) indexOf;
        uint256 length;
    }

    function contains(Set storage s, address value) internal view returns (bool) {
        return s.indexOf[value] != 0 || (s.length > 0 && s.items[0] == value);
    }

    function add(Set storage s, address value) internal returns (bool) {
        if (contains(s, value)) return false;
        if (s.length == 0) {
            s.items.push(address(0));
            s.indexOf[address(0)] = 0;
        }
        s.items.push(value);
        s.indexOf[value] = s.items.length - 1;
        s.length++;
        return true;
    }

    function remove(Set storage s, address value) internal returns (bool) {
        if (!contains(s, value)) return false;
        uint256 idx = s.indexOf[value];
        address lastValue = s.items[s.items.length - 1];
        s.items[idx] = lastValue;
        s.indexOf[lastValue] = idx;
        s.items.pop();
        delete s.indexOf[value];
        s.length--;
        return true;
    }

    function getValues(Set storage s) internal view returns (address[] memory) {
        if (s.length == 0) {
            return new address[](0);
        }
        address[] memory result = new address[](s.length);
        uint256 count;
        for (uint256 i = 1; i < s.items.length; i++) {
            if (s.items[i] != address(0)) {
                result[count] = s.items[i];
                count++;
            }
        }
        assembly { mstore(result, count) }
        return result;
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract Pausable {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    function _pause() internal {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        paused = false;
        emit Unpaused(msg.sender);
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

contract FractionalReservePool is Ownable, Pausable, ReentrancyGuard {
    using AddressSet for AddressSet.Set;
    using SafeERC20 for IERC20;

    uint256 public constant MIN_RESERVE_RATIO_BPS = 1000; // 10%
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant RAY = 1e27;

    IERC20 public immutable stablecoin;
    IERC20 public immutable yieldBearingToken;

    address public operator;
    uint256 public reserveRatioBps;

    uint256 public totalDeposits;
    uint256 public deployedToStrategies;
    uint256 public totalYieldDistributed;

    mapping(address => uint256) public deposits;

    uint256 public yieldIndex; // RAY-scaled cumulative yield index
    mapping(address => uint256) public lastYieldIndex;
    mapping(address => uint256) public unclaimedYield;

    AddressSet.Set internal strategySet;
    mapping(address => uint256) public strategyAllocation;

    event Deposit(address indexed account, uint256 amount, uint256 totalDepositsAfter);
    event Withdraw(address indexed account, uint256 amountReceived, uint256 fee, uint256 totalDepositsAfter);
    event YieldClaimed(address indexed account, uint256 amount);
    event YieldDistributed(address indexed caller, uint256 amount, uint256 yieldIndexAfter);
    event ReserveRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyFunded(address indexed strategy, uint256 amount);
    event StrategyRecalled(address indexed strategy, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error NotOperator();
    error StrategyAlreadyExists();
    error StrategyNotFound();
    error ReserveRatioBelowMinimum();
    error ReserveRatioTooHigh();
    error InsufficientReserve();
    error NoYieldToClaim();
    error ExceedsStrategyAllocation();
    error ProtectedToken();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address _stablecoin,
        address _yieldBearingToken,
        address _operator
    ) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_yieldBearingToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        yieldBearingToken = IERC20(_yieldBearingToken);
        operator = _operator;
        reserveRatioBps = MIN_RESERVE_RATIO_BPS;
        yieldIndex = RAY;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueYield(msg.sender);
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount, totalDeposits);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount) revert InsufficientBalance();
        _accrueYield(msg.sender);

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / MAX_BPS;
        uint256 toUser = amount - fee;

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        uint256 reserveBalance = stablecoin.balanceOf(address(this));
        uint256 required = (totalDeposits * reserveRatioBps) / MAX_BPS;
        if (reserveBalance < required + toUser) {
            revert InsufficientReserve();
        }

        stablecoin.safeTransfer(msg.sender, toUser);

        emit Withdraw(msg.sender, toUser, fee, totalDeposits);
    }

    function claimYield() external nonReentrant {
        uint256 amount = unclaimedYield[msg.sender];
        if (amount == 0) revert NoYieldToClaim();
        unclaimedYield[msg.sender] = 0;
        yieldBearingToken.safeTransfer(msg.sender, amount);
        emit YieldClaimed(msg.sender, amount);
    }

    function pendingYield(address account) external view returns (uint256) {
        return unclaimedYield[account] + _instantPendingYield(account);
    }

    function _instantPendingYield(address account) internal view returns (uint256) {
        if (deposits[account] == 0) return 0;
        uint256 delta = yieldIndex - lastYieldIndex[account];
        if (delta == 0) return 0;
        return (deposits[account] * delta) / RAY;
    }

    function _accrueYield(address account) internal {
        uint256 instant = _instantPendingYield(account);
        if (instant > 0) {
            unclaimedYield[account] += instant;
        }
        lastYieldIndex[account] = yieldIndex;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setReserveRatio(uint256 newRatioBps) external onlyOperator {
        if (newRatioBps < MIN_RESERVE_RATIO_BPS) revert ReserveRatioBelowMinimum();
        if (newRatioBps > MAX_BPS) revert ReserveRatioTooHigh();
        emit ReserveRatioUpdated(reserveRatioBps, newRatioBps);
        reserveRatioBps = newRatioBps;
    }

    function addStrategy(address strategy) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategySet.contains(strategy)) revert StrategyAlreadyExists();
        strategySet.add(strategy);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!strategySet.contains(strategy)) revert StrategyNotFound();
        if (strategyAllocation[strategy] > 0) revert ExceedsStrategyAllocation();
        strategySet.remove(strategy);
        emit StrategyRemoved(strategy);
    }

    function deployToStrategy(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!strategySet.contains(strategy)) revert StrategyNotFound();

        uint256 reserveBalance = stablecoin.balanceOf(address(this));
        uint256 required = (totalDeposits * reserveRatioBps) / MAX_BPS;
        if (reserveBalance < required + amount) {
            revert InsufficientReserve();
        }

        strategyAllocation[strategy] += amount;
        deployedToStrategies += amount;

        stablecoin.safeApprove(strategy, 0);
        stablecoin.safeApprove(strategy, amount);
        IYieldStrategy(strategy).deposit(amount);
        stablecoin.safeApprove(strategy, 0);

        emit StrategyFunded(strategy, amount);
    }

    function recallFromStrategy(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!strategySet.contains(strategy)) revert StrategyNotFound();
        if (strategyAllocation[strategy] < amount) revert ExceedsStrategyAllocation();

        strategyAllocation[strategy] -= amount;
        deployedToStrategies -= amount;

        IYieldStrategy(strategy).withdraw(amount);

        emit StrategyRecalled(strategy, amount);
    }

    function distributeYield(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalDeposits == 0) revert ZeroAmount();
        yieldBearingToken.safeTransferFrom(msg.sender, address(this), amount);
        yieldIndex += (amount * RAY) / totalDeposits;
        totalYieldDistributed += amount;
        emit YieldDistributed(msg.sender, amount, yieldIndex);
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function rescueTokens(address token, uint256 amount, address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token == address(stablecoin) || token == address(yieldBearingToken)) {
            revert ProtectedToken();
        }
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit TokensRescued(token, to, amount);
    }

    function getStrategies() external view returns (address[] memory) {
        return strategySet.getValues();
    }

    function strategiesCount() external view returns (uint256) {
        return strategySet.length;
    }

    function isApprovedStrategy(address strategy) external view returns (bool) {
        return strategySet.contains(strategy);
    }

    function currentReserve() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function requiredReserve() public view returns (uint256) {
        return (totalDeposits * reserveRatioBps) / MAX_BPS;
    }
}
