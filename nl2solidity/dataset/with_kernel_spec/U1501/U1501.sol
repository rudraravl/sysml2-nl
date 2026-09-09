// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CDPManager {
    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              CDP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public operator;
    IOracle public oracle;

    uint256 public constant MIN_COLLATERAL_RATIO = 1.1e18; // 110%
    uint256 public constant MIN_LIQUIDATION_FEE = 0.05e18;  // 5%
    uint256 public constant MAX_LIQUIDATION_FEE = 0.2e18;   // 20%
    uint256 public constant PRICE_PRECISION = 1e18;

    struct CollateralType {
        bool isSupported;
        uint8 decimals;
        uint256 minCollateralRatio;
        uint256 liquidationFee;
    }

    mapping(address => CollateralType) public collateralTypes;
    mapping(address => mapping(address => uint256)) public collateralDeposits;
    mapping(address => uint256) public debts;
    mapping(address => bool) public isLiquidated;
    mapping(address => address[]) internal userCollateralList;
    mapping(address => mapping(address => bool)) internal userCollateralExists;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralTypeAdded(address indexed token, uint256 minCollateralRatio, uint256 liquidationFee);
    event CollateralTypeUpdated(address indexed token, uint256 minCollateralRatio, uint256 liquidationFee);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event OracleSet(address indexed previousOracle, address indexed newOracle);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed user,
        address indexed token,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 fee
    );

    /*//////////////////////////////////////////////////////////////
                              REENTRANCY
    //////////////////////////////////////////////////////////////*/

    uint256 private _status;
    modifier nonReentrant() {
        require(_status != 2, "Reentrant call");
        _status = 2;
        _;
        _status = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _operator
    ) {
        require(_oracle != address(0) && _operator != address(0), "Zero address");
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        oracle = IOracle(_oracle);
        operator = _operator;
        _status = 1;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _burn(from, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: burn amount exceeds balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Zero address");
        emit OperatorSet(operator, _operator);
        operator = _operator;
    }

    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Zero address");
        emit OracleSet(address(oracle), _oracle);
        oracle = IOracle(_oracle);
    }

    function addCollateralType(
        address token,
        uint256 minCollateralRatio,
        uint256 liquidationFee
    ) external onlyOwner {
        require(token != address(0), "Zero address");
        require(minCollateralRatio >= MIN_COLLATERAL_RATIO, "Ratio too low");
        require(
            liquidationFee >= MIN_LIQUIDATION_FEE && liquidationFee <= MAX_LIQUIDATION_FEE,
            "Fee invalid"
        );
        require(!collateralTypes[token].isSupported, "Already supported");
        uint8 dec = IERC20(token).decimals();
        require(dec <= 18, "Decimals too high");

        collateralTypes[token] = CollateralType({
            isSupported: true,
            decimals: dec,
            minCollateralRatio: minCollateralRatio,
            liquidationFee: liquidationFee
        });

        emit CollateralTypeAdded(token, minCollateralRatio, liquidationFee);
    }

    function updateCollateralType(
        address token,
        uint256 minCollateralRatio,
        uint256 liquidationFee
    ) external onlyOwner {
        require(collateralTypes[token].isSupported, "Not supported");
        require(minCollateralRatio >= MIN_COLLATERAL_RATIO, "Ratio too low");
        require(
            liquidationFee >= MIN_LIQUIDATION_FEE && liquidationFee <= MAX_LIQUIDATION_FEE,
            "Fee invalid"
        );

        collateralTypes[token].minCollateralRatio = minCollateralRatio;
        collateralTypes[token].liquidationFee = liquidationFee;

        emit CollateralTypeUpdated(token, minCollateralRatio, liquidationFee);
    }

    /*//////////////////////////////////////////////////////////////
                           USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(collateralTypes[token].isSupported, "Not supported");

        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        collateralDeposits[msg.sender][token] += amount;
        if (!userCollateralExists[msg.sender][token]) {
            userCollateralExists[msg.sender][token] = true;
            userCollateralList[msg.sender].push(token);
        }

        emit Deposit(msg.sender, token, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(!isLiquidated[msg.sender], "Position liquidated");

        uint256 newDebt = debts[msg.sender] + amount;
        require(newDebt <= _getBorrowingPower(msg.sender), "Insufficient collateral");

        debts[msg.sender] = newDebt;
        _mint(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        uint256 currentDebt = debts[msg.sender];
        require(amount <= currentDebt, "Exceeds debt");

        _burn(msg.sender, amount);
        debts[msg.sender] = currentDebt - amount;

        emit Repay(msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(!isLiquidated[msg.sender], "Position liquidated");
        require(collateralDeposits[msg.sender][token] >= amount, "Insufficient collateral");

        collateralDeposits[msg.sender][token] -= amount;
        require(_isPositionHealthy(msg.sender), "Undercollateralized");

        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        if (collateralDeposits[msg.sender][token] == 0) {
            _removeUserCollateral(msg.sender, token);
        }

        emit Withdraw(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION
    //////////////////////////////////////////////////////////////*/

    function liquidate(
        address user,
        address token,
        uint256 debtToCover
    ) external nonReentrant onlyOperator {
        require(debtToCover > 0, "Zero amount");
        require(!isLiquidated[user], "Position liquidated");
        require(debtToCover <= debts[user], "Exceeds debt");
        require(!_isPositionHealthy(user), "Position healthy");
        require(collateralTypes[token].isSupported, "Not supported");

        uint256 price = oracle.getPrice(token);
        require(price > 0, "Price zero");

        CollateralType storage ct = collateralTypes[token];
        uint256 feeAdjusted = debtToCover * (PRICE_PRECISION + ct.liquidationFee);
        uint256 seizeAmount = (feeAdjusted * (10 ** uint256(ct.decimals))) / (price * PRICE_PRECISION);

        uint256 userDeposit = collateralDeposits[user][token];
        require(seizeAmount <= userDeposit, "Seize exceeds deposit");

        uint256 fee = (debtToCover * ct.liquidationFee) / PRICE_PRECISION;

        // Effects
        debts[user] -= debtToCover;
        collateralDeposits[user][token] = userDeposit - seizeAmount;
        if (collateralDeposits[user][token] == 0) {
            _removeUserCollateral(user, token);
        }
        if (debts[user] == 0) {
            isLiquidated[user] = true;
        }

        // Interactions
        _burn(msg.sender, debtToCover);
        require(IERC20(token).transfer(msg.sender, seizeAmount), "Transfer failed");

        emit Liquidation(msg.sender, user, token, debtToCover, seizeAmount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getBorrowingPower(address user) external view returns (uint256) {
        return _getBorrowingPower(user);
    }

    function isPositionHealthy(address user) external view returns (bool) {
        return _isPositionHealthy(user);
    }

    function getUserCollaterals(address user) external view returns (address[] memory) {
        return userCollateralList[user];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getBorrowingPower(address user) internal view returns (uint256) {
        uint256 power = 0;
        address[] storage tokens = userCollateralList[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            address t = tokens[i];
            CollateralType storage ct = collateralTypes[t];
            uint256 amount = collateralDeposits[user][t];
            if (amount == 0) continue;

            uint256 price = oracle.getPrice(t);
            if (price == 0) continue;

            uint256 normalizedAmount = amount * (10 ** (18 - ct.decimals));
            // Fixed: perform a single division to avoid precision loss from
            // divide-then-multiply. Mathematically:
            //   power += (normalizedAmount * price / PRICE_PRECISION) * PRICE_PRECISION / minCollateralRatio
            // which simplifies (without intermediate rounding) to:
            //   power += (normalizedAmount * price) / minCollateralRatio
            power += (normalizedAmount * price) / ct.minCollateralRatio;
        }
        return power;
    }

    function _isPositionHealthy(address user) internal view returns (bool) {
        return debts[user] <= _getBorrowingPower(user);
    }

    function _removeUserCollateral(address user, address token) internal {
        address[] storage tokens = userCollateralList[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
        userCollateralExists[user][token] = false;
    }
}
