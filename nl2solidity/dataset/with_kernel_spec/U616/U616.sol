// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStaking
 * @notice Users deposit Ether and receive a liquid staking token (LSE) representing
 *         their share of the pooled Ether plus accrued rewards. Withdrawals burn LSE
 *         and return proportional Ether, minus a 0.1% fee, subject to a daily cap.
 */
contract LiquidStaking {
    // ============ ERC20 Metadata ============
    string public constant name = "Liquid Staked Ether";
    string public constant symbol = "LSE";
    uint8 public constant decimals = 18;

    // ============ Constants ============
    uint256 public constant FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_DAILY_WITHDRAWAL = 1000 ether;
    uint256 public constant DAY = 1 days;

    // ============ Access Control ============
    address public owner;
    address public operator;

    // ============ Pool Accounting ============
    uint256 public totalSupply;
    uint256 public totalPooledEther;
    uint256 public rewardRate; // wei per second added to the pool
    uint256 public lastRewardTime;

    // ============ Daily Withdrawal Tracking ============
    uint256 public dailyWithdrawn;
    uint256 public currentDay;

    // ============ Pause State ============
    bool public paused;

    // ============ ERC20 Storage ============
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ Reentrancy Guard ============
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // ============ Events ============
    event Deposit(address indexed caller, address indexed receiver, uint256 etherAmount, uint256 sharesMinted);
    event Withdraw(address indexed caller, uint256 sharesBurned, uint256 etherReturned, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error NotAuthorized();
    error Paused();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DailyWithdrawalCapExceeded();
    error InsufficientContractBalance();
    error ReentrancyDetected();
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(address _operator) payable {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        lastRewardTime = block.timestamp;
        currentDay = block.timestamp / DAY;
        _status = _NOT_ENTERED;

        if (msg.value > 0) {
            totalPooledEther += msg.value;
            uint256 shares = msg.value;
            totalSupply += shares;
            balanceOf[msg.sender] += shares;
            emit Deposit(msg.sender, msg.sender, msg.value, shares);
            emit Transfer(address(0), msg.sender, shares);
        }
    }

    // ============ Internal Helpers ============
    function _pendingRewards() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTime || rewardRate == 0) return 0;
        return rewardRate * (block.timestamp - lastRewardTime);
    }

    function _currentTotalPooledEther() internal view returns (uint256) {
        return totalPooledEther + _pendingRewards();
    }

    function _accrueRewards() internal {
        if (block.timestamp <= lastRewardTime) return;
        uint256 elapsed = block.timestamp - lastRewardTime;
        if (rewardRate > 0) {
            uint256 rewards = rewardRate * elapsed;
            totalPooledEther += rewards;
        }
        lastRewardTime = block.timestamp;
    }

    function _resetDailyIfNeeded() internal {
        uint256 day = block.timestamp / DAY;
        if (day != currentDay) {
            dailyWithdrawn = 0;
            currentDay = day;
        }
    }

    function _getSharesByEtherView(uint256 etherAmount) internal view returns (uint256) {
        uint256 totalEther = _currentTotalPooledEther();
        uint256 supply = totalSupply;
        if (supply <= 0 || totalEther <= 0) {
            return etherAmount;
        }
        return (etherAmount * supply) / totalEther;
    }

    function _getEtherBySharesView(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply <= 0) return 0;
        return (shares * _currentTotalPooledEther()) / supply;
    }

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    // ============ Public View Functions ============
    function getSharesByEther(uint256 etherAmount) public view returns (uint256) {
        return _getSharesByEtherView(etherAmount);
    }

    function getEtherByShares(uint256 shares) public view returns (uint256) {
        return _getEtherBySharesView(shares);
    }

    function exchangeRate() public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply <= 0) return 1e18;
        return (_currentTotalPooledEther() * 1e18) / supply;
    }

    function pendingRewards() external view returns (uint256) {
        return _pendingRewards();
    }

    // ============ Core Functions ============
    function deposit(address receiver) external payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        _accrueRewards();

        uint256 shares;
        uint256 supply = totalSupply;
        uint256 pooled = totalPooledEther;
        if (supply <= 0 || pooled <= 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * supply) / pooled;
        }
        if (shares <= 0) revert ZeroAmount();

        totalPooledEther += msg.value;
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, msg.value, shares);
    }

    function withdraw(uint256 shares) external whenNotPaused nonReentrant {
        if (shares == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();

        _accrueRewards();
        _resetDailyIfNeeded();

        uint256 supply = totalSupply;
        uint256 pooled = totalPooledEther;

        uint256 etherOut;
        uint256 fee;
        if (supply <= 0) {
            etherOut = 0;
            fee = 0;
        } else {
            // Compute etherOut from raw values
            etherOut = (shares * pooled) / supply;
            // Compute fee from raw numerator to avoid divide-before-multiply precision loss
            fee = (shares * pooled * FEE_BPS) / (supply * BPS_DENOMINATOR);
        }
        if (etherOut <= 0) revert ZeroAmount();

        uint256 userOut = etherOut - fee;

        if (dailyWithdrawn + etherOut > MAX_DAILY_WITHDRAWAL) revert DailyWithdrawalCapExceeded();
        if (address(this).balance < etherOut) revert InsufficientContractBalance();

        // Effects
        _burn(msg.sender, shares);
        totalPooledEther -= etherOut;
        dailyWithdrawn += etherOut;

        emit Withdraw(msg.sender, shares, userOut, fee);

        // Interactions
        (bool ok, ) = payable(msg.sender).call{value: userOut}("");
        if (!ok) revert TransferFailed();
    }

    // ============ ERC20 Functions ============
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        allowance[msg.sender][spender] = currentAllowance - subtractedValue;
        emit Approval(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    // ============ Operator Functions ============
    function setRewardRate(uint256 newRate) external onlyOperator nonReentrant {
        _accrueRewards();
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // ============ Owner Functions ============
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ Fallback ============
    receive() external payable {
        // Accept ETH for reward funding
    }
}
