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

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

interface IRestakingProtocol {
    function initiateWithdrawal(address staker, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract WrappedBitcoinVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error DepositBelowMinimum();
    error InsufficientBalance();
    error FeeExceedsCap();
    error NotOperator();
    error NothingRestaked();
    error AmountZero();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 fee);
    event RestakeWithdrawalInitiated(address indexed user, uint256 amount);
    event FeeUpdated(address indexed operator, uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event RestakingProtocolUpdated(address indexed oldProtocol, address indexed newProtocol);

    uint256 public constant FEE_CAP = 50; // 0.5% in basis points (50 / 10000)
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 0.0001 * 1e8; // 0.0001 wrapped Bitcoin (8 decimals)

    IERC20 public immutable wbtc;
    IRestakingProtocol public restakingProtocol;
    address public operator;
    uint256 public withdrawalFeeBps;

    mapping(address => uint256) public userBalances;
    uint256 public totalDeposited;

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NotOperator();
        }
        _;
    }

    constructor(
        address _wbtc,
        address _restakingProtocol,
        address _operator,
        uint256 _initialFeeBps
    ) Ownable(msg.sender) {
        if (_wbtc == address(0) || _operator == address(0) || _restakingProtocol == address(0)) {
            revert ZeroAddress();
        }
        if (_initialFeeBps > FEE_CAP) {
            revert FeeExceedsCap();
        }

        wbtc = IERC20(_wbtc);
        restakingProtocol = IRestakingProtocol(_restakingProtocol);
        operator = _operator;
        withdrawalFeeBps = _initialFeeBps;

        emit FeeUpdated(address(0), 0, _initialFeeBps);
        emit OperatorUpdated(address(0), _operator);
        emit RestakingProtocolUpdated(address(0), _restakingProtocol);
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount < MIN_DEPOSIT) {
            revert DepositBelowMinimum();
        }

        uint256 balanceBefore = wbtc.balanceOf(address(this));
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = wbtc.balanceOf(address(this)) - balanceBefore;

        userBalances[msg.sender] += received;
        totalDeposited += received;

        emit Deposited(msg.sender, received);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert AmountZero();
        }
        if (userBalances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        uint256 fee = (amount * withdrawalFeeBps) / FEE_DENOMINATOR;
        uint256 payout = amount - fee;

        userBalances[msg.sender] -= amount;
        totalDeposited -= amount;

        if (payout > 0) {
            wbtc.safeTransfer(msg.sender, payout);
        }
        if (fee > 0) {
            wbtc.safeTransfer(owner(), fee);
        }

        emit Withdrawn(msg.sender, payout, fee);
    }

    function initiateRestakeWithdrawal(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert NothingRestaked();
        }

        uint256 restakedBalance = restakingProtocol.balanceOf(address(this));
        if (restakedBalance < amount) {
            revert InsufficientBalance();
        }

        restakingProtocol.initiateWithdrawal(msg.sender, amount);

        emit RestakeWithdrawalInitiated(msg.sender, amount);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > FEE_CAP) {
            revert FeeExceedsCap();
        }
        uint256 oldFee = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit FeeUpdated(msg.sender, oldFee, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) {
            revert ZeroAddress();
        }
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setRestakingProtocol(address newProtocol) external onlyOwner {
        if (newProtocol == address(0)) {
            revert ZeroAddress();
        }
        address old = address(restakingProtocol);
        restakingProtocol = IRestakingProtocol(newProtocol);
        emit RestakingProtocolUpdated(old, newProtocol);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function balanceOf(address user) external view returns (uint256) {
        return userBalances[user];
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * withdrawalFeeBps) / FEE_DENOMINATOR;
    }
}
