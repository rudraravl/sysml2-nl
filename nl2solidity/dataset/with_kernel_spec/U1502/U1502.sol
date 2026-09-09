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

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

contract StablecoinLSTLoan {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV_BPS = 7000;
    uint256 public constant ORIGINATION_FEE_BPS = 50;
    uint256 public constant BPS = 10000;
    uint256 public constant SCALE = 1e18;
    uint256 public constant MAX_RATE_PER_SECOND = 1e15;

    IERC20 public immutable lstToken;
    IERC20 public immutable stablecoin;
    IPriceOracle public immutable oracle;

    address public feeRecipient;
    address public operator;

    uint256 public globalIndex;
    uint256 public lastGlobalUpdate;
    uint256 public interestRatePerSecond;

    struct Position {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 cumulativeInterest;
        uint256 cumulativeIndexLU;
    }

    mapping(address => Position) public positions;

    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event LoanOriginated(address indexed borrower, uint256 principal, uint256 fee, uint256 disbursement);
    event LoanRepaid(address indexed borrower, uint256 amountRepaid, uint256 remainingDebt);
    event LoanLiquidated(address indexed borrower, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);
    event LiquiditySupplied(address indexed provider, uint256 amount);
    event LiquidityWithdrawn(address indexed recipient, uint256 amount);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OperatorUpdated(address oldOperator, address newOperator);

    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientLiquidity(uint256 requested, uint256 available);
    error LTVExceeded(uint256 currentLTV, uint256 maxLTV);
    error PositionNotLiquidatable(uint256 currentLTV, uint256 threshold);
    error NoOutstandingDebt();
    error NoCollateral();
    error InsufficientCollateral();
    error ExceedsMaxRate(uint256 rate, uint256 max);
    error InvalidOraclePrice();
    error LoanNotFullyRepaid();

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANT");
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        address _lstToken,
        address _stablecoin,
        address _oracle,
        address _operator,
        address _feeRecipient,
        uint256 _initialRatePerSecond
    ) {
        if (
            _lstToken == address(0) ||
            _stablecoin == address(0) ||
            _oracle == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();
        if (_initialRatePerSecond > MAX_RATE_PER_SECOND) {
            revert ExceedsMaxRate(_initialRatePerSecond, MAX_RATE_PER_SECOND);
        }

        lstToken = IERC20(_lstToken);
        stablecoin = IERC20(_stablecoin);
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        feeRecipient = _feeRecipient;
        interestRatePerSecond = _initialRatePerSecond;
        globalIndex = SCALE;
        lastGlobalUpdate = block.timestamp;
    }

    function _updateGlobalIndex() internal {
        if (block.timestamp > lastGlobalUpdate) {
            uint256 timeElapsed = block.timestamp - lastGlobalUpdate;
            globalIndex = globalIndex * (SCALE + interestRatePerSecond * timeElapsed) / SCALE;
            lastGlobalUpdate = block.timestamp;
        }
    }

    function _currentGlobalIndex() internal view returns (uint256) {
        if (block.timestamp == lastGlobalUpdate) return globalIndex;
        uint256 timeElapsed = block.timestamp - lastGlobalUpdate;
        return globalIndex * (SCALE + interestRatePerSecond * timeElapsed) / SCALE;
    }

    function _accrue(address borrower) internal {
        _updateGlobalIndex();
        Position storage pos = positions[borrower];
        if (pos.borrowedAmount > 0 && pos.cumulativeIndexLU > 0 && pos.cumulativeIndexLU < globalIndex) {
            uint256 accrued = pos.borrowedAmount * (globalIndex - pos.cumulativeIndexLU) / SCALE;
            pos.cumulativeInterest += accrued;
        }
        pos.cumulativeIndexLU = globalIndex;
    }

    function _getPrice() internal view returns (uint256) {
        uint256 price = oracle.getPrice();
        if (price == 0) revert InvalidOraclePrice();
        return price;
    }

    function _collateralValue(uint256 collateralAmount) internal view returns (uint256) {
        return collateralAmount * _getPrice() / SCALE;
    }

    function _currentLTV(uint256 totalDebt, uint256 collateralValue) internal pure returns (uint256) {
        if (collateralValue == 0) return type(uint256).max;
        return totalDebt * BPS / collateralValue;
    }

    function _pendingInterest(Position storage pos) internal view returns (uint256) {
        uint256 idx = _currentGlobalIndex();
        if (pos.borrowedAmount > 0 && pos.cumulativeIndexLU > 0 && pos.cumulativeIndexLU < idx) {
            return pos.borrowedAmount * (idx - pos.cumulativeIndexLU) / SCALE;
        }
        return 0;
    }

    function _totalDebt(Position storage pos) internal view returns (uint256) {
        return pos.borrowedAmount + pos.cumulativeInterest + _pendingInterest(pos);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        positions[msg.sender].collateralAmount += amount;
        lstToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        Position storage pos = positions[msg.sender];
        if (amount > pos.collateralAmount) revert InsufficientCollateral();

        uint256 totalDebt = pos.borrowedAmount + pos.cumulativeInterest;
        if (totalDebt > 0) revert LoanNotFullyRepaid();

        pos.collateralAmount -= amount;
        lstToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        Position storage pos = positions[msg.sender];
        if (pos.collateralAmount == 0) revert NoCollateral();

        uint256 fee = amount * ORIGINATION_FEE_BPS / BPS;
        uint256 disbursement = amount - fee;

        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientLiquidity(amount, contractBalance);

        uint256 currentDebt = pos.borrowedAmount + pos.cumulativeInterest;
        uint256 newTotalDebt = currentDebt + amount;
        uint256 colValue = _collateralValue(pos.collateralAmount);
        if (newTotalDebt * BPS > colValue * MAX_LTV_BPS) {
            revert LTVExceeded(_currentLTV(newTotalDebt, colValue), MAX_LTV_BPS);
        }

        pos.borrowedAmount += amount;

        stablecoin.safeTransfer(msg.sender, disbursement);
        if (fee > 0) {
            stablecoin.safeTransfer(feeRecipient, fee);
        }

        emit LoanOriginated(msg.sender, amount, fee, disbursement);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        Position storage pos = positions[msg.sender];
        uint256 totalDebt = pos.borrowedAmount + pos.cumulativeInterest;
        if (totalDebt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;

        if (repayAmount <= pos.cumulativeInterest) {
            pos.cumulativeInterest -= repayAmount;
        } else {
            uint256 principalPortion = repayAmount - pos.cumulativeInterest;
            pos.cumulativeInterest = 0;
            pos.borrowedAmount -= principalPortion;
        }

        stablecoin.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit LoanRepaid(msg.sender, repayAmount, pos.borrowedAmount + pos.cumulativeInterest);
    }

    function liquidate(address borrower) external onlyOperator nonReentrant {
        if (borrower == address(0)) revert ZeroAddress();
        _accrue(borrower);
        Position storage pos = positions[borrower];
        uint256 totalDebt = pos.borrowedAmount + pos.cumulativeInterest;
        if (totalDebt == 0) revert NoOutstandingDebt();
        if (pos.collateralAmount == 0) revert InsufficientCollateral();

        uint256 colValue = _collateralValue(pos.collateralAmount);
        uint256 currentLTV = _currentLTV(totalDebt, colValue);
        if (currentLTV <= MAX_LTV_BPS) {
            revert PositionNotLiquidatable(currentLTV, MAX_LTV_BPS);
        }

        uint256 collateralToSeize = pos.collateralAmount;

        pos.collateralAmount = 0;
        pos.borrowedAmount = 0;
        pos.cumulativeInterest = 0;
        pos.cumulativeIndexLU = globalIndex;

        stablecoin.safeTransferFrom(msg.sender, address(this), totalDebt);
        lstToken.safeTransfer(msg.sender, collateralToSeize);

        emit LoanLiquidated(borrower, msg.sender, totalDebt, collateralToSeize);
    }

    function supplyLiquidity(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquiditySupplied(msg.sender, amount);
    }

    function withdrawLiquidity(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientLiquidity(amount, contractBalance);
        stablecoin.safeTransfer(msg.sender, amount);
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    function setInterestRate(uint256 newRatePerSecond) external onlyOperator {
        if (newRatePerSecond > MAX_RATE_PER_SECOND) {
            revert ExceedsMaxRate(newRatePerSecond, MAX_RATE_PER_SECOND);
        }
        _updateGlobalIndex();
        uint256 oldRate = interestRatePerSecond;
        interestRatePerSecond = newRatePerSecond;
        emit InterestRateUpdated(oldRate, newRatePerSecond);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getPosition(address borrower)
        external
        view
        returns (
            uint256 collateralAmount,
            uint256 borrowedAmount,
            uint256 cumulativeInterest,
            uint256 totalDebt
        )
    {
        Position storage pos = positions[borrower];
        collateralAmount = pos.collateralAmount;
        borrowedAmount = pos.borrowedAmount;
        cumulativeInterest = pos.cumulativeInterest;
        totalDebt = _totalDebt(pos);
    }

    function getCurrentDebt(address borrower) external view returns (uint256) {
        return _totalDebt(positions[borrower]);
    }

    function getLTV(address borrower) external view returns (uint256) {
        Position storage pos = positions[borrower];
        if (pos.collateralAmount == 0) return 0;
        uint256 totalDebt = _totalDebt(pos);
        if (totalDebt == 0) return 0;
        return _currentLTV(totalDebt, _collateralValue(pos.collateralAmount));
    }

    function getCollateralValue(address borrower) external view returns (uint256) {
        return _collateralValue(positions[borrower].collateralAmount);
    }

    function maxBorrow(address borrower) external view returns (uint256) {
        return _collateralValue(positions[borrower].collateralAmount) * MAX_LTV_BPS / BPS;
    }

    function currentGlobalIndex() external view returns (uint256) {
        return _currentGlobalIndex();
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}
