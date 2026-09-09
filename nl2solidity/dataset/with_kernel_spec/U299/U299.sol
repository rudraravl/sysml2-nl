// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract ReserveCurrency {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    uint256 public targetCollateralRatioBips; // 15000 = 150%
    uint256 public stabilityFeeBips;          // 50 = 0.5%

    mapping(address => bool) public isApprovedCollateral;
    mapping(address => uint256) public totalCollateral;
    mapping(address => mapping(address => uint256)) public userCollateral;

    uint256 public constant MIN_RATIO = 10000; // 100%
    uint256 public constant MAX_RATIO = 20000; // 200%
    uint256 public constant MAX_FEE = 50;      // 0.5%
    uint256 private constant BPS_ONE = 10000;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(address indexed minter, address indexed collateral, uint256 collateralAmount, uint256 stableMinted);
    event Burned(address indexed burner, address indexed collateral, uint256 stableBurned, uint256 collateralRedeemed, uint256 feePaid);
    event CollateralAdded(address indexed token);
    event CollateralRemoved(address indexed token);
    event TargetCollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event StabilityFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error CollateralNotApproved();
    error RatioOutOfRange();
    error FeeTooHigh();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error InsufficientUserCollateral();
    error ZeroAddress();
    error ZeroAmount();
    error CollateralHasBalance();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        targetCollateralRatioBips = 15000; // 150%
        stabilityFeeBips = 0;
        name = "Decentralized Reserve Stablecoin";
        symbol = "DRS";
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (spender == address(0)) revert ZeroAddress();
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                         RESERVE LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(address collateral, uint256 amount) external {
        if (!isApprovedCollateral[collateral]) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAmount();

        // Calculate the stablecoin amount to mint from the collateral deposit.
        // mintAmount = amount * 10000 / targetCollateralRatioBips
        uint256 mintAmount = (amount * BPS_ONE) / targetCollateralRatioBips;
        if (mintAmount == 0) revert ZeroAmount();

        // Effects: update accounting before any external calls.
        totalCollateral[collateral] += amount;
        userCollateral[msg.sender][collateral] += amount;

        // Interactions: pull collateral from the caller.
        bool success = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        _mint(msg.sender, mintAmount);
        emit Minted(msg.sender, collateral, amount, mintAmount);
    }

    function burn(address collateral, uint256 stableAmount) external {
        if (!isApprovedCollateral[collateral]) revert CollateralNotApproved();
        if (stableAmount == 0) revert ZeroAmount();

        // Compute the collateral redeemable for the burned stablecoin amount and
        // the stability fee in a single combined expression so that no
        // intermediate division truncation is multiplied later.
        //
        // redeemable = stableAmount * targetCollateralRatioBips / 10000
        // fee        = redeemable * stabilityFeeBips / 10000
        //            = stableAmount * targetCollateralRatioBips * stabilityFeeBips / (10000 * 10000)
        //
        // Computing `fee` directly from `stableAmount` avoids the
        // divide-before-multiply pattern where `fee` would otherwise be
        // calculated from the already-truncated `redeemable` value.
        uint256 redeemable = (stableAmount * targetCollateralRatioBips) / BPS_ONE;
        if (redeemable == 0) revert ZeroAmount();

        uint256 fee = (stableAmount * targetCollateralRatioBips * stabilityFeeBips) / (BPS_ONE * BPS_ONE);
        if (fee > redeemable) {
            // Defensive guard; with the configured bounds this is unreachable.
            fee = redeemable;
        }
        uint256 userGets = redeemable - fee;

        if (userCollateral[msg.sender][collateral] < redeemable) revert InsufficientUserCollateral();
        if (totalCollateral[collateral] < redeemable) revert InsufficientReserve();

        // Effects: burn stablecoin and reduce collateral accounting before transfers.
        _burn(msg.sender, stableAmount);
        totalCollateral[collateral] -= redeemable;
        userCollateral[msg.sender][collateral] -= redeemable;

        // Interactions: return collateral to the user and route the fee to the operator.
        bool successUser = IERC20(collateral).transfer(msg.sender, userGets);
        if (!successUser) revert TransferFailed();

        if (fee > 0) {
            bool successFee = IERC20(collateral).transfer(operator, fee);
            if (!successFee) revert TransferFailed();
        }

        emit Burned(msg.sender, collateral, stableAmount, userGets, fee);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setTargetCollateralRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_RATIO || newRatio > MAX_RATIO) revert RatioOutOfRange();
        emit TargetCollateralRatioUpdated(targetCollateralRatioBips, newRatio);
        targetCollateralRatioBips = newRatio;
    }

    function setStabilityFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        emit StabilityFeeUpdated(stabilityFeeBips, newFee);
        stabilityFeeBips = newFee;
    }

    function addCollateral(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        isApprovedCollateral[token] = true;
        emit CollateralAdded(token);
    }

    function removeCollateral(address token) external onlyOperator {
        if (totalCollateral[token] > 0) revert CollateralHasBalance();
        isApprovedCollateral[token] = false;
        emit CollateralRemoved(token);
    }
}
