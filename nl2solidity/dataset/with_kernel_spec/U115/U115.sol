// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @notice Minimal ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @notice Wrappers around ERC20 operations that throw on failure.
 *         safeTransferFrom is intentionally omitted to avoid arbitrary-from
 *         vulnerabilities; callers must use transferFrom with msg.sender
 *         directly and validate the return value.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    error SafeERC20FailedOperation(address token);
}

/**
 * @title ReentrancyGuard
 * @notice Prevents reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    error ReentrantCall();
}

/**
 * @title Ownable
 * @notice Basic access control mechanism.
 */
abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableUnauthorizedAccount(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableUnauthorizedAccount(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title DecentralizedStablecoin
 * @notice Manages a decentralized stablecoin backed by a base asset reserve.
 *         Users mint synthetic tokens by depositing the base asset, redeem with
 *         a 0.5% fee, and stake to earn seigniorage rewards. An operator can
 *         adjust the peg ratio within a 1% band per 24 hours and trigger rebases.
 */
contract DecentralizedStablecoin is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientReserve();
    error PegDeviationExceeded();
    error CooldownActive();
    error NoStakers();
    error NotOperator();
    error TransferFromFailed();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    event Minted(address indexed account, uint256 baseDeposited, uint256 syntheticMinted);
    event Redeemed(address indexed account, uint256 syntheticBurned, uint256 baseWithdrawn, uint256 fee);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event SeigniorageDistributed(uint256 amount, uint256 newRewardIndex);
    event PegUpdated(uint256 oldPeg, uint256 newPeg);
    event Rebased(uint256 oldPeg, uint256 newPeg, uint256 timestamp);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeTreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant PEG_BASE = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_PEG_DEVIATION_BPS = 100; // 1%
    uint256 public constant PEG_COOLDOWN = 24 hours;
    uint256 public constant MIN_MINT_BASE_AMOUNT = 100; // 100 base units

    /*//////////////////////////////////////////////////////////////
                          STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable baseAsset;
    address public operator;
    address public feeTreasury;

    uint256 public pegRatio; // synthetic per base, scaled by 1e18
    uint256 public lastPegUpdate;

    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;

    uint256 public rewardIndex;
    mapping(address => uint256) public userRewardIndex;
    mapping(address => uint256) public pendingRewards;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _baseAsset, address _operator, address _feeTreasury)
        Ownable(msg.sender)
    {
        if (_baseAsset == address(0) || _operator == address(0) || _feeTreasury == address(0)) {
            revert ZeroAddress();
        }
        baseAsset = IERC20(_baseAsset);
        operator = _operator;
        feeTreasury = _feeTreasury;
        pegRatio = PEG_BASE;
        lastPegUpdate = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setFeeTreasury(address _feeTreasury) external onlyOwner {
        if (_feeTreasury == address(0)) revert ZeroAddress();
        emit FeeTreasuryChanged(feeTreasury, _feeTreasury);
        feeTreasury = _feeTreasury;
    }

    /*//////////////////////////////////////////////////////////////
                         MINT & REDEEM
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint synthetic tokens by depositing base assets.
     * @param baseAmount Amount of base asset to deposit (minimum 100 base units).
     * @return syntheticAmount Amount of synthetic tokens minted.
     */
    function mint(uint256 baseAmount) external nonReentrant returns (uint256 syntheticAmount) {
        if (baseAmount < MIN_MINT_BASE_AMOUNT) revert InsufficientDeposit();

        syntheticAmount = (baseAmount * pegRatio) / PEG_BASE;
        if (syntheticAmount == 0) revert InsufficientDeposit();

        // Use msg.sender directly as the `from` parameter to avoid
        // arbitrary-send-erc20 vulnerability.
        bool success = baseAsset.transferFrom(msg.sender, address(this), baseAmount);
        if (!success) revert TransferFromFailed();

        balances[msg.sender] += syntheticAmount;
        totalSupply += syntheticAmount;

        emit Minted(msg.sender, baseAmount, syntheticAmount);
    }

    /**
     * @notice Redeem synthetic tokens for base assets with a 0.5% fee.
     * @param syntheticAmount Amount of synthetic tokens to burn.
     * @return baseWithdrawn Net base assets returned to the caller.
     */
    function redeem(uint256 syntheticAmount) external nonReentrant returns (uint256 baseWithdrawn) {
        if (syntheticAmount == 0) revert ZeroAmount();
        if (balances[msg.sender] < syntheticAmount) revert InsufficientBalance();

        // Compute fee directly from syntheticAmount to avoid divide-before-multiply.
        // fee = syntheticAmount * PEG_BASE * REDEMPTION_FEE_BPS / (pegRatio * BPS_DENOMINATOR)
        uint256 fee = (syntheticAmount * PEG_BASE * REDEMPTION_FEE_BPS) / (pegRatio * BPS_DENOMINATOR);
        // grossBase = syntheticAmount * PEG_BASE / pegRatio
        uint256 grossBase = (syntheticAmount * PEG_BASE) / pegRatio;
        baseWithdrawn = grossBase - fee;

        if (baseAsset.balanceOf(address(this)) < grossBase) revert InsufficientReserve();

        balances[msg.sender] -= syntheticAmount;
        totalSupply -= syntheticAmount;

        if (fee > 0) {
            baseAsset.safeTransfer(feeTreasury, fee);
        }
        baseAsset.safeTransfer(msg.sender, baseWithdrawn);

        emit Redeemed(msg.sender, syntheticAmount, baseWithdrawn, fee);
    }

    /*//////////////////////////////////////////////////////////////
                      STAKING & SEIGNIORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stake synthetic tokens to earn seigniorage rewards.
     * @param amount Amount of synthetic tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        _updateUserReward(msg.sender);

        balances[msg.sender] -= amount;
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake synthetic tokens, returning them to the caller's balance.
     * @param amount Amount of synthetic tokens to unstake.
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalances[msg.sender] < amount) revert InsufficientBalance();

        _updateUserReward(msg.sender);

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        balances[msg.sender] += amount;

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim all pending seigniorage rewards.
     */
    function claimRewards() external nonReentrant returns (uint256 reward) {
        _updateUserReward(msg.sender);
        reward = pendingRewards[msg.sender];
        if (reward == 0) revert ZeroAmount();

        pendingRewards[msg.sender] = 0;
        balances[msg.sender] += reward;
        totalSupply += reward;

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Distribute newly minted synthetic tokens to all stakers.
     * @param amount Amount of synthetic tokens to distribute as seigniorage.
     */
    function distributeSeigniorage(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalStaked == 0) revert NoStakers();

        rewardIndex += (amount * PEG_BASE) / totalStaked;

        emit SeigniorageDistributed(amount, rewardIndex);
    }

    /**
     * @notice View the total pending rewards for a user.
     */
    function getPendingRewards(address user) external view returns (uint256) {
        if (stakedBalances[user] == 0) return pendingRewards[user];
        uint256 pending = (stakedBalances[user] * (rewardIndex - userRewardIndex[user])) / PEG_BASE;
        return pendingRewards[user] + pending;
    }

    function _updateUserReward(address user) internal {
        if (stakedBalances[user] == 0) {
            userRewardIndex[user] = rewardIndex;
            return;
        }
        uint256 pending = (stakedBalances[user] * (rewardIndex - userRewardIndex[user])) / PEG_BASE;
        pendingRewards[user] += pending;
        userRewardIndex[user] = rewardIndex;
    }

    /*//////////////////////////////////////////////////////////////
                         PEG MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adjust the peg ratio within a 1% band, once per 24 hours.
     * @param newPegRatio New peg ratio (scaled by 1e18).
     */
    function adjustPeg(uint256 newPegRatio) external onlyOperator {
        if (block.timestamp < lastPegUpdate + PEG_COOLDOWN) revert CooldownActive();

        uint256 maxPeg = (pegRatio * (BPS_DENOMINATOR + MAX_PEG_DEVIATION_BPS)) / BPS_DENOMINATOR;
        uint256 minPeg = (pegRatio * (BPS_DENOMINATOR - MAX_PEG_DEVIATION_BPS)) / BPS_DENOMINATOR;
        if (newPegRatio > maxPeg || newPegRatio < minPeg) revert PegDeviationExceeded();

        uint256 oldPeg = pegRatio;
        pegRatio = newPegRatio;
        lastPegUpdate = block.timestamp;

        emit PegUpdated(oldPeg, newPegRatio);
    }

    /**
     * @notice Trigger a system-wide rebase by setting a new peg ratio.
     * @param newPegRatio New peg ratio (scaled by 1e18).
     */
    function rebase(uint256 newPegRatio) external onlyOperator {
        if (newPegRatio == 0) revert ZeroAmount();

        uint256 oldPeg = pegRatio;
        pegRatio = newPegRatio;
        lastPegUpdate = block.timestamp;

        emit Rebased(oldPeg, newPegRatio, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                          SYNTH TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer synthetic tokens between accounts.
     */
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        balances[to] += amount;

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function baseReserve() external view returns (uint256) {
        return baseAsset.balanceOf(address(this));
    }

    function syntheticToBase(uint256 syntheticAmount) external view returns (uint256) {
        return (syntheticAmount * PEG_BASE) / pegRatio;
    }

    function baseToSynthetic(uint256 baseAmount) external view returns (uint256) {
        return (baseAmount * pegRatio) / PEG_BASE;
    }

    function stakedBalanceOf(address account) external view returns (uint256) {
        return stakedBalances[account];
    }
}
