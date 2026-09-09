// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceFeed {
    function getPrice(address token) external view returns (uint256);
}

contract CDPVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error CollateralNotApproved(address token);
    error CollateralAlreadyApproved(address token);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error InsufficientAllowance();
    error InsufficientBalance();
    error PositionUnsafe();
    error PositionSafe();
    error BorrowingPaused(address token);
    error BelowMinimumRatio();
    error NoDebt();
    error InvalidRatio();
    error InvalidThreshold();
    error InvalidDecimals();

    uint256 public constant MIN_COLLATERAL_RATIO = 1.1e18;
    uint256 public constant LIQUIDATION_FEE = 0.005e18;
    uint256 private constant WAD = 1e18;

    struct CollateralConfig {
        bool approved;
        bool borrowingPaused;
        uint8 decimals;
        uint256 collateralRatio;
        uint256 liquidationThreshold;
    }

    struct Position {
        uint256 collateral;
        uint256 debt;
    }

    IPriceFeed public priceFeed;
    address public treasury;

    mapping(address => CollateralConfig) public collateralConfig;
    mapping(address => mapping(address => Position)) public positions;
    mapping(address => uint256) public totalCollateral;
    mapping(address => uint256) public totalDebtPerToken;

    string public constant name = "CDP Stablecoin";
    string public constant symbol = "CDPUSD";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event PositionCreated(address indexed user, address indexed token);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        address indexed token,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 feeCollateral
    );
    event CollateralAdded(address indexed token, uint8 decimals, uint256 collateralRatio, uint256 liquidationThreshold);
    event CollateralConfigUpdated(address indexed token, uint256 collateralRatio, uint256 liquidationThreshold);
    event BorrowingPaused(address indexed token, bool paused);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PriceFeedUpdated(address indexed oldFeed, address indexed newFeed);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyApproved(address token) {
        if (!collateralConfig[token].approved) revert CollateralNotApproved(token);
        _;
    }

    modifier notPausedBorrowing(address token) {
        if (collateralConfig[token].borrowingPaused) revert BorrowingPaused(token);
        _;
    }

    constructor(address _priceFeed, address _treasury) Ownable(msg.sender) {
        if (_priceFeed == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        priceFeed = IPriceFeed(_priceFeed);
        treasury = _treasury;
        emit PriceFeedUpdated(address(0), _priceFeed);
        emit TreasuryUpdated(address(0), _treasury);
    }

    function addCollateral(
        address token,
        uint8 decimals_,
        uint256 collateralRatio,
        uint256 liquidationThreshold
    ) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (collateralConfig[token].approved) revert CollateralAlreadyApproved(token);
        if (collateralRatio < MIN_COLLATERAL_RATIO) revert InvalidRatio();
        if (liquidationThreshold == 0 || liquidationThreshold > collateralRatio) revert InvalidThreshold();
        if (decimals_ > 18) revert InvalidDecimals();

        collateralConfig[token] = CollateralConfig({
            approved: true,
            borrowingPaused: false,
            decimals: decimals_,
            collateralRatio: collateralRatio,
            liquidationThreshold: liquidationThreshold
        });

        emit CollateralAdded(token, decimals_, collateralRatio, liquidationThreshold);
    }

    function updateCollateralConfig(
        address token,
        uint256 collateralRatio,
        uint256 liquidationThreshold
    ) external onlyOwner onlyApproved(token) {
        if (collateralRatio < MIN_COLLATERAL_RATIO) revert InvalidRatio();
        if (liquidationThreshold == 0 || liquidationThreshold > collateralRatio) revert InvalidThreshold();

        collateralConfig[token].collateralRatio = collateralRatio;
        collateralConfig[token].liquidationThreshold = liquidationThreshold;

        emit CollateralConfigUpdated(token, collateralRatio, liquidationThreshold);
    }

    function setBorrowingPaused(address token, bool paused) external onlyOwner onlyApproved(token) {
        collateralConfig[token].borrowingPaused = paused;
        emit BorrowingPaused(token, paused);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        if (_priceFeed == address(0)) revert ZeroAddress();
        address old = address(priceFeed);
        priceFeed = IPriceFeed(_priceFeed);
        emit PriceFeedUpdated(old, _priceFeed);
    }

    function _collateralValue(address token, uint256 collateralAmount) internal view returns (uint256) {
        CollateralConfig memory cfg = collateralConfig[token];
        uint256 price = priceFeed.getPrice(token);
        uint256 normalized = collateralAmount * (10 ** (18 - cfg.decimals));
        return (normalized * price) / WAD;
    }

    function _requiredCollateralValue(uint256 debt, uint256 ratio) internal pure returns (uint256) {
        return (debt * ratio) / WAD;
    }

    function _isSafe(address user, address token) internal view returns (bool) {
        Position memory pos = positions[user][token];
        if (pos.debt == 0) return true;
        uint256 colValue = _collateralValue(token, pos.collateral);
        uint256 required = _requiredCollateralValue(pos.debt, collateralConfig[token].collateralRatio);
        return colValue >= required;
    }

    function _isLiquidatable(address user, address token) internal view returns (bool) {
        Position memory pos = positions[user][token];
        if (pos.debt == 0) return false;
        uint256 colValue = _collateralValue(token, pos.collateral);
        uint256 thresholdValue = _requiredCollateralValue(pos.debt, collateralConfig[token].liquidationThreshold);
        return colValue < thresholdValue;
    }

    function _debtToCollateral(address token, uint256 debt) internal view returns (uint256) {
        uint256 price = priceFeed.getPrice(token);
        CollateralConfig memory cfg = collateralConfig[token];
        uint256 normalized = (debt * WAD) / price;
        return normalized / (10 ** (18 - cfg.decimals));
    }

    function getPosition(address user, address token) external view returns (uint256 collateral, uint256 debt) {
        Position memory pos = positions[user][token];
        return (pos.collateral, pos.debt);
    }

    function isSafe(address user, address token) external view returns (bool) {
        return _isSafe(user, token);
    }

    function isLiquidatable(address user, address token) external view returns (bool) {
        return _isLiquidatable(user, token);
    }

    function depositCollateral(address token, uint256 amount)
        external
        onlyApproved(token)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender][token];
        if (pos.collateral == 0 && pos.debt == 0) {
            emit PositionCreated(msg.sender, token);
        }

        pos.collateral += amount;
        totalCollateral[token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount)
        external
        onlyApproved(token)
        notPausedBorrowing(token)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender][token];
        if (pos.collateral == 0 && pos.debt == 0) {
            emit PositionCreated(msg.sender, token);
        }

        pos.debt += amount;

        uint256 ratio = collateralConfig[token].collateralRatio;
        uint256 colValue = _collateralValue(token, pos.collateral);
        uint256 required = _requiredCollateralValue(pos.debt, ratio);
        if (colValue < required) revert BelowMinimumRatio();

        totalDebtPerToken[token] += amount;
        _mint(msg.sender, amount);

        emit Borrowed(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external onlyApproved(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender][token];
        if (pos.debt == 0) revert NoDebt();

        uint256 repayAmount = amount > pos.debt ? pos.debt : amount;

        pos.debt -= repayAmount;
        totalDebtPerToken[token] -= repayAmount;

        _burn(msg.sender, repayAmount);

        emit Repaid(msg.sender, token, repayAmount);
    }

    function withdrawCollateral(address token, uint256 amount)
        external
        onlyApproved(token)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender][token];
        if (amount > pos.collateral) revert InsufficientCollateral();

        pos.collateral -= amount;

        if (!_isSafe(msg.sender, token)) revert PositionUnsafe();

        totalCollateral[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    function liquidate(address user, address token)
        external
        onlyApproved(token)
        nonReentrant
    {
        Position storage pos = positions[user][token];
        if (pos.debt == 0) revert NoDebt();
        if (!_isLiquidatable(user, token)) revert PositionSafe();

        uint256 debt = pos.debt;
        uint256 collateralNeeded = _debtToCollateral(token, debt);

        uint256 feeCollateral;
        uint256 collateralSeized;

        if (collateralNeeded > pos.collateral) {
            collateralSeized = pos.collateral;
            feeCollateral = 0;
        } else {
            feeCollateral = (collateralNeeded * LIQUIDATION_FEE) / WAD;
            collateralSeized = collateralNeeded + feeCollateral;
            if (collateralSeized > pos.collateral) {
                collateralSeized = pos.collateral;
                feeCollateral = 0;
            }
        }

        pos.collateral -= collateralSeized;
        pos.debt = 0;

        totalCollateral[token] -= collateralSeized;
        totalDebtPerToken[token] -= debt;

        _burn(msg.sender, debt);

        uint256 liquidatorPortion = collateralSeized - feeCollateral;
        if (liquidatorPortion > 0) {
            IERC20(token).safeTransfer(msg.sender, liquidatorPortion);
        }
        if (feeCollateral > 0) {
            IERC20(token).safeTransfer(treasury, feeCollateral);
        }

        emit Liquidated(msg.sender, user, token, debt, liquidatorPortion, feeCollateral);
    }

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
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
