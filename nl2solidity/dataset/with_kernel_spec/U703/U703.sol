// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract BasketStablecoin {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error CollateralNotApproved();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InsufficientAllowance();
    error RatioTooLow();
    error FeeTooHigh();
    error NothingToRedeem();
    error NoDebt();
    error TransferToZero();
    error ReentrantCall();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amountBurned, uint256 feeTaken);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event CollateralAdded(address indexed token);
    event CollateralRemoved(address indexed token);
    event CollateralPriceUpdated(address indexed token, uint256 price);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                            METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                            STABLECOIN STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                          COLLATERAL STATE
    //////////////////////////////////////////////////////////////*/
    /// @dev user => token => amount of collateral deposited
    mapping(address => mapping(address => uint256)) public userCollateral;
    /// @dev token => total collateral held in reserve
    mapping(address => uint256) public reserveBalance;
    /// @dev list of all approved collateral tokens
    address[] public collateralList;
    /// @dev token => approved
    mapping(address => bool) public approvedCollateral;
    /// @dev token => price in USD with 18 decimals
    mapping(address => uint256) public collateralPrice;

    /// @dev user => outstanding minted stablecoin debt
    mapping(address => uint256) public userDebt;

    /*//////////////////////////////////////////////////////////////
                          CONFIG STATE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;

    /// @dev Minimum collateralization ratio in basis points. 150% = 15000.
    uint256 public collateralizationRatio; // bps
    /// @dev Redemption fee in basis points. 0.1% = 10.
    uint256 public redemptionFee; // bps
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MIN_RATIO = 15000; // 150%
    uint256 public constant BPS = 10000;

    /*//////////////////////////////////////////////////////////////
                         REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        string memory _name,
        string memory _symbol,
        address _operator
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = _operator;
        collateralizationRatio = MIN_RATIO;
        redemptionFee = 10; // 0.1%
        emit CollateralizationRatioUpdated(0, MIN_RATIO);
        emit RedemptionFeeUpdated(0, 10);
        emit OperatorUpdated(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_RATIO) revert RatioTooLow();
        uint256 old = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(old, newRatio);
    }

    function setRedemptionFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        uint256 old = redemptionFee;
        redemptionFee = newFee;
        emit RedemptionFeeUpdated(old, newFee);
    }

    function addCollateral(address token, uint256 price) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (price == 0) revert ZeroAddress();
        if (!approvedCollateral[token]) {
            approvedCollateral[token] = true;
            collateralList.push(token);
            emit CollateralAdded(token);
        }
        collateralPrice[token] = price;
        emit CollateralPriceUpdated(token, price);
    }

    function removeCollateral(address token) external onlyOperator {
        if (!approvedCollateral[token]) revert CollateralNotApproved();
        approvedCollateral[token] = false;
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            if (collateralList[i] == token) {
                collateralList[i] = collateralList[len - 1];
                collateralList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit CollateralRemoved(token);
    }

    function setCollateralPrice(address token, uint256 price) external onlyOperator {
        if (!approvedCollateral[token]) revert CollateralNotApproved();
        if (price == 0) revert ZeroAddress();
        collateralPrice[token] = price;
        emit CollateralPriceUpdated(token, price);
    }

    function collateralCount() external view returns (uint256) {
        return collateralList.length;
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL VALUATION
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the USD value (18 decimals) of a user's collateral.
    function collateralValue(address user) public view returns (uint256 value) {
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = collateralList[i];
            uint256 amount = userCollateral[user][token];
            if (amount > 0) {
                uint256 price = collateralPrice[token];
                // amount and price both assumed 18 decimals; product / 1e18
                value += (amount * price) / 1e18;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the maximum mintable stablecoin for a user given the ratio.
    function maxMintable(address user) external view returns (uint256) {
        uint256 cv = collateralValue(user);
        if (cv == 0) return 0;
        uint256 allowed = (cv * BPS) / collateralizationRatio;
        if (userDebt[user] >= allowed) return 0;
        return allowed - userDebt[user];
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL OPERATIONS
    //////////////////////////////////////////////////////////////*/
    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (!approvedCollateral[token]) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAddress();

        // Effects: update state before external interaction.
        userCollateral[msg.sender][token] += amount;
        reserveBalance[token] += amount;

        // Interaction: pull collateral from the depositor.
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /// @dev Allows a user to withdraw excess collateral that is not required
    ///      to back their current debt at the configured ratio.
    function withdrawCollateral(address token, uint256 amount) external nonReentrant {
        if (!approvedCollateral[token]) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAddress();
        if (userCollateral[msg.sender][token] < amount) revert InsufficientBalance();

        // Effects: update state before external interaction.
        userCollateral[msg.sender][token] -= amount;
        reserveBalance[token] -= amount;

        // Check that remaining collateral still satisfies ratio.
        uint256 cv = collateralValue(msg.sender);
        uint256 debt = userDebt[msg.sender];
        if (debt > 0) {
            uint256 required = (debt * collateralizationRatio) / BPS;
            if (cv < required) revert InsufficientCollateral();
        }

        // Interaction: return collateral to the user.
        _safeTransfer(token, msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       STABLECOIN OPERATIONS
    //////////////////////////////////////////////////////////////*/
    function mint(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAddress();
        uint256 newDebt = userDebt[msg.sender] + amount;
        uint256 cv = collateralValue(msg.sender);
        uint256 required = (newDebt * collateralizationRatio) / BPS;
        if (cv < required) revert InsufficientCollateral();

        userDebt[msg.sender] = newDebt;
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        emit Transfer(address(0), msg.sender, amount);
        emit Minted(msg.sender, amount);
    }

    /// @notice Redeem stablecoins for a proportional share of your collateral.
    ///         A fee is taken from the burned stablecoin and does not release collateral.
    function redeem(uint256 amount) external nonReentrant {
        if (amount == 0) revert NothingToRedeem();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        if (userDebt[msg.sender] == 0) revert NoDebt();

        uint256 fee = (amount * redemptionFee) / BPS;
        uint256 redeemable = amount - fee;

        // Effects: burn full amount from the caller's balance.
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        // Reduce debt by redeemable portion (fee does not reduce debt).
        uint256 debt = userDebt[msg.sender];
        if (redeemable > debt) {
            redeemable = debt;
        }
        userDebt[msg.sender] = debt - redeemable;

        // Compute and apply all collateral releases before any external call.
        if (redeemable > 0 && debt > 0) {
            uint256 len = collateralList.length;
            for (uint256 i = 0; i < len; ) {
                address token = collateralList[i];
                uint256 held = userCollateral[msg.sender][token];
                if (held > 0) {
                    uint256 release = (held * redeemable) / debt;
                    if (release > 0) {
                        userCollateral[msg.sender][token] -= release;
                        reserveBalance[token] -= release;
                        emit CollateralWithdrawn(msg.sender, token, release);
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        // Interactions: transfer released collateral to the caller.
        if (redeemable > 0 && debt > 0) {
            uint256 len = collateralList.length;
            for (uint256 i = 0; i < len; ) {
                address token = collateralList[i];
                uint256 held = userCollateral[msg.sender][token];
                // `held` is the remaining balance after release; compute release again
                // deterministically from the original fraction.
                uint256 release = (held * redeemable) / (debt - redeemable);
                // Note: debt - redeemable == new debt == userDebt[msg.sender] after update.
                if (release > 0) {
                    _safeTransfer(token, msg.sender, release);
                }
                unchecked {
                    ++i;
                }
            }
        }

        emit Redeemed(msg.sender, amount, fee);
        emit Transfer(msg.sender, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC20 TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        if (to == address(0)) revert TransferToZero();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external nonReentrant returns (bool) {
        if (to == address(0)) revert TransferToZero();
        if (from == to) revert TransferToZero();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function healthFactor(address user) external view returns (uint256) {
        uint256 debt = userDebt[user];
        if (debt == 0) return type(uint256).max;
        uint256 cv = collateralValue(user);
        return (cv * BPS) / debt;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
