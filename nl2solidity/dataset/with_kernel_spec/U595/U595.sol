// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, uint256 increase) = _tryApprove(token, spender, value);
        if (!success) {
            revert SafeERC20FailedOperation(address(token));
        }
        if (increase == 0 && value != 0) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function _tryApprove(IERC20 token, address spender, uint256 value) private returns (bool, uint256) {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.approve.selector, spender, value));
        if (success) {
            if (data.length == 0) {
                return (true, 1);
            }
            return (true, abi.decode(data, (uint256)));
        }
        return (false, 0);
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(32, returndata), mload(returndata))
                }
            } else {
                revert SafeERC20FailedOperation(address(token));
            }
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert SafeERC20FailedOperation(address(token));
            }
        }
    }
}

interface ILiquidStakingVault {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 fee);
    event Redeem(address indexed caller, address indexed receiver, address indexed owner, uint256 shares, uint256 assets, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event RebalanceInitiated(address indexed target, uint256 amount);
    event RebalanceCompleted(uint256 amountReturned, uint256 timestamp);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event PausedStateChanged(bool paused);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LiquidStakingVault is ILiquidStakingVault {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant WITHDRAWAL_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant UPDATE_COOLDOWN = 24 hours;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    IERC20 public immutable baseAsset;

    address public owner;
    address public operator;
    address public feeRecipient;
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public exchangeRate;
    uint40 public lastExchangeRateUpdate;

    address public rebalanceTarget;
    bool public rebalancing;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientVaultBalance();
    error NotOperator();
    error NotOwner();
    error UpdateTooSoon();
    error InvalidExchangeRate();
    error ContractPaused();
    error RebalanceInProgress();
    error NoRebalanceInProgress();
    error InvalidRebalanceTarget();
    error ReentrancyGuardReentrantCall();

    uint256 private _reentrancyGuard = 1;

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
        if (_reentrancyGuard != 1) revert ReentrancyGuardReentrantCall();
        _reentrancyGuard = 2;
        _;
        _reentrancyGuard = 1;
    }

    constructor(
        address _baseAsset,
        string memory _name,
        string memory _symbol,
        uint256 _initialExchangeRate,
        address _operator,
        address _feeRecipient
    ) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_initialExchangeRate == 0) revert InvalidExchangeRate();

        baseAsset = IERC20(_baseAsset);
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        exchangeRate = _initialExchangeRate;
        lastExchangeRateUpdate = uint40(block.timestamp);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 allowed = allowance[owner_][spender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[owner_][spender] = allowed - amount;
            }
        }
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (assets == 0) return 0;
        return (assets * PRECISION) / exchangeRate;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (shares == 0) return 0;
        return (shares * exchangeRate) / PRECISION;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        if (assets == 0) return 0;
        return (assets * PRECISION + exchangeRate - 1) / exchangeRate;
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroAmount();

        baseAsset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        shares = (assets * PRECISION + exchangeRate - 1) / exchangeRate;
        if (shares == 0) revert ZeroAmount();

        if (baseAsset.balanceOf(address(this)) < assets) revert InsufficientVaultBalance();

        uint256 fee = (assets * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAssets = assets - fee;

        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }

        _burn(owner_, shares);
        baseAsset.safeTransfer(receiver, netAssets);
        if (fee > 0) {
            baseAsset.safeTransfer(feeRecipient, fee);
        }

        emit Withdraw(msg.sender, receiver, owner_, assets, shares, fee);
    }

    function redeem(uint256 shares, address receiver, address owner_) external nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        assets = convertToAssets(shares);
        if (assets == 0) revert ZeroAmount();

        if (baseAsset.balanceOf(address(this)) < assets) revert InsufficientVaultBalance();

        uint256 fee = (assets * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAssets = assets - fee;

        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }

        _burn(owner_, shares);
        baseAsset.safeTransfer(receiver, netAssets);
        if (fee > 0) {
            baseAsset.safeTransfer(feeRecipient, fee);
        }

        emit Redeem(msg.sender, receiver, owner_, shares, assets, fee);
    }

    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        if (block.timestamp < uint256(lastExchangeRateUpdate) + UPDATE_COOLDOWN) revert UpdateTooSoon();

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        lastExchangeRateUpdate = uint40(block.timestamp);

        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }

    function setRebalanceTarget(address target) external onlyOwner {
        if (target == address(0)) revert ZeroAddress();
        rebalanceTarget = target;
    }

    function initiateRebalance(uint256 amount) external onlyOperator whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (rebalancing) revert RebalanceInProgress();
        address target = rebalanceTarget;
        if (target == address(0)) revert InvalidRebalanceTarget();

        if (baseAsset.balanceOf(address(this)) < amount) revert InsufficientVaultBalance();

        rebalancing = true;
        baseAsset.safeTransfer(target, amount);

        emit RebalanceInitiated(target, amount);
    }

    function completeRebalance(uint256 amountReturned) external onlyOperator {
        if (!rebalancing) revert NoRebalanceInProgress();
        rebalancing = false;
        emit RebalanceCompleted(amountReturned, block.timestamp);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function totalAssets() external view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }
}
