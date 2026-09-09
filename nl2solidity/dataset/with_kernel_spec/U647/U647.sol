// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract StablecoinBasket {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Deposit(address indexed user, address indexed collateral, uint256 collateralAmount, uint256 mintedAmount);
    event Redeem(address indexed user, address indexed collateral, uint256 stableAmount, uint256 collateralReturned, uint256 fee);
    event CollateralAdded(address indexed collateral, uint256 price, uint256 ratio);
    event CollateralRemoved(address indexed collateral);
    event CollateralRatioUpdated(address indexed collateral, uint256 oldRatio, uint256 newRatio);
    event CollateralPriceUpdated(address indexed collateral, uint256 oldPrice, uint256 newPrice);
    event MintingPausedChanged(bool paused);
    event RedemptionPausedChanged(bool paused);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error CollateralNotApproved(address collateral);
    error CollateralAlreadyApproved(address collateral);
    error RatioTooLow();
    error MintingPaused();
    error RedemptionPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientCollateral();
    error BelowMinCollateralization();
    error CollateralTransferFailed();
    error Reentrancy();

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_COLLATERAL_RATIO = 15000; // 150% in basis points
    uint256 public constant REDEMPTION_FEE_BPS = 10;       // 0.1%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                        STABLECOIN METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                        STABLECOIN STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL CONFIG
    //////////////////////////////////////////////////////////////*/
    struct CollateralParams {
        bool approved;
        uint256 price; // value of 1 collateral unit in stablecoin terms (18 decimals)
        uint256 ratio; // collateralization ratio in basis points (>= MIN_COLLATERAL_RATIO)
    }
    mapping(address => CollateralParams) public collateralParams;
    address[] public collateralList;
    mapping(address => bool) private _inList;
    mapping(address => uint256) public totalDeposited;

    /*//////////////////////////////////////////////////////////////
                           USER POSITIONS
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(address => uint256)) public deposited; // user => collateral => amount

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL / STATE
    //////////////////////////////////////////////////////////////*/
    address public operator;
    address public treasury;
    bool public mintingPaused;
    bool public redemptionPaused;
    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                           MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, address _operator, address _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
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
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function addCollateral(address collateral, uint256 _price, uint256 _ratio) external onlyOperator {
        if (collateral == address(0)) revert ZeroAddress();
        if (collateralParams[collateral].approved) revert CollateralAlreadyApproved(collateral);
        if (_price == 0) revert ZeroAmount();
        if (_ratio < MIN_COLLATERAL_RATIO) revert RatioTooLow();

        if (!_inList[collateral]) {
            collateralList.push(collateral);
            _inList[collateral] = true;
        }
        collateralParams[collateral] = CollateralParams({approved: true, price: _price, ratio: _ratio});
        emit CollateralAdded(collateral, _price, _ratio);
    }

    function removeCollateral(address collateral) external onlyOperator {
        if (!collateralParams[collateral].approved) revert CollateralNotApproved(collateral);
        collateralParams[collateral].approved = false;
        emit CollateralRemoved(collateral);
    }

    function updateCollateralRatio(address collateral, uint256 _ratio) external onlyOperator {
        if (!collateralParams[collateral].approved) revert CollateralNotApproved(collateral);
        if (_ratio < MIN_COLLATERAL_RATIO) revert RatioTooLow();
        uint256 oldRatio = collateralParams[collateral].ratio;
        collateralParams[collateral].ratio = _ratio;
        emit CollateralRatioUpdated(collateral, oldRatio, _ratio);
    }

    function updateCollateralPrice(address collateral, uint256 _price) external onlyOperator {
        if (!collateralParams[collateral].approved) revert CollateralNotApproved(collateral);
        if (_price == 0) revert ZeroAmount();
        uint256 oldPrice = collateralParams[collateral].price;
        collateralParams[collateral].price = _price;
        emit CollateralPriceUpdated(collateral, oldPrice, _price);
    }

    /*//////////////////////////////////////////////////////////////
                       ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setMintingPaused(bool _paused) external onlyOperator {
        mintingPaused = _paused;
        emit MintingPausedChanged(_paused);
    }

    function setRedemptionPaused(bool _paused) external onlyOperator {
        redemptionPaused = _paused;
        emit RedemptionPausedChanged(_paused);
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function transferOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    /*//////////////////////////////////////////////////////////////
                       MINTING (DEPOSIT & MINT)
    //////////////////////////////////////////////////////////////*/
    function deposit(address collateral, uint256 collateralAmount) external nonReentrant {
        if (mintingPaused) revert MintingPaused();
        CollateralParams memory params = collateralParams[collateral];
        if (!params.approved) revert CollateralNotApproved(collateral);
        if (collateralAmount == 0) revert ZeroAmount();

        uint256 mintAmount = (collateralAmount * params.price * BPS_DENOM) / (PRICE_PRECISION * params.ratio);
        if (mintAmount == 0) revert ZeroAmount();

        deposited[msg.sender][collateral] += collateralAmount;
        totalDeposited[collateral] += collateralAmount;
        unchecked {
            balanceOf[msg.sender] += mintAmount;
        }
        totalSupply += mintAmount;

        if (globalCollateralRatio() < MIN_COLLATERAL_RATIO) revert BelowMinCollateralization();

        emit Deposit(msg.sender, collateral, collateralAmount, mintAmount);
        emit Transfer(address(0), msg.sender, mintAmount);

        if (!IERC20(collateral).transferFrom(msg.sender, address(this), collateralAmount)) {
            revert CollateralTransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                       REDEMPTION (BURN & WITHDRAW)
    //////////////////////////////////////////////////////////////*/
    function redeem(address collateral, uint256 stableAmount) external nonReentrant {
        if (redemptionPaused) revert RedemptionPaused();
        CollateralParams memory params = collateralParams[collateral];
        if (params.price == 0) revert CollateralNotApproved(collateral);
        if (stableAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance();

        uint256 fee = (stableAmount * REDEMPTION_FEE_BPS) / BPS_DENOM;
        uint256 net = stableAmount - fee;
        if (net == 0) revert ZeroAmount();

        uint256 collateralToReturn = (net * params.ratio * PRICE_PRECISION) / (BPS_DENOM * params.price);
        if (collateralToReturn == 0) revert ZeroAmount();
        if (deposited[msg.sender][collateral] < collateralToReturn) revert InsufficientCollateral();

        balanceOf[msg.sender] -= stableAmount;
        if (fee > 0) {
            unchecked {
                balanceOf[treasury] += fee;
            }
        }
        totalSupply -= net;
        deposited[msg.sender][collateral] -= collateralToReturn;
        totalDeposited[collateral] -= collateralToReturn;

        if (globalCollateralRatio() < MIN_COLLATERAL_RATIO) revert BelowMinCollateralization();

        emit Redeem(msg.sender, collateral, stableAmount, collateralToReturn, fee);
        emit Transfer(msg.sender, address(0), net);
        if (fee > 0) {
            emit Transfer(msg.sender, treasury, fee);
        }

        if (!IERC20(collateral).transfer(msg.sender, collateralToReturn)) {
            revert CollateralTransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                       VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function totalCollateralValue() public view returns (uint256 total) {
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address c = collateralList[i];
            uint256 dep = totalDeposited[c];
            if (dep > 0) {
                uint256 price = collateralParams[c].price;
                if (price > 0) {
                    total += (dep * price) / PRICE_PRECISION;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function globalCollateralRatio() public view returns (uint256) {
        if (totalSupply == 0) return type(uint256).max;
        return (totalCollateralValue() * BPS_DENOM) / totalSupply;
    }

    function collateralListLength() external view returns (uint256) {
        return collateralList.length;
    }
}
