// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AssetFundToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public constant CAP = 1_000_000_000 * 10**18;
    uint256 public totalSupply;

    address public operator;
    bool public paused;
    address public feeCollector;

    uint256 public constant FEE_BASIS_POINTS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeCollectorChanged(address indexed previousFeeCollector, address indexed newFeeCollector);

    error NotOperator();
    error WhenPaused();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error CapExceeded(uint256 requested, uint256 cap);
    error BurnExceedsBalance();

    constructor(
        string memory _name,
        string memory _symbol,
        address _operator,
        address _feeCollector
    ) {
        if (_operator == address(0) || _feeCollector == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        feeCollector = _feeCollector;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeCollector(address newFeeCollector) external onlyOperator {
        if (newFeeCollector == address(0)) revert ZeroAddress();
        emit FeeCollectorChanged(feeCollector, newFeeCollector);
        feeCollector = newFeeCollector;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function computeFee(uint256 amount) public pure returns (uint256 fee) {
        fee = (amount * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 fee = computeFee(amount);
        uint256 net = amount - fee;

        balanceOf[msg.sender] = senderBalance - amount;
        balanceOf[to] += net;
        if (fee > 0) {
            balanceOf[feeCollector] += fee;
            emit Transfer(msg.sender, feeCollector, fee);
        }
        emit Transfer(msg.sender, to, net);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        uint256 fee = computeFee(amount);
        uint256 net = amount - fee;

        allowance[from][msg.sender] = currentAllowance - amount;
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += net;
        if (fee > 0) {
            balanceOf[feeCollector] += fee;
            emit Transfer(from, feeCollector, fee);
        }
        emit Transfer(from, to, net);
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
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 newTotal = totalSupply + amount;
        if (newTotal > CAP) revert CapExceeded(newTotal, CAP);
        totalSupply = newTotal;
        balanceOf[to] += amount;
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external returns (bool) {
        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert BurnExceedsBalance();
        balanceOf[msg.sender] = senderBalance - amount;
        totalSupply -= amount;
        emit Burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }
}
