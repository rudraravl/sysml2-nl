// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDepositAddressGenerator {
    function generateDepositAddress(address user) external view returns (string memory);
}

error ZeroAddress();
error AmountBelowMinimum();
error InsufficientBalance();
error InsufficientAllowance();
error AllowanceBelowZero();
error ContractPaused();
error NotAuthorized();
error EmptyDepositAddress();
error InvalidGenerator();
error NoPendingRedemption();
error AlreadyPaused();
error NotPaused();

contract BitcoinBridge {
    string public constant name = "Wrapped Bitcoin";
    string public constant symbol = "wBTC";
    uint8 public constant decimals = 8;

    uint256 public constant MIN_AMOUNT = 10_000; // 0.0001 BTC in satoshis
    uint256 public constant FEE_NUMERATOR = 10; // 0.1%
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 internal constant UINT256_MAX = type(uint256).max;
    address internal constant ZERO_ADDRESS = address(0);

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public owner;
    address public operator;
    bool public paused;

    IDepositAddressGenerator public depositAddressGenerator;

    struct Redemption {
        uint256 amount;
        uint256 fee;
        string btcAddress;
        bool processed;
    }

    mapping(address => Redemption[]) public redemptions;
    mapping(address => uint256) public pendingRedemptionCount;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount, string btcTxId);
    event RedemptionRequested(
        address indexed user,
        uint256 indexed redemptionId,
        uint256 amount,
        uint256 fee,
        string btcAddress
    );
    event RedemptionProcessed(address indexed user, uint256 indexed redemptionId, string btcTxId);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DepositAddressGeneratorUpdated(address indexed previousGenerator, address indexed newGenerator);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier onlyOperatorOrOwner() {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _operator, address _depositAddressGenerator) {
        if (_operator == ZERO_ADDRESS) revert ZeroAddress();
        if (_depositAddressGenerator == ZERO_ADDRESS) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        depositAddressGenerator = IDepositAddressGenerator(_depositAddressGenerator);
        emit OwnershipTransferred(ZERO_ADDRESS, msg.sender);
        emit OperatorUpdated(ZERO_ADDRESS, _operator);
        emit DepositAddressGeneratorUpdated(ZERO_ADDRESS, _depositAddressGenerator);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return _allowances[account][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != UINT256_MAX) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            _allowances[from][msg.sender] = currentAllowance - amount;
            emit Approval(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance > UINT256_MAX - addedValue) {
            _approve(msg.sender, spender, UINT256_MAX);
        } else {
            _approve(msg.sender, spender, currentAllowance + addedValue);
        }
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert AllowanceBelowZero();
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function getDepositAddress(address user) external view returns (string memory) {
        if (user == ZERO_ADDRESS) revert ZeroAddress();
        return depositAddressGenerator.generateDepositAddress(user);
    }

    function mint(address to, uint256 amount, string calldata btcTxId) external whenNotPaused onlyOperator {
        if (to == ZERO_ADDRESS) revert ZeroAddress();
        if (amount < MIN_AMOUNT) revert AmountBelowMinimum();
        if (bytes(btcTxId).length == 0) revert EmptyDepositAddress();

        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(ZERO_ADDRESS, to, amount);
        emit Mint(to, amount, btcTxId);
    }

    function redeem(uint256 amount, string calldata btcAddress) external whenNotPaused returns (uint256) {
        if (amount < MIN_AMOUNT) revert AmountBelowMinimum();
        if (bytes(btcAddress).length == 0) revert EmptyDepositAddress();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, ZERO_ADDRESS, amount);

        uint256 redemptionId = redemptions[msg.sender].length;
        redemptions[msg.sender].push(
            Redemption({
                amount: netAmount,
                fee: fee,
                btcAddress: btcAddress,
                processed: false
            })
        );
        pendingRedemptionCount[msg.sender] += 1;

        emit RedemptionRequested(msg.sender, redemptionId, netAmount, fee, btcAddress);
        return redemptionId;
    }

    function processRedemption(address user, uint256 redemptionId, string calldata btcTxId) external onlyOperator {
        if (redemptionId >= redemptions[user].length) revert NoPendingRedemption();
        Redemption storage r = redemptions[user][redemptionId];
        if (r.processed) revert NoPendingRedemption();
        if (bytes(btcTxId).length == 0) revert EmptyDepositAddress();

        r.processed = true;
        pendingRedemptionCount[user] -= 1;
        emit RedemptionProcessed(user, redemptionId, btcTxId);
    }

    function getRedemption(address user, uint256 redemptionId)
        external
        view
        returns (uint256 amount, uint256 fee, string memory btcAddress, bool processed)
    {
        if (redemptionId >= redemptions[user].length) revert NoPendingRedemption();
        Redemption storage r = redemptions[user][redemptionId];
        return (r.amount, r.fee, r.btcAddress, r.processed);
    }

    function pause() external onlyOperatorOrOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperatorOrOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function updateDepositAddressGenerator(address newGenerator) external onlyOperator {
        if (newGenerator == ZERO_ADDRESS) revert ZeroAddress();
        if (newGenerator.code.length == 0) revert InvalidGenerator();
        address previous = address(depositAddressGenerator);
        depositAddressGenerator = IDepositAddressGenerator(newGenerator);
        emit DepositAddressGeneratorUpdated(previous, newGenerator);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == ZERO_ADDRESS) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == ZERO_ADDRESS) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == ZERO_ADDRESS || to == ZERO_ADDRESS) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address account, address spender, uint256 amount) internal {
        if (account == ZERO_ADDRESS || spender == ZERO_ADDRESS) revert ZeroAddress();
        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }
}
