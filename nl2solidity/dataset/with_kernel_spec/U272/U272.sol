// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
}

contract YieldVault {
    error NotOperator();
    error InvalidAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error StrategyAlreadyActive();
    error StrategyNotActive();
    error MaxStrategiesReached();
    error StrategyHasAllocation();
    error NothingToClaim();
    error TransferFailed();
    error ReentrantCall();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event YieldDistributed(uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyAllocationUpdated(address indexed strategy, uint256 oldAllocation, uint256 newAllocation);
    event Harvested(address indexed strategy, uint256 yieldAmount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 private constant PRECISION = 1e18;

    IERC20 public immutable token;
    address public operator;
    address public feeRecipient;

    uint256 public totalDeposited;
    mapping(address => uint256) public userBalance;

    uint256 public accYieldPerShare;
    mapping(address => uint256) public yieldDebt;

    address[] public strategies;
    mapping(address => StrategyInfo) public strategyInfo;

    struct StrategyInfo {
        uint256 allocated;
        bool active;
    }

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _token, address _feeRecipient) {
        if (_token == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        token = IERC20(_token);
        operator = msg.sender;
        feeRecipient = _feeRecipient;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert InvalidAddress();
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function _safeTransfer(IERC20 token_, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    let dataSize := mload(data)
                    revert(add(data, 32), dataSize)
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token_, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    let dataSize := mload(data)
                    revert(add(data, 32), dataSize)
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert TransferFailed();
        }
    }

    function _safeApprove(IERC20 token_, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    let dataSize := mload(data)
                    revert(add(data, 32), dataSize)
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert TransferFailed();
        }
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount <= 0) revert ZeroAmount();

        _harvestPending(msg.sender);

        _safeTransferFrom(token, msg.sender, address(this), amount);

        userBalance[msg.sender] += amount;
        totalDeposited += amount;
        yieldDebt[msg.sender] = (userBalance[msg.sender] * accYieldPerShare) / PRECISION;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount <= 0) revert ZeroAmount();
        if (userBalance[msg.sender] < amount) revert InsufficientBalance();

        _harvestPending(msg.sender);

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        userBalance[msg.sender] -= amount;
        totalDeposited -= amount;
        yieldDebt[msg.sender] = (userBalance[msg.sender] * accYieldPerShare) / PRECISION;

        uint256 totalOut = netAmount + fee;
        uint256 vaultBalance = token.balanceOf(address(this));
        if (vaultBalance < totalOut) {
            _ensureLiquidity(totalOut - vaultBalance);
        }

        if (netAmount > 0) {
            _safeTransfer(token, msg.sender, netAmount);
        }
        if (fee > 0) {
            _safeTransfer(token, feeRecipient, fee);
        }

        emit Withdraw(msg.sender, amount, fee);
    }

    function claimYield() external nonReentrant {
        uint256 pending = _pendingYield(msg.sender);
        if (pending <= 0) revert NothingToClaim();

        yieldDebt[msg.sender] = (userBalance[msg.sender] * accYieldPerShare) / PRECISION;

        uint256 vaultBalance = token.balanceOf(address(this));
        if (vaultBalance < pending) {
            _ensureLiquidity(pending - vaultBalance);
        }

        _safeTransfer(token, msg.sender, pending);
        emit YieldClaimed(msg.sender, pending);
    }

    function harvest(address strategy) external nonReentrant {
        if (!strategyInfo[strategy].active) revert StrategyNotActive();
        uint256 balBefore = token.balanceOf(address(this));
        IStrategy(strategy).harvest();
        uint256 yieldAmount = token.balanceOf(address(this)) - balBefore;
        if (yieldAmount > 0) {
            _distributeYield(yieldAmount);
        }
        emit Harvested(strategy, yieldAmount);
    }

    function harvestAll() external nonReentrant {
        uint256 length = strategies.length;
        uint256 totalYield = 0;
        for (uint256 i = 0; i < length; i++) {
            address strat = strategies[i];
            uint256 balBefore = token.balanceOf(address(this));
            try IStrategy(strat).harvest() {
                uint256 received = token.balanceOf(address(this)) - balBefore;
                if (received > 0) {
                    totalYield += received;
                }
            } catch {}
        }
        if (totalYield > 0) {
            _distributeYield(totalYield);
        }
    }

    function addStrategy(address strategy) external onlyOperator {
        if (strategy == address(0)) revert InvalidAddress();
        if (strategyInfo[strategy].active) revert StrategyAlreadyActive();
        if (strategies.length >= MAX_STRATEGIES) revert MaxStrategiesReached();

        strategies.push(strategy);
        strategyInfo[strategy] = StrategyInfo({allocated: 0, active: true});
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!strategyInfo[strategy].active) revert StrategyNotActive();
        if (strategyInfo[strategy].allocated > 0) revert StrategyHasAllocation();

        uint256 length = strategies.length;
        for (uint256 i = 0; i < length; i++) {
            if (strategies[i] == strategy) {
                strategies[i] = strategies[length - 1];
                strategies.pop();
                break;
            }
        }
        strategyInfo[strategy].active = false;
        emit StrategyRemoved(strategy);
    }

    function setStrategyAllocation(address strategy, uint256 newAllocation) external onlyOperator nonReentrant {
        if (!strategyInfo[strategy].active) revert StrategyNotActive();

        StrategyInfo storage info = strategyInfo[strategy];
        uint256 current = info.allocated;

        if (newAllocation > current) {
            uint256 increase = newAllocation - current;
            if (token.balanceOf(address(this)) < increase) revert InsufficientLiquidity();
            info.allocated = newAllocation;
            _safeApprove(token, strategy, increase);
            IStrategy(strategy).deposit(increase);
        } else if (newAllocation < current) {
            uint256 decrease = current - newAllocation;
            info.allocated = newAllocation;
            IStrategy(strategy).withdraw(decrease);
        }

        emit StrategyAllocationUpdated(strategy, current, newAllocation);
    }

    function _harvestPending(address user) internal {
        uint256 pending = _pendingYield(user);
        if (pending <= 0) return;

        yieldDebt[user] = (userBalance[user] * accYieldPerShare) / PRECISION;

        uint256 vaultBalance = token.balanceOf(address(this));
        if (vaultBalance < pending) {
            _ensureLiquidity(pending - vaultBalance);
        }

        _safeTransfer(token, user, pending);
        emit YieldClaimed(user, pending);
    }

    function _pendingYield(address user) internal view returns (uint256) {
        return (userBalance[user] * accYieldPerShare) / PRECISION - yieldDebt[user];
    }

    function _distributeYield(uint256 amount) internal {
        if (totalDeposited <= 0) {
            _safeTransfer(token, feeRecipient, amount);
            emit YieldDistributed(amount);
            return;
        }
        accYieldPerShare += (amount * PRECISION) / totalDeposited;
        emit YieldDistributed(amount);
    }

    function _ensureLiquidity(uint256 needed) internal {
        if (needed <= 0) return;
        uint256 stillNeeded = needed;
        uint256 length = strategies.length;
        for (uint256 i = 0; i < length; i++) {
            if (stillNeeded <= 0) break;
            address strat = strategies[i];
            uint256 invested = strategyInfo[strat].allocated;
            if (invested <= 0) continue;
            uint256 toDivest = invested < stillNeeded ? invested : stillNeeded;
            strategyInfo[strat].allocated -= toDivest;
            IStrategy(strat).withdraw(toDivest);
            stillNeeded -= toDivest;
        }
        if (stillNeeded > 0) revert InsufficientLiquidity();
    }

    function pendingYield(address user) external view returns (uint256) {
        return _pendingYield(user);
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function totalAssets() external view returns (uint256) {
        uint256 vaultBalance = token.balanceOf(address(this));
        uint256 allocated;
        uint256 length = strategies.length;
        for (uint256 i = 0; i < length; i++) {
            allocated += strategyInfo[strategies[i]].allocated;
        }
        return vaultBalance + allocated;
    }

    function getStrategies() external view returns (address[] memory) {
        return strategies;
    }
}
