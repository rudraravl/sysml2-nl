// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract EuroStablecoin {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error CollateralNotApproved();
    error PriceNotSet();
    error RatioTooLow();
    error RatioTooHigh();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientCollateralReserve();
    error MaxSupplyExceeded();
    error MintPaused();
    error BurnPaused();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, address indexed collateral, uint256 collateralAmount, uint256 stableMinted);
    event Burn(address indexed burner, address indexed collateral, uint256 stableBurned, uint256 collateralReturned);
    event CollateralApproved(address indexed token, uint256 price);
    event CollateralPriceUpdated(address indexed token, uint256 newPrice);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MintPausedChanged(bool paused);
    event BurnPausedChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint8 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant MIN_RATIO = 100; // 100%
    uint256 public constant MAX_RATIO = 10000; // 10,000% safety cap

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public owner;
    string public name;
    string public symbol;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public collateralizationRatio; // e.g., 150 => 150%

    bool public mintPaused;
    bool public burnPaused;

    mapping(address => bool) public approvedCollateral;
    mapping(address => uint256) public collateralPrice; // EUR value per token, 18 decimals
    mapping(address => uint256) public collateralReserve;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(string memory _name, string memory _symbol, uint256 _initialRatio) {
        if (_initialRatio < MIN_RATIO) revert RatioTooLow();
        if (_initialRatio > MAX_RATIO) revert RatioTooHigh();
        name = _name;
        symbol = _symbol;
        collateralizationRatio = _initialRatio;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit CollateralizationRatioUpdated(0, _initialRatio);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    // ---------------------------------------------------------------------
    // Ownership
    // ---------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    // ---------------------------------------------------------------------
    // Owner: collateral management
    // ---------------------------------------------------------------------
    function approveCollateral(address token, uint256 price) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (price == 0) revert PriceNotSet();
        approvedCollateral[token] = true;
        collateralPrice[token] = price;
        emit CollateralApproved(token, price);
    }

    function setCollateralPrice(address token, uint256 newPrice) external onlyOwner {
        if (!approvedCollateral[token]) revert CollateralNotApproved();
        if (newPrice == 0) revert PriceNotSet();
        collateralPrice[token] = newPrice;
        emit CollateralPriceUpdated(token, newPrice);
    }

    // ---------------------------------------------------------------------
    // Owner: ratio & pause controls
    // ---------------------------------------------------------------------
    function setCollateralizationRatio(uint256 newRatio) external onlyOwner {
        if (newRatio < MIN_RATIO) revert RatioTooLow();
        if (newRatio > MAX_RATIO) revert RatioTooHigh();
        uint256 old = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(old, newRatio);
    }

    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
        emit MintPausedChanged(paused);
    }

    function setBurnPaused(bool paused) external onlyOwner {
        burnPaused = paused;
        emit BurnPausedChanged(paused);
    }

    // ---------------------------------------------------------------------
    // ERC20 transfers
    // ---------------------------------------------------------------------
    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[sender][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[sender][msg.sender] = allowed - amount;
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Mint: deposit collateral, receive stablecoins
    // ---------------------------------------------------------------------
    function mint(address collateral, uint256 collateralAmount) external returns (uint256 minted) {
        if (mintPaused) revert MintPaused();
        if (collateral == address(0)) revert ZeroAddress();
        if (!approvedCollateral[collateral]) revert CollateralNotApproved();
        if (collateralAmount == 0) revert ZeroAmount();

        uint256 price = collateralPrice[collateral];
        if (price == 0) revert PriceNotSet();

        // Collateral value in EUR (18 decimals)
        uint256 collateralValue = (collateralAmount * price) / 1e18;
        if (collateralValue == 0) revert ZeroAmount();

        // Stablecoins mintable = collateralValue * 100 / ratio
        minted = (collateralValue * 100) / collateralizationRatio;
        if (minted == 0) revert ZeroAmount();

        if (totalSupply + minted > MAX_SUPPLY) revert MaxSupplyExceeded();

        // Pull collateral from sender (effects before interactions)
        collateralReserve[collateral] += collateralAmount;
        _mint(msg.sender, minted);

        bool ok = IERC20(collateral).transferFrom(msg.sender, address(this), collateralAmount);
        if (!ok) revert InsufficientAllowance();

        emit Mint(msg.sender, collateral, collateralAmount, minted);
    }

    // ---------------------------------------------------------------------
    // Burn: redeem stablecoins for collateral
    // ---------------------------------------------------------------------
    function burn(uint256 stableAmount, address collateral) external returns (uint256 returned) {
        if (burnPaused) revert BurnPaused();
        if (collateral == address(0)) revert ZeroAddress();
        if (!approvedCollateral[collateral]) revert CollateralNotApproved();
        if (stableAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance();

        uint256 price = collateralPrice[collateral];
        if (price == 0) revert PriceNotSet();

        // Collateral to return = stableAmount * ratio / 100 * 1e18 / price
        returned = (stableAmount * collateralizationRatio * 1e18) / (100 * price);
        if (returned == 0) revert ZeroAmount();
        if (collateralReserve[collateral] < returned) revert InsufficientCollateralReserve();

        // Effects before interactions
        _burn(msg.sender, stableAmount);
        collateralReserve[collateral] -= returned;

        bool ok = IERC20(collateral).transfer(msg.sender, returned);
        if (!ok) revert InsufficientCollateralReserve();

        emit Burn(msg.sender, collateral, stableAmount, returned);
    }

    // ---------------------------------------------------------------------
    // Internal mint / burn
    // ---------------------------------------------------------------------
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
