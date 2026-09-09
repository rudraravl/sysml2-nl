// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AlgorithmicStablecoin {
    // --- ERC20 metadata ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // --- ERC20 state ---
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- System state ---
    IERC20 public immutable baseAsset;
    address public operator;
    uint256 public pegRatio; // scaled by 1e18 (1e18 == 1:1)
    bool public isShutdown;
    uint256 public reserveBalance;

    // --- Constants ---
    uint256 public constant MIN_MINT_AMOUNT = 100;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 private constant RATIO_SCALE = 1e18;

    // --- Reentrancy guard ---
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // --- Events ---
    event Mint(address indexed user, uint256 baseDeposited, uint256 stableMinted);
    event Burn(address indexed user, uint256 stableBurned, uint256 baseReturned, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event PegRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event EmergencyShutdown(bool shutdownState);
    event OperatorUpdated(address oldOperator, address newOperator);

    // --- Custom errors ---
    error ZeroAddress();
    error NotOperator();
    error ContractShutdown();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountTooLow();
    error InvalidPegRatio();
    error TransferFailed();
    error ReentrancyDetected();

    // --- Modifiers ---
    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotShutdown() {
        if (isShutdown) revert ContractShutdown();
        _;
    }

    constructor(
        address _baseAsset,
        string memory _name,
        string memory _symbol,
        uint256 _pegRatio,
        address _operator
    ) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_pegRatio == 0) revert InvalidPegRatio();

        baseAsset = IERC20(_baseAsset);
        name = _name;
        symbol = _symbol;
        operator = _operator;
        pegRatio = _pegRatio;
        _status = _NOT_ENTERED;
    }

    // --- ERC20 logic ---

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
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
        if (balanceOf[from] < amount) revert InsufficientBalance();

        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // --- Minting ---

    function mint(uint256 baseAmount) external whenNotShutdown nonReentrant {
        if (baseAmount < MIN_MINT_AMOUNT) revert AmountTooLow();

        uint256 stableAmount = (baseAmount * RATIO_SCALE) / pegRatio;
        if (stableAmount == 0) revert AmountTooLow();

        // Effects
        reserveBalance += baseAmount;
        balanceOf[msg.sender] += stableAmount;
        totalSupply += stableAmount;

        // Interaction
        bool ok = baseAsset.transferFrom(msg.sender, address(this), baseAmount);
        if (!ok) revert TransferFailed();

        emit Mint(msg.sender, baseAmount, stableAmount);
        emit Transfer(address(0), msg.sender, stableAmount);
    }

    // --- Redemption ---

    function redeem(uint256 stableAmount) external whenNotShutdown nonReentrant {
        if (stableAmount == 0) revert AmountTooLow();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance();

        // Compute fee using full-precision numerator before any division
        // to avoid divide-before-multiply rounding loss.
        uint256 numerator = stableAmount * pegRatio;
        uint256 fee = (numerator * REDEMPTION_FEE_BPS) / (RATIO_SCALE * BPS_DENOMINATOR);
        uint256 grossBase = numerator / RATIO_SCALE;
        uint256 netBase = grossBase - fee;

        if (netBase == 0) revert AmountTooLow();
        if (reserveBalance < netBase) revert InsufficientBalance();

        // Effects: only the redeemed (net) base leaves the reserve;
        // the fee remains in the contract as retained backing.
        balanceOf[msg.sender] -= stableAmount;
        totalSupply -= stableAmount;
        reserveBalance -= netBase;

        // Interaction
        bool ok = baseAsset.transfer(msg.sender, netBase);
        if (!ok) revert TransferFailed();

        emit Burn(msg.sender, stableAmount, netBase, fee);
        emit Transfer(msg.sender, address(0), stableAmount);
    }

    // --- Operator functions ---

    function setPegRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0) revert InvalidPegRatio();
        uint256 oldRatio = pegRatio;
        pegRatio = newRatio;
        emit PegRatioUpdated(oldRatio, newRatio);
    }

    function setShutdown(bool _isShutdown) external onlyOperator {
        isShutdown = _isShutdown;
        emit EmergencyShutdown(_isShutdown);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }
}
