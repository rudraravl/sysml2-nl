// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ProtocolTokenBootstrap {
    // ---------------------------------------------------------------------
    // ERC20 metadata & state (the protocol token itself)
    // ---------------------------------------------------------------------
    string public constant name = "Protocol Token";
    string public constant symbol = "PT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------------
    address public operator;
    uint256 public exchangeRate;
    uint256 public constant MIN_FUNDING_THRESHOLD = 5000 * 10 ** 18;
    uint256 public depositDeadline;
    uint256 public vestingDuration;
    uint256 public vestingStart;
    bool public launched;
    uint256 public totalDeposited;

    // ---------------------------------------------------------------------
    // User ledger
    // ---------------------------------------------------------------------
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public claimed;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ProjectLaunched(uint256 totalDeposited, uint256 totalAllocated);
    event TokensClaimed(address indexed user, uint256 amount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error OnlyOperator();
    error ZeroAmount();
    error ProjectAlreadyLaunched();
    error ProjectNotLaunched();
    error PastDeadline();
    error DeadlineNotPassed();
    error ThresholdNotMet();
    error ThresholdMet();
    error VestingNotComplete();
    error NothingToClaim();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    /// @param _depositDeadline  Unix timestamp after which deposits are rejected.
    /// @param _vestingDuration  Vesting duration in seconds starting at launch.
    constructor(uint256 _depositDeadline, uint256 _vestingDuration) {
        operator = msg.sender;
        exchangeRate = 1000;
        depositDeadline = _depositDeadline;
        vestingDuration = _vestingDuration;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------

    /// @notice Deposit native base currency (ETH) into the pool.
    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (launched) revert ProjectAlreadyLaunched();
        if (block.timestamp > depositDeadline) revert PastDeadline();

        deposits[msg.sender] += msg.value;
        totalDeposited += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw deposited base currency when the funding period ends
    ///         without meeting the minimum threshold.
    function withdraw() external nonReentrant {
        if (launched) revert ProjectAlreadyLaunched();
        if (block.timestamp <= depositDeadline) revert DeadlineNotPassed();
        if (totalDeposited >= MIN_FUNDING_THRESHOLD) revert ThresholdMet();

        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert NothingToClaim();

        deposits[msg.sender] = 0;
        totalDeposited -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claim fully-vested protocol tokens after the vesting period.
    function claimTokens() external nonReentrant {
        if (!launched) revert ProjectNotLaunched();
        if (block.timestamp < vestingStart + vestingDuration) revert VestingNotComplete();

        uint256 allocation = deposits[msg.sender] * exchangeRate;
        uint256 alreadyClaimed = claimed[msg.sender];
        uint256 claimable = allocation - alreadyClaimed;
        if (claimable == 0) revert NothingToClaim();

        claimed[msg.sender] = allocation;
        _mint(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    /// @notice Set the exchange rate (new tokens per 1 unit of base currency).
    ///         Only callable before launch.
    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (launched) revert ProjectAlreadyLaunched();
        if (newRate == 0) revert ZeroAmount();

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;

        emit ExchangeRateUpdated(oldRate, newRate);
    }

    /// @notice Launch the project once the minimum funding threshold is met.
    function launch() external onlyOperator {
        if (launched) revert ProjectAlreadyLaunched();
        if (totalDeposited < MIN_FUNDING_THRESHOLD) revert ThresholdNotMet();

        launched = true;
        vestingStart = block.timestamp;

        uint256 totalAllocated = totalDeposited * exchangeRate;

        emit ProjectLaunched(totalDeposited, totalAllocated);
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    // ---------------------------------------------------------------------
    // ERC20
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Returns the amount of protocol tokens a user may currently claim.
    function claimableAmount(address user) external view returns (uint256) {
        if (!launched) return 0;
        if (block.timestamp < vestingStart + vestingDuration) return 0;
        uint256 allocation = deposits[user] * exchangeRate;
        return allocation - claimed[user];
    }

    /// @notice Returns the total protocol tokens allocated at current exchange rate.
    function totalAllocated() external view returns (uint256) {
        return totalDeposited * exchangeRate;
    }
}
