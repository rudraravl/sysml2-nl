// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WrappedAssetBridge {
    error EnforcedPause();
    error ExpectedPause();
    error Unauthorized();
    error DepositTooSmall();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error ZeroShares();
    error InsufficientReserves();

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Redeem(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 fee);
    event PausedStatusChanged(bool isPaused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    IERC20 public immutable underlyingAsset;
    address public operator;
    bool public paused;
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public minDeposit;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    constructor(address _underlyingAsset, string memory _name, string memory _symbol) {
        if (_underlyingAsset == address(0)) revert ZeroAddress();
        underlyingAsset = IERC20(_underlyingAsset);
        operator = msg.sender;
        name = _name;
        symbol = _symbol;

        uint8 assetDecimals = 18;
        try IERC20(_underlyingAsset).decimals() returns (uint8 d) {
            if (d > 0) {
                assetDecimals = d;
            }
        } catch {}
        decimals = assetDecimals;
        if (assetDecimals >= 3) {
            minDeposit = 10 ** (uint256(assetDecimals) - 3);
        } else {
            minDeposit = 1;
        }
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function deposit(uint256 assets, address receiver) external whenNotPaused returns (uint256 shares) {
        if (receiver == address(0)) revert ZeroAddress();
        if (assets < minDeposit) revert DepositTooSmall();

        shares = assets;

        uint256 balanceBefore = underlyingAsset.balanceOf(address(this));
        if (!underlyingAsset.transferFrom(msg.sender, address(this), assets)) revert TransferFailed();
        if (underlyingAsset.balanceOf(address(this)) < balanceBefore + assets) revert TransferFailed();

        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver) external whenNotPaused returns (uint256 assets) {
        if (receiver == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroShares();
        if (_balances[msg.sender] < shares) revert InsufficientBalance();

        assets = shares;
        uint256 fee = (assets * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 assetsToReturn = assets - fee;

        _burn(msg.sender, shares);

        if (!underlyingAsset.transfer(receiver, assetsToReturn)) revert TransferFailed();

        emit Redeem(msg.sender, receiver, msg.sender, assets, shares, fee);
    }

    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit PausedStatusChanged(true);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit PausedStatusChanged(false);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = underlyingAsset.balanceOf(address(this));
        if (balance < _totalSupply) revert InsufficientReserves();
        uint256 withdrawable = balance - _totalSupply;
        if (withdrawable > 0) {
            if (!underlyingAsset.transfer(to, withdrawable)) revert TransferFailed();
        }
    }
}
