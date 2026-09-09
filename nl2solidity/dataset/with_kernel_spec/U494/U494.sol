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

contract TreasuryBillVault {
    string public constant name = "Tokenized U.S. Treasury Bills";
    string public constant symbol = "tBills";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable stablecoin;
    bool public paused;
    uint256 public redemptionFeeBps;

    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;

    address public owner;
    address public operator;
    address public authorizedImplementation;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed depositor, uint256 stablecoinAmount, uint256 billsMinted);
    event Redeem(address indexed redeemer, uint256 billsBurned, uint256 stablecoinReturned, uint256 feeCollected);
    event RedemptionFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event UpgradeAuthorized(address indexed oldImplementation, address indexed newImplementation);

    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error DepositBelowMinimum();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();
    error ZeroAmount();
    error FeeExceedsMax();
    error StablecoinTransferFailed();
    error StablecoinTransferFromFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = msg.sender;
        redemptionFeeBps = 10;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _approve(msg.sender, spender, allowance[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        allowance[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = stablecoin.transferFrom(from, to, amount);
        if (!success) revert StablecoinTransferFromFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool success = stablecoin.transfer(to, amount);
        if (!success) revert StablecoinTransferFailed();
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();

        _safeTransferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);

        emit Deposit(msg.sender, amount, amount);
    }

    function redeem(uint256 billAmount) external whenNotPaused {
        if (billAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < billAmount) revert InsufficientBalance();

        uint256 fee = (billAmount * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 payout = billAmount - fee;

        _burn(msg.sender, billAmount);

        if (payout > 0) {
            _safeTransfer(msg.sender, payout);
        }

        if (fee > 0) {
            _safeTransfer(operator, fee);
        }

        emit Redeem(msg.sender, billAmount, payout, fee);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeChanged(oldFee, newFeeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address oldImpl = authorizedImplementation;
        authorizedImplementation = newImplementation;
        emit UpgradeAuthorized(oldImpl, newImplementation);
    }

    function getRedemptionOutput(uint256 billAmount) external view returns (uint256 payout, uint256 fee) {
        fee = (billAmount * redemptionFeeBps) / BPS_DENOMINATOR;
        payout = billAmount - fee;
    }
}
