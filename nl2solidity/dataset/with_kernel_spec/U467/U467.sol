// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPriceOracle {
    /// @notice Returns the price of 1 unit of `token` in debt-token terms, scaled to 1e18.
    function getPrice(address token) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
            revert("SafeERC20: low-level call failed");
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract AccessControl {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    mapping(bytes32 => mapping(address => bool)) internal _roles;
    mapping(bytes32 => bytes32) internal _roleAdmins;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender is missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roleAdmins[role];
        return admin == bytes32(0) ? DEFAULT_ADMIN_ROLE : admin;
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roleAdmins[role] = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
}

contract ReentrancyGuard {
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

contract CreditLineManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MAX_ANNUAL_INTEREST_RATE = 2_000;       // 20% in basis points
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15_000;   // 150% in basis points
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable debtToken;
    IPriceOracle public immutable oracle;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public annualInterestRate;       // basis points
    uint256 public minCollateralRatio;       // basis points
    bool public borrowingPaused;

    uint256 public interestIndex;            // global interest accrual index, starts at PRECISION
    uint256 public lastInterestUpdate;       // timestamp of last index update

    struct CollateralConfig {
        bool approved;
        uint256 collateralFactor;           // basis points, 0 < cf <= BPS_DENOMINATOR
    }
    mapping(address => CollateralConfig) public collateralConfigs;
    address[] public approvedCollateralTokens;

    mapping(address => mapping(address => uint256)) public collateralDeposited; // user => token => amount
    mapping(address => uint256) public debtShares; // user => debt shares (debt = shares * interestIndex / PRECISION)

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event CollateralTokenUpdated(address indexed token, bool approved, uint256 collateralFactor);
    event BorrowingPausedChanged(bool paused);
    event InterestAccrued(uint256 oldIndex, uint256 newIndex, uint256 elapsed);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error CollateralTokenNotApproved(address token);
    error InsufficientCollateral();
    error InsufficientDebtTokenBalance();
    error InsufficientCollateralBalance();
    error NoOutstandingDebt();
    error BorrowingPausedError();
    error InterestRateTooHigh(uint256 rate, uint256 max);
    error CollateralizationRatioTooLow(uint256 ratio, uint256 min);
    error InvalidCollateralFactor();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _debtToken, address _oracle) {
        if (_debtToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();

        debtToken = IERC20(_debtToken);
        oracle = IPriceOracle(_oracle);

        annualInterestRate = 500;                           // 5% default
        minCollateralRatio = MIN_COLLATERALIZATION_RATIO;   // 150%
        interestIndex = PRECISION;
        lastInterestUpdate = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenBorrowingNotPaused() {
        if (borrowingPaused) revert BorrowingPausedError();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: INTEREST & VALUE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrues interest globally by updating the interest index.
    function _accrueInterest() internal {
        if (block.timestamp > lastInterestUpdate) {
            uint256 elapsed = block.timestamp - lastInterestUpdate;
            uint256 oldIndex = interestIndex;
            interestIndex =
                oldIndex +
                (oldIndex * annualInterestRate * elapsed) /
                (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            lastInterestUpdate = block.timestamp;
            emit InterestAccrued(oldIndex, interestIndex, elapsed);
        }
    }

    /// @dev Returns the current interest index, including pending (un-accrued) interest.
    function _pendingInterestIndex() internal view returns (uint256) {
        if (block.timestamp > lastInterestUpdate) {
            uint256 elapsed = block.timestamp - lastInterestUpdate;
            return
                interestIndex +
                (interestIndex * annualInterestRate * elapsed) /
                (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        }
        return interestIndex;
    }

    /// @dev Returns the outstanding debt for a user including all accrued interest.
    function _currentDebt(address user) internal view returns (uint256) {
        return (debtShares[user] * _pendingInterestIndex()) / PRECISION;
    }

    /// @dev Computes the risk-adjusted value of a given amount of a collateral token.
    function _getTokenValue(address token, uint256 amount) internal view returns (uint256) {
        if (amount == 0) return 0;
        uint256 price = oracle.getPrice(token);
        uint256 factor = collateralConfigs[token].collateralFactor;
        return (amount * price * factor) / (PRECISION * BPS_DENOMINATOR);
    }

    /// @dev Computes total risk-adjusted collateral value for a user across all tokens.
    function _getTotalCollateralValue(address user) internal view returns (uint256) {
        uint256 totalValue = 0;
        uint256 len = approvedCollateralTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address token = approvedCollateralTokens[i];
            uint256 amount = collateralDeposited[user][token];
            if (amount > 0) {
                totalValue += _getTokenValue(token, amount);
            }
        }
        return totalValue;
    }

    /// @dev Reverts if the user's position is under-collateralized for the given debt.
    function _checkCollateralization(address user, uint256 debt) internal view {
        if (debt > 0) {
            uint256 collateralValue = _getTotalCollateralValue(user);
            if (collateralValue * BPS_DENOMINATOR < debt * minCollateralRatio) {
                revert InsufficientCollateral();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL: DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits an approved collateral token into the protocol.
    /// @param token  The address of the collateral token.
    /// @param amount The amount to deposit (in token's native decimals).
    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].approved) revert CollateralTokenNotApproved(token);

        // Effects
        collateralDeposited[msg.sender][token] += amount;

        // Interactions
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL: BORROW
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrows debt tokens against deposited collateral.
    /// @param amount The amount of debt tokens to borrow.
    function borrow(uint256 amount) external nonReentrant whenBorrowingNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest();

        uint256 currentDebt = _currentDebt(msg.sender);
        uint256 newDebt = currentDebt + amount;

        _checkCollateralization(msg.sender, newDebt);

        if (debtToken.balanceOf(address(this)) < amount) {
            revert InsufficientDebtTokenBalance();
        }

        // Effects: mint debt shares proportional to amount
        // shares = amount * PRECISION / interestIndex
        debtShares[msg.sender] += (amount * PRECISION) / interestIndex;

        // Interactions
        debtToken.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL: REPAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Repays outstanding debt. If amount exceeds current debt, only the outstanding
    ///         portion is collected.
    /// @param amount The amount of debt tokens to repay.
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest();

        uint256 currentDebt = _currentDebt(msg.sender);

        if (currentDebt > 0) {
            uint256 actualRepay = amount > currentDebt ? currentDebt : amount;

            // Compute shares to remove; when fully repaying, clear all shares
            uint256 sharesToRemove;
            if (actualRepay >= currentDebt) {
                sharesToRemove = debtShares[msg.sender];
            } else {
                sharesToRemove = (actualRepay * PRECISION) / interestIndex;
            }

            // Effects
            debtShares[msg.sender] -= sharesToRemove;

            // Interactions
            debtToken.safeTransferFrom(msg.sender, address(this), actualRepay);

            emit Repaid(msg.sender, actualRepay);
        } else {
            revert NoOutstandingDebt();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL: WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraws collateral, provided the position remains sufficiently collateralized.
    /// @param token  The address of the collateral token to withdraw.
    /// @param amount The amount to withdraw.
    function withdrawCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 deposited = collateralDeposited[msg.sender][token];
        if (amount > deposited) revert InsufficientCollateralBalance();

        _accrueInterest();

        // Effects
        collateralDeposited[msg.sender][token] = deposited - amount;

        // Checks: position must remain healthy after withdrawal
        uint256 debt = _currentDebt(msg.sender);
        _checkCollateralization(msg.sender, debt);

        // Interactions
        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL: VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total outstanding debt for a user (principal + accrued interest).
    function getDebt(address user) external view returns (uint256) {
        return _currentDebt(user);
    }

    /// @notice Returns the total risk-adjusted collateral value for a user (in debt-token terms).
    function getCollateralValue(address user) external view returns (uint256) {
        return _getTotalCollateralValue(user);
    }

    /// @notice Returns the available credit for a user — additional debt they can safely take on.
    function getAvailableCredit(address user) external view returns (uint256) {
        uint256 collateralValue = _getTotalCollateralValue(user);
        uint256 maxDebt = (collateralValue * BPS_DENOMINATOR) / minCollateralRatio;
        uint256 debt = _currentDebt(user);

        if (maxDebt <= debt) return 0;
        return maxDebt - debt;
    }

    /// @notice Returns the deposited amount of a specific collateral token for a user.
    function getCollateralAmount(address user, address token) external view returns (uint256) {
        return collateralDeposited[user][token];
    }

    /// @notice Returns the list of all approved collateral token addresses.
    function getApprovedCollateralTokens() external view returns (address[] memory) {
        return approvedCollateralTokens;
    }

    /// @notice Returns a summary of a user's credit position.
    function getPosition(
        address user
    ) external view returns (uint256 totalCollateralValue, uint256 debt, uint256 availableCredit) {
        totalCollateralValue = _getTotalCollateralValue(user);
        debt = _currentDebt(user);
        uint256 maxDebt = (totalCollateralValue * BPS_DENOMINATOR) / minCollateralRatio;
        availableCredit = maxDebt > debt ? maxDebt - debt : 0;
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR: CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the global annual interest rate (in basis points). Maximum 2000 (20%).
    /// @param newRate The new annual interest rate in basis points.
    function setInterestRate(uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        if (newRate > MAX_ANNUAL_INTEREST_RATE) {
            revert InterestRateTooHigh(newRate, MAX_ANNUAL_INTEREST_RATE);
        }

        _accrueInterest();

        uint256 oldRate = annualInterestRate;
        annualInterestRate = newRate;

        emit InterestRateUpdated(oldRate, newRate);
    }

    /// @notice Sets the global minimum collateralization ratio (in basis points). Minimum 15000 (150%).
    /// @param newRatio The new minimum collateralization ratio in basis points.
    function setMinCollateralRatio(uint256 newRatio) external onlyRole(OPERATOR_ROLE) {
        if (newRatio < MIN_COLLATERALIZATION_RATIO) {
            revert CollateralizationRatioTooLow(newRatio, MIN_COLLATERALIZATION_RATIO);
        }

        _accrueInterest();

        uint256 oldRatio = minCollateralRatio;
        minCollateralRatio = newRatio;

        emit CollateralizationRatioUpdated(oldRatio, newRatio);
    }

    /// @notice Approves a collateral token with a given collateral factor.
    /// @param token            The token address to approve.
    /// @param collateralFactor The collateral factor in basis points (e.g. 8000 = 80%).
    function approveCollateralToken(
        address token,
        uint256 collateralFactor
    ) external onlyRole(OPERATOR_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (collateralFactor == 0 || collateralFactor > BPS_DENOMINATOR) {
            revert InvalidCollateralFactor();
        }

        if (!collateralConfigs[token].approved) {
            approvedCollateralTokens.push(token);
        }

        collateralConfigs[token] = CollateralConfig({
            approved: true,
            collateralFactor: collateralFactor
        });

        emit CollateralTokenUpdated(token, true, collateralFactor);
    }

    /// @notice Revokes a previously approved collateral token. Existing deposits may
    ///         still be withdrawn but no new deposits are accepted.
    /// @param token The token address to revoke.
    function revokeCollateralToken(address token) external onlyRole(OPERATOR_ROLE) {
        if (!collateralConfigs[token].approved) revert CollateralTokenNotApproved(token);

        collateralConfigs[token].approved = false;

        // Remove from the approved tokens array (swap-and-pop)
        uint256 len = approvedCollateralTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedCollateralTokens[i] == token) {
                approvedCollateralTokens[i] = approvedCollateralTokens[len - 1];
                approvedCollateralTokens.pop();
                break;
            }
        }

        emit CollateralTokenUpdated(token, false, 0);
    }

    /// @notice Pauses or unpauses all borrowing operations. Repayments and withdrawals
    ///         remain available regardless of pause state.
    /// @param _paused Whether borrowing should be paused.
    function setBorrowingPaused(bool _paused) external onlyRole(OPERATOR_ROLE) {
        borrowingPaused = _paused;
        emit BorrowingPausedChanged(_paused);
    }
}
