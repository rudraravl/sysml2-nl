// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LRTAggregatorVault {
    uint256 public constant MAX_SUPPORTED_LRTS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 1000; // 10%

    address public operator;
    uint256 public redemptionFeeBasisPoints;
    bool public depositsPaused;

    uint256 public totalShares;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public totalLRT;
    mapping(address => mapping(address => uint256)) public userDeposits;

    mapping(address => bool) public isSupportedLRT;
    address[] private _supportedLRTs;

    uint256 private _locked = 1;

    event Deposit(address indexed user, address indexed lrt, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed lrt, uint256 amount, uint256 shares);
    event Redeem(address indexed user, uint256 shares, uint256[] amounts);
    event LRTAdded(address indexed lrt);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositsPausedStateChanged(bool paused);
    event OperatorUpdated(address oldOperator, address newOperator);

    error NotOperator();
    error ZeroAddress();
    error LRTNotSupported();
    error LRTAlreadySupported();
    error MaxLRTsReached();
    error DepositsArePaused();
    error InvalidAmount();
    error InvalidFee();
    error InsufficientShares();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error TransferFailed();
    error ReentrancyGuard();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        redemptionFeeBasisPoints = 50; // 0.5%
        emit OperatorUpdated(address(0), _operator);
        emit RedemptionFeeUpdated(0, 50);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function addSupportedLRT(address lrt) external onlyOperator {
        if (lrt == address(0)) revert ZeroAddress();
        if (isSupportedLRT[lrt]) revert LRTAlreadySupported();
        if (_supportedLRTs.length >= MAX_SUPPORTED_LRTS) revert MaxLRTsReached();
        isSupportedLRT[lrt] = true;
        _supportedLRTs.push(lrt);
        emit LRTAdded(lrt);
    }

    function updateRedemptionFee(uint256 _feeBasisPoints) external onlyOperator {
        if (_feeBasisPoints > MAX_REDEMPTION_FEE_BPS) revert InvalidFee();
        uint256 old = redemptionFeeBasisPoints;
        redemptionFeeBasisPoints = _feeBasisPoints;
        emit RedemptionFeeUpdated(old, _feeBasisPoints);
    }

    function setDepositsPaused(bool _paused) external onlyOperator {
        depositsPaused = _paused;
        emit DepositsPausedStateChanged(_paused);
    }

    function deposit(address lrt, uint256 amount) external nonReentrant {
        if (depositsPaused) revert DepositsArePaused();
        if (!isSupportedLRT[lrt]) revert LRTNotSupported();
        if (amount == 0) revert InvalidAmount();

        if (!IERC20(lrt).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        userDeposits[msg.sender][lrt] += amount;
        totalLRT[lrt] += amount;
        userShares[msg.sender] += amount;
        totalShares += amount;

        emit Deposit(msg.sender, lrt, amount, amount);
    }

    function withdraw(address lrt, uint256 amount) external nonReentrant {
        if (!isSupportedLRT[lrt]) revert LRTNotSupported();
        if (amount == 0) revert InvalidAmount();
        if (userDeposits[msg.sender][lrt] < amount) revert InsufficientDeposit();
        if (userShares[msg.sender] < amount) revert InsufficientShares();
        if (totalLRT[lrt] < amount) revert InsufficientLiquidity();

        userDeposits[msg.sender][lrt] -= amount;
        userShares[msg.sender] -= amount;
        totalShares -= amount;
        totalLRT[lrt] -= amount;

        if (!IERC20(lrt).transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdraw(msg.sender, lrt, amount, amount);
    }

    function redeem(uint256 shares) external nonReentrant {
        if (shares == 0) revert InvalidAmount();
        if (userShares[msg.sender] < shares) revert InsufficientShares();
        if (totalShares == 0) revert InsufficientLiquidity();

        uint256 oldTotalShares = totalShares;
        uint256 len = _supportedLRTs.length;
        uint256[] memory amounts = new uint256[](len);
        uint256[] memory fees = new uint256[](len);

        // ============================================================
        // Effects phase: compute all amounts/fees and update all state
        // before any external token transfers (checks-effects-interactions).
        // ============================================================
        for (uint256 i = 0; i < len; ) {
            address lrt = _supportedLRTs[i];
            uint256 lrtBalance = totalLRT[lrt];
            uint256 grossAmount = (shares * lrtBalance) / oldTotalShares;

            if (grossAmount != 0) {
                amounts[i] = grossAmount;

                // Fee computed from the full-precision product to avoid
                // divide-before-multiply precision loss: instead of
                //   fee = grossAmount * bps / denom   (multiply a pre-rounded value)
                // we compute:
                //   fee = (shares * lrtBalance * bps) / (oldTotalShares * denom)
                // performing all multiplications before the single division.
                fees[i] = (shares * lrtBalance * redemptionFeeBasisPoints)
                    / (oldTotalShares * FEE_DENOMINATOR);

                // Update accounting for this LRT before any transfers.
                totalLRT[lrt] = lrtBalance - grossAmount;
                uint256 prev = userDeposits[msg.sender][lrt];
                userDeposits[msg.sender][lrt] = prev > grossAmount
                    ? prev - grossAmount
                    : 0;
            }

            unchecked { ++i; }
        }

        // Burn the redeemed shares.
        userShares[msg.sender] -= shares;
        totalShares -= shares;

        // ============================================================
        // Interactions phase: transfer tokens only after all state
        // has been settled, eliminating reentrancy surface.
        // ============================================================
        for (uint256 i = 0; i < len; ) {
            address lrt = _supportedLRTs[i];
            uint256 grossAmount = amounts[i];

            if (grossAmount != 0) {
                uint256 fee = fees[i];
                uint256 net = grossAmount - fee;

                if (fee > 0) {
                    if (!IERC20(lrt).transfer(operator, fee)) revert TransferFailed();
                }
                if (net > 0) {
                    if (!IERC20(lrt).transfer(msg.sender, net)) revert TransferFailed();
                }
            }

            unchecked { ++i; }
        }

        emit Redeem(msg.sender, shares, amounts);
    }

    function getSupportedLRTs() external view returns (address[] memory) {
        return _supportedLRTs;
    }

    function supportedLRTCount() external view returns (uint256) {
        return _supportedLRTs.length;
    }

    function getUserDeposit(address user, address lrt) external view returns (uint256) {
        return userDeposits[user][lrt];
    }

    function getTotalLRT(address lrt) external view returns (uint256) {
        return totalLRT[lrt];
    }
}
