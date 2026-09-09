// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract StablecoinSystem {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant BPS = 10_000;
    uint256 public constant MINT_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 1.5e18; // 150%

    IERC20 public immutable collateralAsset;

    address public operator;
    uint256 public collateralizationRatio;
    bool public mintPaused;

    uint256 public totalDebt;
    uint256 public totalStableSupply;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public stableBalance;
    mapping(address => uint256) public debt;

    event CollateralDeposited(address indexed account, uint256 amount);
    event CollateralWithdrawn(address indexed account, uint256 amount);
    event StableMinted(address indexed account, uint256 amount, uint256 fee);
    event StableBurned(address indexed account, uint256 amount);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MintPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error MintPaused();
    error InsufficientCollateral();
    error InsufficientStableBalance();
    error InsufficientDebt();
    error RatioTooLow();
    error ZeroAddress();
    error ZeroAmount();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _collateralAsset, address _operator) {
        if (_collateralAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        collateralAsset = IERC20(_collateralAsset);
        operator = _operator;
        collateralizationRatio = MIN_COLLATERALIZATION_RATIO;

        emit CollateralizationRatioUpdated(0, collateralizationRatio);
        emit OperatorChanged(address(0), _operator);
    }

    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        collateralAsset.safeTransferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function mint(uint256 amount) external {
        if (mintPaused) revert MintPaused();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * MINT_FEE_BPS) / BPS;
        uint256 mintAmount = amount - fee;

        debt[msg.sender] += amount;
        totalDebt += amount;

        stableBalance[msg.sender] += mintAmount;
        totalStableSupply += mintAmount;

        _requireSafe(msg.sender);

        emit StableMinted(msg.sender, mintAmount, fee);
    }

    function repay(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (amount > debt[msg.sender]) revert InsufficientDebt();
        if (amount > stableBalance[msg.sender]) revert InsufficientStableBalance();

        debt[msg.sender] -= amount;
        totalDebt -= amount;
        stableBalance[msg.sender] -= amount;
        totalStableSupply -= amount;

        emit StableBurned(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (amount > collateralBalance[msg.sender]) revert InsufficientCollateral();

        collateralBalance[msg.sender] -= amount;
        collateralAsset.safeTransfer(msg.sender, amount);

        _requireSafe(msg.sender);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function transferStable(address to, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (amount > stableBalance[msg.sender]) revert InsufficientStableBalance();

        stableBalance[msg.sender] -= amount;
        stableBalance[to] += amount;
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_COLLATERALIZATION_RATIO) revert RatioTooLow();
        uint256 old = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(old, newRatio);
    }

    function setMintPaused(bool paused) external onlyOperator {
        mintPaused = paused;
        emit MintPausedChanged(paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function isSafe(address account) public view returns (bool) {
        uint256 required = (debt[account] * collateralizationRatio) / WAD;
        return collateralBalance[account] >= required;
    }

    function maxMintable(address account) external view returns (uint256) {
        uint256 collateral = collateralBalance[account];
        uint256 currentDebt = debt[account];
        uint256 maxDebt = (collateral * WAD) / collateralizationRatio;
        if (maxDebt <= currentDebt) return 0;
        return maxDebt - currentDebt;
    }

    function getUserRatio(address account) external view returns (uint256) {
        uint256 userDebt = debt[account];
        if (userDebt == 0) return type(uint256).max;
        return (collateralBalance[account] * WAD) / userDebt;
    }

    function _requireSafe(address account) internal view {
        uint256 required = (debt[account] * collateralizationRatio) / WAD;
        if (collateralBalance[account] < required) revert InsufficientCollateral();
    }
}
