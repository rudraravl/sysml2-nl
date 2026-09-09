// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

error TransferFailed(address token);
error ZeroAddress();
error ZeroAmount();
error InsufficientBalance();
error InvalidReserveIndex();
error NotOperator();
error ThresholdMustBePositive();
error ThresholdCannotDecrease();

contract DeflationaryReserveToken {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed depositor, uint8 indexed reserveIndex, uint256 amountIn, uint256 amountOut);
    event Redeem(address indexed redeemer, uint256 amountBurned, uint256[3] amountsOut);
    event ReserveYieldDistribution(address indexed operator, uint256[3] amountsAdded);
    event CheckpointThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    address public operator;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    IERC20[3] public reserveTokens;
    uint256[3] public reserveBalances;

    uint256 public checkpointThreshold;
    uint256 public constant FEE_BPS = 100; // 1% deflationary fee
    uint256 public constant BPS_DENOMINATOR = 10000;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address[3] memory _reserveTokens, uint256 _initialCheckpointThreshold) {
        if (_initialCheckpointThreshold == 0) revert ThresholdMustBePositive();
        for (uint8 i = 0; i < 3; i++) {
            if (_reserveTokens[i] == address(0)) revert ZeroAddress();
            reserveTokens[i] = IERC20(_reserveTokens[i]);
        }
        checkpointThreshold = _initialCheckpointThreshold;
        operator = msg.sender;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed(address(token));
    }

    function _safeTransferFromSender(IERC20 token, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed(address(token));
    }

    function deposit(uint8 reserveIndex, uint256 amountIn) external {
        if (reserveIndex > 2) revert InvalidReserveIndex();
        if (amountIn == 0) revert ZeroAmount();

        IERC20 token = reserveTokens[reserveIndex];
        uint256 balanceBefore = token.balanceOf(address(this));
        _safeTransferFromSender(token, amountIn);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;

        uint256 amountOut = received;

        totalSupply += amountOut;
        balanceOf[msg.sender] += amountOut;
        reserveBalances[reserveIndex] += received;

        emit Deposit(msg.sender, reserveIndex, received, amountOut);
        emit Transfer(address(0), msg.sender, amountOut);
    }

    function redeem(uint256 amountBurned) external {
        if (amountBurned == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amountBurned) revert InsufficientBalance();
        if (totalSupply < amountBurned) revert InsufficientBalance();

        uint256 supplyBeforeBurn = totalSupply;
        uint256[3] memory amountsOut = [uint256(0), uint256(0), uint256(0)];

        for (uint8 i = 0; i < 3; i++) {
            amountsOut[i] = (amountBurned * reserveBalances[i]) / supplyBeforeBurn;
            if (amountsOut[i] > 0) {
                reserveBalances[i] -= amountsOut[i];
            }
        }

        totalSupply -= amountBurned;
        balanceOf[msg.sender] -= amountBurned;

        for (uint8 i = 0; i < 3; i++) {
            if (amountsOut[i] > 0) {
                _safeTransfer(reserveTokens[i], msg.sender, amountsOut[i]);
            }
        }

        emit Redeem(msg.sender, amountBurned, amountsOut);
        emit Transfer(msg.sender, address(0), amountBurned);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = amount - fee;

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amountAfterFee;
        totalSupply -= fee;

        emit Transfer(msg.sender, to, amountAfterFee);
        if (fee > 0) {
            emit Transfer(msg.sender, address(0), fee);
        }
        return true;
    }

    function distributeYield(uint256[3] calldata amountsAdded) external onlyOperator {
        // Effects: update state before interactions to prevent reentrancy
        for (uint8 i = 0; i < 3; i++) {
            if (amountsAdded[i] > 0) {
                reserveBalances[i] += amountsAdded[i];
            }
        }

        // Interactions: transfer tokens from operator after state is updated
        for (uint8 i = 0; i < 3; i++) {
            if (amountsAdded[i] > 0) {
                _safeTransferFromSender(reserveTokens[i], amountsAdded[i]);
            }
        }

        emit ReserveYieldDistribution(msg.sender, amountsAdded);
    }

    function updateCheckpointThreshold(uint256 newThreshold) external onlyOperator {
        if (newThreshold == 0) revert ThresholdMustBePositive();
        if (newThreshold <= checkpointThreshold) revert ThresholdCannotDecrease();

        uint256 oldThreshold = checkpointThreshold;
        checkpointThreshold = newThreshold;
        emit CheckpointThresholdUpdated(oldThreshold, newThreshold);
    }

    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function getReserveBalances() external view returns (uint256[3] memory) {
        return reserveBalances;
    }
}
