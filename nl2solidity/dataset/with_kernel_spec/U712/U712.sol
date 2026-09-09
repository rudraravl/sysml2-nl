// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CarbonCreditVault {
    // ---------- Custom errors ----------
    error NotOperator();
    error TokenNotApproved();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DepositBelowMinimum();
    error ZeroAddress();
    error InvalidFee();
    error TransferFailed();
    error Reentrancy();

    // ---------- Events ----------
    event CarbonTokenApproved(address indexed token, string vintage, string projectType, uint256 timestamp);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event Deposited(address indexed token, address indexed depositor, uint256 amount);
    event Redeemed(address indexed token, address indexed redeemer, uint256 amount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------- Structs ----------
    struct CarbonTokenInfo {
        bool approved;
        string vintage;
        string projectType;
        uint256 totalDeposited;
    }

    // ---------- State ----------
    address public operator;
    uint256 public redemptionFeeBps; // basis points, 50 = 0.5%
    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 public constant FEE_DENOMINATOR = 10000;

    string public constant name = "Wrapped Carbon Credit";
    string public constant symbol = "wCC";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => CarbonTokenInfo) public carbonTokenRegistry;

    uint256 private _locked = 1;

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------- Constructor ----------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        redemptionFeeBps = 50; // 0.5%
        emit OperatorUpdated(address(0), _operator);
        emit RedemptionFeeUpdated(0, 50);
    }

    // ---------- Operator functions ----------
    function approveCarbonToken(
        address token,
        string calldata vintage,
        string calldata projectType
    ) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        CarbonTokenInfo storage info = carbonTokenRegistry[token];
        info.approved = true;
        info.vintage = vintage;
        info.projectType = projectType;
        emit CarbonTokenApproved(token, vintage, projectType, block.timestamp);
    }

    function setRedemptionFee(uint256 feeBps) external onlyOperator {
        if (feeBps > FEE_DENOMINATOR) revert InvalidFee();
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = feeBps;
        emit RedemptionFeeUpdated(old, feeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ---------- Deposit ----------
    function deposit(address token, uint256 amount) external nonReentrant returns (uint256 minted) {
        CarbonTokenInfo storage info = carbonTokenRegistry[token];
        if (!info.approved) revert TokenNotApproved();
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();

        uint256 allowed = IERC20(token).allowance(msg.sender, address(this));
        if (allowed < amount) revert InsufficientAllowance();

        // Effects before interactions
        info.totalDeposited += amount;
        minted = amount;
        totalSupply += minted;
        balanceOf[msg.sender] += minted;

        // Interactions
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(token, msg.sender, amount);
        emit Transfer(address(0), msg.sender, minted);
    }

    // ---------- Redeem ----------
    function redeem(address token, uint256 amount) external nonReentrant returns (uint256 net) {
        CarbonTokenInfo storage info = carbonTokenRegistry[token];
        if (!info.approved) revert TokenNotApproved();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * redemptionFeeBps) / FEE_DENOMINATOR;
        net = amount - fee;

        // Effects
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        info.totalDeposited -= amount;

        // Interactions
        if (fee > 0) {
            bool feeOk = IERC20(token).transfer(operator, fee);
            if (!feeOk) revert TransferFailed();
        }
        bool netOk = IERC20(token).transfer(msg.sender, net);
        if (!netOk) revert TransferFailed();

        emit Redeemed(token, msg.sender, amount, fee);
        emit Transfer(msg.sender, address(0), amount);
    }

    // ---------- Wrapped token transfers ----------
    function transfer(address recipient, uint256 amount) external returns (bool) {
        if (recipient == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        if (recipient == address(0)) revert ZeroAddress();
        if (balanceOf[sender] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[sender][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[sender][msg.sender] = allowed - amount;
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    // ---------- Views ----------
    function isCarbonTokenApproved(address token) external view returns (bool) {
        return carbonTokenRegistry[token].approved;
    }

    function getCarbonTokenInfo(address token)
        external
        view
        returns (bool approved, string memory vintage, string memory projectType, uint256 totalDeposited)
    {
        CarbonTokenInfo storage info = carbonTokenRegistry[token];
        return (info.approved, info.vintage, info.projectType, info.totalDeposited);
    }
}
