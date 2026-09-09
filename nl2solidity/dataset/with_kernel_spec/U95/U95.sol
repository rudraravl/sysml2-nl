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

contract DepositVault {
    /* ========== Constants ========== */

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_DEPOSIT_FEE_BPS = 500; // 5%
    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%

    /* ========== State Variables ========== */

    IERC20 public immutable wrappedToken;
    address public owner;
    uint256 public depositFeeBps;
    bool public depositsPaused;
    uint256 private _locked = 1;

    mapping(address => uint256) public nativeBalances;
    mapping(address => uint256) public wrappedBalances;
    uint256 public totalNativeDeposits;
    uint256 public totalWrappedDeposits;

    /* ========== Errors ========== */

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error DepositsArePaused();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();

    /* ========== Events ========== */

    event NativeDeposited(address indexed user, uint256 netAmount, uint256 fee);
    event WrappedDeposited(address indexed user, uint256 netAmount, uint256 fee);
    event NativeWithdrawn(address indexed user, uint256 netAmount, uint256 fee);
    event WrappedWithdrawn(address indexed user, uint256 netAmount, uint256 fee);
    event DepositFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event DepositsPaused();
    event DepositsUnpaused();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesClaimed(address indexed owner, uint256 nativeAmount, uint256 wrappedAmount);

    /* ========== Modifiers ========== */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ========== Constructor ========== */

    constructor(address wrappedToken_) {
        if (wrappedToken_ == address(0)) revert ZeroAddress();
        wrappedToken = IERC20(wrappedToken_);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ========== Receive ========== */

    receive() external payable {
        depositNative();
    }

    /* ========== Internal Safe Transfer Helpers ========== */

    function _safeTransferToken(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferTokenFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    /* ========== Deposit Functions ========== */

    function depositNative() public payable nonReentrant whenDepositsNotPaused {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        nativeBalances[msg.sender] += netAmount;
        totalNativeDeposits += netAmount;

        emit NativeDeposited(msg.sender, netAmount, fee);
    }

    function depositWrapped(uint256 amount) external nonReentrant whenDepositsNotPaused {
        if (amount == 0) revert ZeroAmount();

        _safeTransferTokenFrom(address(wrappedToken), msg.sender, address(this), amount);

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        wrappedBalances[msg.sender] += netAmount;
        totalWrappedDeposits += netAmount;

        emit WrappedDeposited(msg.sender, netAmount, fee);
    }

    /* ========== Withdrawal Functions ========== */

    function withdrawNative(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (nativeBalances[msg.sender] < amount) revert InsufficientBalance();

        nativeBalances[msg.sender] -= amount;
        totalNativeDeposits -= amount;

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        (bool success, ) = payable(msg.sender).call{value: netAmount}("");
        if (!success) revert TransferFailed();

        emit NativeWithdrawn(msg.sender, netAmount, fee);
    }

    function withdrawWrapped(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (wrappedBalances[msg.sender] < amount) revert InsufficientBalance();

        wrappedBalances[msg.sender] -= amount;
        totalWrappedDeposits -= amount;

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        _safeTransferToken(address(wrappedToken), msg.sender, netAmount);

        emit WrappedWithdrawn(msg.sender, netAmount, fee);
    }

    /* ========== Admin Functions ========== */

    function setDepositFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_DEPOSIT_FEE_BPS) revert InvalidFee();
        uint256 oldFeeBps = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit DepositFeeUpdated(oldFeeBps, newFeeBps);
    }

    function pauseDeposits() external onlyOwner {
        depositsPaused = true;
        emit DepositsPaused();
    }

    function unpauseDeposits() external onlyOwner {
        depositsPaused = false;
        emit DepositsUnpaused();
    }

    function claimFees() external onlyOwner nonReentrant {
        uint256 nativeFeeBalance = address(this).balance - totalNativeDeposits;
        uint256 wrappedFeeBalance = wrappedToken.balanceOf(address(this)) - totalWrappedDeposits;

        if (nativeFeeBalance > 0) {
            (bool success, ) = payable(owner).call{value: nativeFeeBalance}("");
            if (!success) revert TransferFailed();
        }

        if (wrappedFeeBalance > 0) {
            _safeTransferToken(address(wrappedToken), owner, wrappedFeeBalance);
        }

        emit FeesClaimed(owner, nativeFeeBalance, wrappedFeeBalance);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
