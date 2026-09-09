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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }
}

error SafeERC20FailedOperation(address token);
error ZeroAddress();
error ZeroAmount();
error InsufficientBalance();
error InsufficientAllowance();
error NotOperator();
error ExchangeRateCannotDecrease(uint256 oldRate, uint256 newRate);
error FeeExceedsMax(uint256 fee, uint256 maxFee);
error AllowanceBelowZero();

contract YieldStablecoin {
    using SafeERC20 for IERC20;

    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 1e18;
    uint256 public constant MAX_REDEMPTION_FEE = 0.005e18; // 0.5%
    uint256 internal constant UINT256_MAX = type(uint256).max;
    address internal constant ZERO_ADDRESS = address(0);

    string public constant name = "Yield Stablecoin";
    string public constant symbol = "yUSD";
    uint8 public constant decimals = 18;

    IERC20 public immutable collateral;
    address public operator;

    uint256 public totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    mapping(address => uint256) internal _collateralDeposited;

    uint256 public exchangeRate;
    uint256 public redemptionFee;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 collateralAmount,
        uint256 stablecoinAmount
    );
    event Redeem(
        address indexed caller,
        address indexed owner,
        uint256 stablecoinAmount,
        uint256 collateralReturned,
        uint256 fee
    );
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorChanged(address oldOperator, address newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NotOperator();
        }
        _;
    }

    constructor(
        address _collateral,
        address _operator,
        uint256 _initialExchangeRate,
        uint256 _initialRedemptionFee
    ) {
        if (_collateral == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (_operator == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (_initialRedemptionFee > MAX_REDEMPTION_FEE) {
            revert FeeExceedsMax(_initialRedemptionFee, MAX_REDEMPTION_FEE);
        }
        collateral = IERC20(_collateral);
        operator = _operator;
        exchangeRate = _initialExchangeRate == 0 ? EXCHANGE_RATE_PRECISION : _initialExchangeRate;
        redemptionFee = _initialRedemptionFee;
        emit OperatorChanged(ZERO_ADDRESS, _operator);
        emit ExchangeRateUpdated(0, exchangeRate);
        emit RedemptionFeeUpdated(0, redemptionFee);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function collateralDeposited(address account) external view returns (uint256) {
        return _collateralDeposited[account];
    }

    function collateralBalance() external view returns (uint256) {
        return collateral.balanceOf(address(this));
    }

    function previewDeposit(uint256 collateralAmount) external view returns (uint256) {
        return (collateralAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 stablecoinAmount)
        external
        view
        returns (uint256 collateralReturned, uint256 fee)
    {
        uint256 gross = (stablecoinAmount * exchangeRate) / EXCHANGE_RATE_PRECISION;
        fee = (gross * redemptionFee) / FEE_PRECISION;
        collateralReturned = gross - fee;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) {
            revert ZeroAmount();
        }
        if (newRate <= exchangeRate) {
            revert ExchangeRateCannotDecrease(exchangeRate, newRate);
        }
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function setRedemptionFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_REDEMPTION_FEE) {
            revert FeeExceedsMax(newFee, MAX_REDEMPTION_FEE);
        }
        uint256 oldFee = redemptionFee;
        redemptionFee = newFee;
        emit RedemptionFeeUpdated(oldFee, newFee);
    }

    function deposit(uint256 collateralAmount) external returns (uint256 stablecoinAmount) {
        return _deposit(msg.sender, msg.sender, collateralAmount);
    }

    function depositTo(address owner, uint256 collateralAmount) external returns (uint256 stablecoinAmount) {
        if (owner == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        return _deposit(msg.sender, owner, collateralAmount);
    }

    function _deposit(
        address payer,
        address owner,
        uint256 collateralAmount
    ) internal returns (uint256 stablecoinAmount) {
        if (collateralAmount == 0) {
            revert ZeroAmount();
        }
        stablecoinAmount = (collateralAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
        if (stablecoinAmount == 0) {
            revert ZeroAmount();
        }
        _collateralDeposited[owner] += collateralAmount;
        totalSupply += stablecoinAmount;
        _balances[owner] += stablecoinAmount;
        collateral.safeTransferFrom(payer, address(this), collateralAmount);
        emit Transfer(ZERO_ADDRESS, owner, stablecoinAmount);
        emit Deposit(payer, owner, collateralAmount, stablecoinAmount);
    }

    function redeem(uint256 stablecoinAmount) external returns (uint256 collateralReturned, uint256 fee) {
        return _redeem(msg.sender, msg.sender, stablecoinAmount);
    }

    function redeemFrom(address owner, uint256 stablecoinAmount)
        external
        returns (uint256 collateralReturned, uint256 fee)
    {
        if (owner == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        uint256 allowed = _allowances[owner][msg.sender];
        if (allowed < stablecoinAmount) {
            revert InsufficientAllowance();
        }
        if (allowed != UINT256_MAX) {
            _allowances[owner][msg.sender] = allowed - stablecoinAmount;
            emit Approval(owner, msg.sender, allowed - stablecoinAmount);
        }
        return _redeem(msg.sender, owner, stablecoinAmount);
    }

    function _redeem(
        address receiver,
        address owner,
        uint256 stablecoinAmount
    ) internal returns (uint256 collateralReturned, uint256 fee) {
        if (stablecoinAmount == 0) {
            revert ZeroAmount();
        }
        if (_balances[owner] < stablecoinAmount) {
            revert InsufficientBalance();
        }
        uint256 grossCollateral = (stablecoinAmount * exchangeRate) / EXCHANGE_RATE_PRECISION;
        fee = (grossCollateral * redemptionFee) / FEE_PRECISION;
        collateralReturned = grossCollateral - fee;
        if (collateralReturned == 0 && fee == 0) {
            revert ZeroAmount();
        }
        _balances[owner] -= stablecoinAmount;
        totalSupply -= stablecoinAmount;
        if (collateralReturned > 0) {
            collateral.safeTransfer(receiver, collateralReturned);
        }
        emit Transfer(owner, ZERO_ADDRESS, stablecoinAmount);
        emit Redeem(receiver, owner, stablecoinAmount, collateralReturned, fee);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (_balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == ZERO_ADDRESS || to == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) {
            revert InsufficientAllowance();
        }
        if (_balances[from] < amount) {
            revert InsufficientBalance();
        }
        if (allowed != UINT256_MAX) {
            _allowances[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowed - amount);
        }
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (addedValue == 0) {
            revert ZeroAmount();
        }
        uint256 newAllowance = _allowances[msg.sender][spender] + addedValue;
        _allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == ZERO_ADDRESS) {
            revert ZeroAddress();
        }
        if (subtractedValue == 0) {
            revert ZeroAmount();
        }
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert AllowanceBelowZero();
        }
        uint256 newAllowance = currentAllowance - subtractedValue;
        _allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }
}
