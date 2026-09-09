// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStaking {
    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error ErrZeroAddress();
    error ErrInsufficientDeposit();
    error ErrInsufficientBalance();
    error ErrInsufficientAllowance();
    error ErrZeroAmount();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrInvalidFeeRate();
    error ErrNoRewardsToClaim();
    error ErrReentrancy();
    error ErrTransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed staker, uint256 nativeAmount, uint256 lstMinted);
    event Withdraw(address indexed staker, uint256 lstBurned, uint256 nativeAmount);
    event RewardsClaimed(address indexed staker, uint256 rewardAmount, uint256 lstBurned);
    event RewardsDistributed(uint256 totalReward, uint256 feeAmount, uint256 netReward);
    event ProtocolFeeWithdrawn(address indexed to, uint256 amount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 private constant RATE_SCALE = 1e18;
    uint256 private constant FEE_SCALE = 100; // percentage basis
    uint256 public constant MIN_DEPOSIT = 10 ether;
    uint256 public constant MAX_FEE_RATE = 100; // 100%

    // -----------------------------------------------------------------------
    // Token metadata
    // -----------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // -----------------------------------------------------------------------
    // Access control
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;

    // -----------------------------------------------------------------------
    // Staking state
    // -----------------------------------------------------------------------
    uint256 public totalStaked;            // total native backing LST supply (excludes fees)
    uint256 public exchangeRate;           // native per LST, scaled by RATE_SCALE
    uint256 public protocolFeeRate;        // percentage (e.g. 5 == 5%)
    uint256 public accumulatedProtocolFee;  // native fees pending withdrawal by owner

    // -----------------------------------------------------------------------
    // ERC20 state
    // -----------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Principal tracking — native deposited per user (for reward calculation)
    // -----------------------------------------------------------------------
    mapping(address => uint256) public principal;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    bool private _locked;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ErrReentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ErrZeroAddress();
        owner = msg.sender;
        operator = _operator;
        name = _name;
        symbol = _symbol;
        exchangeRate = RATE_SCALE; // 1:1 initially
        protocolFeeRate = 5;       // 5% default
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRateUpdated(0, 5);
    }

    // -----------------------------------------------------------------------
    // ERC20 — external
    // -----------------------------------------------------------------------
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
        if (allowed < amount) revert ErrInsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // ERC20 — internal
    // -----------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert ErrInsufficientBalance();

        // Move principal proportionally with the token transfer so that
        // reward accounting remains consistent for both sender and receiver.
        // Initialize explicitly to avoid uninitialized-local warnings.
        uint256 principalMoved = 0;
        if (fromBal > 0) {
            principalMoved = (principal[from] * amount) / fromBal;
        }

        balanceOf[from] = fromBal - amount;
        balanceOf[to] += amount;
        principal[from] -= principalMoved;
        principal[to] += principalMoved;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ErrZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert ErrInsufficientBalance();
        balanceOf[from] = fromBal - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Staking — deposit
    // -----------------------------------------------------------------------
    /// @notice Deposit native tokens and receive LST at the current exchange rate.
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert ErrInsufficientDeposit();

        uint256 lstToMint = (msg.value * RATE_SCALE) / exchangeRate;
        if (lstToMint == 0) revert ErrZeroAmount();

        principal[msg.sender] += msg.value;
        totalStaked += msg.value;
        _mint(msg.sender, lstToMint);

        emit Deposit(msg.sender, msg.value, lstToMint);
    }

    // -----------------------------------------------------------------------
    // Staking — withdraw
    // -----------------------------------------------------------------------
    /// @notice Burn LST to withdraw the corresponding native tokens at the current rate.
    function withdraw(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ErrZeroAmount();
        if (totalSupply == 0) revert ErrZeroAmount();

        uint256 userBal = balanceOf[msg.sender];
        if (userBal < lstAmount) revert ErrInsufficientBalance();

        uint256 nativeAmount = (lstAmount * exchangeRate) / RATE_SCALE;
        if (nativeAmount == 0) revert ErrZeroAmount();
        if (address(this).balance < nativeAmount) revert ErrInsufficientBalance();

        // Reduce principal proportionally to the fraction of LST being withdrawn.
        // Compute directly from LST balances to avoid divide-before-multiply:
        // principalToReduce / principal == lstAmount / userBal
        uint256 principalToReduce = (principal[msg.sender] * lstAmount) / userBal;
        if (principalToReduce > principal[msg.sender]) {
            principalToReduce = principal[msg.sender];
        }
        principal[msg.sender] -= principalToReduce;

        totalStaked -= nativeAmount;
        _burn(msg.sender, lstAmount);

        (bool ok, ) = payable(msg.sender).call{value: nativeAmount}("");
        if (!ok) revert ErrTransferFailed();

        emit Withdraw(msg.sender, lstAmount, nativeAmount);
    }

    // -----------------------------------------------------------------------
    // Staking — claim rewards
    // -----------------------------------------------------------------------
    /// @notice Claim accumulated staking rewards (excess value over principal) in native.
    function claimRewards() external nonReentrant {
        uint256 userBal = balanceOf[msg.sender];
        if (userBal == 0 || totalSupply == 0) revert ErrNoRewardsToClaim();

        uint256 userTotalValue = (userBal * exchangeRate) / RATE_SCALE;
        uint256 userPrincipal = principal[msg.sender];
        if (userTotalValue <= userPrincipal) revert ErrNoRewardsToClaim();

        uint256 rewardAmount = userTotalValue - userPrincipal;
        if (rewardAmount == 0) revert ErrNoRewardsToClaim();
        if (address(this).balance < rewardAmount) revert ErrInsufficientBalance();

        // Compute LST to burn without divide-before-multiply:
        // lstToBurn = userBal - (userPrincipal * RATE_SCALE) / exchangeRate
        uint256 principalInLST = (userPrincipal * RATE_SCALE) / exchangeRate;
        if (userBal <= principalInLST) revert ErrNoRewardsToClaim();
        uint256 lstToBurn = userBal - principalInLST;
        if (lstToBurn == 0) revert ErrNoRewardsToClaim();

        // Burning the reward-portion of LST keeps the exchange rate unchanged;
        // afterwards userTotalValue == userPrincipal, so no further rewards
        // can be claimed until new rewards are distributed.
        totalStaked -= rewardAmount;
        _burn(msg.sender, lstToBurn);

        (bool ok, ) = payable(msg.sender).call{value: rewardAmount}("");
        if (!ok) revert ErrTransferFailed();

        emit RewardsClaimed(msg.sender, rewardAmount, lstToBurn);
    }

    // -----------------------------------------------------------------------
    // Rewards distribution — operator only
    // -----------------------------------------------------------------------
    /// @notice Operator distributes staking rewards. A percentage is taken as
    ///         protocol fee; the remainder appreciates the exchange rate.
    function distributeRewards() external payable onlyOperator nonReentrant {
        if (msg.value == 0) revert ErrZeroAmount();

        uint256 fee = (msg.value * protocolFeeRate) / FEE_SCALE;
        uint256 netReward = msg.value - fee;

        accumulatedProtocolFee += fee;
        totalStaked += netReward;
        _updateExchangeRate();

        emit RewardsDistributed(msg.value, fee, netReward);
    }

    function _updateExchangeRate() internal {
        if (totalSupply == 0) {
            exchangeRate = RATE_SCALE;
            return;
        }
        uint256 newRate = (totalStaked * RATE_SCALE) / totalSupply;
        if (newRate == 0) revert ErrZeroAmount();
        exchangeRate = newRate;
    }

    // -----------------------------------------------------------------------
    // Admin — operator
    // -----------------------------------------------------------------------
    /// @notice Set the protocol fee rate (percentage, max 100).
    function setProtocolFeeRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_FEE_RATE) revert ErrInvalidFeeRate();
        uint256 prev = protocolFeeRate;
        protocolFeeRate = newRate;
        emit FeeRateUpdated(prev, newRate);
    }

    // -----------------------------------------------------------------------
    // Admin — owner
    // -----------------------------------------------------------------------
    /// @notice Set a new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    /// @notice Withdraw accumulated protocol fees in native tokens.
    function withdrawProtocolFee(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 amount = accumulatedProtocolFee;
        if (amount == 0) revert ErrZeroAmount();
        if (address(this).balance < amount) revert ErrInsufficientBalance();

        accumulatedProtocolFee = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert ErrTransferFailed();

        emit ProtocolFeeWithdrawn(to, amount);
    }

    /// @notice Transfer contract ownership.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    /// @notice Renounce ownership, leaving the contract without an owner.
    function renounceOwnership() external onlyOwner {
        address prev = owner;
        owner = address(0);
        emit OwnershipTransferred(prev, address(0));
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------
    /// @notice Current exchange rate (native per LST) scaled by 1e18.
    function getExchangeRate() external view returns (uint256) {
        if (totalSupply == 0) return RATE_SCALE;
        return (totalStaked * RATE_SCALE) / totalSupply;
    }

    /// @notice Pending staking rewards for a staker, in native tokens.
    function getPendingRewards(address staker) external view returns (uint256) {
        if (totalSupply == 0 || balanceOf[staker] == 0) return 0;
        uint256 userTotalValue = (balanceOf[staker] * exchangeRate) / RATE_SCALE;
        uint256 userPrincipal = principal[staker];
        if (userTotalValue <= userPrincipal) return 0;
        return userTotalValue - userPrincipal;
    }

    // -----------------------------------------------------------------------
    // Receive — reject accidental native transfers
    // -----------------------------------------------------------------------
    receive() external payable {
        revert("Use deposit() or distributeRewards()");
    }
}
