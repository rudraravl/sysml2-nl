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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        _checkResult(success, data);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        _checkResult(success, data);
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, value)
        );
        _checkResult(success, data);
    }

    function _checkResult(bool success, bytes memory data) private pure {
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(32, data), mload(data))
                }
            } else {
                revert("SafeERC20: operation failed");
            }
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view virtual override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal virtual {
        require(tokenOwner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(tokenOwner, spender, currentAllowance - amount);
            }
        }
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address account);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        address oldOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }
}

contract Pausable {
    bool internal _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ExpectedPause();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract SyntheticDollar is ERC20, Ownable, Pausable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error InsufficientDebt();
    error InsufficientBalance();
    error Undercollateralized(uint256 currentRatio, uint256 requiredRatio);
    error InvalidRatio();
    error InvalidFee();
    error NoEtherToRescue();
    error EtherTransferFailed();

    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant INITIAL_MIN_COLLATERAL_RATIO = 1.5e18;
    uint256 public constant INITIAL_STABILITY_FEE = 0.005e18;
    uint256 public constant MAX_STABILITY_FEE = 0.1e18;

    IERC20 public immutable collateralToken;

    uint256 public minCollateralizationRatio;
    uint256 public stabilityFeePerYear;

    uint256 public debtIndex;
    uint256 public lastFeeUpdate;

    uint256 public totalCollateral;
    uint256 public totalPrincipalDebt;

    struct Position {
        uint256 collateral;
        uint256 principalDebt;
    }

    mapping(address => Position) public positions;

    event Deposit(address indexed user, uint256 amount, uint256 collateralBalance);
    event Mint(address indexed user, uint256 amount, uint256 debtBalance, uint256 collateralBalance);
    event Redeem(address indexed user, uint256 amountBurned, uint256 collateralWithdrawn, uint256 debtBalance);
    event WithdrawCollateral(address indexed user, uint256 amount, uint256 collateralBalance);
    event StabilityFeeUpdated(uint256 oldFee, uint256 newFee);
    event MinCollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event EtherRescued(address indexed to, uint256 amount);

    modifier nonzero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    constructor(address collateralToken_, address admin_)
        ERC20("Synthetic Dollar", "sUSD")
        Ownable(admin_)
    {
        if (collateralToken_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();

        collateralToken = IERC20(collateralToken_);
        minCollateralizationRatio = INITIAL_MIN_COLLATERAL_RATIO;
        stabilityFeePerYear = INITIAL_STABILITY_FEE;
        debtIndex = PRECISION;
        lastFeeUpdate = block.timestamp;
    }

    function _updateDebtIndex() internal {
        if (block.timestamp > lastFeeUpdate) {
            uint256 elapsed = block.timestamp - lastFeeUpdate;
            uint256 accrued =
                (debtIndex * stabilityFeePerYear * elapsed) / (SECONDS_PER_YEAR * PRECISION);
            debtIndex += accrued;
            lastFeeUpdate = block.timestamp;
        }
    }

    function _getActualDebt(address user) internal view returns (uint256) {
        return (positions[user].principalDebt * debtIndex) / PRECISION;
    }

    function _checkCollateralization(address user) internal view {
        if (positions[user].principalDebt == 0) return;
        uint256 debt = _getActualDebt(user);
        uint256 collateral = positions[user].collateral;
        if (collateral * PRECISION < debt * minCollateralizationRatio) {
            revert Undercollateralized(
                (collateral * PRECISION) / debt,
                minCollateralizationRatio
            );
        }
    }

    function depositCollateral(uint256 amount) external whenNotPaused nonzero(amount) {
        _updateDebtIndex();

        positions[msg.sender].collateral += amount;
        totalCollateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, positions[msg.sender].collateral);
    }

    function mint(uint256 amount) external whenNotPaused nonzero(amount) {
        _updateDebtIndex();

        Position storage pos = positions[msg.sender];

        uint256 principalToAdd = (amount * PRECISION) / debtIndex;
        pos.principalDebt += principalToAdd;
        totalPrincipalDebt += principalToAdd;

        _mint(msg.sender, amount);

        _checkCollateralization(msg.sender);

        emit Mint(msg.sender, amount, _getActualDebt(msg.sender), pos.collateral);
    }

    function redeem(uint256 amount) external whenNotPaused nonzero(amount) {
        _updateDebtIndex();

        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        Position storage pos = positions[msg.sender];
        uint256 currentDebt = _getActualDebt(msg.sender);
        if (currentDebt < amount) revert InsufficientDebt();

        uint256 collateralToReturn = amount;
        if (collateralToReturn > pos.collateral) revert InsufficientCollateral();

        uint256 principalToReduce = (amount * PRECISION) / debtIndex;
        pos.principalDebt -= principalToReduce;
        totalPrincipalDebt -= principalToReduce;

        pos.collateral -= collateralToReturn;
        totalCollateral -= collateralToReturn;

        _burn(msg.sender, amount);

        _checkCollateralization(msg.sender);

        collateralToken.safeTransfer(msg.sender, collateralToReturn);

        emit Redeem(msg.sender, amount, collateralToReturn, _getActualDebt(msg.sender));
    }

    function withdrawCollateral(uint256 amount) external whenNotPaused nonzero(amount) {
        _updateDebtIndex();

        Position storage pos = positions[msg.sender];

        if (amount > pos.collateral) revert InsufficientCollateral();

        pos.collateral -= amount;
        totalCollateral -= amount;

        _checkCollateralization(msg.sender);

        collateralToken.safeTransfer(msg.sender, amount);

        emit WithdrawCollateral(msg.sender, amount, pos.collateral);
    }

    function setStabilityFee(uint256 newFeePerYear) external onlyOwner {
        if (newFeePerYear > MAX_STABILITY_FEE) revert InvalidFee();
        _updateDebtIndex();
        uint256 oldFee = stabilityFeePerYear;
        stabilityFeePerYear = newFeePerYear;
        emit StabilityFeeUpdated(oldFee, newFeePerYear);
    }

    function setMinCollateralizationRatio(uint256 newRatio) external onlyOwner {
        if (newRatio < PRECISION) revert InvalidRatio();
        uint256 oldRatio = minCollateralizationRatio;
        minCollateralizationRatio = newRatio;
        emit MinCollateralizationRatioUpdated(oldRatio, newRatio);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueEther(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoEtherToRescue();
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert EtherTransferFailed();
        emit EtherRescued(to, balance);
    }

    function getActualDebt(address user) external view returns (uint256) {
        return _getActualDebt(user);
    }

    function getCollateralizationRatio(address user) external view returns (uint256) {
        if (positions[user].principalDebt == 0) return type(uint256).max;
        uint256 debt = _getActualDebt(user);
        return (positions[user].collateral * PRECISION) / debt;
    }

    function getTotalDebt() external view returns (uint256) {
        return (totalPrincipalDebt * debtIndex) / PRECISION;
    }

    function getCollateral(address user) external view returns (uint256) {
        return positions[user].collateral;
    }

    function getPendingDebtIndex() external view returns (uint256) {
        uint256 elapsed = block.timestamp - lastFeeUpdate;
        uint256 accrued =
            (debtIndex * stabilityFeePerYear * elapsed) / (SECONDS_PER_YEAR * PRECISION);
        return debtIndex + accrued;
    }

    function isSafe(address user) external view returns (bool) {
        if (positions[user].principalDebt == 0) return true;
        uint256 debt = _getActualDebt(user);
        return positions[user].collateral * PRECISION >= debt * minCollateralizationRatio;
    }

    receive() external payable {
        revert("ETH not accepted");
    }
}
