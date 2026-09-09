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
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract StablecoinSystem is IERC20 {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant RATIO_BASE = 10000; // 100%
    uint256 public constant FEE_BASE = 10000; // 100%
    uint256 public constant MAX_COLLATERAL_RATIO = 100000; // 1000%
    uint256 public constant MAX_MINT_FEE = 1000; // 10%
    uint256 public constant MIN_COLLATERAL_RATIO = 15000; // 150%

    /*//////////////////////////////////////////////////////////////
                              METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable stakedEtherDepositReceipt;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;
    address public feeRecipient;

    bool public paused;
    bool private locked;

    uint256 public minCollateralRatio = MIN_COLLATERAL_RATIO; // 150%
    uint256 public mintFee = 50; // 0.5%

    mapping(address => uint256) public collateralBalances;
    mapping(address => uint256) public mintedStablecoins;

    uint256 public totalCollateralDeposited;
    uint256 public totalMintedStablecoins;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event StablecoinsMinted(address indexed user, uint256 amount, uint256 mintFeeAmount, uint256 debtIncrease);
    event StablecoinsRepaid(address indexed user, uint256 amount);
    event MinCollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error ZeroAmount();
    error NotOwner();
    error NotOperator();
    error IsPaused();
    error AlreadyPaused();
    error NotPaused();
    error ReentrantCall();
    error InsufficientCollateral(uint256 available, uint256 required);
    error ExcessiveRepayment(uint256 attempted, uint256 max);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error RatioOutOfBounds(uint256 ratio, uint256 min, uint256 max);
    error FeeOutOfBounds(uint256 fee, uint256 maxFee);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        IERC20 _stakedEtherDepositReceipt,
        address _feeRecipient,
        address _operator
    ) {
        if (address(_stakedEtherDepositReceipt) == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        name = "Staked Ether Stablecoin";
        symbol = "SEST";
        stakedEtherDepositReceipt = _stakedEtherDepositReceipt;
        owner = msg.sender;
        operator = _operator == address(0) ? msg.sender : _operator;
        feeRecipient = _feeRecipient;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

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
        if (currentAllowance < amount) revert InsufficientAllowance(currentAllowance, amount);
        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
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
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        collateralBalances[msg.sender] += amount;
        totalCollateralDeposited += amount;

        stakedEtherDepositReceipt.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 userCollateral = collateralBalances[msg.sender];
        if (amount > userCollateral) revert InsufficientBalance(userCollateral, amount);

        uint256 newCollateral = userCollateral - amount;
        uint256 debt = mintedStablecoins[msg.sender];

        if (!_isCollateralized(newCollateral, debt)) {
            revert InsufficientCollateral(newCollateral, _requiredCollateral(debt));
        }

        collateralBalances[msg.sender] = newCollateral;
        totalCollateralDeposited -= amount;

        stakedEtherDepositReceipt.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        STABLECOIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mintStablecoins(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (feeRecipient == address(0)) revert ZeroAddress();

        uint256 feeAmount = (amount * mintFee) / FEE_BASE;
        uint256 debtIncrease = amount + feeAmount;
        uint256 newDebt = mintedStablecoins[msg.sender] + debtIncrease;
        uint256 collateral = collateralBalances[msg.sender];

        if (!_isCollateralized(collateral, newDebt)) {
            revert InsufficientCollateral(collateral, _requiredCollateral(newDebt));
        }

        mintedStablecoins[msg.sender] = newDebt;
        totalMintedStablecoins += debtIncrease;

        _mint(msg.sender, amount);
        if (feeAmount > 0) {
            _mint(feeRecipient, feeAmount);
        }

        emit StablecoinsMinted(msg.sender, amount, feeAmount, debtIncrease);
    }

    function repayStablecoins(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 debt = mintedStablecoins[msg.sender];
        if (amount > debt) revert ExcessiveRepayment(amount, debt);

        uint256 bal = balanceOf(msg.sender);
        if (bal < amount) revert InsufficientBalance(bal, amount);

        _burn(msg.sender, amount);

        mintedStablecoins[msg.sender] = debt - amount;
        totalMintedStablecoins -= amount;

        emit StablecoinsRepaid(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                      COLLATERALIZATION HELPERS
    //////////////////////////////////////////////////////////////*/
    function _requiredCollateral(uint256 debt) internal view returns (uint256) {
        return (debt * minCollateralRatio + RATIO_BASE - 1) / RATIO_BASE;
    }

    function _isCollateralized(uint256 collateral, uint256 debt) internal view returns (bool) {
        return debt == 0 || collateral >= _requiredCollateral(debt);
    }

    function isCollateralized(address account) external view returns (bool) {
        return _isCollateralized(collateralBalances[account], mintedStablecoins[account]);
    }

    function getPosition(address account) external view returns (uint256 collateral, uint256 debt) {
        return (collateralBalances[account], mintedStablecoins[account]);
    }

    function requiredCollateralForDebt(uint256 debt) external view returns (uint256) {
        return _requiredCollateral(debt);
    }

    /*//////////////////////////////////////////////////////////////
                         SYSTEM CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    function setMinCollateralRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_COLLATERAL_RATIO || newRatio > MAX_COLLATERAL_RATIO) {
            revert RatioOutOfBounds(newRatio, MIN_COLLATERAL_RATIO, MAX_COLLATERAL_RATIO);
        }
        emit MinCollateralRatioUpdated(minCollateralRatio, newRatio);
        minCollateralRatio = newRatio;
    }

    function setMintFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_MINT_FEE) {
            revert FeeOutOfBounds(newFee, MAX_MINT_FEE);
        }
        emit MintFeeUpdated(mintFee, newFee);
        mintFee = newFee;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/
    function pause() external onlyOperator {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }
}
