// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CoinFlipGame
/// @notice A simple coin-flip prediction game. Players deposit native currency, place bets
///         on heads or tails, and a trusted operator resolves each bet with an outcome.
///         Winning bets pay out 2x the wager minus a 2% fee, which the operator may withdraw.
contract CoinFlipGame {
    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum Outcome {
        None,
        Heads,
        Tails
    }

    struct Bet {
        address player;
        Outcome prediction;
        uint256 wager;
        bool resolved;
        bool won;
        bool claimed;
        uint256 payout;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice Per-player deposit balances used to fund bets and to withdraw unused funds.
    mapping(address => uint256) public balances;

    /// @notice Aggregate accounting of native currency under the contract's management
    ///         (deposits minus withdrawals, claims and fee withdrawals).
    uint256 public totalContractBalance;

    /// @notice Map of bet id to bet details.
    mapping(uint256 => Bet) public bets;

    /// @notice Ordered list of currently unresolved (active) bet ids.
    uint256[] internal _activeBetIds;

    /// @notice Maps a bet id to its index inside `_activeBetIds` for O(1) removal.
    mapping(uint256 => uint256) internal _activeBetIndex;

    /// @notice Next bet id to be assigned (starts at 1).
    uint256 public nextBetId;

    /// @notice Privileged operator who resolves bets and withdraws collected fees.
    address public operator;

    /// @notice Cumulative fees available for the operator to withdraw.
    uint256 public collectedFees;

    /// @notice Total number of bets ever placed.
    uint256 public totalBetsPlaced;

    /// @notice Total number of bets ever resolved.
    uint256 public totalBetsResolved;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Minimum allowed wager (0.01 native currency units).
    uint256 public constant MIN_BET = 0.01 ether;

    /// @notice Fee taken from winning payouts, expressed in basis points (200 = 2%).
    uint256 public constant FEE_BPS = 200;

    /// @notice Gross payout multiplier applied to winning wagers (2x).
    uint256 public constant PAYOUT_MULTIPLIER = 2;

    /// @notice Reentrancy lock.
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event BetPlaced(uint256 indexed betId, address indexed player, Outcome prediction, uint256 wager);
    event BetResolved(
        uint256 indexed betId,
        address indexed player,
        Outcome outcome,
        bool won,
        uint256 payout,
        uint256 fee
    );
    event WinningsClaimed(uint256 indexed betId, address indexed player, uint256 payout);
    event Deposit(address indexed player, uint256 amount);
    event Withdrawal(address indexed player, uint256 amount);
    event FeesWithdrawn(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NotOperator();
    error NotBetOwner();
    error BetDoesNotExist();
    error BetAlreadyResolved();
    error BetNotResolved();
    error BetNotWon();
    error WinningsAlreadyClaimed();
    error InvalidOutcome();
    error WagerBelowMinimum(uint256 wager, uint256 minimum);
    error InsufficientBalance(uint256 required, uint256 available);
    error NoFeesToWithdraw();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        nextBetId = 1;
    }

    // ---------------------------------------------------------------------
    // Player API
    // ---------------------------------------------------------------------

    /// @notice Deposit native currency to fund future bets. Increases player balance.
    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        balances[msg.sender] += msg.value;
        totalContractBalance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Place a bet on `heads` or `tails`. The wager is locked from the caller's balance.
    /// @param prediction The predicted outcome (must be Heads or Tails).
    /// @param wager The amount to wager (must be >= MIN_BET and <= caller's balance).
    /// @return betId The id of the newly created bet.
    function placeBet(Outcome prediction, uint256 wager) external nonReentrant returns (uint256 betId) {
        if (wager < MIN_BET) revert WagerBelowMinimum(wager, MIN_BET);
        if (prediction != Outcome.Heads && prediction != Outcome.Tails) revert InvalidOutcome();
        if (balances[msg.sender] < wager) revert InsufficientBalance(wager, balances[msg.sender]);

        // Effects: lock the wager from the caller's deposit balance.
        // The ETH itself stays in the contract; totalContractBalance is unchanged.
        balances[msg.sender] -= wager;

        betId = nextBetId++;
        bets[betId] = Bet({
            player: msg.sender,
            prediction: prediction,
            wager: wager,
            resolved: false,
            won: false,
            claimed: false,
            payout: 0
        });
        _activeBetIndex[betId] = _activeBetIds.length;
        _activeBetIds.push(betId);

        totalBetsPlaced += 1;
        emit BetPlaced(betId, msg.sender, prediction, wager);
    }

    /// @notice Claim the payout for a resolved, winning bet. Transfers native currency directly.
    /// @param betId The id of the winning bet to claim.
    function claimWinnings(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        if (bet.player != msg.sender) revert NotBetOwner();
        if (!bet.resolved) revert BetNotResolved();
        if (!bet.won) revert BetNotWon();
        if (bet.claimed) revert WinningsAlreadyClaimed();
        if (address(this).balance < bet.payout) {
            revert InsufficientBalance(bet.payout, address(this).balance);
        }

        // Effects (all state updates happen before the external call)
        uint256 payout = bet.payout;
        bet.claimed = true;
        totalContractBalance -= payout;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed();

        emit WinningsClaimed(betId, msg.sender, payout);
    }

    /// @notice Withdraw native currency from your unused deposit balance.
    /// @param amount The amount to withdraw.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance(amount, balances[msg.sender]);
        if (address(this).balance < amount) revert InsufficientBalance(amount, address(this).balance);

        // Effects (all state updates happen before the external call)
        balances[msg.sender] -= amount;
        totalContractBalance -= amount;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Operator API
    // ---------------------------------------------------------------------

    /// @notice Resolve a pending bet with the actual outcome.
    /// @dev This is a trust-based resolution model: the operator chooses the outcome.
    ///      For a winning bet the payout is `wager * PAYOUT_MULTIPLIER` minus a 2% fee.
    ///      The fee is accrued in `collectedFees` and may be withdrawn by the operator.
    /// @param betId The id of the bet to resolve.
    /// @param outcome The actual coin flip outcome (must be Heads or Tails).
    function resolveBet(uint256 betId, Outcome outcome) external onlyOperator nonReentrant {
        Bet storage bet = bets[betId];
        if (bet.player == address(0)) revert BetDoesNotExist();
        if (bet.resolved) revert BetAlreadyResolved();
        if (outcome != Outcome.Heads && outcome != Outcome.Tails) revert InvalidOutcome();

        // Effects
        bet.resolved = true;
        bool won = (bet.prediction == outcome);
        bet.won = won;

        uint256 payout = 0;
        uint256 fee = 0;
        if (won) {
            uint256 grossPayout = bet.wager * PAYOUT_MULTIPLIER;
            fee = (grossPayout * FEE_BPS) / 10000;
            payout = grossPayout - fee;
            bet.payout = payout;
            collectedFees += fee;
        }

        _removeActiveBet(betId);
        totalBetsResolved += 1;

        emit BetResolved(betId, bet.player, outcome, won, payout, fee);
    }

    /// @notice Withdraw accumulated fees to the operator.
    function withdrawFees() external onlyOperator nonReentrant {
        uint256 amount = collectedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        if (address(this).balance < amount) revert InsufficientBalance(amount, address(this).balance);

        // Effects (all state updates happen before the external call)
        collectedFees = 0;
        totalContractBalance -= amount;

        // Interactions
        (bool success, ) = payable(operator).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(operator, amount);
    }

    /// @notice Transfer the operator role to a new address.
    /// @param newOperator The address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Returns the list of currently active (unresolved) bet ids.
    function getActiveBetIds() external view returns (uint256[] memory) {
        return _activeBetIds;
    }

    /// @notice Returns the number of currently active (unresolved) bets.
    function getActiveBetCount() external view returns (uint256) {
        return _activeBetIds.length;
    }

    /// @notice Returns the full Bet record for a given bet id.
    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    /// @notice Returns the actual native currency balance held by the contract.
    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Returns the pending (unclaimed) payout for a given bet id.
    function getPendingPayout(uint256 betId) external view returns (uint256) {
        Bet memory bet = bets[betId];
        if (!bet.resolved || !bet.won || bet.claimed) return 0;
        return bet.payout;
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    /// @dev Removes a bet id from `_activeBetIds` in O(1) by swapping with the last element.
    function _removeActiveBet(uint256 betId) internal {
        uint256 idx = _activeBetIndex[betId];
        uint256 lastIndex = _activeBetIds.length - 1;
        if (idx != lastIndex) {
            uint256 lastBetId = _activeBetIds[lastIndex];
            _activeBetIds[idx] = lastBetId;
            _activeBetIndex[lastBetId] = idx;
        }
        _activeBetIds.pop();
        delete _activeBetIndex[betId];
    }

    // ---------------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------------

    /// @notice Accept direct ETH transfers (e.g., operator top-ups to buffer winning payouts).
    receive() external payable {}
}
