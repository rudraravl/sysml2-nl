// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract SyntheticAsset {
    error NotAuthorized();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ReserveRatioViolation();
    error InvalidPrice();
    error InvalidReserveRatio();
    error NothingToClaim();
    error AlreadyStaked();
    error NotStaked();
    error TransferFailed();
    error DustAmount();

    event Mint(address indexed account, uint256 underlyingDeposited, uint256 syntheticMinted, uint256 fee, uint256 newTotalSupply);
    event Burn(address indexed account, uint256 syntheticBurned, uint256 underlyingReturned, uint256 fee, uint256 newTotalSupply);
    event OraclePriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event ReserveRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event RewardsAdded(uint256 amount, uint256 newRewardRate);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_RESERVE_RATIO = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 private constant SHARE_PRECISION = 1e18;
    uint256 public constant MIN_SYNTHETIC_MINT = 1e6;
    uint256 public constant MIN_REWARD_CLAIM = 1e6;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable underlying;
    uint256 public reserveBalance;
    uint256 public oraclePrice;
    uint256 public reserveRatio;

    address public owner;
    address public operator;

    uint256 public accumulatedFees;

    struct Staker {
        uint256 amount;
        uint256 rewardDebt;
    }
    mapping(address => Staker) public stakers;
    uint256 public totalStaked;

    uint256 public rewardRate;
    uint256 public lastRewardUpdate;
    uint256 public accRewardPerShare;

    IERC20 public immutable rewardToken;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _underlying,
        address _rewardToken,
        string memory _name,
        string memory _symbol,
        uint256 _initialPrice,
        uint256 _initialReserveRatio
    ) {
        if (_underlying == address(0) || _rewardToken == address(0)) revert ZeroAddress();
        if (_initialPrice == 0) revert InvalidPrice();
        if (_initialReserveRatio < MIN_RESERVE_RATIO) revert InvalidReserveRatio();

        underlying = IERC20(_underlying);
        rewardToken = IERC20(_rewardToken);
        name = _name;
        symbol = _symbol;
        oraclePrice = _initialPrice;
        reserveRatio = _initialReserveRatio;
        owner = msg.sender;
        operator = msg.sender;
        lastRewardUpdate = block.timestamp;

        emit OraclePriceUpdated(0, _initialPrice, block.timestamp);
        emit ReserveRatioUpdated(0, _initialReserveRatio);
        emit OperatorUpdated(address(0), msg.sender);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

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
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function totalSyntheticValue() public view returns (uint256) {
        return (totalSupply * oraclePrice) / PRICE_PRECISION;
    }

    function requiredReserve() public view returns (uint256) {
        return (totalSyntheticValue() * reserveRatio) / BPS_DENOMINATOR;
    }

    function _checkReserveRatio() internal view {
        if (reserveBalance < requiredReserve()) revert ReserveRatioViolation();
    }

    function mint(uint256 underlyingAmount) external nonReentrant {
        if (underlyingAmount == 0) revert AmountZero();

        // Compute fee, net deposit and synthetic amount from the requested amount
        // (standard ERC20 transfers the exact amount; avoids balance-before/after pattern).
        uint256 fee = (underlyingAmount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netDeposit = underlyingAmount - fee;

        uint256 syntheticToMint = (netDeposit * PRICE_PRECISION) / oraclePrice;
        if (syntheticToMint < MIN_SYNTHETIC_MINT) revert DustAmount();

        // Effects: update state before external transfer (checks-effects-interactions).
        reserveBalance += netDeposit;
        accumulatedFees += fee;

        unchecked {
            totalSupply += syntheticToMint;
            balanceOf[msg.sender] += syntheticToMint;
        }
        emit Transfer(address(0), msg.sender, syntheticToMint);

        _checkReserveRatio();

        // Interactions: pull underlying asset from minter.
        bool ok = underlying.transferFrom(msg.sender, address(this), underlyingAmount);
        if (!ok) revert TransferFailed();

        emit Mint(msg.sender, underlyingAmount, syntheticToMint, fee, totalSupply);
    }

    function burn(uint256 syntheticAmount) external nonReentrant {
        if (syntheticAmount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < syntheticAmount) revert InsufficientBalance();

        // Compute gross return and fee using full-precision numerator to avoid
        // divide-before-multiply rounding issues.
        uint256 numerator = syntheticAmount * oraclePrice;
        uint256 grossReturn = numerator / PRICE_PRECISION;
        if (grossReturn < MIN_SYNTHETIC_MINT) revert DustAmount();

        uint256 fee = (numerator * FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR);
        uint256 netReturn = grossReturn - fee;

        if (reserveBalance < netReturn) revert InsufficientBalance();

        // Effects: burn synthetic tokens and update reserve before external transfer.
        unchecked {
            balanceOf[msg.sender] -= syntheticAmount;
            totalSupply -= syntheticAmount;
        }
        emit Transfer(msg.sender, address(0), syntheticAmount);

        reserveBalance -= netReturn;
        accumulatedFees += fee;

        _checkReserveRatio();

        // Interactions: return underlying asset to burner.
        bool ok = underlying.transfer(msg.sender, netReturn);
        if (!ok) revert TransferFailed();

        emit Burn(msg.sender, syntheticAmount, netReturn, fee, totalSupply);
    }

    function updateOraclePrice(uint256 newPrice) external onlyOperator nonReentrant {
        if (newPrice == 0) revert InvalidPrice();
        uint256 oldPrice = oraclePrice;
        oraclePrice = newPrice;
        _checkReserveRatio();
        emit OraclePriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    function updateReserveRatio(uint256 newRatio) external onlyOperator nonReentrant {
        if (newRatio < MIN_RESERVE_RATIO) revert InvalidReserveRatio();
        uint256 oldRatio = reserveRatio;
        reserveRatio = newRatio;
        _checkReserveRatio();
        emit ReserveRatioUpdated(oldRatio, newRatio);
    }

    function withdrawFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert AmountZero();
        accumulatedFees = 0;
        bool ok = underlying.transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function _updateRewards() internal {
        if (totalStaked == 0) {
            lastRewardUpdate = block.timestamp;
            return;
        }
        if (block.timestamp <= lastRewardUpdate) return;
        uint256 elapsed = block.timestamp - lastRewardUpdate;
        uint256 newRewards = elapsed * rewardRate;
        accRewardPerShare += (newRewards * SHARE_PRECISION) / totalStaked;
        lastRewardUpdate = block.timestamp;
    }

    function addRewards(uint256 amount, uint256 durationSeconds) external onlyOwner nonReentrant {
        if (amount == 0 || durationSeconds == 0) revert AmountZero();
        uint256 balBefore = rewardToken.balanceOf(address(this));
        bool ok = rewardToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        uint256 received = rewardToken.balanceOf(address(this)) - balBefore;
        if (received < amount) revert InsufficientAllowance();

        _updateRewards();
        rewardRate = received / durationSeconds;
        lastRewardUpdate = block.timestamp;
        emit RewardsAdded(received, rewardRate);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        if (stakers[msg.sender].amount > 0) revert AlreadyStaked();

        _updateRewards();

        unchecked {
            balanceOf[msg.sender] -= amount;
        }
        totalStaked += amount;

        stakers[msg.sender] = Staker({
            amount: amount,
            rewardDebt: (amount * accRewardPerShare) / SHARE_PRECISION
        });

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        Staker storage s = stakers[msg.sender];
        if (s.amount == 0) revert NotStaked();

        _updateRewards();

        uint256 pending = (s.amount * accRewardPerShare) / SHARE_PRECISION - s.rewardDebt;
        uint256 stakedAmount = s.amount;

        totalStaked -= stakedAmount;
        delete stakers[msg.sender];

        unchecked {
            balanceOf[msg.sender] += stakedAmount;
        }

        if (pending >= MIN_REWARD_CLAIM) {
            bool ok = rewardToken.transfer(msg.sender, pending);
            if (!ok) revert TransferFailed();
            emit RewardsClaimed(msg.sender, pending);
        }

        emit Unstaked(msg.sender, stakedAmount);
    }

    function claimRewards() external nonReentrant {
        Staker storage s = stakers[msg.sender];
        if (s.amount == 0) revert NotStaked();

        _updateRewards();

        uint256 pending = (s.amount * accRewardPerShare) / SHARE_PRECISION - s.rewardDebt;
        if (pending < MIN_REWARD_CLAIM) revert NothingToClaim();

        s.rewardDebt = (s.amount * accRewardPerShare) / SHARE_PRECISION;

        bool ok = rewardToken.transfer(msg.sender, pending);
        if (!ok) revert TransferFailed();

        emit RewardsClaimed(msg.sender, pending);
    }

    function pendingRewards(address account) external view returns (uint256) {
        Staker storage s = stakers[account];
        if (s.amount == 0) return 0;
        uint256 elapsed = block.timestamp > lastRewardUpdate ? block.timestamp - lastRewardUpdate : 0;
        uint256 currentAcc = accRewardPerShare;
        if (totalStaked > 0 && elapsed > 0) {
            currentAcc += (elapsed * rewardRate * SHARE_PRECISION) / totalStaked;
        }
        return (s.amount * currentAcc) / SHARE_PRECISION - s.rewardDebt;
    }

    function reserveRatioStatus() external view returns (uint256 currentRatioBps, uint256 required, uint256 actual) {
        required = requiredReserve();
        actual = reserveBalance;
        if (totalSyntheticValue() == 0) {
            currentRatioBps = BPS_DENOMINATOR;
        } else {
            currentRatioBps = (reserveBalance * BPS_DENOMINATOR) / totalSyntheticValue();
        }
    }
}
