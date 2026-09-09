// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Reserve {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PrivateStablecoin {
    // ──────────────────────────────────────────────
    //  Reentrancy guard
    // ──────────────────────────────────────────────
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // ──────────────────────────────────────────────
    //  Metadata
    // ──────────────────────────────────────────────
    string public constant name = "Private Programmable Stablecoin";
    string public constant symbol = "pUSD";
    uint8 public constant decimals = 18;

    // ──────────────────────────────────────────────
    //  Supply constants
    // ──────────────────────────────────────────────
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // ──────────────────────────────────────────────
    //  State variables
    // ──────────────────────────────────────────────
    address private _owner;
    address public operator;
    address public reserveStablecoin;
    address public treasury;
    address public implementation;
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value, uint256 reserveDeposited);
    event Redeem(address indexed from, uint256 value, uint256 netReserve, uint256 fee);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event ReserveStablecoinUpdated(address indexed previousReserve, address indexed newReserve);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event ContractUpgraded(address indexed oldImplementation, address indexed newImplementation);

    // ──────────────────────────────────────────────
    //  Custom errors
    // ──────────────────────────────────────────────
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error MaxSupplyExceeded();
    error TransferFailed();
    error ImplementationNotContract();
    error ReentrantCall();

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────
    constructor(
        address _reserveStablecoin,
        address _treasury,
        address _operator
    ) {
        if (_reserveStablecoin == address(0) || _treasury == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        _owner = msg.sender;
        reserveStablecoin = _reserveStablecoin;
        treasury = _treasury;
        operator = _operator;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit ReserveStablecoinUpdated(address(0), _reserveStablecoin);
        emit TreasuryUpdated(address(0), _treasury);
        emit OperatorUpdated(address(0), _operator);
    }

    // ──────────────────────────────────────────────
    //  Ownership
    // ──────────────────────────────────────────────
    function owner() external view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // ──────────────────────────────────────────────
    //  Operator management
    // ──────────────────────────────────────────────
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ──────────────────────────────────────────────
    //  Pause / Unpause
    // ──────────────────────────────────────────────
    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ──────────────────────────────────────────────
    //  Owner configuration
    // ──────────────────────────────────────────────
    function setReserveStablecoin(address newReserve) external onlyOwner {
        if (newReserve == address(0)) revert ZeroAddress();
        address old = reserveStablecoin;
        reserveStablecoin = newReserve;
        emit ReserveStablecoinUpdated(old, newReserve);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function upgradeContract(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        if (newImplementation.code.length == 0) revert ImplementationNotContract();
        address old = implementation;
        implementation = newImplementation;
        emit ContractUpgraded(old, newImplementation);
    }

    // ──────────────────────────────────────────────
    //  ERC20 view functions
    // ──────────────────────────────────────────────
    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowance[tokenOwner][spender];
    }

    // ──────────────────────────────────────────────
    //  ERC20 mutative functions
    // ──────────────────────────────────────────────
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _allowance[from][msg.sender] = currentAllowance - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    // ──────────────────────────────────────────────
    //  Mint — deposit reserve stablecoin 1:1
    //  CEI: state updated before external transferFrom;
    //  nonReentrant guard prevents cross-function reentrancy.
    // ──────────────────────────────────────────────
    function mint(uint256 amount) external nonReentrant returns (bool) {
        if (amount == 0) revert InvalidAmount();
        if (totalSupply + amount > MAX_TOTAL_SUPPLY) revert MaxSupplyExceeded();

        // Effects: credit private stablecoin first
        balanceOf[msg.sender] += amount;
        totalSupply += amount;

        // Interaction: pull reserve stablecoin from caller (requires prior approval)
        bool success = IERC20Reserve(reserveStablecoin).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Mint(msg.sender, amount, amount);
        emit Transfer(address(0), msg.sender, amount);
        return true;
    }

    // ──────────────────────────────────────────────
    //  Redeem — burn private stablecoin for reserve
    //  CEI: burn first, then transfer out; nonReentrant guard.
    // ──────────────────────────────────────────────
    function redeem(uint256 amount) external nonReentrant whenNotPaused returns (bool) {
        if (amount == 0) revert InvalidAmount();
        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netReserve = amount - fee;

        // Effects: burn first
        unchecked {
            balanceOf[msg.sender] = senderBalance - amount;
        }
        totalSupply -= amount;

        // Interactions: send reserve stablecoin to redeemer and treasury
        if (netReserve > 0) {
            bool successUser = IERC20Reserve(reserveStablecoin).transfer(msg.sender, netReserve);
            if (!successUser) revert TransferFailed();
        }
        if (fee > 0) {
            bool successFee = IERC20Reserve(reserveStablecoin).transfer(treasury, fee);
            if (!successFee) revert TransferFailed();
        }

        emit Transfer(msg.sender, address(0), amount);
        emit Redeem(msg.sender, amount, netReserve, fee);
        return true;
    }

    // ──────────────────────────────────────────────
    //  Views
    // ──────────────────────────────────────────────
    function reserveBalance() external view returns (uint256) {
        return IERC20Reserve(reserveStablecoin).balanceOf(address(this));
    }
}
