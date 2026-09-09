// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    error ZeroAmount();
    error ZeroAddress();
    error NotOperator();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error RateMustIncrease();
    error PendingWithdrawalExists();
    error NoPendingWithdrawal();
    error UnbondingNotComplete();
    error FeeTooHigh();
    error TransferFailed();
    error ReentrantCall();

    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant BIPS_DENOM = 10000;
    uint256 public constant MAX_FEE_BPS = 2000;
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint8 public constant decimals = 18;

    string public name;
    string public symbol;

    IERC20 public immutable underlying;
    address public operator;
    address public feeRecipient;

    uint256 public stakingFeeBps;
    uint256 public exchangeRate;
    uint256 public totalStaked;
    uint256 public totalPendingUnderlying;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct WithdrawalRequest {
        uint256 underlyingAmount;
        uint256 unlockTime;
    }
    mapping(address => WithdrawalRequest) public pendingWithdrawals;

    bool private _locked;

    event Deposit(address indexed user, uint256 underlyingAmount, uint256 lstAmount);
    event WithdrawalRequested(address indexed user, uint256 underlyingAmount, uint256 lstAmount, uint256 unlockTime);
    event WithdrawalClaimed(address indexed user, uint256 underlyingAmount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 feeShares);
    event StakingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _underlying,
        address _operator,
        address _feeRecipient,
        string memory _name,
        string memory _symbol
    ) {
        if (_underlying == address(0) || _operator == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        underlying = IERC20(_underlying);
        operator = _operator;
        feeRecipient = _feeRecipient;
        name = _name;
        symbol = _symbol;
        exchangeRate = RATE_PRECISION;
        stakingFeeBps = 1000;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    function deposit(uint256 underlyingAmount) external nonReentrant {
        if (underlyingAmount == 0) revert ZeroAmount();
        uint256 lstAmount = (underlyingAmount * RATE_PRECISION) / exchangeRate;
        if (lstAmount == 0) revert ZeroAmount();
        _safeTransferFrom(address(underlying), msg.sender, address(this), underlyingAmount);
        _mint(msg.sender, lstAmount);
        totalStaked += underlyingAmount;
        emit Deposit(msg.sender, underlyingAmount, lstAmount);
    }

    function withdraw(uint256 underlyingAmount) external nonReentrant {
        if (underlyingAmount == 0) revert ZeroAmount();
        if (pendingWithdrawals[msg.sender].unlockTime != 0) revert PendingWithdrawalExists();
        uint256 lstAmount = (underlyingAmount * RATE_PRECISION + exchangeRate - 1) / exchangeRate;
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();
        if (totalStaked < underlyingAmount) revert InsufficientLiquidity();
        _burn(msg.sender, lstAmount);
        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        pendingWithdrawals[msg.sender] = WithdrawalRequest({
            underlyingAmount: underlyingAmount,
            unlockTime: unlockTime
        });
        totalPendingUnderlying += underlyingAmount;
        totalStaked -= underlyingAmount;
        emit WithdrawalRequested(msg.sender, underlyingAmount, lstAmount, unlockTime);
    }

    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (pendingWithdrawals[msg.sender].unlockTime != 0) revert PendingWithdrawalExists();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();
        uint256 underlyingAmount = (lstAmount * exchangeRate) / RATE_PRECISION;
        if (underlyingAmount == 0) revert ZeroAmount();
        if (totalStaked < underlyingAmount) revert InsufficientLiquidity();
        _burn(msg.sender, lstAmount);
        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        pendingWithdrawals[msg.sender] = WithdrawalRequest({
            underlyingAmount: underlyingAmount,
            unlockTime: unlockTime
        });
        totalPendingUnderlying += underlyingAmount;
        totalStaked -= underlyingAmount;
        emit WithdrawalRequested(msg.sender, underlyingAmount, lstAmount, unlockTime);
    }

    function claimWithdraw() external nonReentrant {
        WithdrawalRequest storage req = pendingWithdrawals[msg.sender];
        if (req.unlockTime == 0) revert NoPendingWithdrawal();
        if (block.timestamp < req.unlockTime) revert UnbondingNotComplete();
        uint256 amount = req.underlyingAmount;
        delete pendingWithdrawals[msg.sender];
        totalPendingUnderlying -= amount;
        _safeTransfer(address(underlying), msg.sender, amount);
        emit WithdrawalClaimed(msg.sender, amount);
    }

    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate <= exchangeRate) revert RateMustIncrease();
        uint256 oldRate = exchangeRate;
        uint256 rateDelta = newRate - oldRate;
        uint256 feeShares = 0;
        if (totalSupply > 0) {
            // Compute fee shares with all multiplications before divisions to avoid
            // divide-before-multiply precision loss.
            // feeShares = (rateDelta * totalSupply * stakingFeeBps) / (BIPS_DENOM * newRate)
            feeShares = (rateDelta * totalSupply * stakingFeeBps) / (BIPS_DENOM * newRate);
            if (feeShares > 0) {
                _mint(feeRecipient, feeShares);
            }
        }
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate, feeShares);
    }

    function setStakingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFee = stakingFeeBps;
        stakingFeeBps = newFeeBps;
        emit StakingFeeUpdated(oldFee, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function getUnderlyingValue(address user) external view returns (uint256) {
        return (balanceOf[user] * exchangeRate) / RATE_PRECISION;
    }

    function previewDeposit(uint256 underlyingAmount) external view returns (uint256) {
        return (underlyingAmount * RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 lstAmount) external view returns (uint256) {
        return (lstAmount * exchangeRate) / RATE_PRECISION;
    }

    function getWithdrawalStatus(address user)
        external
        view
        returns (uint256 underlyingAmount, uint256 unlockTime, bool isClaimable)
    {
        WithdrawalRequest memory req = pendingWithdrawals[user];
        underlyingAmount = req.underlyingAmount;
        unlockTime = req.unlockTime;
        isClaimable = (req.unlockTime != 0 && block.timestamp >= req.unlockTime);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
