// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    error ZeroAddress();
    error NotOwner();
    error EnforcedPause();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidRate();
    error TransferFailed();
    error ReentrantCall();
    error NoEthToRescue();

    event Deposited(address indexed user, uint256 baseAmount, uint256 lstAmount);
    event Withdrawn(address indexed user, uint256 lstAmount, uint256 baseAmount, uint256 fee);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesClaimed(address indexed owner, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event EthRescued(address indexed owner, uint256 amount);

    IERC20 public immutable baseAsset;
    string public constant name = "Liquid Staked Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant FEE_BPS = 50; // 0.5%
    uint256 private constant RATE_PRECISION = 1e18;
    uint256 public constant MIN_DEPOSIT = 1e17; // 0.1 units (18 decimals)

    address public owner;
    bool public paused;
    bool public initialized;

    uint256 public totalSupply;
    uint256 public totalStaked;
    uint256 public accumulatedFees;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public rewardRateBps;
    uint256 public lastRewardTime;

    uint256 private constant _UNLOCKED = 1;
    uint256 private constant _LOCKED = 2;
    uint256 private _status = _UNLOCKED;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == _LOCKED) revert ReentrantCall();
        _status = _LOCKED;
        _;
        _status = _UNLOCKED;
    }

    constructor(address _baseAsset, uint256 _initialRewardRateBps) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_initialRewardRateBps > BASIS_POINTS) revert InvalidRate();
        baseAsset = IERC20(_baseAsset);
        owner = msg.sender;
        rewardRateBps = _initialRewardRateBps;
        lastRewardTime = block.timestamp;
        emit OwnershipTransferred(address(0), msg.sender);
        emit RewardRateUpdated(0, _initialRewardRateBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function pause() external onlyOwner {
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit PausedStateChanged(false);
    }

    function setRewardRate(uint256 _newRateBps) external onlyOwner {
        if (_newRateBps > BASIS_POINTS) revert InvalidRate();
        _updateRewards();
        emit RewardRateUpdated(rewardRateBps, _newRateBps);
        rewardRateBps = _newRateBps;
    }

    function exchangeRate() public view returns (uint256) {
        if (!initialized) return RATE_PRECISION;
        uint256 elapsed = block.timestamp > lastRewardTime ? block.timestamp - lastRewardTime : 0;
        uint256 accrued = (totalStaked * rewardRateBps * elapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        return ((totalStaked + accrued) * RATE_PRECISION) / totalSupply;
    }

    function _updateRewards() internal {
        if (block.timestamp <= lastRewardTime) return;
        uint256 elapsed = block.timestamp - lastRewardTime;
        uint256 accrued = (totalStaked * rewardRateBps * elapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        if (accrued > 0) {
            totalStaked += accrued;
        }
        lastRewardTime = block.timestamp;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();
        _updateRewards();

        uint256 lstAmount;
        if (!initialized) {
            lstAmount = amount;
            initialized = true;
        } else {
            uint256 rate = exchangeRate();
            lstAmount = (amount * RATE_PRECISION) / rate;
        }

        totalStaked += amount;
        totalSupply += lstAmount;
        balanceOf[msg.sender] += lstAmount;

        _safeTransferFrom(baseAsset, msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount, lstAmount);
    }

    function withdraw(uint256 lstAmount) external whenNotPaused nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();
        _updateRewards();

        uint256 rate = exchangeRate();
        // Compute fee with full precision to avoid divide-before-multiply rounding loss
        uint256 fee = (lstAmount * rate * FEE_BPS) / (RATE_PRECISION * BASIS_POINTS);
        uint256 baseAmount = (lstAmount * rate) / RATE_PRECISION;
        uint256 payout = baseAmount - fee;

        balanceOf[msg.sender] -= lstAmount;
        totalSupply -= lstAmount;
        totalStaked -= baseAmount;
        accumulatedFees += fee;

        _safeTransfer(baseAsset, msg.sender, payout);

        emit Withdrawn(msg.sender, lstAmount, payout, fee);
    }

    function claimFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        _safeTransfer(baseAsset, owner, amount);
        emit FeesClaimed(owner, amount);
    }

    function rescueETH() external onlyOwner nonReentrant {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) revert NoEthToRescue();
        (bool success, ) = payable(owner).call{value: ethBalance}("");
        if (!success) revert TransferFailed();
        emit EthRescued(owner, ethBalance);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    receive() external payable {
        revert("No ETH deposits");
    }
}
