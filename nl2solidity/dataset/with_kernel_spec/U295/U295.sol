// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract RWARestakingPool {
    address public owner;
    address public operator;
    address public feeRecipient;
    IERC20 public collateralToken;

    uint256 public totalCollateralDeposited;
    uint256 public totalLRTSupply;

    uint256 public exchangeRate;
    bool public depositsPaused;
    address public implementation;

    mapping(address => uint256) public depositedCollateral;
    mapping(address => uint256) public lrtBalance;

    uint256 public constant REDEMPTION_FEE_BPS = 50;
    uint256 public constant MAX_RATE_ADJUSTMENT_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    uint256 private _locked;

    event Deposit(address indexed depositor, uint256 collateralAmount, uint256 lrtMinted);
    event Redemption(address indexed redeemer, uint256 lrtBurned, uint256 collateralReturned, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event DepositsPausedChanged(bool paused);
    event Upgraded(address indexed oldImplementation, address indexed newImplementation);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event EtherWithdrawn(address indexed recipient, uint256 amount);

    error NotOwner();
    error NotOperator();
    error DepositsArePaused();
    error ZeroAddress();
    error InvalidAmount();
    error RateAdjustmentTooLarge();
    error InsufficientLRTBalance();
    error TransferFailed();
    error InvalidExchangeRate();
    error NoImplementationSet();
    error ReentrantCall();
    error AmountTooLarge();
    error EtherTransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address _collateralToken, address _operator, address _feeRecipient) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        collateralToken = IERC20(_collateralToken);
        exchangeRate = PRECISION;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(address(0), _operator);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (amount > type(uint256).max / PRECISION) revert AmountTooLarge();

        uint256 lrtToMint = (amount * PRECISION) / exchangeRate;
        if (lrtToMint == 0) revert InvalidAmount();

        depositedCollateral[msg.sender] += amount;
        lrtBalance[msg.sender] += lrtToMint;
        totalCollateralDeposited += amount;
        totalLRTSupply += lrtToMint;

        _safeTransferFrom(address(collateralToken), msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, lrtToMint);
    }

    function redeem(uint256 lrtAmount) external nonReentrant {
        if (lrtAmount == 0) revert InvalidAmount();
        uint256 userLRT = lrtBalance[msg.sender];
        if (userLRT < lrtAmount) revert InsufficientLRTBalance();

        // Compute fee from the full-precision product to avoid divide-before-multiply.
        uint256 rawCollateral = lrtAmount * exchangeRate;
        uint256 fee = (rawCollateral * REDEMPTION_FEE_BPS) / (PRECISION * BPS_DENOMINATOR);
        uint256 grossCollateral = rawCollateral / PRECISION;
        uint256 netCollateral = grossCollateral - fee;

        uint256 userDeposited = depositedCollateral[msg.sender];
        uint256 collateralToDeduct = (lrtAmount * userDeposited) / userLRT;

        lrtBalance[msg.sender] = userLRT - lrtAmount;
        depositedCollateral[msg.sender] = userDeposited - collateralToDeduct;
        totalLRTSupply -= lrtAmount;
        if (totalCollateralDeposited >= grossCollateral) {
            totalCollateralDeposited -= grossCollateral;
        } else {
            totalCollateralDeposited = 0;
        }

        if (netCollateral > 0) {
            _safeTransfer(address(collateralToken), msg.sender, netCollateral);
        }
        if (fee > 0 && feeRecipient != address(0)) {
            _safeTransfer(address(collateralToken), feeRecipient, fee);
        }

        emit Redemption(msg.sender, lrtAmount, netCollateral, fee);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();

        uint256 oldRate = exchangeRate;
        uint256 maxDelta = (oldRate * MAX_RATE_ADJUSTMENT_BPS) / BPS_DENOMINATOR;

        if (newRate > oldRate) {
            if (newRate - oldRate > maxDelta) revert RateAdjustmentTooLarge();
        } else if (newRate < oldRate) {
            if (oldRate - newRate > maxDelta) revert RateAdjustmentTooLarge();
        }

        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function setDepositsPaused(bool paused) external onlyOperator {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorSet(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address old = implementation;
        implementation = newImplementation;
        emit Upgraded(old, newImplementation);
    }

    function getCollateralForLRT(uint256 lrtAmount)
        external
        view
        returns (uint256 gross, uint256 fee, uint256 net)
    {
        uint256 rawCollateral = lrtAmount * exchangeRate;
        fee = (rawCollateral * REDEMPTION_FEE_BPS) / (PRECISION * BPS_DENOMINATOR);
        gross = rawCollateral / PRECISION;
        net = gross - fee;
    }

    function getLRTForCollateral(uint256 collateralAmount) external view returns (uint256) {
        return (collateralAmount * PRECISION) / exchangeRate;
    }

    function withdrawEther(address payable recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (amount > balance) revert InvalidAmount();

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert EtherTransferFailed();

        emit EtherWithdrawn(recipient, amount);
    }

    fallback() external payable {
        address impl = implementation;
        if (impl == address(0)) revert NoImplementationSet();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
