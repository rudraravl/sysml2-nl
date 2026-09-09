// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IValidatorSet {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external returns (uint256);
    function claimRewards() external returns (uint256);
}

contract LiquidStaking {
    // -----------------------------------------------------------------------
    // Token metadata
    // -----------------------------------------------------------------------
    string public constant name = "Liquid Staked Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    // -----------------------------------------------------------------------
    // Immutable base asset
    // -----------------------------------------------------------------------
    IERC20 public immutable baseAsset;

    // -----------------------------------------------------------------------
    // Roles
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;

    // -----------------------------------------------------------------------
    // External validator set
    // -----------------------------------------------------------------------
    IValidatorSet public validatorSet;

    // -----------------------------------------------------------------------
    // LST token state
    // -----------------------------------------------------------------------
    mapping(address => uint256) public lstBalance;
    mapping(address => mapping(address => uint256)) public lstAllowance;
    uint256 public totalLSTSupply;

    // -----------------------------------------------------------------------
    // Per-user deposit tracking (cumulative base asset deposited)
    // -----------------------------------------------------------------------
    mapping(address => uint256) public userDeposits;

    // -----------------------------------------------------------------------
    // Global staking records
    // -----------------------------------------------------------------------
    uint256 public totalBaseAssetStaked;
    uint256 public stakedWithValidators;

    // -----------------------------------------------------------------------
    // Fee configuration (1%)
    // -----------------------------------------------------------------------
    uint256 public constant FEE_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // -----------------------------------------------------------------------
    // Redemption queue
    // -----------------------------------------------------------------------
    struct RedemptionRequest {
        address user;
        uint256 lstAmount;
    }
    RedemptionRequest[] public redemptionQueue;
    uint256 public redemptionQueueHead;
    uint256 public lastProcessedBlock;
    uint256 public processedThisBlock;
    uint256 public constant MAX_REDEMPTIONS_PER_BLOCK = 100;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    uint256 private _locked = 1;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposited(address indexed user, uint256 baseAssetAmount, uint256 lstAmount);
    event RedemptionRequested(address indexed user, uint256 lstAmount, uint256 queueIndex);
    event Redeemed(address indexed user, uint256 lstAmount, uint256 baseAssetAmount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event StakedWithValidator(uint256 amount);
    event UnstakedFromValidator(uint256 amountRequested, uint256 amountReturned);
    event RewardsClaimed(uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event ValidatorSetChanged(address indexed oldSet, address indexed newSet);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientBaseAsset();
    error NoPendingRedemptions();
    error MaxRedemptionsReached();
    error TransferFailed();
    error NoLSTInCirculation();

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

    modifier nonReentrant() {
        require(_locked == 1, "Reentrancy: locked");
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        address _baseAsset,
        address _validatorSet,
        address _feeRecipient
    ) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_validatorSet == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        baseAsset = IERC20(_baseAsset);
        validatorSet = IValidatorSet(_validatorSet);
        feeRecipient = _feeRecipient;
        owner = msg.sender;
        operator = msg.sender;
        lastProcessedBlock = block.number;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        emit ValidatorSetChanged(address(0), _validatorSet);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the current exchange rate: base asset per LST (scaled by 1e18).
     */
    function exchangeRate() public view returns (uint256) {
        if (totalLSTSupply < 1) return 1e18;
        return (totalBaseAssetStaked * 1e18) / totalLSTSupply;
    }

    /**
     * @notice Returns the base asset balance held by this contract.
     */
    function availableBaseAsset() public view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }

    /**
     * @notice Returns the number of unprocessed redemption requests.
     */
    function pendingRedemptionCount() public view returns (uint256) {
        return redemptionQueue.length - redemptionQueueHead;
    }

    function totalSupply() public view returns (uint256) {
        return totalLSTSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return lstBalance[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return lstAllowance[owner_][spender];
    }

    function redemptionQueueLength() public view returns (uint256) {
        return redemptionQueue.length;
    }

    // -----------------------------------------------------------------------
    // Deposit
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit base asset to receive LST at the current exchange rate.
     * @param amount The amount of base asset to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();

        // Compute LST to mint using current state before any external call
        uint256 lstAmount;
        if (totalLSTSupply < 1) {
            lstAmount = amount;
        } else {
            if (totalBaseAssetStaked < 1) revert NoLSTInCirculation();
            lstAmount = (amount * totalLSTSupply) / totalBaseAssetStaked;
        }

        // External call: pull base asset from depositor
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        // Effects: update state after external call (guarded by nonReentrant)
        userDeposits[msg.sender] += amount;
        totalBaseAssetStaked += amount;
        totalLSTSupply += lstAmount;
        lstBalance[msg.sender] += lstAmount;

        emit Deposited(msg.sender, amount, lstAmount);
        emit Transfer(address(0), msg.sender, lstAmount);
    }

    // -----------------------------------------------------------------------
    // Redeem (queue-based)
    // -----------------------------------------------------------------------

    /**
     * @notice Submit a redemption request. LST is locked until the queue is processed.
     * @param lstAmount The amount of LST to redeem.
     */
    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert AmountZero();
        if (lstBalance[msg.sender] < lstAmount) revert InsufficientBalance();

        // Lock LST into the contract
        lstBalance[msg.sender] -= lstAmount;
        lstBalance[address(this)] += lstAmount;

        uint256 queueIndex = redemptionQueue.length;
        redemptionQueue.push(RedemptionRequest({
            user: msg.sender,
            lstAmount: lstAmount
        }));

        emit Transfer(msg.sender, address(this), lstAmount);
        emit RedemptionRequested(msg.sender, lstAmount, queueIndex);
    }

    /**
     * @notice Process up to MAX_REDEMPTIONS_PER_BLOCK pending redemption requests.
     *         Anyone may call this function. Processing stops early if the contract
     *         lacks sufficient base asset liquidity. All state updates occur before
     *         any external token transfers (checks-effects-interactions).
     */
    function processRedemptionQueue() external nonReentrant {
        if (redemptionQueueHead >= redemptionQueue.length) revert NoPendingRedemptions();

        if (block.number != lastProcessedBlock) {
            lastProcessedBlock = block.number;
            processedThisBlock = 0;
        }

        uint256 remaining = MAX_REDEMPTIONS_PER_BLOCK - processedThisBlock;
        if (remaining == 0) revert MaxRedemptionsReached();

        uint256 queueLength = redemptionQueue.length;
        uint256 contractBalance = availableBaseAsset();

        // Determine how many requests we can attempt
        uint256 available = queueLength - redemptionQueueHead;
        uint256 maxAttempt = remaining < available ? remaining : available;

        // Memory arrays to store payout details for the interaction phase
        address[] memory users = new address[](maxAttempt);
        uint256[] memory payouts = new uint256[](maxAttempt);
        uint256[] memory fees = new uint256[](maxAttempt);
        uint256[] memory lstAmounts = new uint256[](maxAttempt);
        uint256 processed = 0;

        // -------------------------------------------------------------------
        // Effects phase: update all state before any external calls
        // -------------------------------------------------------------------
        while (processed < maxAttempt) {
            RedemptionRequest storage request = redemptionQueue[redemptionQueueHead];
            uint256 lstAmount = request.lstAmount;
            address user = request.user;

            // Safety: totalLSTSupply must be > 0 for exchange rate calculation
            if (totalLSTSupply < 1) break;

            // Calculate base asset payout and fee.
            // Multiply before dividing to avoid precision loss (divide-before-multiply).
            uint256 baseAssetAmount = (lstAmount * totalBaseAssetStaked) / totalLSTSupply;
            uint256 fee = (lstAmount * totalBaseAssetStaked * FEE_BPS) / (totalLSTSupply * BPS_DENOMINATOR);
            uint256 payout = baseAssetAmount - fee;

            // Stop if insufficient liquidity
            if (contractBalance < baseAssetAmount) break;

            // Update state (effects)
            lstBalance[address(this)] -= lstAmount;
            totalLSTSupply -= lstAmount;
            totalBaseAssetStaked -= baseAssetAmount;
            contractBalance -= baseAssetAmount;

            redemptionQueueHead++;

            // Store payout details for interaction phase
            users[processed] = user;
            payouts[processed] = payout;
            fees[processed] = fee;
            lstAmounts[processed] = lstAmount;
            processed++;
        }

        processedThisBlock += processed;

        // Cleanup when the queue is fully drained
        if (redemptionQueueHead >= redemptionQueue.length && redemptionQueue.length > 0) {
            delete redemptionQueue;
            redemptionQueueHead = 0;
        }

        // -------------------------------------------------------------------
        // Interactions phase: transfer base asset to users and fee recipient
        // -------------------------------------------------------------------
        for (uint256 i = 0; i < processed; i++) {
            if (payouts[i] > 0) {
                if (!baseAsset.transfer(users[i], payouts[i])) revert TransferFailed();
            }
            if (fees[i] > 0) {
                if (!baseAsset.transfer(feeRecipient, fees[i])) revert TransferFailed();
            }

            emit Transfer(address(this), address(0), lstAmounts[i]);
            emit Redeemed(users[i], lstAmounts[i], payouts[i], fees[i]);
        }
    }

    // -----------------------------------------------------------------------
    // LST ERC-20 style transfers
    // -----------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, lstAllowance[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = lstAllowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (lstBalance[from] < amount) revert InsufficientBalance();

        lstBalance[from] -= amount;
        lstBalance[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();

        lstAllowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 currentAllowance = lstAllowance[owner_][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            lstAllowance[owner_][spender] = currentAllowance - amount;
        }
    }

    // -----------------------------------------------------------------------
    // Operator: staking with external validator set
    // -----------------------------------------------------------------------

    /**
     * @notice Stake base asset with the external validator set.
     * @param amount The amount of base asset to stake.
     */
    function stakeWithValidators(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert AmountZero();
        if (availableBaseAsset() < amount) revert InsufficientBaseAsset();

        // Effects before interactions
        stakedWithValidators += amount;

        if (!baseAsset.transfer(address(validatorSet), amount)) revert TransferFailed();
        validatorSet.stake(amount);

        emit StakedWithValidator(amount);
    }

    /**
     * @notice Unstake base asset from the external validator set.
     * @param amount The amount to unstake.
     */
    function unstakeFromValidators(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert AmountZero();
        if (stakedWithValidators < amount) revert InsufficientBalance();

        // Effects before interactions: reduce staked amount first
        stakedWithValidators -= amount;

        // Interaction: call validator set and use the returned amount
        uint256 returned = validatorSet.unstake(amount);

        // Account for potential slashing: if less is returned, reduce total backing
        if (returned < amount) {
            totalBaseAssetStaked -= (amount - returned);
        }

        emit UnstakedFromValidator(amount, returned);
    }

    /**
     * @notice Claim staking rewards from the external validator set.
     *         Rewards increase totalBaseAssetStaked, raising the exchange rate.
     */
    function claimRewards() external onlyOperator nonReentrant {
        // Interaction: claim rewards and use the returned value
        uint256 rewards = validatorSet.claimRewards();

        // Effects: increase total backing by claimed rewards
        if (rewards > 0) {
            totalBaseAssetStaked += rewards;
        }

        emit RewardsClaimed(rewards);
    }

    // -----------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function setValidatorSet(address newValidatorSet) external onlyOwner {
        if (newValidatorSet == address(0)) revert ZeroAddress();
        emit ValidatorSetChanged(address(validatorSet), newValidatorSet);
        validatorSet = IValidatorSet(newValidatorSet);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
