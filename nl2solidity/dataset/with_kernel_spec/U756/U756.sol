// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract YieldBearingVault {
    // ---------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------
    error ZeroAmount();
    error ZeroShares();
    error ZeroAddress();
    error InsufficientShares();
    error InsufficientAllowance();
    error DepositsWithdrawalsPaused();
    error RebaseCooldownActive(uint256 lastRebaseTimestamp, uint256 remainingSeconds);
    error NotOperator();
    error TransferFailed();
    error CannotSweepAsset();

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares, uint256 newTotalAssets);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 newTotalAssets);
    event Rebase(address indexed caller, uint256 oldTotalAssets, uint256 newTotalAssets, uint256 timestamp);
    event PausedStateChanged(bool isPaused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------
    IERC20 public immutable asset;

    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalShares;
    uint256 private _totalAssets;

    uint256 public lastRebaseTimestamp;
    address public operator;
    bool public paused;

    uint256 public constant REBASE_COOLDOWN = 1 days;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5% = 50 bps
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert DepositsWithdrawalsPaused();
        _;
    }

    modifier nonReentrant() {
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    constructor(IERC20 _asset, address _operator) {
        if (address(_asset) == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        asset = _asset;
        operator = _operator;
        lastRebaseTimestamp = block.timestamp;
    }

    // ---------------------------------------------------------------
    // Public view functions
    // ---------------------------------------------------------------
    function totalAssets() public view returns (uint256) {
        return _totalAssets;
    }

    function totalSupply() public view returns (uint256) {
        return _totalShares;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint256 supply = _totalShares;
        if (supply == 0 || _totalAssets == 0) {
            shares = assets;
        } else {
            shares = (assets * supply) / _totalAssets;
        }
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint256 supply = _totalShares;
        if (supply == 0) {
            assets = 0;
        } else {
            assets = (shares * _totalAssets) / supply;
        }
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256 assets) {
        uint256 supply = _totalShares;
        uint256 total = _totalAssets;
        if (supply == 0 || total == 0) {
            assets = shares;
        } else {
            // Round up in favor of the vault
            assets = (shares * total + supply - 1) / supply;
        }
    }

    function previewWithdrawShares(uint256 assets) public view returns (uint256 shares) {
        uint256 supply = _totalShares;
        uint256 total = _totalAssets;
        if (total == 0 || supply == 0) return 0;
        // Round up in favor of the vault
        shares = (assets * supply + total - 1) / total;
    }

    function previewWithdraw(uint256 assets) public pure returns (uint256) {
        uint256 fee = (assets * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        return assets - fee;
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        assets = convertToAssets(shares);
        if (assets == 0) return 0;
        uint256 fee = (assets * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        return assets - fee;
    }

    // ---------------------------------------------------------------
    // Deposit / Mint
    // ---------------------------------------------------------------
    function deposit(uint256 assets, address receiver) public nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        _totalAssets += assets;
        _totalShares += shares;
        _shares[receiver] += shares;

        _safeTransferFrom(asset, msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares, _totalAssets);
    }

    function mint(uint256 shares, address receiver) public nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();
        assets = previewMint(shares);
        if (assets == 0) revert ZeroAmount();

        _totalAssets += assets;
        _totalShares += shares;
        _shares[receiver] += shares;

        _safeTransferFrom(asset, msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares, _totalAssets);
    }

    // ---------------------------------------------------------------
    // Withdraw / Redeem
    // ---------------------------------------------------------------
    function withdraw(
        uint256 assets,
        address receiver,
        address owner_
    ) public nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        shares = previewWithdrawShares(assets);
        if (_shares[owner_] < shares) revert InsufficientShares();

        if (msg.sender != owner_) {
            uint256 allowed = _allowances[owner_][msg.sender];
            if (allowed < shares) revert InsufficientAllowance();
            unchecked {
                _allowances[owner_][msg.sender] = allowed - shares;
            }
        }

        uint256 netAssets = previewWithdraw(assets);

        _totalAssets -= assets;
        _totalShares -= shares;
        _shares[owner_] -= shares;

        _safeTransfer(asset, receiver, netAssets);

        emit Withdraw(msg.sender, receiver, owner_, netAssets, shares, _totalAssets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner_
    ) public nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();
        if (_shares[owner_] < shares) revert InsufficientShares();

        if (msg.sender != owner_) {
            uint256 allowed = _allowances[owner_][msg.sender];
            if (allowed < shares) revert InsufficientAllowance();
            unchecked {
                _allowances[owner_][msg.sender] = allowed - shares;
            }
        }

        uint256 grossAssets = convertToAssets(shares);
        assets = previewWithdraw(grossAssets);

        _totalAssets -= grossAssets;
        _totalShares -= shares;
        _shares[owner_] -= shares;

        _safeTransfer(asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner_, assets, shares, _totalAssets);
    }

    // ---------------------------------------------------------------
    // ERC-20 style share transfer and approvals
    // ---------------------------------------------------------------
    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        _transferShares(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        unchecked {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transferShares(from, to, amount);
        emit Transfer(from, to, amount);
        return true;
    }

    function _transferShares(address from, address to, uint256 amount) internal {
        uint256 currentShares = _shares[from];
        if (currentShares < amount) revert InsufficientShares();
        unchecked {
            _shares[from] = currentShares - amount;
        }
        _shares[to] += amount;
    }

    // ---------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------
    function rebase(uint256 newTotalAssets) public onlyOperator {
        uint256 last = lastRebaseTimestamp;
        if (block.timestamp < last + REBASE_COOLDOWN) {
            revert RebaseCooldownActive(last, (last + REBASE_COOLDOWN) - block.timestamp);
        }

        uint256 oldTotalAssets = _totalAssets;
        _totalAssets = newTotalAssets;
        lastRebaseTimestamp = block.timestamp;

        emit Rebase(msg.sender, oldTotalAssets, newTotalAssets, block.timestamp);
    }

    function setOperator(address newOperator) public onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function pause() public onlyOperator {
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() public onlyOperator {
        paused = false;
        emit PausedStateChanged(false);
    }

    function setPaused(bool _paused) public onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // ---------------------------------------------------------------
    // Emergency token recovery
    // ---------------------------------------------------------------
    function sweep(address token, address to, uint256 amount) public onlyOperator {
        if (token == address(asset)) revert CannotSweepAsset();
        if (to == address(0)) revert ZeroAddress();
        _safeTransfer(IERC20(token), to, amount);
    }

    // ---------------------------------------------------------------
    // Internal safe transfer helpers
    // ---------------------------------------------------------------
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
