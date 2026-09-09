// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IExchangeRateOracle {
    function getExchangeRate() external view returns (uint256);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (success) {
            if (returndata.length > 0) {
                require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
            }
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract LiquidStakingPool is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_DEPOSIT = 0.01 ether; // 0.01 units (18 decimals)

    IERC20 public immutable baseAsset;
    address public operator;
    address public treasury;
    address public oracle;
    uint256 public totalStaked;
    uint256 public exchangeRate;
    bool public paused;

    error ZeroAddress();
    error NotOperator();
    error DepositBelowMinimum();
    error ZeroShares();
    error ZeroAssets();
    error InvalidExchangeRate();
    error WhenPaused();
    error InsufficientBalance();
    error InsufficientAllowance();

    event Deposited(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdrawn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        uint256 fee
    );
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event OracleChanged(address indexed oldOracle, address indexed newOracle);
    event Staked(address indexed operator, uint256 amount);
    event Unstaked(address indexed operator, uint256 amount);
    event PausedStateChanged(bool paused);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    constructor(
        address _baseAsset,
        address _operator,
        address _treasury,
        address _oracle,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (
            _baseAsset == address(0) ||
            _operator == address(0) ||
            _treasury == address(0) ||
            _oracle == address(0)
        ) {
            revert ZeroAddress();
        }
        baseAsset = IERC20(_baseAsset);
        operator = _operator;
        treasury = _treasury;
        oracle = _oracle;
        exchangeRate = PRECISION;
        emit ExchangeRateUpdated(0, PRECISION, block.timestamp);
    }

    function totalAssets() public view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (assets == 0) return 0;
        return (assets * PRECISION) / exchangeRate;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (shares == 0) return 0;
        return (shares * exchangeRate) / PRECISION;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 shares) external view returns (uint256) {
        uint256 gross = convertToAssets(shares);
        uint256 fee = (gross * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        return gross - fee;
    }

    function deposit(uint256 assets, address receiver) external nonReentrant notPaused returns (uint256 shares) {
        if (assets < MIN_DEPOSIT) revert DepositBelowMinimum();
        if (receiver == address(0)) revert ZeroAddress();
        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();

        baseAsset.safeTransferFrom(msg.sender, address(this), assets);

        totalStaked += assets;
        _mint(receiver, shares);

        emit Deposited(msg.sender, receiver, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner_
    ) external nonReentrant notPaused returns (uint256 assetsOut) {
        if (shares == 0) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();
        if (balanceOf(owner_) < shares) revert InsufficientBalance();

        uint256 grossAssets = convertToAssets(shares);
        if (grossAssets == 0) revert ZeroAssets();
        uint256 fee = (grossAssets * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        assetsOut = grossAssets - fee;
        if (assetsOut == 0) revert ZeroAssets();

        if (msg.sender != owner_) {
            uint256 allowed = allowance(owner_, msg.sender);
            if (allowed < shares) revert InsufficientAllowance();
            _approve(owner_, msg.sender, allowed - shares);
        }

        if (baseAsset.balanceOf(address(this)) < grossAssets) revert InsufficientBalance();

        _burn(owner_, shares);
        totalStaked = totalStaked > grossAssets ? totalStaked - grossAssets : 0;

        if (fee > 0) {
            baseAsset.safeTransfer(treasury, fee);
        }
        baseAsset.safeTransfer(receiver, assetsOut);

        emit Withdrawn(msg.sender, receiver, owner_, assetsOut, shares, fee);
    }

    function stake(uint256 amount) external onlyOperator nonReentrant notPaused {
        if (amount == 0) revert ZeroAssets();
        if (baseAsset.balanceOf(address(this)) < amount) revert InsufficientBalance();
        baseAsset.safeTransfer(msg.sender, amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external onlyOperator nonReentrant notPaused {
        if (amount == 0) revert ZeroAssets();
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
        emit Unstaked(msg.sender, amount);
    }

    function updateExchangeRateFromOracle() external onlyOperator {
        uint256 newRate = IExchangeRateOracle(oracle).getExchangeRate();
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryChanged(old, newTreasury);
    }

    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = oracle;
        oracle = newOracle;
        emit OracleChanged(old, newOracle);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAssets();
        IERC20(token).safeTransfer(to, amount);
        emit Recovered(token, to, amount);
    }
}
