// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract SyntheticDollarVault {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientStakedBalance();
    error InsufficientAllowance();
    error InsufficientCollateral();
    error RatioTooLow();
    error NotOperator();
    error TransferFailed();
    error Undercollateralized();

    event Mint(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 collateralDeposited
    );
    event Burn(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 collateralReturned
    );
    event Stake(address indexed sender, address indexed recipient, uint256 amount);
    event Unstake(
        address indexed sender,
        address indexed recipient,
        uint256 stakedAmount,
        uint256 returnedAmount,
        uint256 fee
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event RebalanceInitiated(address indexed operator, address indexed target, uint256 collateralAmount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MIN_COLLATERALIZATION_RATIO = 1.05e18;
    uint256 public constant UNSTAKE_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRECISION = 1e18;

    IERC20 public immutable collateralToken;
    address public operator;

    uint256 public totalSupply;
    uint256 public totalStaked;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public stakedBalanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public collateralizationRatio;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _collateralToken) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = msg.sender;
        collateralizationRatio = MIN_COLLATERALIZATION_RATIO;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_COLLATERALIZATION_RATIO) revert RatioTooLow();
        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        if (collateralBalance < (totalSupply * newRatio) / PRECISION) revert Undercollateralized();
        emit CollateralizationRatioUpdated(collateralizationRatio, newRatio);
        collateralizationRatio = newRatio;
    }

    function mint(address recipient, uint256 collateralAmount) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (collateralAmount == 0) revert ZeroAmount();

        uint256 synthToMint = (collateralAmount * PRECISION) / collateralizationRatio;
        if (synthToMint == 0) revert ZeroAmount();

        _safeTransferFrom(collateralToken, msg.sender, address(this), collateralAmount);

        totalSupply += synthToMint;
        balanceOf[recipient] += synthToMint;

        emit Transfer(address(0), recipient, synthToMint);
        emit Mint(msg.sender, recipient, synthToMint, collateralAmount);
    }

    function burn(uint256 synthAmount) external {
        if (synthAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < synthAmount) revert InsufficientBalance();

        uint256 collateralToReturn = (synthAmount * collateralizationRatio) / PRECISION;
        if (collateralToken.balanceOf(address(this)) < collateralToReturn) revert InsufficientCollateral();

        balanceOf[msg.sender] -= synthAmount;
        totalSupply -= synthAmount;

        _safeTransfer(collateralToken, msg.sender, collateralToReturn);

        emit Transfer(msg.sender, address(0), synthAmount);
        emit Burn(msg.sender, msg.sender, synthAmount, collateralToReturn);
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
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        stakedBalanceOf[msg.sender] += amount;
        totalStaked += amount;

        emit Stake(msg.sender, msg.sender, amount);
    }

    function unstake(uint256 stakedAmount) external {
        if (stakedAmount == 0) revert ZeroAmount();
        if (stakedBalanceOf[msg.sender] < stakedAmount) revert InsufficientStakedBalance();

        uint256 fee = (stakedAmount * UNSTAKE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 returned = stakedAmount - fee;

        stakedBalanceOf[msg.sender] -= stakedAmount;
        totalStaked -= stakedAmount;
        balanceOf[msg.sender] += returned;

        if (fee > 0) {
            totalSupply -= fee;
            emit Transfer(msg.sender, address(0), fee);
        }

        emit Unstake(msg.sender, msg.sender, stakedAmount, returned, fee);
    }

    function rebalance(address target, uint256 collateralAmount) external onlyOperator {
        if (target == address(0)) revert ZeroAddress();
        if (collateralAmount == 0) revert ZeroAmount();

        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        uint256 requiredCollateral = (totalSupply * collateralizationRatio) / PRECISION;
        if (collateralBalance < requiredCollateral) revert Undercollateralized();
        if (collateralBalance - requiredCollateral < collateralAmount) revert Undercollateralized();

        _safeTransfer(collateralToken, target, collateralAmount);
        emit RebalanceInitiated(operator, target, collateralAmount);
    }

    function getCollateralizationRatio() external view returns (uint256) {
        if (totalSupply == 0) return 0;
        return (collateralToken.balanceOf(address(this)) * PRECISION) / totalSupply;
    }

    function getCollateralBalance() external view returns (uint256) {
        return collateralToken.balanceOf(address(this));
    }

    function previewMint(uint256 collateralAmount) external view returns (uint256) {
        return (collateralAmount * PRECISION) / collateralizationRatio;
    }

    function previewBurn(uint256 synthAmount) external view returns (uint256) {
        return (synthAmount * collateralizationRatio) / PRECISION;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
