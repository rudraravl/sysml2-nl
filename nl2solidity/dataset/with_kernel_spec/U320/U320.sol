// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StablecoinFacility {
    // -----------------------------------------------------------------------
    // ERC-20 stablecoin metadata
    // -----------------------------------------------------------------------
    string public constant name = "Facility USD";
    string public constant symbol = "FUSD";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Lending facility state
    // -----------------------------------------------------------------------
    IERC20 public immutable baseToken;
    address public owner;
    uint256 public collateralizationRatio; // basis points, 15000 = 150%
    bool public mintPaused;

    uint256 public constant MINT_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_RATIO = 10000; // 100% minimum

    uint256 public totalCollateral;
    mapping(address => uint256) public collateralBalances;
    mapping(address => uint256) public debts;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    uint256 private _locked = 1;
    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Mint(address indexed user, uint256 requested, uint256 received, uint256 fee);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MintPausedChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error MintIsPaused();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientDebt();
    error InvalidRatio();
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _baseToken) {
        if (_baseToken == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        owner = msg.sender;
        collateralizationRatio = 15000; // 150%
        emit OwnershipTransferred(address(0), msg.sender);
        emit CollateralizationRatioUpdated(0, 15000);
    }

    // -----------------------------------------------------------------------
    // ERC-20 transfer / approve
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Internal mint / burn
    // -----------------------------------------------------------------------
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Lending: deposit base token
    // -----------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        collateralBalances[msg.sender] += amount;
        totalCollateral += amount;

        if (!baseToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Lending: mint stablecoin against collateral
    // -----------------------------------------------------------------------
    function mint(uint256 amount) external nonReentrant {
        if (mintPaused) revert MintIsPaused();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netToUser = amount - fee;

        uint256 newDebt = debts[msg.sender] + amount;
        // collateral >= (ratio * debt) / 10000
        if (collateralBalances[msg.sender] * BPS_DENOMINATOR < collateralizationRatio * newDebt) {
            revert InsufficientCollateral();
        }

        debts[msg.sender] = newDebt;
        _mint(msg.sender, netToUser);
        if (fee > 0) {
            _mint(owner, fee);
        }

        emit Mint(msg.sender, amount, netToUser, fee);
    }

    // -----------------------------------------------------------------------
    // Lending: repay stablecoin to reduce debt
    // -----------------------------------------------------------------------
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (debts[msg.sender] < amount) revert InsufficientDebt();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        debts[msg.sender] -= amount;
        _burn(msg.sender, amount);

        emit Repay(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Lending: withdraw base token (collateral)
    // -----------------------------------------------------------------------
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender] < amount) revert InsufficientBalance();

        uint256 newCollateral = collateralBalances[msg.sender] - amount;
        if (newCollateral * BPS_DENOMINATOR < collateralizationRatio * debts[msg.sender]) {
            revert InsufficientCollateral();
        }

        collateralBalances[msg.sender] = newCollateral;
        totalCollateral -= amount;

        if (!baseToken.transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdraw(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Owner: set collateralization ratio
    // -----------------------------------------------------------------------
    function setCollateralizationRatio(uint256 newRatio) external onlyOwner {
        if (newRatio < MIN_RATIO) revert InvalidRatio();
        uint256 oldRatio = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(oldRatio, newRatio);
    }

    // -----------------------------------------------------------------------
    // Owner: pause / unpause minting
    // -----------------------------------------------------------------------
    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
        emit MintPausedChanged(paused);
    }

    // -----------------------------------------------------------------------
    // Owner: transfer ownership
    // -----------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // -----------------------------------------------------------------------
    // View: maximum stablecoin a user can mint given current collateral & debt
    // -----------------------------------------------------------------------
    function maxMintable(address user) external view returns (uint256) {
        uint256 collateral = collateralBalances[user];
        uint256 debt = debts[user];
        // maxDebt = (collateral * 10000) / ratio
        uint256 maxDebt = (collateral * BPS_DENOMINATOR) / collateralizationRatio;
        if (maxDebt <= debt) return 0;
        return maxDebt - debt;
    }

    // -----------------------------------------------------------------------
    // View: maximum base token a user can withdraw given current debt
    // -----------------------------------------------------------------------
    function maxWithdrawable(address user) external view returns (uint256) {
        uint256 collateral = collateralBalances[user];
        uint256 debt = debts[user];
        // requiredCollateral = (ratio * debt) / 10000
        uint256 requiredCollateral = (collateralizationRatio * debt) / BPS_DENOMINATOR;
        if (collateral <= requiredCollateral) return 0;
        return collateral - requiredCollateral;
    }

    // -----------------------------------------------------------------------
    // View: current collateralization status for a user
    // -----------------------------------------------------------------------
    function collateralizationStatus(address user)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 ratioBps)
    {
        return (collateralBalances[user], debts[user], collateralizationRatio);
    }
}
