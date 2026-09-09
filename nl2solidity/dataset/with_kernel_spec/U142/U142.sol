// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert("Ownable: zero address");
        }
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert("Ownable: caller is not the owner");
        }
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert("Ownable: new owner is the zero address");
        }
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
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
        if (_status == ENTERED) {
            revert("ReentrancyGuard: reentrant call");
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) {
                revert("ERC20: insufficient allowance");
            }
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert("ERC20: transfer from the zero address");
        }
        if (to == address(0)) {
            revert("ERC20: transfer to the zero address");
        }
        if (balanceOf[from] < amount) {
            revert("ERC20: transfer amount exceeds balance");
        }
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) {
            revert("ERC20: mint to the zero address");
        }
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert("ERC20: burn from the zero address");
        }
        if (balanceOf[from] < amount) {
            revert("ERC20: burn amount exceeds balance");
        }
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal virtual {
        if (ownerAddr == address(0)) {
            revert("ERC20: approve from the zero address");
        }
        if (spender == address(0)) {
            revert("ERC20: approve to the zero address");
        }
        allowance[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }
}

contract LiquidStakingToken is ERC20, Ownable {
    error LiquidStakingToken__ZeroAddress();

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

contract LiquidStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error LiquidStaking__ZeroAmount();
    error LiquidStaking__ZeroAddress();
    error LiquidStaking__InvalidExchangeRate();
    error LiquidStaking__InsufficientLSTBalance();
    error LiquidStaking__InsufficientDepositedBase();
    error LiquidStaking__InsufficientContractBalance();
    error LiquidStaking__DepositsPaused();
    error LiquidStaking__RedemptionsPaused();
    error LiquidStaking__NotOperator();

    event Deposit(address indexed account, uint256 baseAmount, uint256 lstAmount);
    event Redeem(address indexed account, uint256 lstAmount, uint256 baseAmount, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event DepositsPausedChanged(bool paused);
    event RedemptionsPausedChanged(bool paused);

    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public constant REDEMPTION_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant FEE_DENOMINATOR = EXCHANGE_RATE_PRECISION * BPS_DENOMINATOR;

    IERC20 public immutable baseAsset;
    LiquidStakingToken public immutable lstToken;

    uint256 public exchangeRate;
    mapping(address => uint256) public depositedBase;
    mapping(address => uint256) public issuedLST;

    address public operator;
    bool public depositsPaused;
    bool public redemptionsPaused;

    modifier onlyOperator() {
        if (msg.sender != operator) revert LiquidStaking__NotOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert LiquidStaking__DepositsPaused();
        _;
    }

    modifier whenRedemptionsNotPaused() {
        if (redemptionsPaused) revert LiquidStaking__RedemptionsPaused();
        _;
    }

    constructor(
        IERC20 _baseAsset,
        string memory _lstName,
        string memory _lstSymbol,
        address _operator
    ) Ownable(msg.sender) {
        if (address(_baseAsset) == address(0)) revert LiquidStaking__ZeroAddress();
        if (_operator == address(0)) revert LiquidStaking__ZeroAddress();

        baseAsset = _baseAsset;
        lstToken = new LiquidStakingToken(_lstName, _lstSymbol);
        exchangeRate = EXCHANGE_RATE_PRECISION;
        operator = _operator;

        emit ExchangeRateUpdated(0, exchangeRate);
        emit OperatorUpdated(address(0), _operator);
    }

    function deposit(uint256 baseAmount) external nonReentrant whenDepositsNotPaused {
        if (baseAmount == 0) revert LiquidStaking__ZeroAmount();

        uint256 lstAmount = (baseAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
        if (lstAmount == 0) revert LiquidStaking__ZeroAmount();

        depositedBase[msg.sender] += baseAmount;
        issuedLST[msg.sender] += lstAmount;

        baseAsset.safeTransferFrom(msg.sender, address(this), baseAmount);
        lstToken.mint(msg.sender, lstAmount);

        emit Deposit(msg.sender, baseAmount, lstAmount);
    }

    function redeem(uint256 lstAmount) external nonReentrant whenRedemptionsNotPaused {
        if (lstAmount == 0) revert LiquidStaking__ZeroAmount();
        if (issuedLST[msg.sender] < lstAmount) revert LiquidStaking__InsufficientLSTBalance();

        // Fee computed in a single expression (multiply-then-divide) to avoid
        // precision loss from divide-before-multiply.
        uint256 fee = (lstAmount * exchangeRate * REDEMPTION_FEE_BPS) / FEE_DENOMINATOR;
        uint256 baseAmount = (lstAmount * exchangeRate) / EXCHANGE_RATE_PRECISION;
        if (baseAmount == 0) revert LiquidStaking__ZeroAmount();

        uint256 payout = baseAmount - fee;

        if (depositedBase[msg.sender] < baseAmount) revert LiquidStaking__InsufficientDepositedBase();
        if (baseAsset.balanceOf(address(this)) < payout) {
            revert LiquidStaking__InsufficientContractBalance();
        }

        depositedBase[msg.sender] -= baseAmount;
        issuedLST[msg.sender] -= lstAmount;

        lstToken.burn(msg.sender, lstAmount);
        baseAsset.safeTransfer(msg.sender, payout);

        emit Redeem(msg.sender, lstAmount, payout, fee);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert LiquidStaking__InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert LiquidStaking__ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setDepositsPaused(bool paused) external onlyOperator {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    function setRedemptionsPaused(bool paused) external onlyOperator {
        redemptionsPaused = paused;
        emit RedemptionsPausedChanged(paused);
    }

    function previewDeposit(uint256 baseAmount) external view returns (uint256 lstAmount) {
        if (baseAmount == 0) return 0;
        lstAmount = (baseAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 lstAmount) external view returns (uint256 payout, uint256 fee) {
        if (lstAmount == 0) return (0, 0);
        // Fee computed in a single expression (multiply-then-divide) to avoid
        // precision loss from divide-before-multiply.
        fee = (lstAmount * exchangeRate * REDEMPTION_FEE_BPS) / FEE_DENOMINATOR;
        uint256 baseAmount = (lstAmount * exchangeRate) / EXCHANGE_RATE_PRECISION;
        payout = baseAmount - fee;
    }
}
