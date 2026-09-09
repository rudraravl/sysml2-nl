// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ExternalCurrencyBridge {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable externalToken;
    address public operator;
    uint256 public bridgeFeeBps;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public immutable minDeposit;
    bool public paused;

    event Deposit(address indexed user, uint256 amount, uint256 fee, uint256 mintedAmount);
    event Withdrawal(address indexed user, uint256 amount);
    event BridgeFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error NotOperator();
    error BridgePaused();
    error DepositTooSmall(uint256 amount, uint256 minRequired);
    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address owner, address spender, uint256 available, uint256 required);
    error TransferFailed();
    error FeeTooHigh(uint256 feeBps, uint256 maxFeeBps);
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert BridgePaused();
        _;
    }

    constructor(
        address _externalToken,
        address _operator,
        string memory _name,
        string memory _symbol
    ) {
        if (_externalToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        externalToken = IERC20(_externalToken);
        operator = _operator;
        name = _name;
        symbol = _symbol;

        uint8 _decimals = 18;
        try IERC20Metadata(_externalToken).decimals() returns (uint8 d) {
            if (d > 0) _decimals = d;
        } catch {}
        decimals = _decimals;

        bridgeFeeBps = 10;

        if (_decimals >= 3) {
            minDeposit = 10 ** (uint256(_decimals) - 3);
        } else {
            minDeposit = 1;
        }
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount < minDeposit) revert DepositTooSmall(amount, minDeposit);

        uint256 fee = (amount * bridgeFeeBps) / 10000;
        uint256 mintedAmount = amount - fee;

        _safeTransferFrom(address(externalToken), msg.sender, address(this), amount);

        _mint(msg.sender, mintedAmount);

        emit Deposit(msg.sender, amount, fee, mintedAmount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(msg.sender, balanceOf[msg.sender], amount);
        }

        _burn(msg.sender, amount);

        _safeTransfer(address(externalToken), msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setBridgeFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 oldFeeBps = bridgeFeeBps;
        bridgeFeeBps = newFeeBps;
        emit BridgeFeeUpdated(oldFeeBps, newFeeBps);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) {
                revert InsufficientAllowance(from, msg.sender, allowed, amount);
            }
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(from, balanceOf[from], amount);
        }
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
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(from, balanceOf[from], amount);
        }
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
