// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStaking {
    // ============ ERC20 Metadata ============
    string public constant name = "Liquid Staked Native";
    string public constant symbol = "lsNATIVE";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ Staking State ============
    /// @notice Native principal deposited per user.
    mapping(address => uint256) public depositedAssets;
    /// @notice Aggregate native principal currently staked in the protocol.
    uint256 public totalDepositedAssets;
    /// @notice Exchange rate: native asset amount per 1 LST, scaled by 1e18.
    uint256 public exchangeRate;

    // ============ Rewards ============
    /// @notice Exchange rate snapshot at the user's last reward settlement.
    mapping(address => uint256) public lastClaimedRate;

    // ============ Fees ============
    /// @notice Redemption fee in basis points (50 = 0.5%).
    uint256 public redemptionFeeRate;
    /// @notice Maximum allowable redemption fee (10% = 1000 bps).
    uint256 public constant FEE_CAP = 1000;
    /// @notice Accumulated redemption fees available for owner withdrawal.
    uint256 public accumulatedFees;

    // ============ Limits ============
    /// @notice Minimum native deposit amount (0.1 native).
    uint256 public constant MIN_DEPOSIT = 0.1 ether;

    // ============ Access Control ============
    address public owner;
    address public operator;

    // ============ Reentrancy Guard ============
    bool private _locked;

    // ============ Events ============
    event Deposit(address indexed user, uint256 nativeAmount, uint256 lstMinted);
    event Redeem(address indexed user, uint256 lstBurned, uint256 nativeReturned, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 rewardAmount, uint256 lstBurned);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============ Errors ============
    error NotOwner();
    error NotOperator();
    error ReentrantCall();
    error InsufficientDeposit();
    error InsufficientBalance();
    error ZeroAmount();
    error InsufficientContractBalance();
    error FeeExceedsCap();
    error TransferFailed();
    error ZeroAddress();
    error InvalidExchangeRate();
    error NoRewardsAccrued();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;
        operator = msg.sender;
        exchangeRate = 1e18; // 1:1 initially
        redemptionFeeRate = 50; // 0.5%
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), msg.sender);
        emit ExchangeRateUpdated(0, exchangeRate);
        emit RedemptionFeeUpdated(0, redemptionFeeRate);
    }

    /// @notice Accepts native assets (e.g., staking yield funded by the operator).
    receive() external payable {}

    // ============ ERC20 ============
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientBalance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        // Initialize reward baseline for first-time recipients.
        if (lastClaimedRate[to] == 0) lastClaimedRate[to] = exchangeRate;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (lastClaimedRate[to] == 0) lastClaimedRate[to] = exchangeRate;
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

    // ============ Rewards Accounting ============
    /// @dev Settles pending rewards for `user` by burning the LST equivalent of
    /// the accrued yield and updating their last-claimed rate. Performs effects
    /// only (no external calls); the caller is responsible for paying out the
    /// returned native `reward` after all state updates are complete.
    function _settlePendingRewards(address user) internal returns (uint256 reward, uint256 lstToBurn) {
        uint256 lastRate = lastClaimedRate[user];
        if (exchangeRate <= lastRate) return (0, 0);
        uint256 lstBalance = balanceOf[user];
        if (lstBalance == 0) {
            lastClaimedRate[user] = exchangeRate;
            return (0, 0);
        }
        uint256 delta = exchangeRate - lastRate;
        // Single division per result — avoids divide-before-multiply rounding.
        reward = (lstBalance * delta) / 1e18;
        lstToBurn = (lstBalance * delta) / exchangeRate;
        lastClaimedRate[user] = exchangeRate;
        if (reward == 0 || lstToBurn == 0) return (0, 0);
        _burn(user, lstToBurn);
        emit RewardsClaimed(user, reward, lstToBurn);
    }

    // ============ Staking ============
    /// @notice Deposit native assets and receive minted liquid staking tokens.
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit();
        uint256 lstToMint = (msg.value * 1e18) / exchangeRate;
        if (lstToMint == 0) revert ZeroAmount();

        // Effects: settle pending rewards (burns yield LST, updates rate),
        // record the deposit, and mint new LST — all before any external call.
        (uint256 reward, ) = _settlePendingRewards(msg.sender);
        depositedAssets[msg.sender] += msg.value;
        totalDepositedAssets += msg.value;
        lastClaimedRate[msg.sender] = exchangeRate;
        _mint(msg.sender, lstToMint);

        // Interaction: pay out accrued rewards after state is consistent.
        if (reward > 0) {
            if (address(this).balance < reward) revert InsufficientContractBalance();
            (bool ok, ) = payable(msg.sender).call{value: reward}("");
            if (!ok) revert TransferFailed();
        }

        emit Deposit(msg.sender, msg.value, lstToMint);
    }

    /// @notice Redeem liquid staking tokens for native assets, less the redemption fee.
    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        uint256 userBal = balanceOf[msg.sender];
        if (userBal < lstAmount) revert InsufficientBalance();

        // Effects: settle pending rewards first (burns yield LST, updates rate).
        (uint256 reward, uint256 lstToBurn) = _settlePendingRewards(msg.sender);
        // After burning yield LST, ensure the remaining balance covers the redeem.
        if (userBal - lstToBurn < lstAmount) revert InsufficientBalance();

        // Redeem value — single division to avoid divide-before-multiply rounding.
        uint256 nativeToReturn = (lstAmount * exchangeRate) / 1e18;
        // Fee in a single expression (1e18 * 10000 = 1e22) avoids precision loss.
        uint256 fee = (lstAmount * exchangeRate * redemptionFeeRate) / 1e22;
        if (fee > nativeToReturn) fee = nativeToReturn;
        uint256 netReturn = nativeToReturn - fee;
        uint256 totalToSend = reward + netReturn;

        if (address(this).balance < totalToSend) revert InsufficientContractBalance();

        // Effects: burn principal, update deposit trackers and accumulated fees.
        _burn(msg.sender, lstAmount);
        uint256 toDeductUser = nativeToReturn > depositedAssets[msg.sender]
            ? depositedAssets[msg.sender]
            : nativeToReturn;
        depositedAssets[msg.sender] -= toDeductUser;
        uint256 toDeductTotal = nativeToReturn > totalDepositedAssets
            ? totalDepositedAssets
            : nativeToReturn;
        totalDepositedAssets -= toDeductTotal;
        accumulatedFees += fee;

        // Interaction: single external transfer of reward + net redemption.
        if (totalToSend > 0) {
            (bool ok, ) = payable(msg.sender).call{value: totalToSend}("");
            if (!ok) revert TransferFailed();
        }

        emit Redeem(msg.sender, lstAmount, netReturn, fee);
    }

    /// @notice Claim accrued staking rewards in native assets without redeeming principal.
    function claimRewards() external nonReentrant {
        if (balanceOf[msg.sender] == 0) revert InsufficientBalance();
        if (exchangeRate <= lastClaimedRate[msg.sender]) revert NoRewardsAccrued();

        // Effects: burn yield LST and update last-claimed rate.
        (uint256 reward, ) = _settlePendingRewards(msg.sender);
        if (reward == 0) revert NoRewardsAccrued();
        if (address(this).balance < reward) revert InsufficientContractBalance();

        // Interaction: pay out the reward.
        (bool ok, ) = payable(msg.sender).call{value: reward}("");
        if (!ok) revert TransferFailed();
    }

    // ============ Admin ============
    /// @notice Operator updates the exchange rate between native asset and LST.
    /// @dev The contract must hold enough native (excluding accumulated fees) to
    /// back the new total LST value, ensuring redemptions/claims remain solvent.
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 totalLSTValue = (totalSupply * newRate) / 1e18;
        if (address(this).balance < totalLSTValue + accumulatedFees) {
            revert InsufficientContractBalance();
        }
        uint256 old = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(old, newRate);
    }

    /// @notice Owner sets the redemption fee rate in basis points (capped at 10%).
    function setRedemptionFee(uint256 newFee) external onlyOwner {
        if (newFee > FEE_CAP) revert FeeExceedsCap();
        uint256 old = redemptionFeeRate;
        redemptionFeeRate = newFee;
        emit RedemptionFeeUpdated(old, newFee);
    }

    /// @notice Owner designates a new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /// @notice Owner transfers contract ownership.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /// @notice Owner withdraws accumulated redemption fees.
    function withdrawFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientContractBalance();
        accumulatedFees = 0;
        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    // ============ Views ============
    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return balanceOf[user];
    }

    function getDepositedAssets(address user) external view returns (uint256) {
        return depositedAssets[user];
    }

    function getPendingRewards(address user) external view returns (uint256) {
        uint256 lstBal = balanceOf[user];
        uint256 lastRate = lastClaimedRate[user];
        if (lstBal == 0 || exchangeRate <= lastRate) return 0;
        return (lstBal * (exchangeRate - lastRate)) / 1e18;
    }
}
