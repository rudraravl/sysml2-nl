// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface ISyntheticStablecoin {
    function mint(address to, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

contract CDPManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant MAX_COLLATERAL_RATIO = 1.5e18;

    IERC20 public immutable collateralToken;
    ISyntheticStablecoin public immutable stablecoin;
    IPriceOracle public immutable oracle;

    uint256 public liquidationThreshold;
    uint256 public liquidationPenalty;
    uint256 public mintFee;
    address public feeRecipient;

    struct CDP {
        uint256 collateral;
        uint256 debt;
        bool liquidated;
    }

    mapping(address => CDP) public cdps;
    mapping(address => bool) public hasCDP;

    event CDPOpened(address indexed user, uint256 collateralAmount);
    event CollateralDeposited(address indexed user, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 amountMinted, uint256 feePaid, uint256 newDebt);
    event StablecoinRepaid(address indexed user, uint256 amountRepaid, uint256 newDebt);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CDPLiquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);
    event LiquidationThresholdSet(uint256 oldThreshold, uint256 newThreshold);
    event LiquidationPenaltySet(uint256 oldPenalty, uint256 newPenalty);
    event MintFeeSet(uint256 oldFee, uint256 newFee);
    event FeeRecipientSet(address indexed oldRecipient, address indexed newRecipient);

    error ZeroAmount();
    error ZeroAddress();
    error CDPAlreadyExists();
    error CDPDoesNotExist();
    error CDPLiquidated();
    error CDPNotLiquidatable();
    error InsufficientCollateral();
    error InsufficientDebt();
    error InvalidParameter();

    constructor(
        address _collateralToken,
        address _stablecoin,
        address _oracle,
        address _admin,
        address _feeRecipient,
        uint256 _liquidationThreshold,
        uint256 _liquidationPenalty,
        uint256 _mintFee
    ) {
        if (_collateralToken == address(0) || _stablecoin == address(0) || _oracle == address(0)) revert ZeroAddress();
        if (_admin == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_liquidationThreshold < 1e18 || _liquidationThreshold > MAX_COLLATERAL_RATIO) revert InvalidParameter();
        if (_liquidationPenalty > 0.5e18) revert InvalidParameter();
        if (_mintFee > 0.1e18) revert InvalidParameter();

        collateralToken = IERC20(_collateralToken);
        stablecoin = ISyntheticStablecoin(_stablecoin);
        oracle = IPriceOracle(_oracle);
        feeRecipient = _feeRecipient;

        liquidationThreshold = _liquidationThreshold;
        liquidationPenalty = _liquidationPenalty;
        mintFee = _mintFee;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }

    function openCDP(uint256 collateralAmount) external nonReentrant {
        if (collateralAmount == 0) revert ZeroAmount();
        CDP storage cdp = cdps[msg.sender];
        if (hasCDP[msg.sender] && !cdp.liquidated) revert CDPAlreadyExists();

        collateralToken.safeTransferFrom(msg.sender, address(this), collateralAmount);

        cdp.collateral = collateralAmount;
        cdp.debt = 0;
        cdp.liquidated = false;
        hasCDP[msg.sender] = true;

        emit CDPOpened(msg.sender, collateralAmount);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CDP storage cdp = cdps[msg.sender];
        if (!hasCDP[msg.sender]) revert CDPDoesNotExist();
        if (cdp.liquidated) revert CDPLiquidated();

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        cdp.collateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function mintStablecoin(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CDP storage cdp = cdps[msg.sender];
        if (!hasCDP[msg.sender]) revert CDPDoesNotExist();
        if (cdp.liquidated) revert CDPLiquidated();

        uint256 fee = (amount * mintFee) / WAD;
        uint256 newDebt = cdp.debt + amount + fee;

        if (!_isSafeForMint(cdp.collateral, newDebt)) revert InsufficientCollateral();

        cdp.debt = newDebt;
        stablecoin.mint(msg.sender, amount);
        if (fee > 0) {
            stablecoin.mint(feeRecipient, fee);
        }

        emit StablecoinMinted(msg.sender, amount, fee, newDebt);
    }

    function repayStablecoin(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CDP storage cdp = cdps[msg.sender];
        if (!hasCDP[msg.sender]) revert CDPDoesNotExist();
        if (cdp.liquidated) revert CDPLiquidated();
        if (cdp.debt == 0) revert InsufficientDebt();

        uint256 repayAmount = amount > cdp.debt ? cdp.debt : amount;
        cdp.debt -= repayAmount;

        stablecoin.burnFrom(msg.sender, repayAmount);

        emit StablecoinRepaid(msg.sender, repayAmount, cdp.debt);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CDP storage cdp = cdps[msg.sender];
        if (!hasCDP[msg.sender]) revert CDPDoesNotExist();
        if (cdp.liquidated) revert CDPLiquidated();
        if (amount > cdp.collateral) revert InsufficientCollateral();

        uint256 newCollateral = cdp.collateral - amount;
        if (!_isSafeForMint(newCollateral, cdp.debt)) revert InsufficientCollateral();

        cdp.collateral = newCollateral;
        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function liquidate(address user) external nonReentrant {
        CDP storage cdp = cdps[user];
        if (!hasCDP[user]) revert CDPDoesNotExist();
        if (cdp.liquidated) revert CDPLiquidated();
        if (cdp.debt == 0) revert CDPNotLiquidatable();
        if (!_isLiquidatable(cdp.collateral, cdp.debt)) revert CDPNotLiquidatable();

        uint256 debtToRepay = cdp.debt;
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (collateralPrice == 0) revert InvalidParameter();
        uint256 stablecoinPrice = oracle.getPrice(address(stablecoin));
        if (stablecoinPrice == 0) revert InvalidParameter();

        uint256 debtValue = (debtToRepay * stablecoinPrice) / WAD;
        uint256 seizeValue = (debtValue * (WAD + liquidationPenalty)) / WAD;
        uint256 collateralToSeize = (seizeValue * WAD) / collateralPrice;
        if (collateralToSeize > cdp.collateral) {
            collateralToSeize = cdp.collateral;
        }
        uint256 remainingCollateral = cdp.collateral - collateralToSeize;

        stablecoin.burnFrom(msg.sender, debtToRepay);

        cdp.debt = 0;
        cdp.collateral = 0;
        cdp.liquidated = true;

        collateralToken.safeTransfer(msg.sender, collateralToSeize);
        if (remainingCollateral > 0) {
            collateralToken.safeTransfer(user, remainingCollateral);
        }

        emit CDPLiquidated(user, msg.sender, debtToRepay, collateralToSeize);
    }

    function setLiquidationThreshold(uint256 newThreshold) external onlyRole(OPERATOR_ROLE) {
        if (newThreshold < 1e18 || newThreshold > MAX_COLLATERAL_RATIO) revert InvalidParameter();
        uint256 old = liquidationThreshold;
        liquidationThreshold = newThreshold;
        emit LiquidationThresholdSet(old, newThreshold);
    }

    function setLiquidationPenalty(uint256 newPenalty) external onlyRole(OPERATOR_ROLE) {
        if (newPenalty > 0.5e18) revert InvalidParameter();
        uint256 old = liquidationPenalty;
        liquidationPenalty = newPenalty;
        emit LiquidationPenaltySet(old, newPenalty);
    }

    function setMintFee(uint256 newFee) external onlyRole(OPERATOR_ROLE) {
        if (newFee > 0.1e18) revert InvalidParameter();
        uint256 old = mintFee;
        mintFee = newFee;
        emit MintFeeSet(old, newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientSet(old, newRecipient);
    }

    function getCDP(address user) external view returns (CDP memory) {
        return cdps[user];
    }

    function isLiquidatable(address user) external view returns (bool) {
        CDP storage cdp = cdps[user];
        if (!hasCDP[user] || cdp.liquidated || cdp.debt == 0) return false;
        return _isLiquidatable(cdp.collateral, cdp.debt);
    }

    function collateralizationRatio(address user) external view returns (uint256) {
        CDP storage cdp = cdps[user];
        if (cdp.debt == 0) return type(uint256).max;
        uint256 cv = _collateralValue(cdp.collateral);
        uint256 dv = _debtValue(cdp.debt);
        if (dv == 0) return type(uint256).max;
        return (cv * WAD) / dv;
    }

    function maxMintableStablecoin(address user) external view returns (uint256) {
        CDP storage cdp = cdps[user];
        if (!hasCDP[user] || cdp.liquidated) return 0;
        uint256 cv = _collateralValue(cdp.collateral);
        uint256 maxDebtValue = (cv * WAD) / MAX_COLLATERAL_RATIO;
        uint256 stablecoinPrice = oracle.getPrice(address(stablecoin));
        if (stablecoinPrice == 0) return 0;
        uint256 maxDebt = (maxDebtValue * WAD) / stablecoinPrice;
        if (maxDebt <= cdp.debt) return 0;
        uint256 headroom = maxDebt - cdp.debt;
        if (mintFee >= WAD) return 0;
        return (headroom * WAD) / (WAD + mintFee);
    }

    function _collateralValue(uint256 collateral) internal view returns (uint256) {
        uint256 price = oracle.getPrice(address(collateralToken));
        return (collateral * price) / WAD;
    }

    function _debtValue(uint256 debt) internal view returns (uint256) {
        uint256 price = oracle.getPrice(address(stablecoin));
        return (debt * price) / WAD;
    }

    function _isSafeForMint(uint256 collateral, uint256 debt) internal view returns (bool) {
        if (debt == 0) return true;
        uint256 cv = _collateralValue(collateral);
        uint256 dv = _debtValue(debt);
        if (dv == 0) return true;
        return cv * WAD >= dv * MAX_COLLATERAL_RATIO;
    }

    function _isLiquidatable(uint256 collateral, uint256 debt) internal view returns (bool) {
        if (debt == 0) return false;
        uint256 cv = _collateralValue(collateral);
        uint256 dv = _debtValue(debt);
        if (dv == 0) return false;
        return cv * WAD < dv * liquidationThreshold;
    }
}
