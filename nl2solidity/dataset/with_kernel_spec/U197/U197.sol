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
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract LendingPool {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////////////////////
    ////////////////////////// CONSTANTS /////////////////////////
    //////////////////////////////////////////////////////////////

    uint256 public constant SECONDS_PER_YEAR = 31_536_000;
    uint256 public constant WAD = 1e18;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18;
    uint256 public constant MAX_LTV = 0.75e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 0.80e18;
    uint256 public constant LIQUIDATION_PENALTY = 0.05e18;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    //////////////////////////////////////////////////////////////
    ////////////////////////// IMMUTABLES ////////////////////////
    //////////////////////////////////////////////////////////////

    IERC20 public immutable asset;

    //////////////////////////////////////////////////////////////
    ////////////////////////// ERC20 STORAGE ////////////////////
    //////////////////////////////////////////////////////////////

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    //////////////////////////////////////////////////////////////
    ///////////////////////// OWNABLE STORAGE ////////////////////
    //////////////////////////////////////////////////////////////

    address public owner;

    //////////////////////////////////////////////////////////////
    /////////////////////// REENTRANCY STORAGE ///////////////////
    //////////////////////////////////////////////////////////////

    uint256 private _status;

    //////////////////////////////////////////////////////////////
    ///////////////////////// LENDING STORAGE ////////////////////
    //////////////////////////////////////////////////////////////

    address public operator;
    bool public depositPaused;
    bool public borrowPaused;

    struct InterestRateModel {
        uint256 baseRatePerYear;
        uint256 slope1;
        uint256 slope2;
        uint256 kink;
        uint256 reserveFactor;
    }

    InterestRateModel public irm;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public borrowIndex;
    uint256 public lastAccrualTime;
    mapping(address => uint256) public borrowPrincipal;
    mapping(address => uint256) public userBorrowIndex;

    //////////////////////////////////////////////////////////////
    //////////////////////////// EVENTS //////////////////////////
    //////////////////////////////////////////////////////////////

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares, uint256 newShareBalance);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares, uint256 newShareBalance);
    event Borrow(address indexed caller, address indexed borrower, uint256 assets, uint256 newDebt);
    event Repay(address indexed payer, address indexed borrower, uint256 assets, uint256 newDebt);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 debtRepaid, uint256 collateralSeized, uint256 remainingDebt);
    event InterestAccrued(uint256 interestAccrued, uint256 reserveAdded, uint256 newBorrowIndex);
    event InterestRateModelUpdated(InterestRateModel oldModel, InterestRateModel newModel);
    event OperatorUpdated(address oldOperator, address newOperator);
    event PauseToggled(bool depositPaused, bool borrowPaused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    //////////////////////////////////////////////////////////////
    //////////////////////////// ERRORS //////////////////////////
    //////////////////////////////////////////////////////////////

    error ZeroAmount();
    error ZeroShares();
    error NoDebt();
    error ExceedsLTV();
    error PositionNotUnsafe();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InsufficientAllowance();
    error SeizeExceedsCollateral();
    error InvalidModel();
    error Unauthorized();
    error ZeroAddress();
    error DepositPausedError();
    error BorrowPausedError();

    //////////////////////////////////////////////////////////////
    ////////////////////////// MODIFIERS /////////////////////////
    //////////////////////////////////////////////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notDepositPaused() {
        if (depositPaused) revert DepositPausedError();
        _;
    }

    modifier notBorrowPaused() {
        if (borrowPaused) revert BorrowPausedError();
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    //////////////////////////////////////////////////////////////
    ////////////////////////// CONSTRUCTOR ///////////////////////
    //////////////////////////////////////////////////////////////

    constructor(
        address asset_,
        address operator_,
        InterestRateModel memory irm_,
        string memory name_,
        string memory symbol_
    ) {
        if (asset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (irm_.kink > WAD || irm_.reserveFactor > WAD) revert InvalidModel();

        asset = IERC20(asset_);
        operator = operator_;
        irm = irm_;
        name = name_;
        symbol = symbol_;

        owner = msg.sender;
        borrowIndex = WAD;
        lastAccrualTime = block.timestamp;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
    }

    //////////////////////////////////////////////////////////////
    //////////////////////// ERC20 FUNCTIONS /////////////////////
    //////////////////////////////////////////////////////////////

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        _allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientShares();
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientShares();
        _balances[from] = fromBalance - amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////////// VIEWS //////////////////////////
    //////////////////////////////////////////////////////////////

    function exchangeRateStored() public view returns (uint256) {
        if (_totalSupply == 0) return INITIAL_EXCHANGE_RATE;
        uint256 cash = asset.balanceOf(address(this));
        uint256 assetsUnderManagement = cash + totalBorrows - totalReserves;
        return (assetsUnderManagement * WAD) / _totalSupply;
    }

    function depositBalance(address user) public view returns (uint256) {
        return (_balances[user] * exchangeRateStored()) / WAD;
    }

    function borrowBalanceOf(address user) public view returns (uint256) {
        uint256 principal = borrowPrincipal[user];
        if (principal == 0) return 0;
        return (principal * borrowIndex) / userBorrowIndex[user];
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + totalBorrows;
    }

    function utilization() public view returns (uint256) {
        uint256 ta = totalAssets();
        if (ta == 0) return 0;
        return (totalBorrows * WAD) / ta;
    }

    function borrowRatePerYear() public view returns (uint256) {
        InterestRateModel memory m = irm;
        uint256 util = utilization();
        uint256 rate = m.baseRatePerYear;
        if (util <= m.kink) {
            rate += (util * m.slope1) / WAD;
        } else {
            rate += (m.kink * m.slope1) / WAD;
            rate += ((util - m.kink) * m.slope2) / WAD;
        }
        return rate;
    }

    function borrowRatePerSec() public view returns (uint256) {
        return borrowRatePerYear() / SECONDS_PER_YEAR;
    }

    function borrowCapacity(address user) public view returns (uint256) {
        uint256 collateral = depositBalance(user);
        uint256 debt = borrowBalanceOf(user);
        uint256 maxDebt = (collateral * MAX_LTV) / WAD;
        if (debt >= maxDebt) return 0;
        return maxDebt - debt;
    }

    function isUnsafe(address user) public view returns (bool) {
        uint256 debt = borrowBalanceOf(user);
        if (debt == 0) return false;
        uint256 collateral = depositBalance(user);
        return (debt * WAD) > (collateral * LIQUIDATION_THRESHOLD);
    }

    //////////////////////////////////////////////////////////////
    /////////////////////// INTEREST ACCRUAL /////////////////////
    //////////////////////////////////////////////////////////////

    function accrueInterest() public {
        uint256 now_ = block.timestamp;
        if (now_ == lastAccrualTime) return;

        uint256 dt = now_ - lastAccrualTime;
        uint256 interestFactor = borrowRatePerSec() * dt;

        if (totalBorrows > 0) {
            uint256 interestAccrued = (totalBorrows * interestFactor) / WAD;
            uint256 reserveAdded = (interestAccrued * irm.reserveFactor) / WAD;

            totalReserves += reserveAdded;
            totalBorrows += interestAccrued;

            emit InterestAccrued(interestAccrued, reserveAdded, borrowIndex);
        }

        borrowIndex = (borrowIndex * (WAD + interestFactor)) / WAD;
        lastAccrualTime = now_;
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////// USER ACTIONS //////////////////////
    //////////////////////////////////////////////////////////////

    function deposit(uint256 assets) external notDepositPaused nonReentrant {
        if (assets == 0) revert ZeroAmount();

        accrueInterest();

        uint256 rate = exchangeRateStored();
        uint256 shares = (assets * WAD) / rate;
        if (shares == 0) revert ZeroShares();

        _mint(msg.sender, shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, msg.sender, assets, shares, _balances[msg.sender]);
    }

    function withdraw(uint256 shares) external nonReentrant {
        if (shares == 0) revert ZeroAmount();

        accrueInterest();

        uint256 rate = exchangeRateStored();
        uint256 assets = (shares * rate) / WAD;

        uint256 userShares = _balances[msg.sender];
        if (shares > userShares) revert InsufficientShares();
        if (assets > asset.balanceOf(address(this))) revert InsufficientLiquidity();

        uint256 currentDebt = borrowBalanceOf(msg.sender);
        if (currentDebt != 0) {
            uint256 currentCollateral = (userShares * rate) / WAD;
            uint256 newCollateral = currentCollateral - assets;
            if ((currentDebt * WAD) > (newCollateral * MAX_LTV)) revert ExceedsLTV();
        }

        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, assets);

        emit Withdraw(msg.sender, msg.sender, assets, shares, _balances[msg.sender]);
    }

    function borrow(uint256 assets) external notBorrowPaused nonReentrant {
        if (assets == 0) revert ZeroAmount();

        accrueInterest();

        uint256 currentDebt = borrowBalanceOf(msg.sender);
        uint256 collateral = depositBalance(msg.sender);
        uint256 newDebt = currentDebt + assets;

        if ((newDebt * WAD) > (collateral * MAX_LTV)) revert ExceedsLTV();
        if (assets > asset.balanceOf(address(this))) revert InsufficientLiquidity();

        borrowPrincipal[msg.sender] = newDebt;
        userBorrowIndex[msg.sender] = borrowIndex;
        totalBorrows += assets;

        asset.safeTransfer(msg.sender, assets);

        emit Borrow(msg.sender, msg.sender, assets, newDebt);
    }

    function repay(uint256 assets) external nonReentrant {
        if (assets == 0) revert ZeroAmount();

        accrueInterest();

        uint256 currentDebt = borrowBalanceOf(msg.sender);
        if (currentDebt == 0) revert NoDebt();

        uint256 repayAmount = assets > currentDebt ? currentDebt : assets;

        uint256 newDebt = currentDebt - repayAmount;
        borrowPrincipal[msg.sender] = newDebt;
        userBorrowIndex[msg.sender] = borrowIndex;
        totalBorrows -= repayAmount;

        asset.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, msg.sender, repayAmount, newDebt);
    }

    function liquidate(address borrower, uint256 debtToCover) external nonReentrant {
        if (borrower == address(0)) revert ZeroAddress();

        accrueInterest();

        uint256 debt = borrowBalanceOf(borrower);
        if (debt == 0) revert NoDebt();

        uint256 collateral = depositBalance(borrower);
        if ((debt * WAD) <= (collateral * LIQUIDATION_THRESHOLD)) revert PositionNotUnsafe();

        uint256 repayAmount = debtToCover > debt ? debt : debtToCover;
        if (repayAmount == 0) revert ZeroAmount();

        uint256 collateralSeized = (repayAmount * (WAD + LIQUIDATION_PENALTY)) / WAD;
        if (collateralSeized > collateral) collateralSeized = collateral;

        uint256 remainingDebt = debt - repayAmount;
        borrowPrincipal[borrower] = remainingDebt;
        userBorrowIndex[borrower] = borrowIndex;
        totalBorrows -= repayAmount;

        uint256 rate = exchangeRateStored();
        uint256 sharesToBurn = (collateralSeized * WAD) / rate;
        if (sharesToBurn > _balances[borrower]) sharesToBurn = _balances[borrower];
        _burn(borrower, sharesToBurn);

        asset.safeTransferFrom(msg.sender, address(this), repayAmount);
        asset.safeTransfer(msg.sender, collateralSeized);

        emit Liquidate(msg.sender, borrower, repayAmount, collateralSeized, remainingDebt);
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////////// ADMIN //////////////////////////
    //////////////////////////////////////////////////////////////

    function setInterestRateModel(InterestRateModel memory newModel) external onlyOperator {
        if (newModel.kink > WAD || newModel.reserveFactor > WAD) revert InvalidModel();

        InterestRateModel memory old = irm;
        irm = newModel;

        emit InterestRateModelUpdated(old, newModel);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();

        address old = operator;
        operator = newOperator;

        emit OperatorUpdated(old, newOperator);
    }

    function setPause(bool _depositPaused, bool _borrowPaused) external onlyOperator {
        depositPaused = _depositPaused;
        borrowPaused = _borrowPaused;

        emit PauseToggled(_depositPaused, _borrowPaused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address old = owner;
        owner = newOwner;

        emit OwnershipTransferred(old, newOwner);
    }
}
