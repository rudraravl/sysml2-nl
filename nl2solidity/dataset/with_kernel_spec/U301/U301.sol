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

contract YieldBearingStablecoin {
    error Unauthorized();
    error UnderlyingNotApproved(address token);
    error UnderlyingAlreadyApproved(address token);
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientReserve(uint256 required, uint256 available);
    error YieldRateTooHigh(uint256 rate, uint256 max);
    error SafeTransferFailed();

    event Deposit(
        address indexed sender,
        address indexed recipient,
        address indexed underlying,
        uint256 underlyingAmount,
        uint256 mintedShares
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Redeem(
        address indexed sender,
        address indexed recipient,
        address indexed underlying,
        uint256 burnedShares,
        uint256 underlyingOut,
        uint256 fee
    );
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);
    event YieldAccrued(uint256 oldIndex, uint256 newIndex, uint256 elapsed);
    event UnderlyingApproved(address indexed token);
    event UnderlyingRemoved(address indexed token);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesClaimed(address indexed underlying, uint256 amount);

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant INDEX_SCALE = 1e18;
    uint256 public constant MAX_YIELD_RATE_BPS = 100000; // 1000% cap

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public operator;
    uint256 public totalSupply;
    uint256 public globalReserve;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public approvedUnderlying;
    address[] public underlyingList;
    mapping(address => uint256) internal _underlyingListIndexPlusOne;

    mapping(address => uint256) public accumulatedFees;

    uint256 public yieldIndex;
    uint256 public annualYieldRateBps;
    uint256 public lastAccrualTime;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _operator,
        uint256 _initialYieldRateBps
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialYieldRateBps > MAX_YIELD_RATE_BPS) {
            revert YieldRateTooHigh(_initialYieldRateBps, MAX_YIELD_RATE_BPS);
        }
        name = _name;
        symbol = _symbol;
        operator = _operator;
        yieldIndex = INDEX_SCALE;
        annualYieldRateBps = _initialYieldRateBps;
        lastAccrualTime = block.timestamp;
    }

    function accrueYield() public {
        if (block.timestamp <= lastAccrualTime) return;
        uint256 elapsed = block.timestamp - lastAccrualTime;
        uint256 oldIndex = yieldIndex;
        uint256 growth = (oldIndex * annualYieldRateBps * elapsed) /
            (BPS_DENOM * SECONDS_PER_YEAR);
        uint256 newIndex = oldIndex + growth;
        yieldIndex = newIndex;
        lastAccrualTime = block.timestamp;
        emit YieldAccrued(oldIndex, newIndex, elapsed);
    }

    function deposit(
        address recipient,
        address underlying,
        uint256 amount
    ) external returns (uint256 mintedShares) {
        if (!approvedUnderlying[underlying]) revert UnderlyingNotApproved(underlying);
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum(amount, MIN_DEPOSIT);

        accrueYield();

        _safeTransferFrom(underlying, msg.sender, address(this), amount);

        mintedShares = (amount * INDEX_SCALE) / yieldIndex;
        totalSupply += mintedShares;
        balanceOf[recipient] += mintedShares;
        globalReserve += amount;

        emit Deposit(msg.sender, recipient, underlying, amount, mintedShares);
        emit Transfer(address(0), recipient, mintedShares);
    }

    function redeem(
        address recipient,
        address underlying,
        uint256 shareAmount
    ) external returns (uint256 underlyingOut) {
        if (!approvedUnderlying[underlying]) revert UnderlyingNotApproved(underlying);
        if (recipient == address(0)) revert ZeroAddress();
        if (shareAmount == 0) revert ZeroAmount();
        uint256 bal = balanceOf[msg.sender];
        if (bal < shareAmount) revert InsufficientBalance(bal, shareAmount);

        accrueYield();

        // Compute fee as a single multiply-after-divide-free expression to
        // avoid precision loss from dividing before multiplying.
        uint256 fee = (shareAmount * yieldIndex * REDEMPTION_FEE_BPS) /
            (INDEX_SCALE * BPS_DENOM);
        uint256 underlyingAmount = (shareAmount * yieldIndex) / INDEX_SCALE;
        underlyingOut = underlyingAmount - fee;

        if (underlyingAmount > globalReserve) {
            revert InsufficientReserve(underlyingAmount, globalReserve);
        }

        balanceOf[msg.sender] = bal - shareAmount;
        totalSupply -= shareAmount;
        globalReserve -= underlyingAmount;
        accumulatedFees[underlying] += fee;

        _safeTransfer(underlying, recipient, underlyingOut);

        emit Redeem(msg.sender, recipient, underlying, shareAmount, underlyingOut, fee);
        emit Transfer(msg.sender, address(0), shareAmount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        balanceOf[msg.sender] = bal - amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] = bal - amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function setYieldRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_YIELD_RATE_BPS) {
            revert YieldRateTooHigh(newRate, MAX_YIELD_RATE_BPS);
        }
        accrueYield();
        uint256 old = annualYieldRateBps;
        annualYieldRateBps = newRate;
        emit YieldRateUpdated(old, newRate);
    }

    function addUnderlying(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (approvedUnderlying[token]) revert UnderlyingAlreadyApproved(token);
        approvedUnderlying[token] = true;
        _underlyingListIndexPlusOne[token] = underlyingList.length + 1;
        underlyingList.push(token);
        emit UnderlyingApproved(token);
    }

    function removeUnderlying(address token) external onlyOperator {
        if (!approvedUnderlying[token]) revert UnderlyingNotApproved(token);
        approvedUnderlying[token] = false;
        uint256 idxPlusOne = _underlyingListIndexPlusOne[token];
        uint256 lastIdx = underlyingList.length - 1;
        if (idxPlusOne - 1 != lastIdx) {
            address lastToken = underlyingList[lastIdx];
            underlyingList[idxPlusOne - 1] = lastToken;
            _underlyingListIndexPlusOne[lastToken] = idxPlusOne;
        }
        underlyingList.pop();
        delete _underlyingListIndexPlusOne[token];
        emit UnderlyingRemoved(token);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function claimFees(address underlying) external onlyOperator returns (uint256) {
        uint256 amount = accumulatedFees[underlying];
        if (amount == 0) return 0;
        accumulatedFees[underlying] = 0;
        _safeTransfer(underlying, operator, amount);
        emit FeesClaimed(underlying, amount);
        return amount;
    }

    function underlyingListLength() external view returns (uint256) {
        return underlyingList.length;
    }

    function convertToUnderlying(uint256 shareAmount) external view returns (uint256) {
        return (shareAmount * yieldIndex) / INDEX_SCALE;
    }

    function convertToShares(uint256 underlyingAmount) external view returns (uint256) {
        return (underlyingAmount * INDEX_SCALE) / yieldIndex;
    }

    function underlyingBalanceOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }
}
