// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IERC20Minimal {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BasketStablecoin {
    error ZeroAddress();
    error ZeroAmount();
    error CallerNotOperator();
    error CollateralNotApproved();
    error CollateralAlreadyApproved();
    error InvalidWeight();
    error InvalidPrice();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferToZeroAddress();
    error CollateralBalanceNotZero();
    error ReserveRatioExceeded();
    error ReentrantCall();
    error TransferFailed();
    error InvalidDecimals();
    error NoCollateral();

    uint256 public constant MAX_RESERVE_RATIO = 9500;
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant decimals = 18;

    struct CollateralConfig {
        bool active;
        uint8 decimals;
        uint256 targetWeight;
    }

    string public name;
    string public symbol;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => CollateralConfig) public collateralConfigs;
    address[] public collateralList;

    mapping(address => mapping(address => uint256)) public userCollateralDeposits;
    mapping(address => uint256) public totalCollateralDeposits;

    address public oracle;
    address public operator;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed depositor, address collateral, uint256 amount, uint256 stablecoinMinted);
    event Redeem(address indexed redeemer, uint256 stablecoinAmount, uint256 feeCollected);
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event CollateralAdded(address indexed token, uint8 decimals, uint256 targetWeight);
    event CollateralRemoved(address indexed token);
    event WeightUpdated(address indexed token, uint256 oldWeight, uint256 newWeight);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert CallerNotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _operator
    ) {
        if (_oracle == address(0) || _operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        oracle = _oracle;
        operator = _operator;
        _status = _NOT_ENTERED;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert TransferToZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address minter, address to, uint256 amount) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit Mint(minter, to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
    }

    function deposit(address collateral, uint256 amount) external nonReentrant {
        CollateralConfig storage config = collateralConfigs[collateral];
        if (!config.active) revert CollateralNotApproved();
        if (amount == 0) revert ZeroAmount();

        uint256 price = _getPrice(collateral);
        if (price == 0) revert InvalidPrice();

        // Compute mint amount without intermediate division truncation.
        uint256 mintAmount = (amount * price * MAX_RESERVE_RATIO) /
            ((10 ** config.decimals) * BPS_DENOMINATOR);
        if (mintAmount == 0) revert ZeroAmount();

        bool success = IERC20Minimal(collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        userCollateralDeposits[msg.sender][collateral] += amount;
        totalCollateralDeposits[collateral] += amount;

        uint256 totalValue = totalCollateralValue();
        uint256 newTotalSupply = totalSupply + mintAmount;
        if (newTotalSupply > (totalValue * MAX_RESERVE_RATIO) / BPS_DENOMINATOR) {
            revert ReserveRatioExceeded();
        }

        _mint(msg.sender, msg.sender, mintAmount);

        emit Deposit(msg.sender, collateral, amount, mintAmount);
    }

    function redeem(uint256 stablecoinAmount) external nonReentrant {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < stablecoinAmount) revert InsufficientBalance();
        if (totalSupply == 0) revert NoCollateral();

        uint256 supplyBefore = totalSupply;

        uint256 fee = (stablecoinAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 effectiveAmount = stablecoinAmount - fee;

        uint256 listLength = collateralList.length;
        uint256[] memory transferAmounts = new uint256[](listLength);
        for (uint256 i = 0; i < listLength; ) {
            address token = collateralList[i];
            if (collateralConfigs[token].active) {
                uint256 deposited = totalCollateralDeposits[token];
                if (deposited > 0) {
                    transferAmounts[i] = (deposited * effectiveAmount) / supplyBefore;
                }
            }
            unchecked {
                ++i;
            }
        }

        _burn(msg.sender, stablecoinAmount);

        // Effects before interactions: update all state prior to external transfers.
        for (uint256 i = 0; i < listLength; ) {
            if (transferAmounts[i] > 0) {
                address token = collateralList[i];
                totalCollateralDeposits[token] -= transferAmounts[i];
                userCollateralDeposits[msg.sender][token] -= transferAmounts[i];
            }
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < listLength; ) {
            if (transferAmounts[i] > 0) {
                address token = collateralList[i];
                bool success = IERC20Minimal(token).transfer(msg.sender, transferAmounts[i]);
                if (!success) revert TransferFailed();
            }
            unchecked {
                ++i;
            }
        }

        emit Redeem(msg.sender, stablecoinAmount, fee);
    }

    function addCollateral(address token, uint256 targetWeight, uint8 tokenDecimals) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (collateralConfigs[token].active) revert CollateralAlreadyApproved();
        if (tokenDecimals == 0 || tokenDecimals > 18) revert InvalidDecimals();
        if (targetWeight == 0 || targetWeight > BPS_DENOMINATOR) revert InvalidWeight();

        collateralConfigs[token] = CollateralConfig({
            active: true,
            decimals: tokenDecimals,
            targetWeight: targetWeight
        });
        collateralList.push(token);

        emit CollateralAdded(token, tokenDecimals, targetWeight);
    }

    function removeCollateral(address token) external onlyOperator {
        if (!collateralConfigs[token].active) revert CollateralNotApproved();
        if (totalCollateralDeposits[token] > 0) revert CollateralBalanceNotZero();

        collateralConfigs[token].active = false;

        uint256 listLength = collateralList.length;
        for (uint256 i = 0; i < listLength; ) {
            if (collateralList[i] == token) {
                collateralList[i] = collateralList[listLength - 1];
                collateralList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit CollateralRemoved(token);
    }

    function setWeight(address token, uint256 newWeight) external onlyOperator {
        if (!collateralConfigs[token].active) revert CollateralNotApproved();
        if (newWeight == 0 || newWeight > BPS_DENOMINATOR) revert InvalidWeight();

        uint256 oldWeight = collateralConfigs[token].targetWeight;
        collateralConfigs[token].targetWeight = newWeight;

        emit WeightUpdated(token, oldWeight, newWeight);
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function totalCollateralValue() public view returns (uint256) {
        uint256 total = 0;
        uint256 listLength = collateralList.length;
        for (uint256 i = 0; i < listLength; ) {
            address token = collateralList[i];
            if (collateralConfigs[token].active) {
                uint256 deposited = totalCollateralDeposits[token];
                if (deposited > 0) {
                    uint256 price = _getPrice(token);
                    if (price > 0) {
                        total += (deposited * price) / (10 ** collateralConfigs[token].decimals);
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        return total;
    }

    function getCollateralValue(address token) public view returns (uint256) {
        CollateralConfig storage config = collateralConfigs[token];
        if (!config.active) return 0;
        uint256 deposited = totalCollateralDeposits[token];
        if (deposited == 0) return 0;
        uint256 price = _getPrice(token);
        if (price == 0) return 0;
        return (deposited * price) / (10 ** config.decimals);
    }

    function currentReserveRatio() external view returns (uint256) {
        uint256 totalValue = totalCollateralValue();
        if (totalValue == 0) return 0;
        return (totalSupply * BPS_DENOMINATOR) / totalValue;
    }

    function collateralCount() external view returns (uint256) {
        return collateralList.length;
    }

    function getCollateralList() external view returns (address[] memory) {
        return collateralList;
    }

    function getCollateralConfig(address token) external view returns (CollateralConfig memory) {
        return collateralConfigs[token];
    }

    function getUserCollateralDeposit(address user, address collateral) external view returns (uint256) {
        return userCollateralDeposits[user][collateral];
    }

    function getTotalCollateralDeposits(address token) external view returns (uint256) {
        return totalCollateralDeposits[token];
    }

    function _getPrice(address token) internal view returns (uint256) {
        return IPriceOracle(oracle).getPrice(token);
    }
}
