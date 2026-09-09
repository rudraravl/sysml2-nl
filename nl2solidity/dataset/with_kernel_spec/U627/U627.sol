// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

contract LiquidStakingToken is ReentrancyGuard {
    // ============ Constants ============
    uint256 public constant RATE_SCALE = 1e18;
    uint256 public constant MIN_DEPOSIT = 0.1 ether;

    string public constant name = "Liquid Staked Native";
    string public constant symbol = "lsNATIVE";
    uint8 public constant decimals = 18;

    // ============ State Variables ============
    uint256 public totalSupply;
    uint256 public totalNativeStaked;
    uint256 public totalRewards;
    uint256 public redemptionRate;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public operator;

    // ============ Events ============
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposited(address indexed user, uint256 nativeAmount, uint256 lstAmount);
    event Redeemed(address indexed user, uint256 lstAmount, uint256 nativeAmount);
    event Rebased(uint256 oldRate, uint256 newRate, uint256 rewardsAdded);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error OnlyOwner();
    error OnlyOperator();
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error RateCannotDecrease();
    error InsufficientNativeReserve();
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ============ Constructor ============
    constructor() {
        owner = msg.sender;
        operator = msg.sender;
        redemptionRate = RATE_SCALE;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(address(0), msg.sender);
    }

    // ============ Admin Functions ============
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, newOperator);
        operator = newOperator;
    }

    // ============ Core Staking Functions ============
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();

        uint256 lstAmount = (msg.value * RATE_SCALE) / redemptionRate;
        if (lstAmount == 0) revert ZeroAmount();

        totalNativeStaked += msg.value;
        totalSupply += lstAmount;
        balanceOf[msg.sender] += lstAmount;

        emit Transfer(address(0), msg.sender, lstAmount);
        emit Deposited(msg.sender, msg.value, lstAmount);
    }

    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();

        uint256 nativeAmount = (lstAmount * redemptionRate) / RATE_SCALE;
        if (nativeAmount == 0) revert ZeroAmount();
        if (nativeAmount > address(this).balance) revert InsufficientNativeReserve();

        balanceOf[msg.sender] -= lstAmount;
        totalSupply -= lstAmount;

        (bool success, ) = payable(msg.sender).call{value: nativeAmount}("");
        if (!success) revert TransferFailed();

        emit Transfer(msg.sender, address(0), lstAmount);
        emit Redeemed(msg.sender, lstAmount, nativeAmount);
    }

    function rebase(uint256 newRate) external payable onlyOperator nonReentrant {
        if (newRate < redemptionRate) revert RateCannotDecrease();

        uint256 oldRate = redemptionRate;
        uint256 rewardsAdded = msg.value;

        uint256 requiredNative = (totalSupply * newRate) / RATE_SCALE;
        if (address(this).balance < requiredNative) revert InsufficientNativeReserve();

        redemptionRate = newRate;
        if (rewardsAdded > 0) {
            totalRewards += rewardsAdded;
        }

        emit Rebased(oldRate, newRate, rewardsAdded);
    }

    // ============ ERC20 Transfer Functions ============
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // ============ View Functions ============
    function announce() external view returns (uint256 lstTotalSupply, uint256 currentRedemptionRate) {
        return (totalSupply, redemptionRate);
    }

    function getRedemptionValue(uint256 lstAmount) external view returns (uint256) {
        return (lstAmount * redemptionRate) / RATE_SCALE;
    }

    function nativeReserve() external view returns (uint256) {
        return address(this).balance;
    }

    function requiredNativeBacking() external view returns (uint256) {
        return (totalSupply * redemptionRate) / RATE_SCALE;
    }

    receive() external payable {
        revert("Use deposit() to stake native tokens");
    }
}
