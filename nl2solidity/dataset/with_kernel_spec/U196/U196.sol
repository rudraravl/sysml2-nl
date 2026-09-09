// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract LeveragedToken {
    uint8 public constant MAX_LEVERAGE = 10;
    uint16 public constant MAX_FEE_BPS = 1000; // 10% upper bound for operator-set fees
    uint16 public constant DEFAULT_FEE_BPS = 10; // 0.1% applied by default on mint & redeem
    uint16 public constant BPS_DENOMINATOR = 10000;

    address public operator;
    address public pendingOperator;
    IERC20 public immutable collateral;

    struct TokenConfig {
        string name;
        string symbol;
        uint8 leverageFactor;
        uint16 mintFeeBps;
        uint16 redemptionFeeBps;
        bool exists;
    }

    mapping(uint256 => TokenConfig) public tokenConfigs;
    mapping(uint256 => uint256) public totalSupply;
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;

    // Tracks the collateral currently committed to backing outstanding leveraged tokens.
    uint256 public totalCollateralBacking;

    event Mint(
        address indexed minter,
        address indexed recipient,
        uint256 indexed tokenId,
        uint256 collateralDeposited,
        uint256 mintedAmount,
        uint256 fee
    );
    event Redeem(
        address indexed redeemer,
        address indexed recipient,
        uint256 indexed tokenId,
        uint256 tokenAmount,
        uint256 collateralReturned,
        uint256 fee
    );
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId, uint256 amount);
    event TokenCreated(uint256 indexed tokenId, string name, string symbol, uint8 leverageFactor);
    event LeverageUpdated(uint256 indexed tokenId, uint8 oldLeverage, uint8 newLeverage);
    event FeesUpdated(uint256 indexed tokenId, uint16 mintFeeBps, uint16 redemptionFeeBps);
    event OperatorProposed(address indexed previousOperator, address indexed newOperator);
    event OperatorAccepted(address indexed previousOperator, address indexed newOperator);
    event FeesSwept(address indexed operator, address indexed recipient, uint256 amount);

    error NotOperator();
    error NotPendingOperator();
    error TokenDoesNotExist(uint256 tokenId);
    error TokenAlreadyExists(uint256 tokenId);
    error LeverageTooHigh(uint8 leverage);
    error ZeroLeverage();
    error FeeTooHigh(uint16 fee);
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientCollateral();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error NothingToSweep();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator, IERC20 _collateral) {
        if (_operator == address(0)) revert ZeroAddress();
        if (address(_collateral) == address(0)) revert ZeroAddress();
        operator = _operator;
        collateral = _collateral;
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function createToken(
        uint256 tokenId,
        string calldata name,
        string calldata symbol,
        uint8 leverageFactor
    ) external onlyOperator {
        if (tokenConfigs[tokenId].exists) revert TokenAlreadyExists(tokenId);
        if (leverageFactor == 0) revert ZeroLeverage();
        if (leverageFactor > MAX_LEVERAGE) revert LeverageTooHigh(leverageFactor);
        tokenConfigs[tokenId] = TokenConfig({
            name: name,
            symbol: symbol,
            leverageFactor: leverageFactor,
            mintFeeBps: DEFAULT_FEE_BPS,
            redemptionFeeBps: DEFAULT_FEE_BPS,
            exists: true
        });
        emit TokenCreated(tokenId, name, symbol, leverageFactor);
    }

    function mint(
        uint256 tokenId,
        uint256 collateralAmount,
        address recipient
    ) external returns (uint256 mintedAmount) {
        TokenConfig storage cfg = tokenConfigs[tokenId];
        if (!cfg.exists) revert TokenDoesNotExist(tokenId);
        if (recipient == address(0)) revert ZeroAddress();
        if (collateralAmount == 0) revert ZeroAmount();

        uint256 fee = (collateralAmount * uint256(cfg.mintFeeBps)) / BPS_DENOMINATOR;
        uint256 netCollateral = collateralAmount - fee;

        // Pull the full collateral amount from the caller; the fee remains custodied by the contract.
        _safeTransferFrom(collateral, msg.sender, address(this), collateralAmount);

        mintedAmount = netCollateral * uint256(cfg.leverageFactor);

        totalSupply[tokenId] += mintedAmount;
        balanceOf[recipient][tokenId] += mintedAmount;
        totalCollateralBacking += netCollateral;

        emit Mint(msg.sender, recipient, tokenId, collateralAmount, mintedAmount, fee);
    }

    function redeem(
        uint256 tokenId,
        uint256 tokenAmount,
        address recipient
    ) external returns (uint256 collateralReturned) {
        TokenConfig storage cfg = tokenConfigs[tokenId];
        if (!cfg.exists) revert TokenDoesNotExist(tokenId);
        if (recipient == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender][tokenId] < tokenAmount) revert InsufficientBalance();

        uint256 lev = uint256(cfg.leverageFactor);
        // Compute the redemption fee by multiplying before dividing so that no
        // intermediate division result is subsequently multiplied, avoiding
        // precision loss from divide-before-multiply.
        uint256 fee = (tokenAmount * uint256(cfg.redemptionFeeBps)) / (lev * BPS_DENOMINATOR);
        uint256 grossCollateral = tokenAmount / lev;
        collateralReturned = grossCollateral - fee;

        if (collateral.balanceOf(address(this)) < collateralReturned) revert InsufficientCollateral();
        if (totalCollateralBacking < grossCollateral) revert InsufficientCollateral();

        // checks-effects-interactions
        balanceOf[msg.sender][tokenId] -= tokenAmount;
        totalSupply[tokenId] -= tokenAmount;
        totalCollateralBacking -= grossCollateral;

        _safeTransfer(collateral, recipient, collateralReturned);

        emit Redeem(msg.sender, recipient, tokenId, tokenAmount, collateralReturned, fee);
    }

    function transfer(address to, uint256 tokenId, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (!tokenConfigs[tokenId].exists) revert TokenDoesNotExist(tokenId);
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender][tokenId] < amount) revert InsufficientBalance();

        balanceOf[msg.sender][tokenId] -= amount;
        balanceOf[to][tokenId] += amount;

        emit Transfer(msg.sender, to, tokenId, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 tokenId, uint256 amount) external returns (bool) {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (!tokenConfigs[tokenId].exists) revert TokenDoesNotExist(tokenId);
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from][tokenId] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender][tokenId];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender][tokenId] = allowed - amount;
        }

        balanceOf[from][tokenId] -= amount;
        balanceOf[to][tokenId] += amount;

        emit Transfer(from, to, tokenId, amount);
        return true;
    }

    function approve(address spender, uint256 tokenId, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        if (!tokenConfigs[tokenId].exists) revert TokenDoesNotExist(tokenId);
        allowance[msg.sender][spender][tokenId] = amount;
        emit Approval(msg.sender, spender, tokenId, amount);
        return true;
    }

    function updateLeverage(uint256 tokenId, uint8 newLeverage) external onlyOperator {
        if (!tokenConfigs[tokenId].exists) revert TokenDoesNotExist(tokenId);
        if (newLeverage == 0) revert ZeroLeverage();
        if (newLeverage > MAX_LEVERAGE) revert LeverageTooHigh(newLeverage);
        uint8 oldLeverage = tokenConfigs[tokenId].leverageFactor;
        tokenConfigs[tokenId].leverageFactor = newLeverage;
        emit LeverageUpdated(tokenId, oldLeverage, newLeverage);
    }

    function updateFees(uint256 tokenId, uint16 mintFeeBps, uint16 redemptionFeeBps) external onlyOperator {
        if (!tokenConfigs[tokenId].exists) revert TokenDoesNotExist(tokenId);
        if (mintFeeBps > MAX_FEE_BPS) revert FeeTooHigh(mintFeeBps);
        if (redemptionFeeBps > MAX_FEE_BPS) revert FeeTooHigh(redemptionFeeBps);
        tokenConfigs[tokenId].mintFeeBps = mintFeeBps;
        tokenConfigs[tokenId].redemptionFeeBps = redemptionFeeBps;
        emit FeesUpdated(tokenId, mintFeeBps, redemptionFeeBps);
    }

    function proposeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
        emit OperatorProposed(operator, newOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();
        address previous = operator;
        operator = pendingOperator;
        delete pendingOperator;
        emit OperatorAccepted(previous, operator);
    }

    function sweepFees(address recipient) external onlyOperator returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 contractBalance = collateral.balanceOf(address(this));
        if (contractBalance <= totalCollateralBacking) revert NothingToSweep();
        uint256 amount = contractBalance - totalCollateralBacking;
        _safeTransfer(collateral, recipient, amount);
        emit FeesSwept(msg.sender, recipient, amount);
        return amount;
    }

    function getTokenConfig(uint256 tokenId) external view returns (TokenConfig memory) {
        return tokenConfigs[tokenId];
    }

    function getFees(uint256 tokenId) external view returns (uint16 mintFeeBps, uint16 redemptionFeeBps) {
        TokenConfig storage cfg = tokenConfigs[tokenId];
        return (cfg.mintFeeBps, cfg.redemptionFeeBps);
    }
}
