// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract FixedRateYieldExchange {
    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */

    error ZeroAddress();
    error ZeroAmount();
    error TokenNotRegistered();
    error TermTooShort();
    error TermTooLong();
    error YieldExceedsMax(uint256 requested, uint256 max);
    error YieldBelowMin(uint256 requested, uint256 min);
    error InsufficientAvailablePrincipal(uint256 requested, uint256 available);
    error PositionNotMature(uint256 maturity, uint256 current);
    error PositionNotFound();
    error NotPositionOwner();
    error PositionAlreadyClosed();
    error MaxYieldExceedsCap(uint256 requested);
    error NotOperator();
    error NotOwner();
    error TransferFailed();

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */

    event TokenRegistered(address indexed token, uint8 decimals, uint256 minTerm, uint256 maxTerm);
    event TokenConfigUpdated(address indexed token, uint256 minTerm, uint256 maxTerm, uint256 minYield, uint256 maxYield);
    event Deposited(address indexed token, address indexed account, uint256 amount);
    event PrincipalWithdrawn(address indexed token, address indexed account, uint256 amount);
    event PositionOpened(
        uint256 indexed positionId,
        address indexed token,
        address indexed owner,
        uint256 principal,
        uint256 fixedRate,
        uint256 maturity
    );
    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 principalReturned,
        uint256 yieldEarned
    );
    event MaxYieldUpdated(address indexed token, uint256 oldMaxYield, uint256 newMaxYield);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /* Constants                                                          */
    /* ------------------------------------------------------------------ */

    /// @dev 15% APR expressed in basis points (1e4 = 100%).
    uint256 public constant YIELD_CAP_BPS = 1500;
    /// @dev Basis points scaling factor.
    uint256 public constant BPS_DENOMINATOR = 10000;
    /// @dev Seconds per year used for pro-rata yield calculation.
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /* ------------------------------------------------------------------ */
    /* Structs                                                            */
    /* ------------------------------------------------------------------ */

    struct TokenConfig {
        bool registered;
        uint8 decimals;
        uint256 minTerm;      // minimum term in seconds
        uint256 maxTerm;      // maximum term in seconds
        uint256 minYieldBps;  // minimum acceptable fixed rate in bps
        uint256 maxYieldBps;  // maximum acceptable fixed rate in bps (<= cap)
    }

    struct Position {
        address token;
        address owner;
        uint256 principal;
        uint256 fixedRateBps;
        uint256 startTimestamp;
        uint256 maturityTimestamp;
        bool closed;
    }

    /* ------------------------------------------------------------------ */
    /* State                                                              */
    /* ------------------------------------------------------------------ */

    address public owner;
    address public operator;

    mapping(address => TokenConfig) public tokenConfigs;

    /// @dev Available (uncommitted) principal per user per token.
    mapping(address => mapping(address => uint256)) public availablePrincipal;

    /// @dev Total principal custodied per token.
    mapping(address => uint256) public totalCustodied;

    Position[] internal _positions;

    /// @dev Position ids owned by each account.
    mapping(address => uint256[]) internal _userPositionIds;

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyRegisteredToken(address token) {
        if (!tokenConfigs[token].registered) revert TokenNotRegistered();
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    /* ------------------------------------------------------------------ */
    /* Admin functions                                                    */
    /* ------------------------------------------------------------------ */

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function registerToken(
        address token,
        uint256 minTerm,
        uint256 maxTerm,
        uint256 minYieldBps,
        uint256 maxYieldBps
    ) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (minTerm == 0 || maxTerm < minTerm) revert TermTooShort();
        if (maxYieldBps > YIELD_CAP_BPS) revert MaxYieldExceedsCap(maxYieldBps);
        if (maxYieldBps < minYieldBps) revert YieldBelowMin(minYieldBps, maxYieldBps);

        uint8 dec = IERC20(token).decimals();
        tokenConfigs[token] = TokenConfig({
            registered: true,
            decimals: dec,
            minTerm: minTerm,
            maxTerm: maxTerm,
            minYieldBps: minYieldBps,
            maxYieldBps: maxYieldBps
        });

        emit TokenRegistered(token, dec, minTerm, maxTerm);
    }

    /// @notice Operator adjusts the maximum allowable fixed-rate yield for new positions.
    function setMaxYield(address token, uint256 newMaxYieldBps) external onlyOperator onlyRegisteredToken(token) {
        if (newMaxYieldBps > YIELD_CAP_BPS) revert MaxYieldExceedsCap(newMaxYieldBps);
        TokenConfig storage cfg = tokenConfigs[token];
        if (newMaxYieldBps < cfg.minYieldBps) revert YieldBelowMin(cfg.minYieldBps, newMaxYieldBps);

        uint256 old = cfg.maxYieldBps;
        cfg.maxYieldBps = newMaxYieldBps;

        emit MaxYieldUpdated(token, old, newMaxYieldBps);
        emit TokenConfigUpdated(token, cfg.minTerm, cfg.maxTerm, cfg.minYieldBps, newMaxYieldBps);
    }

    /* ------------------------------------------------------------------ */
    /* User functions                                                     */
    /* ------------------------------------------------------------------ */

    /// @notice Deposit wrapped yield-bearing tokens into custody.
    function deposit(address token, uint256 amount) external onlyRegisteredToken(token) {
        if (amount == 0) revert ZeroAmount();

        availablePrincipal[msg.sender][token] += amount;
        totalCustodied[token] += amount;

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(token, msg.sender, amount);
    }

    /// @notice Open a fixed-rate position by locking available principal for a term at a desired yield.
    function openPosition(
        address token,
        uint256 principal,
        uint256 termSeconds,
        uint256 desiredYieldBps
    ) external onlyRegisteredToken(token) returns (uint256 positionId) {
        if (principal == 0) revert ZeroAmount();

        TokenConfig storage cfg = tokenConfigs[token];

        if (termSeconds < cfg.minTerm) revert TermTooShort();
        if (termSeconds > cfg.maxTerm) revert TermTooLong();
        if (desiredYieldBps < cfg.minYieldBps) revert YieldBelowMin(desiredYieldBps, cfg.minYieldBps);
        if (desiredYieldBps > cfg.maxYieldBps) revert YieldExceedsMax(desiredYieldBps, cfg.maxYieldBps);

        uint256 avail = availablePrincipal[msg.sender][token];
        if (principal > avail) revert InsufficientAvailablePrincipal(principal, avail);

        // Effects
        availablePrincipal[msg.sender][token] = avail - principal;

        uint256 start = block.timestamp;
        uint256 maturity = start + termSeconds;

        positionId = _positions.length;
        _positions.push(Position({
            token: token,
            owner: msg.sender,
            principal: principal,
            fixedRateBps: desiredYieldBps,
            startTimestamp: start,
            maturityTimestamp: maturity,
            closed: false
        }));
        _userPositionIds[msg.sender].push(positionId);

        emit PositionOpened(positionId, token, msg.sender, principal, desiredYieldBps, maturity);
    }

    /// @notice Close a matured position and redeem principal plus earned yield.
    function closePosition(uint256 positionId) external returns (uint256 principalReturned, uint256 yieldEarned) {
        if (positionId >= _positions.length) revert PositionNotFound();
        Position storage p = _positions[positionId];
        if (p.owner != msg.sender) revert NotPositionOwner();
        if (p.closed) revert PositionAlreadyClosed();
        if (block.timestamp < p.maturityTimestamp) revert PositionNotMature(p.maturityTimestamp, block.timestamp);

        // Calculate yield: principal * rate * (term / year)
        uint256 term = p.maturityTimestamp - p.startTimestamp;
        yieldEarned = (p.principal * p.fixedRateBps * term) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        principalReturned = p.principal;

        // Effects
        p.closed = true;
        totalCustodied[p.token] -= principalReturned;

        // Interactions
        if (principalReturned > 0) {
            bool ok = IERC20(p.token).transfer(msg.sender, principalReturned);
            if (!ok) revert TransferFailed();
        }
        if (yieldEarned > 0) {
            bool ok = IERC20(p.token).transfer(msg.sender, yieldEarned);
            if (!ok) revert TransferFailed();
        }

        emit PositionClosed(positionId, msg.sender, principalReturned, yieldEarned);
    }

    /// @notice Withdraw available (uncommitted) principal.
    function withdraw(address token, uint256 amount) external onlyRegisteredToken(token) {
        if (amount == 0) revert ZeroAmount();

        uint256 avail = availablePrincipal[msg.sender][token];
        if (amount > avail) revert InsufficientAvailablePrincipal(amount, avail);

        availablePrincipal[msg.sender][token] = avail - amount;
        totalCustodied[token] -= amount;

        bool ok = IERC20(token).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit PrincipalWithdrawn(token, msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /* View functions                                                     */
    /* ------------------------------------------------------------------ */

    function positionCount() external view returns (uint256) {
        return _positions.length;
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        if (positionId >= _positions.length) revert PositionNotFound();
        return _positions[positionId];
    }

    function userPositionIds(address account) external view returns (uint256[] memory) {
        return _userPositionIds[account];
    }

    function getAvailablePrincipal(address account, address token) external view returns (uint256) {
        return availablePrincipal[account][token];
    }

    function getTokenConfig(address token) external view returns (TokenConfig memory) {
        return tokenConfigs[token];
    }

    /// @dev Preview the yield that would be earned for a given principal, rate, and term.
    function previewYield(uint256 principal, uint256 yieldBps, uint256 termSeconds) external pure returns (uint256) {
        return (principal * yieldBps * termSeconds) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
    }
}
