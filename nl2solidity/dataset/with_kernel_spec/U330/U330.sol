// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

library Address {
    error AddressEmptyCode(address target);
    error CallFailed();

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        if (!isContract(target)) revert AddressEmptyCode(target);
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            if (ret.length > 0) {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
            revert CallFailed();
        }
        return ret;
    }
}

library SafeERC20 {
    using Address for address;

    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedOperationFromAddressToAddress(address from, address to, uint256 value);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_callOptionalReturnBool(token, abi.encodeWithSelector(token.transfer.selector, to, value))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_callOptionalReturnBool(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value))) {
            revert SafeERC20FailedOperationFromAddressToAddress(from, to, value);
        }
    }

    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        if (!address(token).isContract()) return false;
        (bool ok, bytes memory ret) = address(token).call(data);
        if (!ok) return false;
        if (ret.length == 0) return true;
        return abi.decode(ret, (bool));
    }
}

library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) return false;
        uint256 lastIndex = set._values.length;
        if (valueIndex != lastIndex) {
            address lastValue = set._values[lastIndex - 1];
            set._values[valueIndex - 1] = lastValue;
            set._indexes[lastValue] = valueIndex;
        }
        set._values.pop();
        delete set._indexes[value];
        return true;
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract ERC20 is IERC20, IERC20Metadata {
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance_, uint256 needed);
    error ERC20InvalidApprove(address approver, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert ERC20InsufficientAllowance(msg.sender, currentAllowance, amount);
        }
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) {
            revert ERC20InsufficientBalance(account, accountBalance, amount);
        }
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (owner == address(0) || spender == address(0)) {
            revert ERC20InvalidApprove(address(0), amount);
        }
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract ReserveCurrency is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotApproved();
    error TokenAlreadyApproved();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error InsufficientBalance();
    error WeightOutOfBounds();
    error ReserveRatioTooLow();
    error OraclePriceZero();
    error CannotRescueApproved();

    uint256 public constant WAD = 1e18;
    uint256 public constant MIN_RESERVE_RATIO = 1.5e18; // 150%
    uint256 public constant MIN_WEIGHT = 1e17;          // 10%
    uint256 public constant MAX_WEIGHT = 1e18;          // 100%
    uint256 public constant WITHDRAW_FEE_BPS = 50;      // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    struct Collateral {
        bool approved;
        uint256 weight;
        uint8 decimals;
    }

    address public operator;
    IPriceOracle public oracle;

    mapping(address => Collateral) public collaterals;
    EnumerableSet.AddressSet internal _approvedTokens;
    mapping(address => mapping(address => uint256)) public deposits; // user => token => amount

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Deposit(address indexed user, address indexed token, uint256 amountDeposited, uint256 reserveMinted);
    event Withdraw(address indexed user, address indexed token, uint256 amountRequested, uint256 reserveBurned, uint256 feeAmount);
    event Redeem(address indexed user, uint256 reserveBurned, address[] tokens, uint256[] amountsOut, uint256 totalFee);
    event CollateralAdded(address indexed token, uint256 weight);
    event CollateralRemoved(address indexed token);
    event WeightUpdated(address indexed token, uint256 oldWeight, uint256 newWeight);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Rescue(address indexed token, address indexed to, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address operator_, address oracle_) ERC20("Decentralized Reserve", "RSV") {
        if (operator_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        operator = operator_;
        oracle = IPriceOracle(oracle_);
        emit OperatorUpdated(address(0), operator_);
        emit OracleUpdated(address(0), oracle_);
    }

    function reserveRatio() public view returns (uint256) {
        uint256 s = totalSupply();
        if (s < 1) return type(uint256).max;
        return (totalCollateralValue() * WAD) / s;
    }

    function totalCollateralValue() public view returns (uint256 value) {
        address[] memory tokens = _approvedTokens.values();
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; ++i) {
            address token = tokens[i];
            Collateral memory c = collaterals[token];
            if (!c.approved) continue;
            uint256 balance = IERC20(token).balanceOf(address(this));
            value += _value(token, balance, c);
        }
    }

    function approvedTokens() external view returns (address[] memory) {
        return _approvedTokens.values();
    }

    function getCollateral(address token) external view returns (bool approved, uint256 weight, uint8 decimals) {
        Collateral memory c = collaterals[token];
        return (c.approved, c.weight, c.decimals);
    }

    function isApprovedCollateral(address token) external view returns (bool) {
        return collaterals[token].approved;
    }

    function _value(address token, uint256 amount, Collateral memory c) internal view returns (uint256) {
        if (amount < 1) return 0;
        uint256 price = oracle.getPrice(token);
        if (price < 1) revert OraclePriceZero();
        // Combined multiplication before division to avoid divide-before-multiply precision loss
        return (amount * price * c.weight) / ((10 ** c.decimals) * WAD);
    }

    function _checkRatio(uint256 tv, uint256 s) internal pure returns (bool) {
        if (s < 1) return true;
        return tv * WAD >= s * MIN_RESERVE_RATIO;
    }

    function _reserveRatioSatisfied() internal view returns (bool) {
        return _checkRatio(totalCollateralValue(), totalSupply());
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        if (!_reserveRatioSatisfied()) {
            oracle = IPriceOracle(old);
            revert ReserveRatioTooLow();
        }
        emit OracleUpdated(old, newOracle);
    }

    function addCollateral(address token, uint256 weight) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        Collateral storage c = collaterals[token];
        if (c.approved) revert TokenAlreadyApproved();
        if (weight < MIN_WEIGHT || weight > MAX_WEIGHT) revert WeightOutOfBounds();

        uint8 dec = IERC20Metadata(token).decimals();
        c.approved = true;
        c.weight = weight;
        c.decimals = dec;
        _approvedTokens.add(token);

        if (!_reserveRatioSatisfied()) {
            c.approved = false;
            c.weight = 0;
            c.decimals = 0;
            _approvedTokens.remove(token);
            revert ReserveRatioTooLow();
        }

        emit CollateralAdded(token, weight);
    }

    function removeCollateral(address token) external onlyOperator {
        Collateral storage c = collaterals[token];
        if (!c.approved) revert TokenNotApproved();

        c.approved = false;
        c.weight = 0;
        c.decimals = 0;
        _approvedTokens.remove(token);

        if (!_reserveRatioSatisfied()) revert ReserveRatioTooLow();

        emit CollateralRemoved(token);
    }

    function setWeight(address token, uint256 weight) external onlyOperator {
        Collateral storage c = collaterals[token];
        if (!c.approved) revert TokenNotApproved();
        if (weight < MIN_WEIGHT || weight > MAX_WEIGHT) revert WeightOutOfBounds();

        uint256 oldWeight = c.weight;
        c.weight = weight;

        if (!_reserveRatioSatisfied()) {
            c.weight = oldWeight;
            revert ReserveRatioTooLow();
        }

        emit WeightUpdated(token, oldWeight, weight);
    }

    function rescue(address token, address to, uint256 amount) external onlyOperator {
        if (collaterals[token].approved) revert CannotRescueApproved();
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit Rescue(token, to, amount);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        Collateral memory c = collaterals[token];
        if (!c.approved) revert TokenNotApproved();

        uint256 tv = totalCollateralValue();
        uint256 s = totalSupply();
        if (!_checkRatio(tv, s)) revert ReserveRatioTooLow();

        uint256 value = _value(token, amount, c);
        if (value < 1) revert OraclePriceZero();

        // Effects: update state before external transfer (checks-effects-interactions)
        deposits[msg.sender][token] += amount;

        uint256 mintAmount;
        if (s < 1 || tv < 1) {
            mintAmount = (value * WAD) / MIN_RESERVE_RATIO;
        } else {
            mintAmount = (value * s) / tv;
        }

        _mint(msg.sender, mintAmount);

        // Interaction: pull collateral from depositor
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Mint(msg.sender, mintAmount);
        emit Deposit(msg.sender, token, amount, mintAmount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        Collateral memory c = collaterals[token];
        if (!c.approved) revert TokenNotApproved();
        if (deposits[msg.sender][token] < amount) revert InsufficientDeposit();
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        uint256 tv = totalCollateralValue();
        uint256 s = totalSupply();
        if (tv < 1 || s < 1) revert InsufficientLiquidity();
        if (!_checkRatio(tv, s)) revert ReserveRatioTooLow();

        uint256 value = _value(token, amount, c);
        if (value < 1) revert OraclePriceZero();
        uint256 burnAmount = (value * s) / tv;

        uint256 feeAmount = (amount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 toUser = amount - feeAmount;

        // Effects: update state before external transfer
        deposits[msg.sender][token] -= amount;
        _burn(msg.sender, burnAmount);

        // Interaction: send collateral to user
        IERC20(token).safeTransfer(msg.sender, toUser);

        emit Burn(msg.sender, burnAmount);
        emit Withdraw(msg.sender, token, amount, burnAmount, feeAmount);
    }

    function redeem(uint256 reserveAmount) external nonReentrant {
        if (reserveAmount < 1) revert ZeroAmount();
        uint256 s = totalSupply();
        if (s < 1) revert InsufficientLiquidity();
        if (balanceOf(msg.sender) < reserveAmount) revert InsufficientBalance();

        address[] memory tokens = _approvedTokens.values();
        uint256 len = tokens.length;
        uint256[] memory amountsOut = new uint256[](len);
        uint256 totalFee;

        for (uint256 i = 0; i < len; ++i) {
            address token = tokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance < 1) continue;

            uint256 numerator = balance * reserveAmount;
            uint256 grossAmount = numerator / s;
            if (grossAmount < 1) continue;

            // Compute fee from the full-precision numerator to avoid divide-before-multiply
            uint256 feeAmount = (numerator * WITHDRAW_FEE_BPS) / (s * BPS_DENOMINATOR);
            uint256 netAmount = grossAmount - feeAmount;
            amountsOut[i] = netAmount;
            totalFee += feeAmount;
        }

        // Effects: burn reserve tokens before external transfers
        _burn(msg.sender, reserveAmount);

        // Interactions: transfer collateral to redeemer
        for (uint256 i = 0; i < len; ++i) {
            if (amountsOut[i] < 1) continue;
            IERC20(tokens[i]).safeTransfer(msg.sender, amountsOut[i]);
        }

        emit Burn(msg.sender, reserveAmount);
        emit Redeem(msg.sender, reserveAmount, tokens, amountsOut, totalFee);
    }
}
