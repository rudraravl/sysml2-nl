// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IExternalAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AssetBridge {
    error ContractPaused();
    error NotOperator();
    error ZeroAddress();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidFee();
    error InvalidMinDeposit();
    error TransferFailed();
    error ZeroAmount();

    event Deposit(address indexed user, uint256 assetAmount, uint256 mintedAmount, uint256 fee);
    event Withdraw(address indexed user, uint256 burnedAmount, uint256 assetAmount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event MinDepositUpdated(uint256 oldMin, uint256 newMin);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    IExternalAsset public immutable asset;
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public operator;
    bool public paused;

    uint256 public feeRate;
    uint256 public minDeposit;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public depositedAssets;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _operator
    ) {
        if (_asset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        asset = IExternalAsset(_asset);
        name = _name;
        symbol = _symbol;
        operator = _operator;
        feeRate = 50;
        minDeposit = 10 ** 16;
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (amount < minDeposit) revert DepositTooSmall();

        uint256 fee = (amount * feeRate) / 10000;
        uint256 net = amount - fee;

        if (!asset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        depositedAssets[msg.sender] += amount;
        _mint(msg.sender, net);

        emit Deposit(msg.sender, amount, net, fee);
    }

    function redeem(uint256 tokenAmount) external whenNotPaused {
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        _burn(msg.sender, tokenAmount);

        if (!asset.transfer(msg.sender, tokenAmount)) revert TransferFailed();

        emit Withdraw(msg.sender, tokenAmount, tokenAmount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                _approve(from, msg.sender, allowed - amount);
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function setFee(uint256 newFee) external onlyOperator {
        if (newFee > 10000) revert InvalidFee();
        emit FeeUpdated(feeRate, newFee);
        feeRate = newFee;
    }

    function setMinDeposit(uint256 newMin) external onlyOperator {
        if (newMin == 0) revert InvalidMinDeposit();
        emit MinDepositUpdated(minDeposit, newMin);
        minDeposit = newMin;
    }

    function pause() external onlyOperator {
        if (paused) revert ContractPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert ContractPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
