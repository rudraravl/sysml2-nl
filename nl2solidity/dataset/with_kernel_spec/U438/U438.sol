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

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library Address {
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
        return returndata;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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
        } else {
            return false;
        }
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) {
            return false;
        }
        uint256 toDeleteIndex = valueIndex - 1;
        uint256 lastIndex = set._values.length - 1;
        if (lastIndex != toDeleteIndex) {
            address lastvalue = set._values[lastIndex];
            set._values[toDeleteIndex] = lastvalue;
            set._indexes[lastvalue] = valueIndex;
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

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract TreasuryBillPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ========== Constants ==========

    uint256 public constant MINIMUM_DEPOSIT = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 1000;
    uint256 public constant INITIAL_REDEMPTION_FEE_BPS = 10;
    uint8 public constant DECIMALS = 18;

    // ========== Token Metadata ==========

    string public name;
    string public symbol;

    // ========== Access Control ==========

    address public operator;
    address public pendingOperator;

    // ========== Pool Configuration ==========

    bool public paused;
    uint256 public redemptionFeeBps;
    address public feeRecipient;

    // ========== Share Token State ==========

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ========== Supported Assets ==========

    EnumerableSet.AddressSet private _supportedStablecoins;
    mapping(address => uint256) public cumulativeDeposits;

    // ========== Events ==========

    event Deposit(address indexed depositor, address indexed token, uint256 amount, uint256 shares);
    event Redeem(address indexed redeemer, address indexed token, uint256 sharesBurned, uint256 amountReceived, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event RedemptionFeeUpdated(address indexed operator, uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed operator, address indexed oldRecipient, address indexed newRecipient);
    event StablecoinAdded(address indexed operator, address indexed token);
    event StablecoinRemoved(address indexed operator, address indexed token);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event PendingOperatorSet(address indexed operator, address indexed pendingOperator);

    // ========== Errors ==========

    error NotOperator();
    error NotPendingOperator();
    error PoolPaused();
    error AlreadyPaused();
    error NotPaused();
    error UnsupportedStablecoin(address token);
    error InsufficientDeposit(uint256 provided, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddress();
    error InvalidFee(uint256 fee);
    error AlreadySupported(address token);
    error NotSupported(address token);
    error InsufficientPoolLiquidity(address token, uint256 available, uint256 required);
    error DecimalsTooHigh(uint8 decimals);

    // ========== Modifiers ==========

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PoolPaused();
        _;
    }

    // ========== Constructor ==========

    constructor(
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        address[] memory _initialStablecoins
    ) {
        if (_feeRecipient == address(0)) revert ZeroAddress();

        name = _name;
        symbol = _symbol;
        operator = msg.sender;
        redemptionFeeBps = INITIAL_REDEMPTION_FEE_BPS;
        feeRecipient = _feeRecipient;

        for (uint256 i; i < _initialStablecoins.length; ) {
            address token = _initialStablecoins[i];
            if (token == address(0)) revert ZeroAddress();
            if (IERC20Metadata(token).decimals() > DECIMALS) revert DecimalsTooHigh(IERC20Metadata(token).decimals());
            if (!_supportedStablecoins.add(token)) revert AlreadySupported(token);
            emit StablecoinAdded(msg.sender, token);

            unchecked {
                ++i;
            }
        }
    }

    // ========== Internal Helpers ==========

    function _scaleFactor(address token) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals == DECIMALS) return 1;
        return 10 ** (uint256(DECIMALS) - uint256(tokenDecimals));
    }

    function _rawMinimumDeposit(address token) internal view returns (uint256) {
        return MINIMUM_DEPOSIT * (10 ** uint256(IERC20Metadata(token).decimals()));
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        unchecked {
            balanceOf[from] = bal - amount;
        }
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ========== Core: Deposit ==========

    function deposit(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (!_supportedStablecoins.contains(token)) revert UnsupportedStablecoin(token);

        uint256 minDeposit = _rawMinimumDeposit(token);
        if (amount < minDeposit) revert InsufficientDeposit(amount, minDeposit);

        uint256 scaleFactor = _scaleFactor(token);
        uint256 shares = amount * scaleFactor;

        _mint(msg.sender, shares);
        cumulativeDeposits[token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount, shares);
    }

    // ========== Core: Redeem ==========

    function redeem(address token, uint256 shareAmount) external nonReentrant whenNotPaused {
        if (!_supportedStablecoins.contains(token)) revert UnsupportedStablecoin(token);

        uint256 bal = balanceOf[msg.sender];
        if (bal < shareAmount) revert InsufficientBalance(bal, shareAmount);

        uint256 scaleFactor = _scaleFactor(token);
        // Compute the fee directly from shareAmount (multiply first) to avoid
        // divide-before-multiply precision loss. Because redemptionFeeBps is
        // capped at MAX_REDEMPTION_FEE_BPS (<= 10% of FEE_DENOMINATOR), the
        // resulting fee never exceeds tokenAmount, so the subtraction below
        // cannot underflow.
        uint256 fee = (shareAmount * redemptionFeeBps) / (FEE_DENOMINATOR * scaleFactor);
        uint256 tokenAmount = shareAmount / scaleFactor;
        uint256 amountToUser = tokenAmount - fee;

        uint256 poolBalance = IERC20(token).balanceOf(address(this));
        if (poolBalance < tokenAmount) revert InsufficientPoolLiquidity(token, poolBalance, tokenAmount);

        _burn(msg.sender, shareAmount);

        IERC20(token).safeTransfer(msg.sender, amountToUser);
        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }

        emit Redeem(msg.sender, token, shareAmount, amountToUser, fee);
    }

    // ========== ERC20: Transfer ==========

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();

        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance(fromBal, amount);

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(allowed, amount);

        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
            allowance[from][msg.sender] = allowed - amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance(currentAllowance, subtractedValue);
        unchecked {
            uint256 newAllowance = currentAllowance - subtractedValue;
            allowance[msg.sender][spender] = newAllowance;
            emit Approval(msg.sender, spender, newAllowance);
        }
        return true;
    }

    // ========== View Functions ==========

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function getSupportedStablecoins() external view returns (address[] memory) {
        return _supportedStablecoins.values();
    }

    function isSupportedStablecoin(address token) external view returns (bool) {
        return _supportedStablecoins.contains(token);
    }

    function getMinimumDeposit(address token) external view returns (uint256) {
        return _rawMinimumDeposit(token);
    }

    function getPoolBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function supportedStablecoinCount() external view returns (uint256) {
        return _supportedStablecoins.length();
    }

    function previewRedeem(address token, uint256 shareAmount) external view returns (uint256 amountToUser, uint256 fee) {
        uint256 scaleFactor = _scaleFactor(token);
        // Multiply shareAmount by the fee rate before any division to avoid
        // divide-before-multiply precision loss.
        fee = (shareAmount * redemptionFeeBps) / (FEE_DENOMINATOR * scaleFactor);
        uint256 tokenAmount = shareAmount / scaleFactor;
        amountToUser = tokenAmount - fee;
    }

    // ========== Operator: Pause / Unpause ==========

    function pause() external onlyOperator {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ========== Operator: Fee Configuration ==========

    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_REDEMPTION_FEE_BPS) revert InvalidFee(newFeeBps);
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(msg.sender, oldFee, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(msg.sender, oldRecipient, newRecipient);
    }

    // ========== Operator: Stablecoin Management ==========

    function addStablecoin(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (IERC20Metadata(token).decimals() > DECIMALS) revert DecimalsTooHigh(IERC20Metadata(token).decimals());
        if (!_supportedStablecoins.add(token)) revert AlreadySupported(token);
        emit StablecoinAdded(msg.sender, token);
    }

    function removeStablecoin(address token) external onlyOperator {
        if (!_supportedStablecoins.remove(token)) revert NotSupported(token);
        emit StablecoinRemoved(msg.sender, token);
    }

    // ========== Operator: Access Control Transfer ==========

    function setPendingOperator(address newPendingOperator) external onlyOperator {
        pendingOperator = newPendingOperator;
        emit PendingOperatorSet(msg.sender, newPendingOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();
        address oldOperator = operator;
        operator = pendingOperator;
        pendingOperator = address(0);
        emit OperatorChanged(oldOperator, operator);
    }
}
