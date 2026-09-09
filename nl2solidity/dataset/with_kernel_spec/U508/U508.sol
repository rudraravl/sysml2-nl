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
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            amount == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
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

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (contains(set, value)) {
            return false;
        }
        set._values.push(value);
        set._indexes[value] = set._values.length;
        return true;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) {
            return false;
        }
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
}

contract LiquidStakingPool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant DEFAULT_SWAP_FEE_BPS = 5;
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant MAX_SUPPORTED_LSTS = 200;
    uint256 public constant WAD = 1e18;

    struct LSTConfig {
        address underlying;
        uint256 exchangeRate;
    }

    address public owner;
    bool public paused;

    EnumerableSet.AddressSet internal _supportedLSTs;
    mapping(address => LSTConfig) public lstConfigs;
    mapping(address => uint256) public poolBalanceOfLST;
    mapping(address => uint256) public underlyingBalanceOfLST;
    uint256 public swapFeeBps;

    event Deposit(address indexed user, address indexed lst, uint256 amount, uint256 underlyingAmount);
    event Withdraw(address indexed user, address indexed lst, uint256 amount, uint256 underlyingAmount);
    event Swap(
        address indexed user,
        address indexed fromLST,
        address indexed toLST,
        uint256 fromAmount,
        uint256 toAmount,
        uint256 feeUnderlying
    );
    event LSTAdded(address indexed lst, address underlying, uint256 exchangeRate);
    event ExchangeRateUpdated(address indexed lst, uint256 oldRate, uint256 newRate);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);

    error NotOwner();
    error EnforcedPause();
    error LSTNotSupported();
    error LSTAlreadySupported();
    error MaxLSTsReached();
    error ZeroAmount();
    error InsufficientPoolBalance();
    error SameLSTSwap();
    error ZeroAddress();
    error InvalidExchangeRate();
    error FeeExceedsMax();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier onlySupportedLST(address lst) {
        if (!_supportedLSTs.contains(lst)) revert LSTNotSupported();
        _;
    }

    constructor() {
        owner = msg.sender;
        swapFeeBps = DEFAULT_SWAP_FEE_BPS;
        emit OwnershipTransferred(address(0), msg.sender);
        emit SwapFeeUpdated(0, DEFAULT_SWAP_FEE_BPS);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previousOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    function isLSTSupported(address lst) external view returns (bool) {
        return _supportedLSTs.contains(lst);
    }

    function supportedLSTs() external view returns (address[] memory) {
        return _supportedLSTs.values();
    }

    function supportedLSTCount() external view returns (uint256) {
        return _supportedLSTs.length();
    }

    function getLSTConfig(address lst)
        external
        view
        onlySupportedLST(lst)
        returns (address underlying, uint256 exchangeRate, uint256 poolBalance, uint256 underlyingBalance)
    {
        LSTConfig storage c = lstConfigs[lst];
        return (c.underlying, c.exchangeRate, poolBalanceOfLST[lst], underlyingBalanceOfLST[lst]);
    }

    function underlyingValueOf(address lst, uint256 lstAmount)
        public
        view
        onlySupportedLST(lst)
        returns (uint256)
    {
        return (lstAmount * lstConfigs[lst].exchangeRate) / WAD;
    }

    function addLST(address lst, address underlying, uint256 exchangeRate) external onlyOwner {
        if (lst == address(0) || underlying == address(0)) revert ZeroAddress();
        if (_supportedLSTs.length() >= MAX_SUPPORTED_LSTS) revert MaxLSTsReached();
        if (exchangeRate == 0) revert InvalidExchangeRate();
        lstConfigs[lst] = LSTConfig({underlying: underlying, exchangeRate: exchangeRate});
        bool added = _supportedLSTs.add(lst);
        if (!added) revert LSTAlreadySupported();
        emit LSTAdded(lst, underlying, exchangeRate);
    }

    function updateExchangeRate(address lst, uint256 newRate)
        external
        onlyOwner
        onlySupportedLST(lst)
    {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = lstConfigs[lst].exchangeRate;
        lstConfigs[lst].exchangeRate = newRate;
        emit ExchangeRateUpdated(lst, oldRate, newRate);
    }

    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_BPS) revert FeeExceedsMax();
        uint256 oldFee = swapFeeBps;
        swapFeeBps = newFee;
        emit SwapFeeUpdated(oldFee, newFee);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function deposit(address lst, uint256 amount) external whenNotPaused onlySupportedLST(lst) {
        if (amount == 0) revert ZeroAmount();
        IERC20(lst).safeTransferFrom(msg.sender, address(this), amount);
        uint256 underlyingAmount = underlyingValueOf(lst, amount);
        poolBalanceOfLST[lst] += amount;
        underlyingBalanceOfLST[lst] += underlyingAmount;
        emit Deposit(msg.sender, lst, amount, underlyingAmount);
    }

    function withdraw(address lst, uint256 amount) external onlySupportedLST(lst) {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = poolBalanceOfLST[lst];
        if (bal < amount) revert InsufficientPoolBalance();
        uint256 underlyingAmount = underlyingValueOf(lst, amount);
        poolBalanceOfLST[lst] = bal - amount;
        underlyingBalanceOfLST[lst] -= underlyingAmount;
        IERC20(lst).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, lst, amount, underlyingAmount);
    }

    function swap(address fromLST, address toLST, uint256 fromAmount)
        external
        whenNotPaused
        onlySupportedLST(fromLST)
        onlySupportedLST(toLST)
        returns (uint256 toAmount)
    {
        if (fromLST == toLST) revert SameLSTSwap();
        if (fromAmount == 0) revert ZeroAmount();

        IERC20(fromLST).safeTransferFrom(msg.sender, address(this), fromAmount);
        poolBalanceOfLST[fromLST] += fromAmount;

        uint256 fromNumerator = fromAmount * lstConfigs[fromLST].exchangeRate;
        uint256 underlyingAmount = fromNumerator / WAD;
        underlyingBalanceOfLST[fromLST] += underlyingAmount;

        uint256 feeUnderlying = (fromNumerator * swapFeeBps) / (WAD * MAX_BPS);
        uint256 netUnderlying = underlyingAmount - feeUnderlying;
        toAmount = (netUnderlying * WAD) / lstConfigs[toLST].exchangeRate;

        if (toAmount == 0) revert ZeroAmount();

        uint256 toBal = poolBalanceOfLST[toLST];
        if (toBal < toAmount) revert InsufficientPoolBalance();
        poolBalanceOfLST[toLST] = toBal - toAmount;
        underlyingBalanceOfLST[toLST] -= netUnderlying;

        IERC20(toLST).safeTransfer(msg.sender, toAmount);

        emit Swap(msg.sender, fromLST, toLST, fromAmount, toAmount, feeUnderlying);
        return toAmount;
    }

    function previewSwap(address fromLST, address toLST, uint256 fromAmount)
        external
        view
        onlySupportedLST(fromLST)
        onlySupportedLST(toLST)
        returns (uint256 toAmount, uint256 feeUnderlying)
    {
        if (fromLST == toLST) revert SameLSTSwap();
        if (fromAmount == 0) revert ZeroAmount();

        uint256 fromNumerator = fromAmount * lstConfigs[fromLST].exchangeRate;
        uint256 underlyingAmount = fromNumerator / WAD;
        feeUnderlying = (fromNumerator * swapFeeBps) / (WAD * MAX_BPS);
        uint256 netUnderlying = underlyingAmount - feeUnderlying;
        toAmount = (netUnderlying * WAD) / lstConfigs[toLST].exchangeRate;
    }
}
