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

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

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

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableZeroAddress();
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableZeroAddress();
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error PausedEnforced();
    error PausedNotEnforced();

    constructor() {
        _paused = false;
    }

    modifier whenPaused() {
        if (!paused()) revert PausedNotEnforced();
        _;
    }

    modifier whenNotPaused() {
        if (paused()) revert PausedEnforced();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract PaymentRoutingHub is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_MERCHANTS = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 50;
    uint256 public constant MAX_FEE_BPS = 1000;

    IERC20 public immutable stablecoin;

    uint256 public feeBps;
    uint256 public totalFeesCollected;
    uint256 public totalDeposits;

    address[] private _merchantList;
    mapping(address => bool) public isMerchant;
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Payment(address indexed from, address indexed merchant, uint256 amount, uint256 fee);
    event Withdrawn(address indexed user, uint256 amount);
    event MerchantRegistered(address indexed merchant);
    event MerchantDeregistered(address indexed merchant);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesCollected(address indexed collector, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error NotMerchant(address account);
    error MerchantAlreadyRegistered(address account);
    error MaxMerchantsReached(uint256 currentCount, uint256 max);
    error InsufficientBalance(uint256 available, uint256 required);
    error FeeExceedsCap(uint256 feeBps, uint256 maxFeeBps);
    error InsufficientFees(uint256 available, uint256 requested);

    modifier mustBeMerchant(address merchant) {
        if (!isMerchant[merchant]) revert NotMerchant(merchant);
        _;
    }

    constructor(address _stablecoin) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        feeBps = DEFAULT_FEE_BPS;
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        balances[msg.sender] += amount;
        totalDeposits += amount;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function pay(address merchant, uint256 amount) external whenNotPaused nonReentrant mustBeMerchant(merchant) {
        if (amount == 0) revert ZeroAmount();
        uint256 fee = (amount * feeBps) / FEE_DENOMINATOR;
        uint256 totalCost = amount + fee;
        uint256 available = balances[msg.sender];
        if (available < totalCost) {
            revert InsufficientBalance(available, totalCost);
        }

        balances[msg.sender] = available - totalCost;
        totalDeposits -= amount;
        totalFeesCollected += fee;

        stablecoin.safeTransfer(merchant, amount);
        emit Payment(msg.sender, merchant, amount, fee);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = balances[msg.sender];
        if (available < amount) {
            revert InsufficientBalance(available, amount);
        }

        balances[msg.sender] = available - amount;
        totalDeposits -= amount;

        stablecoin.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function registerMerchant(address merchant) external onlyOwner {
        if (merchant == address(0)) revert ZeroAddress();
        if (isMerchant[merchant]) revert MerchantAlreadyRegistered(merchant);
        if (_merchantList.length >= MAX_MERCHANTS) {
            revert MaxMerchantsReached(_merchantList.length, MAX_MERCHANTS);
        }
        isMerchant[merchant] = true;
        _merchantList.push(merchant);
        emit MerchantRegistered(merchant);
    }

    function deregisterMerchant(address merchant) external onlyOwner {
        if (!isMerchant[merchant]) revert NotMerchant(merchant);
        isMerchant[merchant] = false;
        uint256 len = _merchantList.length;
        for (uint256 i = 0; i < len; ++i) {
            if (_merchantList[i] == merchant) {
                _merchantList[i] = _merchantList[len - 1];
                _merchantList.pop();
                break;
            }
        }
        emit MerchantDeregistered(merchant);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(newFeeBps, MAX_FEE_BPS);
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(oldFeeBps, newFeeBps);
    }

    function collectFees(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (amount > totalFeesCollected) revert InsufficientFees(totalFeesCollected, amount);
        totalFeesCollected -= amount;
        stablecoin.safeTransfer(owner(), amount);
        emit FeesCollected(owner(), amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function merchantCount() external view returns (uint256) {
        return _merchantList.length;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function getMerchants() external view returns (address[] memory) {
        return _merchantList;
    }

    function contractTokenBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
