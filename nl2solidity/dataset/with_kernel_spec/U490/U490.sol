// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title ReserveTreasury
/// @notice Treasury for a decentralized reserve currency backed by a basket of
///         approved collateral tokens. Users deposit approved collateral to mint
///         the native reserve token, redeem the native token for a proportional
///         share of the collateral basket, and transfer the native token freely.
///         A designated operator manages the approved collateral set and target
///         weights. The reserve ratio (total collateral / total native supply)
///         is enforced to remain at or above 100% at all times, and the number
///         of approved collateral tokens is capped at 10.
contract ReserveTreasury {
    uint256 public constant MAX_COLLATERAL_COUNT = 10;
    uint256 public constant WEIGHT_PRECISION = 1e4; // basis points, 100% = 1e4
    uint256 public constant RATIO_PRECISION = 1e18; // 100% = 1e18
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    string public constant name = "Decentralized Reserve Currency";
    string public constant symbol = "DRC";
    uint8 public constant decimals = 18;

    address public operator;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address[] internal _collateralList;
    mapping(address => bool) public isCollateral;
    mapping(address => uint256) public targetWeight; // in basis points

    uint256 public lastReserveRatio; // cached ratio in 1e18 precision
    uint256 private _status; // reentrancy guard status

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event CollateralAdded(address indexed collateral, uint256 weight);
    event CollateralRemoved(address indexed collateral);
    event CollateralWeightUpdated(address indexed collateral, uint256 oldWeight, uint256 newWeight);
    event Deposited(
        address indexed depositor,
        address indexed collateral,
        uint256 amountDeposited,
        uint256 amountMinted
    );
    event Redeemed(address indexed redeemer, uint256 amountRedeemed);
    event CollateralSent(address indexed redeemer, address indexed collateral, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error NotOperator();
    error CollateralAlreadyApproved();
    error CollateralNotApproved();
    error MaxCollateralReached();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidWeight();
    error InsufficientReserveRatio();
    error InsufficientCollateral();
    error CollateralHasBalance();
    error TransferFailed();
    error ReentrancyCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address initialOperator) {
        if (initialOperator == address(0)) revert ZeroAddress();
        operator = initialOperator;
        lastReserveRatio = RATIO_PRECISION;
        _status = _NOT_ENTERED;
        emit OperatorChanged(address(0), initialOperator);
    }

    // ---------------------------------------------------------------------
    // Native token - ERC20-like interface
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = senderBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        emit Transfer(from, to, amount);
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
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------
    function collateralCount() external view returns (uint256) {
        return _collateralList.length;
    }

    function collateralList() external view returns (address[] memory) {
        return _collateralList;
    }

    function totalCollateralValue() public view returns (uint256 total) {
        for (uint256 i = 0; i < _collateralList.length; ) {
            total += IERC20(_collateralList[i]).balanceOf(address(this));
            unchecked { ++i; }
        }
    }

    function totalTargetWeight() public view returns (uint256 total) {
        for (uint256 i = 0; i < _collateralList.length; ) {
            total += targetWeight[_collateralList[i]];
            unchecked { ++i; }
        }
    }

    /// @dev Computes (collateralValue * RATIO_PRECISION) / supply.
    ///      Multiplies before dividing to preserve precision. If the product
    ///      would overflow, returns type(uint256).max since the ratio is
    ///      astronomically large.
    function _safeRatio(uint256 collateralValue, uint256 supply) internal pure returns (uint256) {
        if (supply < 1) return RATIO_PRECISION;
        if (collateralValue < 1) return 0;
        if (collateralValue <= type(uint256).max / RATIO_PRECISION) {
            return (collateralValue * RATIO_PRECISION) / supply;
        }
        return type(uint256).max;
    }

    function currentReserveRatio() public view returns (uint256) {
        return _safeRatio(totalCollateralValue(), totalSupply);
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------

    /// @notice Deposit an approved collateral token to mint native tokens 1:1.
    /// @dev Follows checks-effects-interactions: state is updated before the
    ///      external token transfer. If the transfer fails, the transaction
    ///      reverts and all state changes are rolled back.
    /// @param collateral Address of the approved collateral token.
    /// @param amount Amount of collateral to deposit.
    /// @return minted Amount of native tokens minted to the caller.
    function deposit(address collateral, uint256 amount)
        external
        nonReentrant
        returns (uint256 minted)
    {
        if (!isCollateral[collateral]) revert CollateralNotApproved();
        if (amount < 1) revert ZeroAmount();

        minted = amount;

        // Checks: verify reserve ratio will hold after deposit.
        // Uses direct comparison to avoid multiplication overflow.
        uint256 currentCollateral = totalCollateralValue();
        uint256 newCollateralValue = currentCollateral + amount;
        uint256 newSupply = totalSupply + minted;
        if (newCollateralValue < newSupply) revert InsufficientReserveRatio();

        // Effects: update state before external call.
        totalSupply = newSupply;
        balanceOf[msg.sender] += minted;
        lastReserveRatio = _safeRatio(newCollateralValue, newSupply);

        // Interactions: pull collateral from depositor.
        bool ok = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Transfer(address(0), msg.sender, minted);
        emit Deposited(msg.sender, collateral, amount, minted);
    }

    /// @notice Redeem native tokens for a proportional share of the collateral basket.
    /// @dev Burns the native tokens first (effects), then transfers out each
    ///      collateral token proportionally (interactions). The reserve ratio
    ///      is re-validated after redemption as a safety net.
    /// @param amount Amount of native tokens to redeem.
    /// @return True if successful.
    function redeem(uint256 amount) external nonReentrant returns (bool) {
        if (amount < 1) revert ZeroAmount();
        uint256 redeemerBalance = balanceOf[msg.sender];
        if (redeemerBalance < amount) revert InsufficientBalance();
        uint256 currentSupply = totalSupply;
        if (currentSupply < 1) revert InsufficientCollateral();

        // Effects: burn native tokens.
        unchecked {
            balanceOf[msg.sender] = redeemerBalance - amount;
            totalSupply = currentSupply - amount;
        }

        // Interactions: send proportional share of each collateral token.
        address[] memory tokens = _collateralList;
        for (uint256 i = 0; i < tokens.length; ) {
            address collateral = tokens[i];
            uint256 tokenBalance = IERC20(collateral).balanceOf(address(this));
            if (tokenBalance > 0) {
                uint256 sendAmount = (tokenBalance * amount) / currentSupply;
                if (sendAmount > 0) {
                    bool ok = IERC20(collateral).transfer(msg.sender, sendAmount);
                    if (!ok) revert TransferFailed();
                    emit CollateralSent(msg.sender, collateral, sendAmount);
                }
            }
            unchecked { ++i; }
        }

        // Update cached reserve ratio after redemption.
        uint256 newCollateralValue = totalCollateralValue();
        if (totalSupply < 1) {
            lastReserveRatio = RATIO_PRECISION;
        } else {
            if (newCollateralValue < totalSupply) revert InsufficientReserveRatio();
            lastReserveRatio = _safeRatio(newCollateralValue, totalSupply);
        }

        emit Transfer(msg.sender, address(0), amount);
        emit Redeemed(msg.sender, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    // Operator actions
    // ---------------------------------------------------------------------

    /// @notice Transfer operator role to a new address.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /// @notice Adjust the target weight of an already-approved collateral token.
    /// @param collateral Address of the collateral token.
    /// @param weight New target weight in basis points (1..WEIGHT_PRECISION).
    function setTargetWeight(address collateral, uint256 weight) external onlyOperator {
        if (!isCollateral[collateral]) revert CollateralNotApproved();
        if (weight < 1 || weight > WEIGHT_PRECISION) revert InvalidWeight();
        uint256 oldWeight = targetWeight[collateral];
        targetWeight[collateral] = weight;
        emit CollateralWeightUpdated(collateral, oldWeight, weight);
    }

    /// @notice Add a new collateral token to the approved list.
    /// @param collateral Address of the collateral token to add.
    /// @param weight Initial target weight in basis points (1..WEIGHT_PRECISION).
    function addCollateral(address collateral, uint256 weight) external onlyOperator {
        if (collateral == address(0)) revert ZeroAddress();
        if (isCollateral[collateral]) revert CollateralAlreadyApproved();
        if (_collateralList.length >= MAX_COLLATERAL_COUNT) revert MaxCollateralReached();
        if (weight < 1 || weight > WEIGHT_PRECISION) revert InvalidWeight();

        isCollateral[collateral] = true;
        targetWeight[collateral] = weight;
        _collateralList.push(collateral);

        emit CollateralAdded(collateral, weight);
    }

    /// @notice Remove a collateral token from the approved list.
    /// @dev The token must have zero balance in the treasury before removal.
    /// @param collateral Address of the collateral token to remove.
    function removeCollateral(address collateral) external onlyOperator {
        if (!isCollateral[collateral]) revert CollateralNotApproved();
        if (IERC20(collateral).balanceOf(address(this)) > 0) revert CollateralHasBalance();

        uint256 oldWeight = targetWeight[collateral];
        delete targetWeight[collateral];
        isCollateral[collateral] = false;

        uint256 len = _collateralList.length;
        for (uint256 i = 0; i < len; ) {
            if (_collateralList[i] == collateral) {
                _collateralList[i] = _collateralList[len - 1];
                _collateralList.pop();
                break;
            }
            unchecked { ++i; }
        }

        emit CollateralWeightUpdated(collateral, oldWeight, 0);
        emit CollateralRemoved(collateral);
    }
}
