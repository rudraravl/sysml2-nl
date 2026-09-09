// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract SyntheticDollar {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, uint256 amount, uint256 collateralDeposited);
    event Burn(address indexed burner, uint256 amount, uint256 collateralReturned, uint256 fee);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeCollectorChanged(address indexed previousFeeCollector, address indexed newFeeCollector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error WhenNotPaused();
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientCollateral();
    error Undercollateralized();
    error ReentrantCall();

    string public constant name = "Synthetic Dollar";
    string public constant symbol = "sUSD";
    uint8 public constant decimals = 18;
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable collateralToken;
    address public owner;
    address public operator;
    address public feeCollector;
    bool public paused;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _collateralToken, address _operator, address _feeCollector) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();

        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        operator = _operator;
        feeCollector = _feeCollector;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeCollectorChanged(address(0), _feeCollector);
    }

    function transferOwnership(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        if (_feeCollector == address(0)) revert ZeroAddress();
        emit FeeCollectorChanged(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

    function pause() external onlyOperator {
        if (paused) revert WhenPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert WhenNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function totalCollateral() public view returns (uint256) {
        return collateralToken.balanceOf(address(this));
    }

    function collateralizationRatio() external view returns (uint256) {
        uint256 ts = totalSupply;
        return ts > 0 ? (totalCollateral() * BPS_DENOMINATOR) / ts : type(uint256).max;
    }

    function isCollateralized() public view returns (bool) {
        return totalCollateral() >= totalSupply;
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

    function mint(uint256 amount) external whenNotPaused nonReentrant returns (uint256 minted) {
        if (amount == 0) revert ZeroAmount();

        if (totalSupply > 0 && totalCollateral() < totalSupply) {
            revert Undercollateralized();
        }

        minted = amount;

        _mint(msg.sender, minted);

        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit Mint(msg.sender, minted, amount);
    }

    function burn(uint256 amount) external nonReentrant returns (uint256 returned) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        returned = amount - fee;

        if (totalCollateral() < amount) revert InsufficientCollateral();

        _burn(msg.sender, amount);

        if (returned > 0) {
            if (!collateralToken.transfer(msg.sender, returned)) revert TransferFailed();
        }

        if (fee > 0) {
            if (!collateralToken.transfer(feeCollector, fee)) revert TransferFailed();
        }

        emit Burn(msg.sender, amount, returned, fee);
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }
}
