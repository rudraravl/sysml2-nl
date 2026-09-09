// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBaseAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WrappedAsset {
    error Paused();
    error NotOperator();
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error DepositExceedsMax(uint256 amount, uint256 maxAmount);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error InsufficientReserve(uint256 available, uint256 required);
    error TransferFailed();
    error DepositFailed();
    error ReentrantCall();

    event Mint(address indexed minter, address indexed to, uint256 baseAmount, uint256 wrappedAmount);
    event Redeem(address indexed redeemer, address indexed to, uint256 wrappedAmount, uint256 baseAmount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event PausedStateChanged(bool isPaused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event TotalSupplyChanged(uint256 newTotalSupply);

    uint256 public constant MAX_DEPOSIT_BASE_UNITS = 100;
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant WRAPPED_DECIMALS = 18;

    string public name;
    string public symbol;
    uint8 public immutable baseDecimals;
    IBaseAsset public immutable baseAsset;
    uint256 public immutable maxDepositPerMint;

    address public owner;
    address public operator;
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _baseAsset,
        string memory _name,
        string memory _symbol,
        address _operator
    ) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        baseAsset = IBaseAsset(_baseAsset);
        baseDecimals = IBaseAsset(_baseAsset).decimals();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        owner = msg.sender;
        paused = false;
        maxDepositPerMint = MAX_DEPOSIT_BASE_UNITS * (10 ** uint256(baseDecimals));

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit PausedStateChanged(false);
    }

    function decimals() external pure returns (uint8) {
        return WRAPPED_DECIMALS;
    }

    function totalReserve() external view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }

    function mint(address to, uint256 baseAmount) external nonReentrant whenNotPaused returns (uint256 wrappedAmount) {
        if (to == address(0)) revert ZeroAddress();
        if (baseAmount == 0) revert ZeroAmount();
        if (baseAmount > maxDepositPerMint) revert DepositExceedsMax(baseAmount, maxDepositPerMint);

        _safeTransferFrom(baseAsset, msg.sender, address(this), baseAmount);

        wrappedAmount = _normalizeToWrapped(baseAmount);

        _mint(to, wrappedAmount);

        emit Mint(msg.sender, to, baseAmount, wrappedAmount);
    }

    function redeem(address to, uint256 wrappedAmount) external nonReentrant whenNotPaused returns (uint256 baseAmount) {
        if (to == address(0)) revert ZeroAddress();
        if (wrappedAmount == 0) revert ZeroAmount();

        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < wrappedAmount) revert InsufficientBalance(senderBalance, wrappedAmount);

        uint256 grossBase = _denormalizeFromWrapped(wrappedAmount);
        uint256 fee = (grossBase * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        baseAmount = grossBase - fee;

        _burn(msg.sender, wrappedAmount);

        _safeTransfer(baseAsset, to, baseAmount);

        emit Redeem(msg.sender, to, wrappedAmount, baseAmount, fee);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
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
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function setPaused(bool isPaused) external onlyOperator {
        paused = isPaused;
        emit PausedStateChanged(isPaused);
    }

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
        emit OwnershipTransferred(old, newOwner);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit TotalSupplyChanged(totalSupply);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance(balance, amount);
        totalSupply -= amount;
        balanceOf[from] = balance - amount;
        emit Transfer(from, address(0), amount);
        emit TotalSupplyChanged(totalSupply);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance(fromBal, amount);
        balanceOf[from] = fromBal - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _safeTransfer(IBaseAsset token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IBaseAsset.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length >= 32 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IBaseAsset token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IBaseAsset.transferFrom.selector, from, to, amount)
        );
        if (!success) revert DepositFailed();
        if (data.length >= 32 && !abi.decode(data, (bool))) revert DepositFailed();
    }

    function _normalizeToWrapped(uint256 baseAmount) internal view returns (uint256) {
        if (baseDecimals == WRAPPED_DECIMALS) {
            return baseAmount;
        } else if (baseDecimals > WRAPPED_DECIMALS) {
            return baseAmount / (10 ** (uint256(baseDecimals) - uint256(WRAPPED_DECIMALS)));
        } else {
            return baseAmount * (10 ** (uint256(WRAPPED_DECIMALS) - uint256(baseDecimals)));
        }
    }

    function _denormalizeFromWrapped(uint256 wrappedAmount) internal view returns (uint256) {
        if (baseDecimals == WRAPPED_DECIMALS) {
            return wrappedAmount;
        } else if (baseDecimals > WRAPPED_DECIMALS) {
            return wrappedAmount * (10 ** (uint256(baseDecimals) - uint256(WRAPPED_DECIMALS)));
        } else {
            return wrappedAmount / (10 ** (uint256(WRAPPED_DECIMALS) - uint256(baseDecimals)));
        }
    }
}
