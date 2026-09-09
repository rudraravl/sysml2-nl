// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                    MINIMAL INTERFACE DEFINITIONS
//////////////////////////////////////////////////////////////*/

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/*//////////////////////////////////////////////////////////////
                          SAFE ERC20 LIBRARY
//////////////////////////////////////////////////////////////*/

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            (amount == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/*//////////////////////////////////////////////////////////////
                               OWNABLE
//////////////////////////////////////////////////////////////*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/*//////////////////////////////////////////////////////////////
                              PAUSABLE
//////////////////////////////////////////////////////////////*/

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function _pause() internal virtual {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

/*//////////////////////////////////////////////////////////////
                          REENTRANCY GUARD
//////////////////////////////////////////////////////////////*/

abstract contract ReentrancyGuard {
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

/*//////////////////////////////////////////////////////////////
                         EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface IPriceOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function getNFTValue(address nft, uint256 tokenId) external view returns (uint256);
}

interface IInterestRateModel {
    function borrowRate(uint256 utilization) external view returns (uint256);
}

/*//////////////////////////////////////////////////////////////
                        MAIN CONTRACT
//////////////////////////////////////////////////////////////*/

contract ConcentratedLiquidityLender is Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LTV = 0.7e18;              // 70%
    uint256 public constant LIQUIDATION_PENALTY = 0.05e18; // 5%
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error TokenNotActive();
    error TokenNotConfigured();
    error ExceedsLTV();
    error OutstandingDebt();
    error NotCollateralOwner();
    error NFTAlreadyDeposited();
    error InsufficientLiquidity();
    error NotLiquidatable();
    error NothingToRepay();
    error InvalidCollateralIndex();
    error InvalidCollateralFactor();
    error OnlyOperator();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositNFT(address indexed user, address indexed nft, uint256 indexed tokenId);
    event DepositERC20(address indexed user, address indexed token, uint256 amount);
    event WithdrawNFT(address indexed user, address indexed nft, uint256 indexed tokenId);
    event WithdrawERC20(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Repay(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed token,
        uint256 debtRepaid,
        uint256 collateralValueSeized
    );
    event TokenConfigUpdated(
        address indexed token,
        uint256 collateralFactor,
        address rateModel,
        bool isActive
    );
    event OperatorUpdated(address indexed newOperator);
    event OracleUpdated(address indexed newOracle);
    event LiquiditySupplied(address indexed token, uint256 amount);
    event PauseToggled(bool paused);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    struct TokenConfig {
        bool isActive;
        uint256 collateralFactor;       // [wad] <= MAX_LTV
        IInterestRateModel rateModel;   // interest rate model for this token
        uint256 borrowIndex;            // [wad] cumulative borrow index, starts at 1e18
        uint256 lastAccrual;            // last timestamp interest was accrued
        uint256 totalBorrows;           // total borrowed amount in token units
        uint256 totalReserves;          // total liquidity supplied in token units
    }

    struct CollateralItem {
        bool isNFT;            // true if NFT collateral, false if ERC-20
        address token;         // token address (NFT collection or ERC-20)
        uint256 tokenId;       // NFT tokenId (0 for ERC-20)
        uint256 amount;        // ERC-20 amount (0 for NFT)
    }

    address public operator;
    IPriceOracle public oracle;

    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => mapping(address => uint256)) public userBorrowShares; // user => token => shares
    mapping(address => CollateralItem[]) public userCollaterals;
    mapping(address => mapping(uint256 => address)) public nftDepositor;     // nft => tokenId => depositor
    address[] public configuredTokens;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperatorRole() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _oracle, address _operator) Ownable(msg.sender) {
        if (_oracle == address(0) || _operator == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        emit OperatorUpdated(_operator);
        emit OracleUpdated(_oracle);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    function pause() external onlyOwner {
        _pause();
        emit PauseToggled(true);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit PauseToggled(false);
    }

    function setTokenConfig(
        address token,
        bool isActive,
        uint256 collateralFactor,
        address rateModel
    ) external onlyOperatorRole {
        if (token == address(0)) revert ZeroAddress();
        if (rateModel == address(0)) revert ZeroAddress();
        if (collateralFactor > MAX_LTV) revert InvalidCollateralFactor();

        TokenConfig storage config = tokenConfigs[token];
        if (config.borrowIndex == 0) {
            config.borrowIndex = WAD;
            config.lastAccrual = block.timestamp;
            configuredTokens.push(token);
        } else {
            _accrueInterest(token);
        }
        config.isActive = isActive;
        config.collateralFactor = collateralFactor;
        config.rateModel = IInterestRateModel(rateModel);

        emit TokenConfigUpdated(token, collateralFactor, rateModel, isActive);
    }

    function supplyLiquidity(address token, uint256 amount) external onlyOperatorRole {
        if (amount == 0) revert ZeroAmount();
        TokenConfig storage config = tokenConfigs[token];
        if (config.borrowIndex == 0) revert TokenNotConfigured();

        // Effects before interactions
        config.totalReserves += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit LiquiditySupplied(token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    COLLATERAL: DEPOSIT & WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function depositNFT(address nft, uint256 tokenId) external whenNotPaused nonReentrant {
        if (nft == address(0)) revert ZeroAddress();
        if (nftDepositor[nft][tokenId] != address(0)) revert NFTAlreadyDeposited();

        // Effects before interactions
        nftDepositor[nft][tokenId] = msg.sender;
        userCollaterals[msg.sender].push(
            CollateralItem({isNFT: true, token: nft, tokenId: tokenId, amount: 0})
        );

        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        emit DepositNFT(msg.sender, nft, tokenId);
    }

    function depositERC20Collateral(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (token == address(0) || amount == 0) revert ZeroAmount();

        // Effects before interactions
        userCollaterals[msg.sender].push(
            CollateralItem({isNFT: false, token: token, tokenId: 0, amount: amount})
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositERC20(msg.sender, token, amount);
    }

    function withdrawCollateral(uint256 index) external whenNotPaused nonReentrant {
        if (index >= userCollaterals[msg.sender].length) revert InvalidCollateralIndex();
        if (_getTotalDebtValue(msg.sender) > 0) revert OutstandingDebt();

        CollateralItem memory item = userCollaterals[msg.sender][index];

        // Effects before interactions
        _removeCollateralItemByIndex(msg.sender, index);
        if (item.isNFT) {
            nftDepositor[item.token][item.tokenId] = address(0);
        }

        if (item.isNFT) {
            IERC721(item.token).safeTransferFrom(address(this), msg.sender, item.tokenId);
            emit WithdrawNFT(msg.sender, item.token, item.tokenId);
        } else {
            IERC20(item.token).safeTransfer(msg.sender, item.amount);
            emit WithdrawERC20(msg.sender, item.token, item.amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        BORROW & REPAY
    //////////////////////////////////////////////////////////////*/

    function borrow(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        TokenConfig storage config = tokenConfigs[token];
        if (!config.isActive) revert TokenNotActive();
        if (config.borrowIndex == 0) revert TokenNotConfigured();

        _accrueInterest(token);

        if (config.totalBorrows + amount > config.totalReserves) revert InsufficientLiquidity();

        uint256 newDebtValue = (amount * oracle.getAssetPrice(token)) / WAD;
        uint256 totalCollateralValue = _getTotalCollateralValue(msg.sender);
        if (
            _getTotalDebtValue(msg.sender) + newDebtValue >
            (totalCollateralValue * MAX_LTV) / WAD
        ) {
            revert ExceedsLTV();
        }

        // Effects before interactions
        uint256 shares = (amount * WAD) / config.borrowIndex;
        userBorrowShares[msg.sender][token] += shares;
        config.totalBorrows += amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, token, amount, shares);
    }

    function repay(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        TokenConfig storage config = tokenConfigs[token];
        if (config.borrowIndex == 0) revert TokenNotConfigured();

        _accrueInterest(token);

        uint256 shares = userBorrowShares[msg.sender][token];
        if (shares == 0) revert NothingToRepay();

        uint256 currentDebt = (shares * config.borrowIndex) / WAD;
        uint256 actualRepay;
        uint256 sharesToRepay;

        if (amount >= currentDebt) {
            // Full repayment: use exact shares to avoid rounding loss
            actualRepay = currentDebt;
            sharesToRepay = shares;
        } else {
            actualRepay = amount;
            sharesToRepay = (amount * WAD) / config.borrowIndex;
        }

        // Effects before interactions
        userBorrowShares[msg.sender][token] = shares - sharesToRepay;
        config.totalBorrows -= actualRepay;

        IERC20(token).safeTransferFrom(msg.sender, address(this), actualRepay);

        emit Repay(msg.sender, token, actualRepay, sharesToRepay);
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDATION
    //////////////////////////////////////////////////////////////*/

    function liquidate(
        address borrower,
        address token,
        uint256 repayAmount,
        uint256 collateralIndex
    ) external whenNotPaused nonReentrant {
        if (repayAmount == 0) revert ZeroAmount();
        TokenConfig storage config = tokenConfigs[token];
        if (!config.isActive) revert TokenNotActive();
        if (config.borrowIndex == 0) revert TokenNotConfigured();

        _accrueInterest(token);

        if (_getTotalDebtValue(borrower) <= (_getTotalCollateralValue(borrower) * MAX_LTV) / WAD)
            revert NotLiquidatable();

        uint256 shares = userBorrowShares[borrower][token];
        if (shares == 0) revert NothingToRepay();

        uint256 currentDebt = (shares * config.borrowIndex) / WAD;
        uint256 actualRepay;
        uint256 sharesToRepay;

        if (repayAmount >= currentDebt) {
            actualRepay = currentDebt;
            sharesToRepay = shares;
        } else {
            actualRepay = repayAmount;
            sharesToRepay = (repayAmount * WAD) / config.borrowIndex;
        }

        if (collateralIndex >= userCollaterals[borrower].length) revert InvalidCollateralIndex();
        CollateralItem memory item = userCollaterals[borrower][collateralIndex];

        uint256 collateralValue = _getCollateralItemValue(item);
        if (collateralValue < _computeSeizeValue(actualRepay, token))
            revert InsufficientLiquidity();

        // Effects before interactions
        userBorrowShares[borrower][token] = shares - sharesToRepay;
        config.totalBorrows -= actualRepay;
        _removeCollateralItemByIndex(borrower, collateralIndex);
        if (item.isNFT) {
            nftDepositor[item.token][item.tokenId] = address(0);
        }

        _transferCollateralOut(item, msg.sender);

        // Transfer repayment from liquidator
        IERC20(token).safeTransferFrom(msg.sender, address(this), actualRepay);

        emit Liquidate(msg.sender, borrower, token, actualRepay, collateralValue);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCurrentDebt(address user, address token) public view returns (uint256) {
        uint256 shares = userBorrowShares[user][token];
        if (shares == 0) return 0;
        return (shares * _currentBorrowIndex(token)) / WAD;
    }

    function getTotalCollateralValue(address user) public view returns (uint256) {
        return _getTotalCollateralValue(user);
    }

    function getTotalDebtValue(address user) public view returns (uint256) {
        return _getTotalDebtValue(user);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint256 debt = _getTotalDebtValue(user);
        if (debt == 0) return type(uint256).max;
        return (_getTotalCollateralValue(user) * WAD) / debt;
    }

    function isLiquidatable(address user) external view returns (bool) {
        uint256 debt = _getTotalDebtValue(user);
        if (debt == 0) return false;
        return debt > (_getTotalCollateralValue(user) * MAX_LTV) / WAD;
    }

    function getCollateralCount(address user) external view returns (uint256) {
        return userCollaterals[user].length;
    }

    function getCollateralItem(address user, uint256 index) external view returns (CollateralItem memory) {
        return userCollaterals[user][index];
    }

    function getAvailableLiquidity(address token) external view returns (uint256) {
        TokenConfig storage config = tokenConfigs[token];
        if (config.borrowIndex == 0) return 0;
        return config.totalReserves - config.totalBorrows;
    }

    function getCurrentBorrowIndex(address token) external view returns (uint256) {
        return _currentBorrowIndex(token);
    }

    function getConfiguredTokensCount() external view returns (uint256) {
        return configuredTokens.length;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: INTEREST ACCRUAL
    //////////////////////////////////////////////////////////////*/

    function _accrueInterest(address token) internal {
        TokenConfig storage config = tokenConfigs[token];
        if (config.lastAccrual == 0) {
            config.lastAccrual = block.timestamp;
            return;
        }
        if (block.timestamp <= config.lastAccrual) return;

        uint256 timeDelta = block.timestamp - config.lastAccrual;

        uint256 utilization = _computeUtilization(config.totalBorrows, config.totalReserves);
        // Avoid divide-before-multiply: compute interestFactor in single expression
        uint256 interestFactor = (config.rateModel.borrowRate(utilization) * timeDelta) / SECONDS_PER_YEAR;
        config.borrowIndex = (config.borrowIndex * (WAD + interestFactor)) / WAD;
        config.lastAccrual = block.timestamp;
    }

    function _currentBorrowIndex(address token) internal view returns (uint256) {
        TokenConfig storage config = tokenConfigs[token];
        if (config.borrowIndex == 0) return WAD;
        if (config.lastAccrual == 0 || block.timestamp <= config.lastAccrual) {
            return config.borrowIndex;
        }

        uint256 timeDelta = block.timestamp - config.lastAccrual;

        uint256 utilization = _computeUtilization(config.totalBorrows, config.totalReserves);
        // Avoid divide-before-multiply: compute interestFactor in single expression
        uint256 interestFactor = (config.rateModel.borrowRate(utilization) * timeDelta) / SECONDS_PER_YEAR;
        return (config.borrowIndex * (WAD + interestFactor)) / WAD;
    }

    function _computeUtilization(uint256 totalBorrows, uint256 totalReserves) internal pure returns (uint256) {
        if (totalBorrows == 0 || totalReserves == 0) return 0;
        return (totalBorrows * WAD) / totalReserves;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: LIQUIDATION HELPERS
    //////////////////////////////////////////////////////////////*/

    function _computeSeizeValue(uint256 actualRepay, address token) internal view returns (uint256) {
        uint256 price = oracle.getAssetPrice(token);
        // Avoid divide-before-multiply: combine into single expression
        return (actualRepay * price * (WAD + LIQUIDATION_PENALTY)) / (WAD * WAD);
    }

    function _transferCollateralOut(CollateralItem memory item, address to) internal {
        if (item.isNFT) {
            IERC721(item.token).safeTransferFrom(address(this), to, item.tokenId);
        } else {
            IERC20(item.token).safeTransfer(to, item.amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: VALUATION
    //////////////////////////////////////////////////////////////*/

    function _getTotalCollateralValue(address user) internal view returns (uint256 total) {
        CollateralItem[] storage items = userCollaterals[user];
        for (uint256 i = 0; i < items.length; i++) {
            total += _getCollateralItemValue(items[i]);
        }
    }

    function _getTotalDebtValue(address user) internal view returns (uint256 total) {
        for (uint256 i = 0; i < configuredTokens.length; i++) {
            address token = configuredTokens[i];
            uint256 shares = userBorrowShares[user][token];
            if (shares == 0) continue;
            uint256 currentIndex = _currentBorrowIndex(token);
            uint256 price = oracle.getAssetPrice(token);
            // Avoid divide-before-multiply: combine into single expression
            total += (shares * currentIndex * price) / (WAD * WAD);
        }
    }

    function _getCollateralItemValue(CollateralItem memory item) internal view returns (uint256) {
        if (item.isNFT) {
            return oracle.getNFTValue(item.token, item.tokenId);
        } else {
            return (item.amount * oracle.getAssetPrice(item.token)) / WAD;
        }
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: COLLATERAL UTIL
    //////////////////////////////////////////////////////////////*/

    function _removeCollateralItemByIndex(address user, uint256 index) internal {
        CollateralItem[] storage items = userCollaterals[user];
        uint256 lastIndex = items.length - 1;
        if (index != lastIndex) {
            items[index] = items[lastIndex];
        }
        items.pop();
    }

    /*//////////////////////////////////////////////////////////////
                       IERC721Receiver
    //////////////////////////////////////////////////////////////*/

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
