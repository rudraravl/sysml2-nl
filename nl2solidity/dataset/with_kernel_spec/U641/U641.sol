// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LiquidRestaking
/// @notice Accepts native currency deposits, issues a liquid restaking token (LRT),
///         tracks an operator-managed exchange rate, accrues protocol fees, and
///         enforces a 7-day unbonding period on withdrawals.
contract LiquidRestaking {
    /* ------------------------------------------------------------------ */
    /* ERC20 metadata                                                     */
    /* ------------------------------------------------------------------ */
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* ------------------------------------------------------------------ */
    /* Access control                                                     */
    /* ------------------------------------------------------------------ */
    address public owner;
    address public operator;
    bool public paused;

    /* ------------------------------------------------------------------ */
    /* Staking / exchange rate                                            */
    /* ------------------------------------------------------------------ */
    /// @dev Total native currency currently backing outstanding LRT.
    uint256 public totalStaked;
    /// @dev Native currency per 1 LRT, scaled by 1e18.
    uint256 public exchangeRate;

    /* ------------------------------------------------------------------ */
    /* Protocol fee distribution                                          */
    /* ------------------------------------------------------------------ */
    /// @dev Protocol fee in basis points. Max 1000 (10%).
    uint256 public protocolFeePercent;
    uint256 public accumulatedFeePerShare; // scaled by 1e18
    uint256 public totalFeesCollected;
    uint256 public unclaimedFees; // native currency reserved for fee claims
    mapping(address => uint256) public userFeeDebt;
    mapping(address => uint256) public userWithdrawableFees;

    /* ------------------------------------------------------------------ */
    /* Unbonding                                                          */
    /* ------------------------------------------------------------------ */
    uint256 public constant UNBONDING_PERIOD = 7 days;

    struct WithdrawalRequest {
        uint256 amount; // native currency to return
        uint256 unlockTime;
        bool active;
    }
    mapping(address => WithdrawalRequest[]) internal _withdrawalRequests;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */
    event Deposit(address indexed user, uint256 nativeAmount, uint256 lrtMinted);
    event WithdrawRequested(address indexed user, uint256 lrtBurned, uint256 nativeAmount, uint256 unlockTime, uint256 index);
    event WithdrawCompleted(address indexed user, uint256 nativeAmount, uint256 index);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 feeCollected);
    event ProtocolFeePercentUpdated(uint256 oldPercent, uint256 newPercent);
    event FeeClaimed(address indexed user, uint256 nativeAmount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error OnlyOwner();
    error OnlyOperator();
    error Paused();
    error InvalidRate();
    error InvalidAmount();
    error NoPendingWithdrawal();
    error StillLocked();
    error FeeTooHigh();
    error ZeroAddress();
    error TransferFailed();
    error IndexOutOfRange();

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialRate,
        address _operator,
        uint256 _protocolFeePercent
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialRate == 0) revert InvalidRate();
        if (_protocolFeePercent > 1000) revert FeeTooHigh();
        name = _name;
        symbol = _symbol;
        exchangeRate = _initialRate;
        operator = _operator;
        owner = msg.sender;
        protocolFeePercent = _protocolFeePercent;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit ProtocolFeePercentUpdated(0, _protocolFeePercent);
        emit ExchangeRateUpdated(0, _initialRate, 0);
    }

    /* ------------------------------------------------------------------ */
    /* ERC20 core                                                         */
    /* ------------------------------------------------------------------ */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
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
            if (allowed < amount) revert InvalidAmount();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InvalidAmount();

        _updateFeeDebt(from);
        _updateFeeDebt(to);

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _updateFeeDebt(to);
        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InvalidAmount();
        _updateFeeDebt(from);
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    /* ------------------------------------------------------------------ */
    /* Fee accounting                                                     */
    /* ------------------------------------------------------------------ */
    function _updateFeeDebt(address user) internal {
        uint256 owed = (balanceOf[user] * accumulatedFeePerShare) / 1e18 - userFeeDebt[user];
        if (owed > 0) {
            userWithdrawableFees[user] += owed;
        }
        userFeeDebt[user] = (balanceOf[user] * accumulatedFeePerShare) / 1e18;
    }

    /// @notice Pending protocol fees claimable by `user` (not yet moved to withdrawable).
    function pendingFees(address user) external view returns (uint256) {
        uint256 owed = (balanceOf[user] * accumulatedFeePerShare) / 1e18 - userFeeDebt[user];
        return userWithdrawableFees[user] + owed;
    }

    /* ------------------------------------------------------------------ */
    /* Deposit                                                            */
    /* ------------------------------------------------------------------ */
    function deposit() external payable whenNotPaused {
        if (msg.value == 0) revert InvalidAmount();
        uint256 lrtToMint = (msg.value * 1e18) / exchangeRate;
        if (lrtToMint == 0) revert InvalidAmount();

        totalStaked += msg.value;
        _mint(msg.sender, lrtToMint);

        emit Deposit(msg.sender, msg.value, lrtToMint);
    }

    /* ------------------------------------------------------------------ */
    /* Withdraw (initiate unbonding)                                      */
    /* ------------------------------------------------------------------ */
    function withdraw(uint256 lrtAmount) external whenNotPaused {
        if (lrtAmount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < lrtAmount) revert InvalidAmount();

        uint256 nativeToReturn = (lrtAmount * exchangeRate) / 1e18;
        if (nativeToReturn == 0) revert InvalidAmount();

        _burn(msg.sender, lrtAmount);

        totalStaked -= nativeToReturn;

        uint256 unlock = block.timestamp + UNBONDING_PERIOD;
        uint256 index = _withdrawalRequests[msg.sender].length;
        _withdrawalRequests[msg.sender].push(WithdrawalRequest(nativeToReturn, unlock, true));

        emit WithdrawRequested(msg.sender, lrtAmount, nativeToReturn, unlock, index);
    }

    /// @notice Complete a previously requested withdrawal after the unbonding period.
    function completeWithdraw(uint256 index) external {
        WithdrawalRequest[] storage reqs = _withdrawalRequests[msg.sender];
        if (index >= reqs.length) revert IndexOutOfRange();
        WithdrawalRequest storage req = reqs[index];
        if (!req.active) revert NoPendingWithdrawal();
        if (block.timestamp < req.unlockTime) revert StillLocked();

        req.active = false;
        uint256 amount = req.amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit WithdrawCompleted(msg.sender, amount, index);
    }

    /// @notice Read all withdrawal requests for a user.
    function pendingWithdrawals(address user)
        external
        view
        returns (uint256[] memory amounts, uint256[] memory unlockTimes, bool[] memory actives)
    {
        WithdrawalRequest[] storage reqs = _withdrawalRequests[user];
        uint256 len = reqs.length;
        amounts = new uint256[](len);
        unlockTimes = new uint256[](len);
        actives = new bool[](len);
        for (uint256 i = 0; i < len; i++) {
            amounts[i] = reqs[i].amount;
            unlockTimes[i] = reqs[i].unlockTime;
            actives[i] = reqs[i].active;
        }
    }

    function withdrawalRequestCount(address user) external view returns (uint256) {
        return _withdrawalRequests[user].length;
    }

    /* ------------------------------------------------------------------ */
    /* Claim protocol fees                                                */
    /* ------------------------------------------------------------------ */
    function claimFees() external {
        _updateFeeDebt(msg.sender);
        uint256 claimable = userWithdrawableFees[msg.sender];
        if (claimable == 0) revert InvalidAmount();

        userWithdrawableFees[msg.sender] = 0;
        unclaimedFees -= claimable;

        (bool ok, ) = payable(msg.sender).call{value: claimable}("");
        if (!ok) revert TransferFailed();

        emit FeeClaimed(msg.sender, claimable);
    }

    /* ------------------------------------------------------------------ */
    /* Operator: exchange rate                                            */
    /* ------------------------------------------------------------------ */
    /// @notice Update the exchange rate from oracle data. A rate increase
    ///         distributes a protocol fee cut to the fee pool and the
    ///         remainder to stakers via the net rate. A decrease (slashing)
    ///         applies directly with no fee.
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = exchangeRate;

        if (newRate <= oldRate) {
            // Slashing / devaluation: reduce staked backing proportionally.
            uint256 loss = ((oldRate - newRate) * totalSupply) / 1e18;
            if (loss > totalStaked) {
                totalStaked = 0;
            } else {
                totalStaked -= loss;
            }
            exchangeRate = newRate;
            emit ExchangeRateUpdated(oldRate, newRate, 0);
            return;
        }

        uint256 delta = newRate - oldRate;
        uint256 feeBps = protocolFeePercent;
        uint256 netBps = 10000 - feeBps;

        // Compute fee and net reward without divide-before-multiply loss.
        // fee = delta * totalSupply * feeBps / (1e18 * 10000)
        // netReward = delta * totalSupply * netBps / (1e18 * 10000)
        uint256 deltaTimesSupply = delta * totalSupply;
        uint256 fee = (deltaTimesSupply * feeBps) / (1e18 * 10000);
        uint256 netReward = (deltaTimesSupply * netBps) / (1e18 * 10000);

        if (fee > 0 && totalSupply > 0) {
            // accumulatedFeePerShare increment = fee * 1e18 / totalSupply
            //   = (delta * totalSupply * feeBps / (1e18 * 10000)) * 1e18 / totalSupply
            //   = delta * feeBps / 10000
            accumulatedFeePerShare += (delta * feeBps) / 10000;
            unclaimedFees += fee;
            totalFeesCollected += fee;
        }

        // Net rate after fee deduction: oldRate + delta * netBps / 10000
        exchangeRate = oldRate + (delta * netBps) / 10000;

        // Net reward accrues to the staked backing pool.
        totalStaked += netReward;

        emit ExchangeRateUpdated(oldRate, exchangeRate, fee);
    }

    /* ------------------------------------------------------------------ */
    /* Owner administration                                               */
    /* ------------------------------------------------------------------ */
    function setProtocolFeePercent(uint256 _percent) external onlyOwner {
        if (_percent > 1000) revert FeeTooHigh();
        uint256 old = protocolFeePercent;
        protocolFeePercent = _percent;
        emit ProtocolFeePercentUpdated(old, _percent);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /* ------------------------------------------------------------------ */
    /* Views                                                              */
    /* ------------------------------------------------------------------ */
    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }

    function totalWithdrawableFees(address user) external view returns (uint256) {
        return userWithdrawableFees[user];
    }

    /// @dev Accept native currency (e.g. restaking rewards forwarded by the operator).
    receive() external payable {}
}
