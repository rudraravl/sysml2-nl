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

contract DecentralizedSavings {
    error ErrZeroAddress();
    error ErrUnsupportedToken(address token);
    error ErrDepositExceedsLimit(address user, address token, uint256 current, uint256 limit);
    error ErrInsufficientBalance(address user, address token, uint256 requested, uint256 available);
    error ErrNoYieldToClaim(address user, address token);
    error ErrZeroAmount();
    error ErrTokenAlreadySupported(address token);
    error ErrInvalidFeeRecipient();
    error ErrNotOwner();
    error ErrPaused();
    error ErrNotPaused();
    error ErrTransferFailed();

    event LogDeposit(address indexed user, address indexed token, uint256 amount);
    event LogWithdraw(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event LogYieldClaimed(address indexed user, address indexed token, uint256 amount);
    event LogTokenAdded(address indexed token, uint256 yieldRate);
    event LogTokenParametersUpdated(address indexed token, uint256 newYieldRate);
    event LogFeeRecipientChanged(address indexed newFeeRecipient);
    event LogPaused();
    event LogUnpaused();
    event LogOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MAX_DEPOSIT_PER_TOKEN = 10_000 * 10 ** 18;
    uint256 public constant FEE_BASIS_POINTS = 10;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 private constant PRECISION = 1e18;

    struct TokenConfig {
        bool supported;
        uint256 yieldRate;
        uint256 lastUpdateTime;
        uint256 yieldPerTokenStored;
        uint256 totalDeposits;
    }

    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => mapping(address => uint256)) public deposits;
    mapping(address => mapping(address => uint256)) public yieldDebt;

    address public feeRecipient;
    address public owner;
    bool public paused;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ErrNotPaused();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!tokenConfigs[token].supported) revert ErrUnsupportedToken(token);
        _;
    }

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ErrInvalidFeeRecipient();
        feeRecipient = _feeRecipient;
        owner = msg.sender;
        emit LogOwnershipTransferred(address(0), msg.sender);
    }

    function deposit(address token, uint256 amount) external whenNotPaused onlySupportedToken(token) {
        if (amount == 0) revert ErrZeroAmount();
        _updateYield(token);

        TokenConfig storage config = tokenConfigs[token];
        uint256 newDeposit = deposits[msg.sender][token] + amount;

        if (newDeposit > MAX_DEPOSIT_PER_TOKEN) {
            revert ErrDepositExceedsLimit(msg.sender, token, newDeposit, MAX_DEPOSIT_PER_TOKEN);
        }

        deposits[msg.sender][token] = newDeposit;
        config.totalDeposits += amount;
        yieldDebt[msg.sender][token] = (newDeposit * config.yieldPerTokenStored) / PRECISION;

        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit LogDeposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused onlySupportedToken(token) {
        if (amount == 0) revert ErrZeroAmount();
        _updateYield(token);

        TokenConfig storage config = tokenConfigs[token];
        uint256 userDeposit = deposits[msg.sender][token];

        if (amount > userDeposit) {
            revert ErrInsufficientBalance(msg.sender, token, amount, userDeposit);
        }

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 withdrawAmount = amount - fee;

        deposits[msg.sender][token] = userDeposit - amount;
        config.totalDeposits -= amount;
        yieldDebt[msg.sender][token] = (deposits[msg.sender][token] * config.yieldPerTokenStored) / PRECISION;

        if (fee > 0) {
            _safeTransfer(token, feeRecipient, fee);
        }
        _safeTransfer(token, msg.sender, withdrawAmount);

        emit LogWithdraw(msg.sender, token, amount, fee);
    }

    function claimYield(address token) external whenNotPaused onlySupportedToken(token) {
        _updateYield(token);

        TokenConfig storage config = tokenConfigs[token];
        uint256 userDeposit = deposits[msg.sender][token];
        uint256 pending = (userDeposit * config.yieldPerTokenStored) / PRECISION - yieldDebt[msg.sender][token];

        if (pending == 0) revert ErrNoYieldToClaim(msg.sender, token);

        yieldDebt[msg.sender][token] = (userDeposit * config.yieldPerTokenStored) / PRECISION;
        _safeTransfer(token, msg.sender, pending);

        emit LogYieldClaimed(msg.sender, token, pending);
    }

    function pendingYield(address user, address token) external view onlySupportedToken(token) returns (uint256) {
        TokenConfig storage config = tokenConfigs[token];
        uint256 yieldPerToken = config.yieldPerTokenStored;
        uint256 totalDeposits = config.totalDeposits;

        if (totalDeposits > 0 && config.lastUpdateTime > 0) {
            uint256 timeElapsed = block.timestamp - config.lastUpdateTime;
            uint256 yieldPerTokenIncrease = (config.yieldRate * timeElapsed * PRECISION) / totalDeposits;
            yieldPerToken += yieldPerTokenIncrease;
        }

        return (deposits[user][token] * yieldPerToken) / PRECISION - yieldDebt[user][token];
    }

    function addSupportedToken(address token, uint256 yieldRate) external onlyOwner whenNotPaused {
        if (token == address(0)) revert ErrZeroAddress();
        if (tokenConfigs[token].supported) revert ErrTokenAlreadySupported(token);

        tokenConfigs[token] = TokenConfig({
            supported: true,
            yieldRate: yieldRate,
            lastUpdateTime: block.timestamp,
            yieldPerTokenStored: 0,
            totalDeposits: 0
        });

        emit LogTokenAdded(token, yieldRate);
    }

    function updateTokenYieldRate(address token, uint256 newYieldRate) external onlyOwner onlySupportedToken(token) {
        _updateYield(token);
        tokenConfigs[token].yieldRate = newYieldRate;
        emit LogTokenParametersUpdated(token, newYieldRate);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ErrInvalidFeeRecipient();
        feeRecipient = _feeRecipient;
        emit LogFeeRecipientChanged(_feeRecipient);
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit LogPaused();
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit LogUnpaused();
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit LogOwnershipTransferred(previousOwner, newOwner);
    }

    function _updateYield(address token) internal {
        TokenConfig storage config = tokenConfigs[token];
        if (config.lastUpdateTime == 0) {
            config.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - config.lastUpdateTime;
        if (timeElapsed > 0 && config.totalDeposits > 0) {
            uint256 yieldPerTokenIncrease = (config.yieldRate * timeElapsed * PRECISION) / config.totalDeposits;
            config.yieldPerTokenStored += yieldPerTokenIncrease;
        }
        config.lastUpdateTime = block.timestamp;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ErrTransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ErrTransferFailed();
        }
    }
}
