// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal ERC-20 interface used by the game contract.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Minimal SafeERC20 wrapper that reverts on failed transfers and also
 *      tolerates non-standard ERC-20 tokens that do not return a bool.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        bytes32 ret;
        assembly {
            let ok := call(gas(), token, 0, add(data, 32), mload(data), 0, 32)
            if iszero(ok) {
                // bubble up the revert reason if any
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            switch returndatasize()
            case 32 { ret := returndatasize() }
            case 0 { }
            default { revert(0, 0) }
        }
        if (ret == 0) {
            require(token.transfer(address(0), 0), "SafeERC20: non-ERC20");
        }
    }
}

/**
 * @title ProvablyFairGame
 * @notice A provably fair on-chain multiplier game for a single ERC-20 token.
 *         Players deposit tokens to start a session, take successive steps that
 *         increase their multiplier by 5%-20%, and cash out at any time.
 *         Winnings are capped at 100x the initial wager. Fairness is achieved
 *         via an operator commit-reveal scheme: the operator commits a hash of
 *         a per-step seed before the player decides, then reveals the seed so
 *         the contract can verify it on-chain.
 */
contract ProvablyFairGame {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev Multiplier scale: 1e18 = 1x.
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_MULTIPLIER = 100e18; // 100x hard cap
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MIN_INCREMENT_PCT = 5;  // 5% floor
    uint256 public constant MAX_INCREMENT_PCT = 20; // 20% ceiling

    // -----------------------------------------------------------------------
    // Immutables & roles
    // -----------------------------------------------------------------------

    IERC20 public immutable token;
    address public owner;
    address public operator;

    // -----------------------------------------------------------------------
    // Configuration
    // -----------------------------------------------------------------------

    struct GameParams {
        uint256 initialMultiplierMin; // minimum starting multiplier (1e18 scale)
        uint256 initialMultiplierMax; // maximum starting multiplier (1e18 scale)
        uint256 maxSteps;             // maximum steps per session (>= 1)
        uint256 crashChanceBps;      // 0..10_000 probability of bust per step
    }

    GameParams public gameParams;

    // -----------------------------------------------------------------------
    // Sessions
    // -----------------------------------------------------------------------

    struct Session {
        uint256 wager;        // tokens locked at start
        uint256 multiplier;   // current multiplier (1e18 scale)
        uint256 steps;        // successful steps taken
        bool active;          // true while the session is open
        bool pendingStep;     // true after the player opted into the next step
        bytes32 nextCommit;   // operator's committed hash of the next step seed
    }

    mapping(address => Session) public sessions;

    /// @dev Sum of all active wagers; protects them from being swept.
    uint256 public totalActiveWagers;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event GameStarted(address indexed player, uint256 wager, uint256 initialMultiplier);
    event DecisionMade(address indexed player, uint256 stepIndex);
    event StepProcessed(address indexed player, uint256 stepIndex, uint256 newMultiplier, bool crashed);
    event GameConcluded(address indexed player, uint256 finalMultiplier, uint256 amountPaid, bool won);
    event ParamsUpdated(
        uint256 initialMultiplierMin,
        uint256 initialMultiplierMax,
        uint256 maxSteps,
        uint256 crashChanceBps
    );
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event NextStepCommitted(address indexed player, bytes32 commitHash);
    event RewardsFunded(address indexed funder, uint256 amount);
    event RewardsSwept(address indexed receiver, uint256 amount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error InvalidParams();
    error InvalidWager();
    error SessionActive();
    error NoActiveSession();
    error MaxStepsReached();
    error MultiplierCapReached();
    error NoCommitAvailable();
    error AlreadyCommitted();
    error AlreadyPending();
    error NotPending();
    error InvalidCommit();
    error InsufficientRewards();
    error ZeroAddress();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address token_, address operator_, GameParams memory params_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        _validateParams(params_);
        token = IERC20(token_);
        owner = msg.sender;
        operator = operator_;
        gameParams = params_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
    }

    // -----------------------------------------------------------------------
    // Internal validation
    // -----------------------------------------------------------------------

    function _validateParams(GameParams memory p) internal pure {
        if (p.initialMultiplierMin == 0) revert InvalidParams();
        if (p.initialMultiplierMax < p.initialMultiplierMin) revert InvalidParams();
        if (p.initialMultiplierMax > MAX_MULTIPLIER) revert InvalidParams();
        if (p.maxSteps == 0) revert InvalidParams();
        if (p.crashChanceBps > BASIS_POINTS) revert InvalidParams();
    }

    // -----------------------------------------------------------------------
    // Owner administration
    // -----------------------------------------------------------------------

    function setGameParams(GameParams calldata params_) external onlyOwner {
        _validateParams(params_);
        gameParams = params_;
        emit ParamsUpdated(
            params_.initialMultiplierMin,
            params_.initialMultiplierMax,
            params_.maxSteps,
            params_.crashChanceBps
        );
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Funds the reward pool so payouts above player wagers are possible.
    function fundRewards(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidWager();
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsFunded(msg.sender, amount);
    }

    /// @notice Sweeps unused reward tokens (excludes active player wagers).
    function sweepRewards(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = token.balanceOf(address(this));
        uint256 sweepable = bal - totalActiveWagers;
        if (amount > sweepable) revert InsufficientRewards();
        token.safeTransfer(to, amount);
        emit RewardsSwept(to, amount);
    }

    // -----------------------------------------------------------------------
    // Operator: provably-fair RNG plumbing
    // -----------------------------------------------------------------------

    /// @notice Operator commits the hash of the next step's seed for a player.
    ///         Must happen before the player calls makeDecision() for that step.
    function commitNextStep(address player, bytes32 commitHash) external onlyOperator {
        if (player == address(0)) revert ZeroAddress();
        Session storage s = sessions[player];
        if (!s.active) revert NoActiveSession();
        if (s.nextCommit != bytes32(0)) revert AlreadyCommitted();
        if (commitHash == bytes32(0)) revert InvalidCommit();
        s.nextCommit = commitHash;
        emit NextStepCommitted(player, commitHash);
    }

    /// @notice Operator reveals the seed for a pending step, applying the RNG.
    function revealStep(address player, bytes32 seed) external onlyOperator {
        Session storage s = sessions[player];
        if (!s.active) revert NoActiveSession();
        if (!s.pendingStep) revert NotPending();
        if (s.nextCommit == bytes32(0)) revert NoCommitAvailable();
        if (keccak256(abi.encode(seed)) != s.nextCommit) revert InvalidCommit();

        // Clear commitment and pending flag before effects.
        s.nextCommit = bytes32(0);
        s.pendingStep = false;
        s.steps += 1;

        GameParams memory p = gameParams;
        uint256 rng = uint256(keccak256(abi.encode(seed, player, s.steps)));

        bool crashed = (rng % BASIS_POINTS) < p.crashChanceBps;
        if (crashed) {
            // Session ends; wager is forfeited to the reward pool.
            totalActiveWagers -= s.wager;
            s.active = false;
            s.multiplier = 0;
            s.wager = 0;
            emit StepProcessed(player, s.steps, 0, true);
            emit GameConcluded(player, 0, 0, false);
            return;
        }

        // Non-crash: compound the multiplier by an increment in [5, 20]%.
        uint256 range = MAX_INCREMENT_PCT - MIN_INCREMENT_PCT;
        uint256 incPct = MIN_INCREMENT_PCT + (rng % (range + 1));
        uint256 newMultiplier = (s.multiplier * (100 + incPct)) / 100;
        if (newMultiplier > MAX_MULTIPLIER) {
            newMultiplier = MAX_MULTIPLIER;
        }
        s.multiplier = newMultiplier;

        emit StepProcessed(player, s.steps, newMultiplier, false);

        // Auto-conclude if the multiplier cap or maximum steps are reached.
        if (newMultiplier >= MAX_MULTIPLIER || s.steps >= p.maxSteps) {
            _cashout(player, newMultiplier, true);
        }
    }

    // -----------------------------------------------------------------------
    // Player actions
    // -----------------------------------------------------------------------

    /// @notice Deposits `amount` of the game token to begin a new session.
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidWager();
        Session storage s = sessions[msg.sender];
        if (s.active) revert SessionActive();

        GameParams memory p = gameParams;

        // The initial multiplier is the minimum until the first operator step.
        uint256 initialMultiplier = p.initialMultiplierMin;

        s.wager = amount;
        s.multiplier = initialMultiplier;
        s.steps = 0;
        s.active = true;
        s.pendingStep = false;
        s.nextCommit = bytes32(0);

        totalActiveWagers += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit GameStarted(msg.sender, amount, initialMultiplier);
    }

    /// @notice The player decides to take the next step (operator must commit first).
    function makeDecision() external {
        Session storage s = sessions[msg.sender];
        if (!s.active) revert NoActiveSession();
        if (s.steps >= gameParams.maxSteps) revert MaxStepsReached();
        if (s.multiplier >= MAX_MULTIPLIER) revert MultiplierCapReached();
        if (s.nextCommit == bytes32(0)) revert NoCommitAvailable();
        if (s.pendingStep) revert AlreadyPending();

        s.pendingStep = true;
        emit DecisionMade(msg.sender, s.steps);
    }

    /// @notice Concludes the session and pays out at the current multiplier.
    function withdraw() external {
        Session storage s = sessions[msg.sender];
        if (!s.active) revert NoActiveSession();
        _cashout(msg.sender, s.multiplier, true);
    }

    // -----------------------------------------------------------------------
    // Internal settlement
    // -----------------------------------------------------------------------

    function _cashout(address player, uint256 multiplier, bool won) internal {
        Session storage s = sessions[player];
        uint256 wager = s.wager;
        uint256 payout = (wager * multiplier) / PRECISION;
        uint256 cap = (wager * MAX_MULTIPLIER) / PRECISION;
        if (payout > cap) payout = cap;

        s.active = false;
        s.wager = 0;
        s.multiplier = 0;
        s.pendingStep = false;
        s.nextCommit = bytes32(0);

        totalActiveWagers -= wager;

        if (payout > token.balanceOf(address(this))) revert InsufficientRewards();
        if (payout != 0) {
            token.safeTransfer(player, payout);
        }
        emit GameConcluded(player, multiplier, payout, won);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    function getSession(address player) external view returns (Session memory) {
        return sessions[player];
    }

    function availableRewardPool() external view returns (uint256) {
        return token.balanceOf(address(this)) - totalActiveWagers;
    }

    function pendingPayout(address player) external view returns (uint256) {
        Session storage s = sessions[player];
        if (!s.active) return 0;
        uint256 payout = (s.wager * s.multiplier) / PRECISION;
        uint256 cap = (s.wager * MAX_MULTIPLIER) / PRECISION;
        return payout > cap ? cap : payout;
    }
}
