// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    function deposit() external payable;
    function withdraw(uint256 amount) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract LiquidStakingToken {
    string public constant name = "Liquid Staking Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    address public treasury;

    uint256 public constant REDEMPTION_FEE_BPS = 50;           // 0.5%
    uint256 public constant MAX_STRATEGY_ALLOCATION_BPS = 7500; // 75%
    uint256 private constant BPS_DENOMINATOR = 10000;

    address[] public strategyList;
    mapping(address => bool) public isApprovedStrategy;

    event Mint(address indexed account, uint256 etherAmount, uint256 sharesMinted);
    event Redeem(address indexed account, uint256 sharesBurned, uint256 etherReturned, uint256 fee);
    event Rebalance(address indexed fromStrategy, address indexed toStrategy, uint256 amount);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error OnlyOperator();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error StrategyAlreadyApproved();
    error StrategyNotApproved();
    error StrategyNotEmpty();
    error SameStrategy();
    error ExceedsMaxAllocation();
    error InvalidOperator();
    error InvalidTreasury();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(address _operator, address _treasury) {
        if (_operator == address(0)) revert InvalidOperator();
        if (_treasury == address(0)) revert InvalidTreasury();
        operator = _operator;
        treasury = _treasury;
    }

    function totalAssets() public view returns (uint256) {
        uint256 sum = address(this).balance;
        for (uint256 i = 0; i < strategyList.length; i++) {
            sum += IStrategy(strategyList[i]).totalAssets();
        }
        return sum;
    }

    function strategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function deposit() external payable {
        if (msg.value < 1) revert ZeroAmount();

        uint256 shares;
        uint256 _totalSupply = totalSupply;
        uint256 _totalAssets = totalAssets();

        if (_totalSupply < 1 || _totalAssets < 1) {
            shares = msg.value;
        } else {
            shares = (msg.value * _totalSupply) / _totalAssets;
        }

        if (shares < 1) revert ZeroShares();

        _mint(msg.sender, shares);
        emit Mint(msg.sender, msg.value, shares);
    }

    function redeem(uint256 shares) external {
        if (shares < 1) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();

        uint256 _totalAssets = totalAssets();
        uint256 _totalSupply = totalSupply;

        // Compute gross assets from the full product (single division).
        uint256 grossAssets = (shares * _totalAssets) / _totalSupply;
        if (grossAssets < 1) revert ZeroAmount();

        // Compute payout from the full product to avoid divide-before-multiply.
        // payout = shares * totalAssets * (1 - fee) / (totalSupply * BPS_DENOMINATOR)
        uint256 payout = (shares * _totalAssets * (BPS_DENOMINATOR - REDEMPTION_FEE_BPS)) /
            (_totalSupply * BPS_DENOMINATOR);
        uint256 fee = grossAssets - payout;

        // Effects: burn shares before any external interaction.
        _burn(msg.sender, shares);

        // Interactions: ensure enough buffer ETH is available.
        _ensureBufferLiquidity(payout + fee);

        if (fee > 0) {
            (bool okFee, ) = payable(treasury).call{value: fee}("");
            if (!okFee) revert TransferFailed();
        }
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();

        emit Redeem(msg.sender, shares, payout, fee);
    }

    function _ensureBufferLiquidity(uint256 needed) internal {
        uint256 buffer = address(this).balance;
        if (buffer >= needed) return;

        uint256 shortfall = needed - buffer;
        for (uint256 i = 0; i < strategyList.length && shortfall > 0; i++) {
            address strat = strategyList[i];
            uint256 avail = IStrategy(strat).totalAssets();
            if (avail < 1) continue;
            uint256 toWithdraw = shortfall < avail ? shortfall : avail;
            uint256 withdrawn = IStrategy(strat).withdraw(toWithdraw);
            shortfall -= withdrawn;
        }

        if (shortfall > 0) revert InsufficientLiquidity();
    }

    function rebalance(address fromStrategy, address toStrategy, uint256 amount) external onlyOperator {
        if (!isApprovedStrategy[fromStrategy]) revert StrategyNotApproved();
        if (!isApprovedStrategy[toStrategy]) revert StrategyNotApproved();
        if (amount < 1) revert ZeroAmount();
        if (fromStrategy == toStrategy) revert SameStrategy();

        uint256 withdrawn = IStrategy(fromStrategy).withdraw(amount);

        uint256 totalAfter = totalAssets();
        if (totalAfter < 1) revert InsufficientLiquidity();

        uint256 newToAllocation = IStrategy(toStrategy).totalAssets() + withdrawn;
        if ((newToAllocation * BPS_DENOMINATOR) / totalAfter > MAX_STRATEGY_ALLOCATION_BPS) {
            revert ExceedsMaxAllocation();
        }

        IStrategy(toStrategy).deposit{value: withdrawn}();
        emit Rebalance(fromStrategy, toStrategy, withdrawn);
    }

    function allocateToStrategy(address strategy, uint256 amount) external onlyOperator {
        if (!isApprovedStrategy[strategy]) revert StrategyNotApproved();
        if (amount < 1) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientLiquidity();

        uint256 totalAfter = totalAssets() + amount;
        uint256 newAllocation = IStrategy(strategy).totalAssets() + amount;
        if ((newAllocation * BPS_DENOMINATOR) / totalAfter > MAX_STRATEGY_ALLOCATION_BPS) {
            revert ExceedsMaxAllocation();
        }

        IStrategy(strategy).deposit{value: amount}();
        emit Rebalance(address(0), strategy, amount);
    }

    function withdrawFromStrategy(address strategy, uint256 amount) external onlyOperator {
        if (!isApprovedStrategy[strategy]) revert StrategyNotApproved();
        if (amount < 1) revert ZeroAmount();

        uint256 withdrawn = IStrategy(strategy).withdraw(amount);
        emit Rebalance(strategy, address(0), withdrawn);
    }

    function addStrategy(address strategy) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (isApprovedStrategy[strategy]) revert StrategyAlreadyApproved();

        isApprovedStrategy[strategy] = true;
        strategyList.push(strategy);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!isApprovedStrategy[strategy]) revert StrategyNotApproved();
        if (IStrategy(strategy).totalAssets() > 0) revert StrategyNotEmpty();

        isApprovedStrategy[strategy] = false;
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[strategyList.length - 1];
                strategyList.pop();
                break;
            }
        }
        emit StrategyRemoved(strategy);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidOperator();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert InvalidTreasury();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

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
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    receive() external payable {
        // Accepts Ether from strategy withdrawals and donations, increasing share price for holders.
    }
}
