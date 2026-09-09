// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert("SafeERC20: transferFrom failed");
        }
    }
}

contract YieldBearingStablecoin {
    using SafeERC20 for IERC20;

    // ---------- Metadata ----------
    string public constant name = "Yield Bearing Stablecoin";
    string public constant symbol = "yUSD";
    uint8 public constant decimals = 18;

    // ---------- Constants ----------
    uint256 public constant MAX_DEPOSIT_PER_TX = 10_000 * 10**18; // 10,000 stablecoins
    uint256 public constant FEE_NUMERATOR = 1;
    uint256 public constant FEE_DENOMINATOR = 1000; // 0.1%
    uint256 private constant SCALE = 1e18;

    // ---------- Immutable ----------
    IERC20 public immutable stablecoin;
    address public feeReceiver;

    // ---------- Access control ----------
    address public operator;

    // ---------- Reentrancy guard ----------
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ---------- ERC20 state ----------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------- Profit distribution state ----------
    uint256 public profitRate;            // profit tokens per second distributed across all stakers
    uint256 public periodFinish;          // timestamp when current distribution ends
    uint256 public lastUpdateTime;        // last time profitPerTokenStored was updated
    uint256 public profitPerTokenStored;  // accumulated profit per token (scaled by SCALE)
    mapping(address => uint256) public userProfitPerTokenPaid;
    mapping(address => uint256) public profits; // pending profits per user

    // ---------- Events ----------
    event Deposit(address indexed user, uint256 collateralAmount, uint256 minted);
    event Withdraw(address indexed user, uint256 burned, uint256 returned, uint256 fee);
    event ProfitClaimed(address indexed user, uint256 amount);
    event ProfitRateUpdated(uint256 oldRate, uint256 newRate, uint256 newPeriodFinish);
    event ProfitDistributed(uint256 amount, uint256 duration, uint256 rate);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeReceiverChanged(address indexed previousFeeReceiver, address indexed newFeeReceiver);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ---------- Errors ----------
    error ZeroAddress();
    error AmountZero();
    error ExceedsMaxDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DurationZero();
    error NotOperator();
    error NothingToClaim();
    error Reentrancy();

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------- Constructor ----------
    constructor(address _stablecoin, address _operator, address _feeReceiver) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeReceiver == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        feeReceiver = _feeReceiver;
        _status = _NOT_ENTERED;

        emit OperatorChanged(address(0), _operator);
        emit FeeReceiverChanged(address(0), _feeReceiver);
    }

    // ---------- Admin functions ----------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeReceiver(address newFeeReceiver) external onlyOperator {
        if (newFeeReceiver == address(0)) revert ZeroAddress();
        emit FeeReceiverChanged(feeReceiver, newFeeReceiver);
        feeReceiver = newFeeReceiver;
    }

    // ---------- Profit accrual core ----------
    function lastTimeProfitApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function profitPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return profitPerTokenStored;
        }
        uint256 lastApplicable = lastTimeProfitApplicable();
        if (lastApplicable <= lastUpdateTime) {
            return profitPerTokenStored;
        }
        uint256 elapsed = lastApplicable - lastUpdateTime;
        return profitPerTokenStored + ((profitRate * elapsed) * SCALE) / totalSupply;
    }

    function profitEarned(address account) public view returns (uint256) {
        uint256 perToken = profitPerToken();
        uint256 paid = userProfitPerTokenPaid[account];
        if (perToken <= paid) {
            return profits[account];
        }
        return (balanceOf[account] * (perToken - paid)) / SCALE + profits[account];
    }

    function _updateProfit() internal {
        uint256 currentTime = lastTimeProfitApplicable();
        if (currentTime <= lastUpdateTime) {
            return;
        }
        if (totalSupply == 0 || profitRate == 0) {
            lastUpdateTime = currentTime;
            return;
        }
        uint256 elapsed = currentTime - lastUpdateTime;
        profitPerTokenStored += (profitRate * elapsed * SCALE) / totalSupply;
        lastUpdateTime = currentTime;
    }

    function _settle(address account) internal {
        uint256 perToken = profitPerTokenStored;
        uint256 paid = userProfitPerTokenPaid[account];
        if (perToken > paid) {
            profits[account] += (balanceOf[account] * (perToken - paid)) / SCALE;
        }
        userProfitPerTokenPaid[account] = perToken;
    }

    function updateProfit() external {
        _updateProfit();
    }

    // ---------- Operator: rate / distribution ----------
    function setProfitRate(uint256 newRate, uint256 duration) external onlyOperator {
        if (duration == 0) revert DurationZero();
        _updateProfit();
        uint256 oldRate = profitRate;
        profitRate = newRate;
        periodFinish = block.timestamp + duration;
        lastUpdateTime = block.timestamp;
        emit ProfitRateUpdated(oldRate, newRate, periodFinish);
    }

    function distributeProfit(uint256 amount, uint256 duration) external onlyOperator nonReentrant {
        if (duration == 0) revert DurationZero();
        if (amount == 0) revert AmountZero();

        _updateProfit();

        // Effects: update distribution parameters before the external interaction.
        uint256 newRate = amount / duration;
        uint256 oldRate = profitRate;
        profitRate = newRate;
        periodFinish = block.timestamp + duration;
        lastUpdateTime = block.timestamp;

        // Interaction: pull profit tokens from the operator into the contract.
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit ProfitDistributed(amount, duration, newRate);
        emit ProfitRateUpdated(oldRate, newRate, periodFinish);
    }

    // ---------- User actions ----------
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (amount > MAX_DEPOSIT_PER_TX) revert ExceedsMaxDeposit();

        _updateProfit();
        _settle(msg.sender);

        // Effects: mint yield-bearing tokens before pulling collateral.
        _mint(msg.sender, amount);

        // Interaction: pull stablecoins from the depositor.
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, amount);
    }

    function withdraw(uint256 yieldAmount) external nonReentrant {
        if (yieldAmount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < yieldAmount) revert InsufficientBalance();

        _updateProfit();
        _settle(msg.sender);

        // Effects: burn yield-bearing tokens before returning collateral.
        _burn(msg.sender, yieldAmount);

        uint256 fee = (yieldAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 returned = yieldAmount - fee;

        // Interactions
        if (returned > 0) {
            stablecoin.safeTransfer(msg.sender, returned);
        }
        if (fee > 0) {
            stablecoin.safeTransfer(feeReceiver, fee);
        }

        emit Withdraw(msg.sender, yieldAmount, returned, fee);
    }

    function claimProfit() external nonReentrant {
        _updateProfit();
        _settle(msg.sender);

        uint256 amount = profits[msg.sender];

        // Effects: zero out pending profits before transferring.
        profits[msg.sender] = 0;

        // Avoid dangerous strict equality by checking the positive condition.
        if (amount > 0) {
            // Interaction
            stablecoin.safeTransfer(msg.sender, amount);
            emit ProfitClaimed(msg.sender, amount);
        } else {
            revert NothingToClaim();
        }
    }

    // ---------- ERC20 transfers ----------
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external nonReentrant returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        if (to == address(0)) revert ZeroAddress();

        _updateProfit();
        _settle(from);
        if (from != to) {
            _settle(to);
        }

        // Effects
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
}
