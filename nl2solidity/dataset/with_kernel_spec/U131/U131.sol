// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CollateralizedStablecoinVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_LTV_BPS = 8000;
    uint256 public constant MINT_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CollateralNotApproved();
    error CollateralAlreadyExists();
    error MintingPaused();
    error InsufficientCollateral();
    error InsufficientDebt();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidLTV();
    error InvalidPrice();
    error MintCapExceeded();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    struct CollateralConfig {
        bool approved;
        uint8 decimals;
        uint256 decimalFactor;
        uint256 price;
        uint256 maxLTV;
        uint256 mintCap;
        uint256 totalMinted;
    }

    EnumerableSet.AddressSet internal _approvedCollaterals;
    mapping(address => CollateralConfig) public collateralConfig;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(address => uint256)) public userAssetDebt;
    mapping(address => uint256) public userDebt;
    mapping(address => EnumerableSet.AddressSet) internal _userCollaterals;
    bool public mintingPaused;
    address public treasury;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed asset, uint256 amount);
    event StablecoinMinted(address indexed user, address indexed asset, uint256 amountMinted, uint256 fee, uint256 newDebt);
    event StablecoinRepaid(address indexed user, address indexed asset, uint256 amountRepaid, uint256 newDebt);
    event CollateralWithdrawn(address indexed user, address indexed asset, uint256 amount);
    event CollateralAdded(address indexed asset, uint256 price, uint256 maxLTV, uint256 mintCap);
    event CollateralPriceUpdated(address indexed asset, uint256 newPrice);
    event CollateralLTVUpdated(address indexed asset, uint256 newLTV);
    event MintCapUpdated(address indexed asset, uint256 newCap);
    event MintingPausedChanged(bool paused);
    event TreasuryUpdated(address indexed newTreasury);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, address _treasury) ERC20("Collateralized USD", "cUSD") Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyApprovedCollateral(address asset) {
        if (!collateralConfig[asset].approved) revert CollateralNotApproved();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(address asset, uint256 amount) external nonReentrant onlyApprovedCollateral(asset) {
        if (amount == 0) revert InvalidAmount();
        collateralBalances[msg.sender][asset] += amount;
        _userCollaterals[msg.sender].add(asset);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, asset, amount);
    }

    function mintStablecoin(address asset, uint256 amount) external nonReentrant onlyApprovedCollateral(asset) {
        if (mintingPaused) revert MintingPaused();
        if (amount == 0) revert InvalidAmount();
        CollateralConfig storage cfg = collateralConfig[asset];
        uint256 fee = (amount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 debtIncrease = amount + fee;
        uint256 newDebt = userDebt[msg.sender] + debtIncrease;
        if (newDebt > _maxDebtForUser(msg.sender)) revert InsufficientCollateral();
        if (cfg.totalMinted + debtIncrease > cfg.mintCap) revert MintCapExceeded();
        userDebt[msg.sender] = newDebt;
        userAssetDebt[msg.sender][asset] += debtIncrease;
        cfg.totalMinted += debtIncrease;
        _mint(msg.sender, amount);
        if (fee > 0) {
            _mint(treasury, fee);
        }
        emit StablecoinMinted(msg.sender, asset, amount, fee, newDebt);
    }

    function repayStablecoin(address asset, uint256 amount) external nonReentrant onlyApprovedCollateral(asset) {
        if (amount == 0) revert InvalidAmount();
        uint256 currentAssetDebt = userAssetDebt[msg.sender][asset];
        if (amount > currentAssetDebt) revert InsufficientDebt();
        userAssetDebt[msg.sender][asset] = currentAssetDebt - amount;
        userDebt[msg.sender] -= amount;
        collateralConfig[asset].totalMinted -= amount;
        _burn(msg.sender, amount);
        emit StablecoinRepaid(msg.sender, asset, amount, userDebt[msg.sender]);
    }

    function withdrawCollateral(address asset, uint256 amount) external nonReentrant onlyApprovedCollateral(asset) {
        if (amount == 0) revert InvalidAmount();
        if (collateralBalances[msg.sender][asset] < amount) revert InsufficientBalance();
        collateralBalances[msg.sender][asset] -= amount;
        if (userDebt[msg.sender] > _maxDebtForUser(msg.sender)) revert InsufficientCollateral();
        if (collateralBalances[msg.sender][asset] == 0) {
            _userCollaterals[msg.sender].remove(asset);
        }
        IERC20(asset).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, asset, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function approvedCollaterals() external view returns (address[] memory) {
        return _approvedCollaterals.values();
    }

    function approvedCollateralsCount() external view returns (uint256) {
        return _approvedCollaterals.length();
    }

    function getCollateralConfig(address asset) external view returns (CollateralConfig memory) {
        return collateralConfig[asset];
    }

    function getCollateralValue(address user) public view returns (uint256 totalValue) {
        address[] memory userTokens = _userCollaterals[user].values();
        uint256 len = userTokens.length;
        for (uint256 i = 0; i < len; ) {
            address asset = userTokens[i];
            CollateralConfig storage cfg = collateralConfig[asset];
            uint256 bal = collateralBalances[user][asset];
            if (bal > 0 && cfg.approved) {
                totalValue += (bal * cfg.price) / cfg.decimalFactor;
            }
            unchecked { ++i; }
        }
    }

    function getMaxDebt(address user) public view returns (uint256) {
        return _maxDebtForUser(user);
    }

    function isPositionSafe(address user) external view returns (bool) {
        return userDebt[user] <= _maxDebtForUser(user);
    }

    function getUserPosition(address user)
        external
        view
        returns (uint256 debt, uint256 collateralValue, uint256 maxDebt)
    {
        debt = userDebt[user];
        collateralValue = getCollateralValue(user);
        maxDebt = _maxDebtForUser(user);
    }

    function userCollateralBalance(address user, address asset) external view returns (uint256) {
        return collateralBalances[user][asset];
    }

    function userAssetDebtAmount(address user, address asset) external view returns (uint256) {
        return userAssetDebt[user][asset];
    }

    function userDepositedAssets(address user) external view returns (address[] memory) {
        return _userCollaterals[user].values();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _maxDebtForUser(address user) internal view returns (uint256 totalMaxDebt) {
        address[] memory userTokens = _userCollaterals[user].values();
        uint256 len = userTokens.length;
        for (uint256 i = 0; i < len; ) {
            address asset = userTokens[i];
            CollateralConfig storage cfg = collateralConfig[asset];
            uint256 bal = collateralBalances[user][asset];
            if (bal > 0 && cfg.approved) {
                uint256 value = (bal * cfg.price) / cfg.decimalFactor;
                totalMaxDebt += (value * cfg.maxLTV) / BPS_DENOMINATOR;
            }
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addCollateral(address asset, uint256 price, uint256 maxLTV, uint256 mintCap) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (collateralConfig[asset].approved) revert CollateralAlreadyExists();
        if (maxLTV > MAX_LTV_BPS) revert InvalidLTV();
        if (price == 0) revert InvalidPrice();
        uint8 decimals = IERC20Metadata(asset).decimals();
        collateralConfig[asset] = CollateralConfig({
            approved: true,
            decimals: decimals,
            decimalFactor: 10 ** uint256(decimals),
            price: price,
            maxLTV: maxLTV,
            mintCap: mintCap,
            totalMinted: 0
        });
        _approvedCollaterals.add(asset);
        emit CollateralAdded(asset, price, maxLTV, mintCap);
    }

    function setCollateralPrice(address asset, uint256 newPrice) external onlyOwner onlyApprovedCollateral(asset) {
        if (newPrice == 0) revert InvalidPrice();
        collateralConfig[asset].price = newPrice;
        emit CollateralPriceUpdated(asset, newPrice);
    }

    function setMaxLTV(address asset, uint256 newLTV) external onlyOwner onlyApprovedCollateral(asset) {
        if (newLTV > MAX_LTV_BPS) revert InvalidLTV();
        collateralConfig[asset].maxLTV = newLTV;
        emit CollateralLTVUpdated(asset, newLTV);
    }

    function setMintCap(address asset, uint256 newCap) external onlyOwner onlyApprovedCollateral(asset) {
        if (collateralConfig[asset].totalMinted > newCap) revert MintCapExceeded();
        collateralConfig[asset].mintCap = newCap;
        emit MintCapUpdated(asset, newCap);
    }

    function setMintingPaused(bool paused) external onlyOwner {
        mintingPaused = paused;
        emit MintingPausedChanged(paused);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
}
