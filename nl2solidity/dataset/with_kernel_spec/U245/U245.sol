// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StablecoinSystem {
    IERC20 public referenceAsset;
    address public operator;

    uint256 public targetReserveRatio; // 1e18 represents 1.0
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public accumulatedFees;
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;

    event Mint(address indexed account, uint256 refAssetAmount, uint256 synthAmount);
    event Burn(address indexed account, uint256 synthAmount, uint256 refAssetPayout, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event ReserveRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event PausedStateChanged(bool paused);
    event FeesClaimed(address indexed to, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error SystemPaused();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidRatio();
    error ZeroAmount();
    error TransferFailed();

    constructor(address _referenceAsset, address _operator) {
        if (_referenceAsset == address(0) || _operator == address(0)) revert ZeroAddress();
        referenceAsset = IERC20(_referenceAsset);
        operator = _operator;
        targetReserveRatio = PRECISION; // 1.0
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (paused) revert SystemPaused();
        _;
    }

    function mint(uint256 refAssetAmount) external notPaused {
        if (refAssetAmount == 0) revert ZeroAmount();

        uint256 synthAmount = (refAssetAmount * PRECISION) / targetReserveRatio;
        if (synthAmount == 0) revert ZeroAmount();

        bool success = referenceAsset.transferFrom(msg.sender, address(this), refAssetAmount);
        if (!success) revert TransferFailed();

        totalSupply += synthAmount;
        balanceOf[msg.sender] += synthAmount;

        emit Transfer(address(0), msg.sender, synthAmount);
        emit Mint(msg.sender, refAssetAmount, synthAmount);
    }

    function burn(uint256 synthAmount) external notPaused {
        if (synthAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < synthAmount) revert InsufficientBalance();

        // Compute the untruncated numerator to avoid divide-before-multiply precision loss
        uint256 numerator = synthAmount * targetReserveRatio;
        uint256 refAssetAmount = numerator / PRECISION;
        // Compute fee from the untruncated numerator, then divide by the combined divisor
        uint256 fee = (numerator * FEE_BPS) / (PRECISION * BPS_DIVISOR);
        uint256 payout = refAssetAmount - fee;

        // Effects: burn synthetic asset and accumulate fees
        balanceOf[msg.sender] -= synthAmount;
        totalSupply -= synthAmount;
        accumulatedFees += fee;

        // Interactions: transfer reference asset to msg.sender
        if (payout > 0) {
            bool success = referenceAsset.transfer(msg.sender, payout);
            if (!success) revert TransferFailed();
        }

        emit Transfer(msg.sender, address(0), synthAmount);
        emit Burn(msg.sender, synthAmount, payout, fee);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
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
        if (to == address(0) || from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function setTargetReserveRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0) revert InvalidRatio();
        uint256 oldRatio = targetReserveRatio;
        targetReserveRatio = newRatio;
        emit ReserveRatioUpdated(oldRatio, newRatio);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function claimFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();

        accumulatedFees = 0;
        bool success = referenceAsset.transfer(to, fees);
        if (!success) revert TransferFailed();

        emit FeesClaimed(to, fees);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }
}
