// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedEthStaking {
    // ============ Constants ============
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant OPERATOR_CONTRIBUTION = 16 ether;
    uint256 public constant POOL_CONTRIBUTION = 16 ether;
    uint256 public constant BIPS = 10_000;
    uint256 public constant MAX_PROTOCOL_FEE_BIPS = 2_000;
    uint256 public constant OPERATOR_REWARD_BIPS = 1_000;
    uint256 public constant PUBKEY_LENGTH = 48;

    string public constant name = "Decentralized Liquid Staked Ether";
    string public constant symbol = "dlsETH";
    uint8 public constant decimals = 18;

    // ============ Custom Errors ============
    error NotOwner();
    error NotOracleOrOwner();
    error NotOperatorOrOwner();
    error ReentrantCall();
    error DepositsPaused();
    error DepositTooSmall();
    error ZeroAddress();
    error OperatorAlreadyRegistered();
    error OperatorNotActive();
    error NotOperator();
    error InvalidPubkeyLength();
    error InsufficientAvailableEth();
    error InvalidOperatorDeposit();
    error ValidatorNotFound();
    error ValidatorNotActive();
    error NotEnoughShares();
    error InsufficientAllowance();
    error ZeroAmount();
    error NoUnclaimedRewards();
    error NoUnlockedPrincipal();
    error InvalidProtocolFee();
    error TransferFailed();
    error AmountMismatch();
    error NoProtocolFeesAccrued();
    error DirectEthNotAccepted();

    // ============ Events ============
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Deposit(address indexed user, uint256 ethAmount, uint256 sharesMinted);
    event Withdrawal(address indexed user, uint256 sharesBurned, uint256 ethAmount);
    event ValidatorCreated(
        uint256 indexed validatorId,
        uint256 indexed operatorId,
        bytes pubkey,
        uint256 operatorEth,
        uint256 poolEth
    );
    event ValidatorExited(uint256 indexed validatorId, uint256 indexed operatorId);
    event ProtocolFeeUpdated(uint256 oldFeeBips, uint256 newFeeBips);
    event DepositsPausedChanged(bool paused);
    event ExchangeRateOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event NodeOperatorRegistered(uint256 indexed operatorId, address operator, address rewardsRecipient);
    event NodeOperatorDeposit(uint256 indexed operatorId, uint256 indexed validatorId, uint256 amount);
    event RewardsReported(
        uint256 indexed validatorId,
        uint256 indexed operatorId,
        uint256 amount,
        uint256 protocolFee,
        uint256 operatorReward,
        uint256 stakerReward
    );
    event OperatorRewardsClaimed(uint256 indexed operatorId, address indexed recipient, uint256 amount);
    event OperatorPrincipalWithdrawn(uint256 indexed operatorId, address indexed recipient, uint256 amount);
    event ProtocolFeeWithdrawn(address indexed recipient, uint256 amount);
    event RewardsRecipientUpdated(uint256 indexed operatorId, address recipient);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // ============ Enums ============
    enum ValidatorState {
        Pending,
        Active,
        Exited,
        Slashed
    }

    // ============ Structs ============
    struct NodeOperator {
        bool active;
        address payable operatorAddress;
        address payable rewardsRecipient;
        uint64 activeValidators;
        uint64 exitedValidators;
        uint256 lockedPrincipal;
        uint256 unlockedPrincipal;
        uint256 unclaimedRewards;
        uint256 claimedRewards;
    }

    struct Validator {
        uint64 operatorId;
        ValidatorState state;
        bytes pubkey;
        uint256 poolContribution;
        uint256 operatorContribution;
        uint256 rewardsAccrued;
        uint256 createdAt;
        uint256 exitedAt;
    }

    // ============ State Variables ============
    address public owner;
    address public exchangeRateOracle;
    bool public depositsPaused;
    uint256 public protocolFeeBips;

    uint256 public totalPooledEth;
    uint256 public totalShares;
    uint256 public availableEth;
    uint256 public stakedEth;
    uint256 public protocolFeeAccrued;

    mapping(address => uint256) public depositedEth;
    mapping(address => uint256) public shares;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public operatorCount;
    mapping(uint256 => NodeOperator) public operators;
    mapping(address => uint256) public operatorIdByAddress;

    uint256 public validatorCount;
    mapping(uint256 => Validator) public validators;

    uint256 private _reentrancyStatus;

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOracleOrOwner() {
        if (msg.sender != exchangeRateOracle && msg.sender != owner) revert NotOracleOrOwner();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(address _oracle, uint256 _protocolFeeBips) {
        if (_oracle == address(0)) revert ZeroAddress();
        if (_protocolFeeBips > MAX_PROTOCOL_FEE_BIPS) revert InvalidProtocolFee();
        owner = msg.sender;
        exchangeRateOracle = _oracle;
        protocolFeeBips = _protocolFeeBips;
        _reentrancyStatus = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit ExchangeRateOracleUpdated(address(0), _oracle);
        emit ProtocolFeeUpdated(0, _protocolFeeBips);
    }

    // ============ Receive ============
    receive() external payable {
        revert DirectEthNotAccepted();
    }

    // ============ User Staking Functions ============

    /// @notice Deposit ETH to receive liquid staking tokens (shares)
    function deposit() external payable whenDepositsNotPaused {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();

        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = msg.value;
        } else {
            sharesToMint = (msg.value * totalShares) / totalPooledEth;
        }
        if (sharesToMint == 0) revert ZeroAmount();

        _mint(msg.sender, sharesToMint);
        totalPooledEth += msg.value;
        availableEth += msg.value;
        depositedEth[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.value, sharesToMint);
    }

    /// @notice Burn liquid staking tokens to withdraw deposited ETH and accrued rewards
    function withdraw(uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert ZeroAmount();
        if (shares[msg.sender] < shareAmount) revert NotEnoughShares();
        if (totalShares == 0) revert NotEnoughShares();

        uint256 ethAmount = (shareAmount * totalPooledEth) / totalShares;
        if (ethAmount == 0) revert ZeroAmount();
        if (availableEth < ethAmount) revert InsufficientAvailableEth();

        totalPooledEth -= ethAmount;
        availableEth -= ethAmount;
        _burn(msg.sender, shareAmount);

        emit Withdrawal(msg.sender, shareAmount, ethAmount);

        (bool ok, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!ok) revert TransferFailed();
    }

    // ============ Node Operator Functions ============

    /// @notice Register as a node operator with a designated rewards recipient
    function registerNodeOperator(address payable rewardsRecipient) external {
        if (rewardsRecipient == address(0)) revert ZeroAddress();
        if (operatorIdByAddress[msg.sender] != 0) revert OperatorAlreadyRegistered();

        uint256 id = ++operatorCount;
        NodeOperator storage op = operators[id];
        op.active = true;
        op.operatorAddress = payable(msg.sender);
        op.rewardsRecipient = rewardsRecipient;
        operatorIdByAddress[msg.sender] = id;

        emit NodeOperatorRegistered(id, msg.sender, rewardsRecipient);
    }

    /// @notice Operator deposits exactly 16 ETH to create a validator, paired with 16 ETH from the pool
    function depositValidator(bytes calldata pubkey) external payable {
        uint256 operatorId = operatorIdByAddress[msg.sender];
        if (operatorId == 0) revert NotOperator();

        NodeOperator storage op = operators[operatorId];
        if (!op.active) revert OperatorNotActive();
        if (msg.value != OPERATOR_CONTRIBUTION) revert InvalidOperatorDeposit();
        if (pubkey.length != PUBKEY_LENGTH) revert InvalidPubkeyLength();
        if (availableEth < POOL_CONTRIBUTION) revert InsufficientAvailableEth();

        uint256 validatorId = ++validatorCount;
        Validator storage v = validators[validatorId];
        v.operatorId = uint64(operatorId);
        v.state = ValidatorState.Active;
        v.pubkey = pubkey;
        v.poolContribution = POOL_CONTRIBUTION;
        v.operatorContribution = OPERATOR_CONTRIBUTION;
        v.createdAt = block.timestamp;

        availableEth -= POOL_CONTRIBUTION;
        stakedEth += POOL_CONTRIBUTION;

        op.activeValidators += 1;
        op.lockedPrincipal += OPERATOR_CONTRIBUTION;

        emit NodeOperatorDeposit(operatorId, validatorId, msg.value);
        emit ValidatorCreated(validatorId, operatorId, pubkey, OPERATOR_CONTRIBUTION, POOL_CONTRIBUTION);
    }

    /// @notice Mark a validator as exited, releasing locked principal back to the operator
    function exitValidator(uint256 validatorId) external {
        Validator storage v = validators[validatorId];
        if (v.operatorId == 0) revert ValidatorNotFound();
        if (v.state != ValidatorState.Active) revert ValidatorNotActive();

        uint256 operatorId = uint256(v.operatorId);
        bool isOwnerCaller = msg.sender == owner;
        bool isOperator = operatorIdByAddress[msg.sender] == operatorId;
        if (!isOwnerCaller && !isOperator) revert NotOperatorOrOwner();

        v.state = ValidatorState.Exited;
        v.exitedAt = block.timestamp;

        stakedEth -= POOL_CONTRIBUTION;
        availableEth += POOL_CONTRIBUTION;

        NodeOperator storage op = operators[operatorId];
        op.activeValidators -= 1;
        op.exitedValidators += 1;
        op.lockedPrincipal -= OPERATOR_CONTRIBUTION;
        op.unlockedPrincipal += OPERATOR_CONTRIBUTION;

        emit ValidatorExited(validatorId, operatorId);
    }

    /// @notice Operator claims accumulated rewards to their designated rewards recipient
    function claimOperatorRewards() external nonReentrant {
        uint256 operatorId = operatorIdByAddress[msg.sender];
        if (operatorId == 0) revert NotOperator();

        NodeOperator storage op = operators[operatorId];
        uint256 amount = op.unclaimedRewards;
        if (amount == 0) revert NoUnclaimedRewards();

        op.unclaimedRewards = 0;
        op.claimedRewards += amount;

        address payable recipient = op.rewardsRecipient;
        emit OperatorRewardsClaimed(operatorId, recipient, amount);

        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Operator withdraws unlocked principal after their validator has exited
    function withdrawOperatorPrincipal(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 operatorId = operatorIdByAddress[msg.sender];
        if (operatorId == 0) revert NotOperator();

        NodeOperator storage op = operators[operatorId];
        if (amount > op.unlockedPrincipal) revert NoUnlockedPrincipal();

        op.unlockedPrincipal -= amount;

        address payable recipient = op.operatorAddress;
        emit OperatorPrincipalWithdrawn(operatorId, recipient, amount);

        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Operator updates their rewards recipient address
    function setRewardsRecipient(address payable recipient) external {
        uint256 operatorId = operatorIdByAddress[msg.sender];
        if (operatorId == 0) revert NotOperator();
        if (recipient == address(0)) revert ZeroAddress();

        operators[operatorId].rewardsRecipient = recipient;
        emit RewardsRecipientUpdated(operatorId, recipient);
    }

    // ============ Oracle / Owner Reward Reporting ============

    /// @notice Oracle or owner reports staking rewards for a specific validator, distributing them among protocol, operator, and stakers
    function reportValidatorRewards(uint256 validatorId, uint256 amount)
        external
        payable
        onlyOracleOrOwner
    {
        if (amount == 0) revert ZeroAmount();
        if (msg.value != amount) revert AmountMismatch();

        Validator storage v = validators[validatorId];
        if (v.operatorId == 0) revert ValidatorNotFound();
        if (v.state != ValidatorState.Active) revert ValidatorNotActive();

        uint256 fee = (amount * protocolFeeBips) / BIPS;
        uint256 operatorReward = (amount * OPERATOR_REWARD_BIPS) / BIPS;
        uint256 stakerReward = amount - fee - operatorReward;

        protocolFeeAccrued += fee;

        uint256 operatorId = uint256(v.operatorId);
        NodeOperator storage op = operators[operatorId];
        op.unclaimedRewards += operatorReward;

        totalPooledEth += stakerReward;
        availableEth += stakerReward;

        v.rewardsAccrued += amount;

        emit RewardsReported(validatorId, operatorId, amount, fee, operatorReward, stakerReward);
    }

    // ============ Owner Administrative Functions ============

    /// @notice Owner withdraws accumulated protocol fees
    function claimProtocolFee(address payable recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = protocolFeeAccrued;
        if (amount == 0) revert NoProtocolFeesAccrued();

        protocolFeeAccrued = 0;
        emit ProtocolFeeWithdrawn(recipient, amount);

        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Owner sets the protocol fee in basis points (max 2000 = 20%)
    function setProtocolFee(uint256 newFeeBips) external onlyOwner {
        if (newFeeBips > MAX_PROTOCOL_FEE_BIPS) revert InvalidProtocolFee();
        emit ProtocolFeeUpdated(protocolFeeBips, newFeeBips);
        protocolFeeBips = newFeeBips;
    }

    /// @notice Owner pauses or unpauses user deposits
    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    /// @notice Owner updates the exchange rate oracle address
    function setExchangeRateOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        emit ExchangeRateOracleUpdated(exchangeRateOracle, newOracle);
        exchangeRateOracle = newOracle;
    }

    /// @notice Owner transfers contract ownership to a new address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ View Functions ============

    /// @notice Current exchange rate: how much ETH one share is worth (1e18 scaled)
    function exchangeRate() public view returns (uint256) {
        if (totalShares == 0) return 1 ether;
        return (totalPooledEth * 1e18) / totalShares;
    }

    /// @notice Returns the ETH value of a user's share balance
    function userEthValue(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[user] * totalPooledEth) / totalShares;
    }

    /// @notice Total supply of liquid staking tokens
    function totalSupply() external view returns (uint256) {
        return totalShares;
    }

    /// @notice Balance of liquid staking tokens for a given account
    function balanceOf(address account) external view returns (uint256) {
        return shares[account];
    }

    /// @notice Returns the number of validators created
    function validatorCountView() external view returns (uint256) {
        return validatorCount;
    }

    /// @notice Returns the number of registered node operators
    function operatorCountView() external view returns (uint256) {
        return operatorCount;
    }

    // ============ ERC20 Transfer Functions ============

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
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    // ============ Internal Functions ============

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = shares[from];
        if (amount > fromBalance) revert NotEnoughShares();

        if (from != to) {
            shares[from] = fromBalance - amount;
            shares[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalShares += amount;
        shares[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 balance = shares[from];
        if (amount > balance) revert NotEnoughShares();
        shares[from] = balance - amount;
        totalShares -= amount;
        emit Transfer(from, address(0), amount);
    }
}
