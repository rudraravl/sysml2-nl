// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title PrivateTransferEscrow
 * @dev Facilitates private, wallet-to-wallet transfers of Ether and approved ERC20 tokens
 * using one-time redeemable codes. Deposited assets are held until redemption.
 * A deposit fee of 0.1% is applied, with a minimum deposit amount.
 */
contract PrivateTransferEscrow {
    address public owner;
    address public feeRecipient;
    address public operator;

    uint256 public constant FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 1e15; // 0.001 ether

    struct Deposit {
        address asset;      // address(0) for Ether, otherwise ERC20 token
        uint256 amount;      // redeemable amount after fee
        address depositor;
        bool redeemed;
    }

    mapping(bytes32 => Deposit) private _deposits;
    mapping(address => bool) public approvedTokens;
    // user => asset => pending claimable amount (pull-payment pattern)
    mapping(address => mapping(address => uint256)) private _pending;

    uint256 private _status; // reentrancy guard: 1 = NOT_ENTERED, 2 = ENTERED

    event CodeCreated(bytes32 indexed code, address indexed asset, uint256 amount, address indexed depositor);
    event CodeRedeemed(bytes32 indexed code, address indexed asset, uint256 amount, address indexed redeemer);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event TokenApproved(address indexed token);
    event TokenRevoked(address indexed token);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event FeeCollected(address indexed asset, address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OnlyOperator();
    error OnlyOwner();
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumDeposit();
    error CodeAlreadyExists();
    error CodeNotFound();
    error CodeAlreadyRedeemed();
    error TokenNotApproved();
    error EtherTransferFailed();
    error TokenTransferFailed();
    error ReentrantCall();
    error NothingToWithdraw();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _feeRecipient, address _operator) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        operator = _operator;
        _status = 1;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientChanged(previous, newFeeRecipient);
    }

    function approveToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        approvedTokens[token] = true;
        emit TokenApproved(token);
    }

    function revokeToken(address token) external onlyOperator {
        approvedTokens[token] = false;
        emit TokenRevoked(token);
    }

    function getDeposit(bytes32 code)
        external
        view
        returns (address asset, uint256 amount, address depositor, bool redeemed)
    {
        Deposit storage d = _deposits[code];
        return (d.asset, d.amount, d.depositor, d.redeemed);
    }

    function pendingWithdrawal(address user, address asset) external view returns (uint256) {
        return _pending[user][asset];
    }

    function computeFee(uint256 amount) public pure returns (uint256) {
        return (amount * FEE_BPS) / BPS_DENOMINATOR;
    }

    function depositEther(bytes32 code) external payable nonReentrant returns (uint256) {
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value < MIN_DEPOSIT) revert BelowMinimumDeposit();
        if (_deposits[code].depositor != address(0)) revert CodeAlreadyExists();

        uint256 fee = computeFee(msg.value);
        uint256 redeemable = msg.value - fee;

        // Effects before interactions
        _deposits[code] = Deposit({
            asset: address(0),
            amount: redeemable,
            depositor: msg.sender,
            redeemed: false
        });

        if (fee > 0) {
            (bool ok, ) = payable(feeRecipient).call{value: fee}("");
            if (!ok) revert EtherTransferFailed();
            emit FeeCollected(address(0), feeRecipient, fee);
        }

        emit CodeCreated(code, address(0), redeemable, msg.sender);
        return redeemable;
    }

    function depositToken(bytes32 code, address token, uint256 amount)
        external
        nonReentrant
        returns (uint256)
    {
        if (token == address(0)) revert ZeroAddress();
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();
        if (_deposits[code].depositor != address(0)) revert CodeAlreadyExists();

        uint256 fee = computeFee(amount);
        uint256 redeemable = amount - fee;

        // Effects before interactions: record deposit state first
        _deposits[code] = Deposit({
            asset: token,
            amount: redeemable,
            depositor: msg.sender,
            redeemed: false
        });

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TokenTransferFailed();

        if (fee > 0) {
            bool sent = IERC20(token).transfer(feeRecipient, fee);
            if (!sent) revert TokenTransferFailed();
            emit FeeCollected(token, feeRecipient, fee);
        }

        emit CodeCreated(code, token, redeemable, msg.sender);
        return redeemable;
    }

    function redeem(bytes32 code) external nonReentrant {
        Deposit storage d = _deposits[code];
        if (d.depositor == address(0)) revert CodeNotFound();
        if (d.redeemed) revert CodeAlreadyRedeemed();

        // Effects: mark redeemed and credit the redeemer's pending balance
        d.redeemed = true;
        address asset = d.asset;
        uint256 amount = d.amount;

        _pending[msg.sender][asset] += amount;

        emit CodeRedeemed(code, asset, amount, msg.sender);
    }

    function withdraw(address asset) external nonReentrant {
        uint256 amount = _pending[msg.sender][asset];
        if (amount == 0) revert NothingToWithdraw();

        // Effects before interactions
        _pending[msg.sender][asset] = 0;

        if (asset == address(0)) {
            (bool ok, ) = payable(msg.sender).call{value: amount}("");
            if (!ok) revert EtherTransferFailed();
        } else {
            bool ok = IERC20(asset).transfer(msg.sender, amount);
            if (!ok) revert TokenTransferFailed();
        }

        emit Withdrawn(msg.sender, asset, amount);
    }

    function isCodeValid(bytes32 code) external view returns (bool) {
        Deposit storage d = _deposits[code];
        return (d.depositor != address(0) && !d.redeemed);
    }

    receive() external payable {}
}
