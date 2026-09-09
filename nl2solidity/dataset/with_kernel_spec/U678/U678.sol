// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WrappedAssetVault {
    // -------- Errors --------
    error ZeroAddress();
    error NotOperator();
    error NotOwner();
    error ContractPaused();
    error AlreadyPaused();
    error AlreadyUnpaused();
    error AmountBelowMinimum();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error StableTransferFailed();
    error StableTransferFromFailed();
    error InvalidFeeBps();
    error InvalidMinimumDeposit();
    error InsufficientReserve();
    error Reentrancy();

    // -------- Events --------
    event Minted(address indexed sender, address indexed recipient, uint256 stableAmount, uint256 wrappedAmount);
    event Redeemed(address indexed sender, address indexed recipient, uint256 wrappedAmount, uint256 stableAmount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event VaultPaused(address indexed operator);
    event VaultUnpaused(address indexed operator);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event MinimumDepositChanged(uint256 oldMinimum, uint256 newMinimum);
    event RedemptionFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);
    event ReserveWithdrawn(address indexed operator, address indexed recipient, uint256 amount);

    // -------- Constants --------
    string public constant name = "Wrapped Stable Asset";
    string public constant symbol = "WSA";
    uint8 public constant decimals = 18;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // -------- State --------
    IERC20 public immutable stablecoin;

    address public owner;
    address public operator;

    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public minimumDeposit;
    uint256 public redemptionFeeBps;

    bool private locked;

    // -------- Modifiers --------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    // -------- Constructor --------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        minimumDeposit = 100 * 10 ** decimals;
        redemptionFeeBps = 50; // 0.5%
    }

    // -------- Mint / Redeem --------

    function mint(uint256 stableAmount, address recipient) external whenNotPaused nonReentrant returns (uint256 wrappedAmount) {
        if (stableAmount == 0) revert ZeroAmount();
        if (stableAmount < minimumDeposit) revert AmountBelowMinimum();
        if (recipient == address(0)) revert ZeroAddress();

        wrappedAmount = stableAmount;

        _safeTransferFrom(stablecoin, msg.sender, address(this), stableAmount);

        totalSupply += wrappedAmount;
        balanceOf[recipient] += wrappedAmount;

        emit Minted(msg.sender, recipient, stableAmount, wrappedAmount);
        emit Transfer(address(0), recipient, wrappedAmount);
    }

    function redeem(uint256 wrappedAmount, address recipient) external whenNotPaused nonReentrant returns (uint256 stableAmount) {
        if (wrappedAmount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < wrappedAmount) revert InsufficientBalance();

        uint256 fee = (wrappedAmount * redemptionFeeBps) / BPS_DENOMINATOR;
        stableAmount = wrappedAmount - fee;

        // Effects
        balanceOf[msg.sender] -= wrappedAmount;
        totalSupply -= wrappedAmount;

        // Interactions
        _safeTransfer(stablecoin, recipient, stableAmount);

        // Fee remains in the reserve, increasing backing for remaining wrapped tokens.
        emit Redeemed(msg.sender, recipient, wrappedAmount, stableAmount, fee);
        emit Transfer(msg.sender, address(0), wrappedAmount);
    }

    // -------- ERC20-style transfers --------

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // -------- Operator functions --------

    function pause() external onlyOperator {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit VaultPaused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert AlreadyUnpaused();
        paused = false;
        emit VaultUnpaused(msg.sender);
    }

    function withdrawReserve(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 reserve = stablecoin.balanceOf(address(this));
        if (reserve < totalSupply) revert InsufficientReserve();
        uint256 excess = reserve - totalSupply;
        if (amount > excess) revert InsufficientReserve();
        _safeTransfer(stablecoin, recipient, amount);
        emit ReserveWithdrawn(msg.sender, recipient, amount);
    }

    function setMinimumDeposit(uint256 newMinimum) external onlyOperator {
        if (newMinimum == 0) revert InvalidMinimumDeposit();
        uint256 old = minimumDeposit;
        minimumDeposit = newMinimum;
        emit MinimumDepositChanged(old, newMinimum);
    }

    function setRedemptionFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFeeBps();
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeChanged(old, newFeeBps);
    }

    // -------- Owner functions --------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }

    // -------- Views --------

    function reserveBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function excessReserve() external view returns (uint256) {
        uint256 reserve = stablecoin.balanceOf(address(this));
        if (reserve < totalSupply) return 0;
        return reserve - totalSupply;
    }

    // -------- Internal --------

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert StableTransferFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert StableTransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert StableTransferFromFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert StableTransferFromFailed();
        }
    }
}
