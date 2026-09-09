// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CollateralizedStablecoin {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error CollateralNotApproved();
    error CollateralAlreadyApproved();
    error InvalidValuation();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error MintBurnPaused();
    error DailyMintCapExceeded();
    error Undercollateralized();
    error CollateralTransferFailed();
    error CollateralReservesInsufficient();
    error ReentrancyGuardReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Mint(
        address indexed user,
        uint256 stableAmount,
        address indexed collateralToken,
        uint256 collateralAmount
    );
    event Burn(
        address indexed user,
        uint256 stableAmount,
        address indexed collateralToken,
        uint256 collateralAmount
    );
    event CollateralApproved(address indexed token, uint256 valuation);
    event CollateralRevoked(address indexed token);
    event CollateralValuationUpdated(address indexed token, uint256 oldValuation, uint256 newValuation);
    event MintBurnPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    string public constant name = "Government Collateralized Stablecoin";
    string public constant symbol = "GCS";
    uint8 public constant decimals = 18;
    uint256 public constant DAILY_MINT_CAP = 1_000_000 * 10 ** 18;
    uint256 private constant VALUATION_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    address public operator;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 public totalSupply;

    address[] private _collateralTokens;
    mapping(address => bool) public isCollateralApproved;
    mapping(address => uint256) public collateralValuation;
    mapping(address => uint256) public collateralReserves;
    mapping(address => uint256) private _collateralIndex;

    uint256 public totalCollateralValue;
    bool public mintBurnPaused;

    uint256 public mintedToday;
    uint256 public dayStartTimestamp;

    bool private _locked;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (mintBurnPaused) revert MintBurnPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyGuardReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        dayStartTimestamp = block.timestamp;
        emit OperatorChanged(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // ERC20 view functions
    // -----------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // -----------------------------------------------------------------------
    // ERC20 transfer / approval
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        if (currentAllowance != type(uint256).max) {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Operator management
    // -----------------------------------------------------------------------
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // -----------------------------------------------------------------------
    // Collateral management
    // -----------------------------------------------------------------------
    function approveCollateral(address token, uint256 valuation) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isCollateralApproved[token]) revert CollateralAlreadyApproved();
        if (valuation == 0) revert InvalidValuation();

        isCollateralApproved[token] = true;
        _collateralIndex[token] = _collateralTokens.length;
        _collateralTokens.push(token);
        collateralValuation[token] = valuation;

        emit CollateralApproved(token, valuation);
    }

    function revokeCollateral(address token) external onlyOperator {
        if (!isCollateralApproved[token]) revert CollateralNotApproved();
        if (collateralReserves[token] > 0) revert InvalidAmount();

        isCollateralApproved[token] = false;
        collateralValuation[token] = 0;

        uint256 idx = _collateralIndex[token];
        uint256 lastIdx = _collateralTokens.length - 1;
        if (idx != lastIdx) {
            address lastToken = _collateralTokens[lastIdx];
            _collateralTokens[idx] = lastToken;
            _collateralIndex[lastToken] = idx;
        }
        _collateralTokens.pop();
        _collateralIndex[token] = 0;

        emit CollateralRevoked(token);
    }

    function updateValuation(address token, uint256 newValuation) external onlyOperator {
        if (!isCollateralApproved[token]) revert CollateralNotApproved();
        if (newValuation == 0) revert InvalidValuation();

        uint256 oldValuation = collateralValuation[token];
        collateralValuation[token] = newValuation;

        _recomputeTotalCollateralValue();
        if (totalSupply > totalCollateralValue) revert Undercollateralized();

        emit CollateralValuationUpdated(token, oldValuation, newValuation);
    }

    function setMintBurnPaused(bool paused) external onlyOperator {
        mintBurnPaused = paused;
        emit MintBurnPausedChanged(paused);
    }

    // -----------------------------------------------------------------------
    // Minting
    // -----------------------------------------------------------------------
    function mint(address collateralToken, uint256 collateralAmount) external notPaused nonReentrant {
        if (!isCollateralApproved[collateralToken]) revert CollateralNotApproved();
        if (collateralAmount == 0) revert InvalidAmount();

        uint256 valuation = collateralValuation[collateralToken];
        uint256 collateralValue = (collateralAmount * valuation) / VALUATION_PRECISION;
        if (collateralValue == 0) revert InvalidAmount();

        // Daily mint cap
        if (block.timestamp >= dayStartTimestamp + 1 days) {
            dayStartTimestamp = block.timestamp;
            mintedToday = 0;
        }
        if (mintedToday + collateralValue > DAILY_MINT_CAP) revert DailyMintCapExceeded();

        // Effects before interactions
        collateralReserves[collateralToken] += collateralAmount;
        totalCollateralValue += collateralValue;
        mintedToday += collateralValue;
        _mint(msg.sender, collateralValue);

        // Interaction
        bool ok = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if (!ok) revert CollateralTransferFailed();

        emit Mint(msg.sender, collateralValue, collateralToken, collateralAmount);
    }

    // -----------------------------------------------------------------------
    // Burning / redemption
    // -----------------------------------------------------------------------
    function redeem(address collateralToken, uint256 stableAmount) external notPaused nonReentrant {
        if (!isCollateralApproved[collateralToken]) revert CollateralNotApproved();
        if (stableAmount == 0) revert InvalidAmount();
        if (_balances[msg.sender] < stableAmount) revert InsufficientBalance();

        uint256 valuation = collateralValuation[collateralToken];
        uint256 collateralAmount = (stableAmount * VALUATION_PRECISION) / valuation;
        if (collateralAmount == 0) revert InvalidAmount();
        if (collateralAmount > collateralReserves[collateralToken]) revert CollateralReservesInsufficient();

        // Effects before interactions
        _burn(msg.sender, stableAmount);
        collateralReserves[collateralToken] -= collateralAmount;
        totalCollateralValue -= stableAmount;

        // Interaction
        bool ok = IERC20(collateralToken).transfer(msg.sender, collateralAmount);
        if (!ok) revert CollateralTransferFailed();

        emit Burn(msg.sender, stableAmount, collateralToken, collateralAmount);
    }

    // -----------------------------------------------------------------------
    // Internal ERC20 logic
    // -----------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        if (_balances[account] < amount) revert InsufficientBalance();
        _balances[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Internal collateral accounting
    // -----------------------------------------------------------------------
    function _recomputeTotalCollateralValue() internal {
        uint256 total = 0;
        for (uint256 i = 0; i < _collateralTokens.length; ++i) {
            address token = _collateralTokens[i];
            uint256 reserves = collateralReserves[token];
            if (reserves == 0) continue;
            uint256 valuation = collateralValuation[token];
            total += (reserves * valuation) / VALUATION_PRECISION;
        }
        totalCollateralValue = total;
    }

    // -----------------------------------------------------------------------
    // View helpers
    // -----------------------------------------------------------------------
    function collateralTokensCount() external view returns (uint256) {
        return _collateralTokens.length;
    }

    function collateralTokenAt(uint256 index) external view returns (address) {
        return _collateralTokens[index];
    }

    function collateralizationRatio() external view returns (uint256) {
        if (totalSupply == 0) return 0;
        return (totalCollateralValue * 1e18) / totalSupply;
    }
}
