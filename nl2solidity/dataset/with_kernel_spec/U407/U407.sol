// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ReserveBackedStable {
    // ============ Stable asset (ERC20) ============
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============ Access control ============
    address public admin;
    mapping(address => bool) public isOperator;

    // ============ Reentrancy guard ============
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Reserve / governance ============
    IERC20 public immutable governanceToken;
    uint256 public mintRate;
    uint256 public constant MAX_MINT_RATE = 1000e18;
    uint256 public constant UNSTAKE_FEE_BPS = 50;
    uint256 private constant BPS_DENOM = 10000;

    mapping(address => bool) public approvedReserves;
    address[] public reserveList;
    mapping(address => uint256) public treasury;

    // ============ Staking ============
    mapping(address => uint256) public stakedBalance;
    uint256 public totalStaked;

    // ============ Rewards ============
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // ============ Errors ============
    error ZeroAddress();
    error ZeroAmount();
    error ReserveNotApproved();
    error ReserveAlreadyApproved();
    error MintRateExceeded();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientStake();
    error DurationCannotBeZero();
    error NotAdmin();
    error NotOperator();
    error ReentrantCall();
    error TransferFailed();
    error CannotRecover();

    // ============ Events ============
    event Minted(address indexed account, address indexed reserve, uint256 reserveAmount, uint256 minted);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount, uint256 fee);
    event ReserveAdded(address indexed reserve);
    event ReserveRemoved(address indexed reserve);
    event MintRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsDistributed(uint256 amount, uint256 duration);
    event RewardPaid(address indexed account, uint256 amount);
    event Recovered(address indexed token, address indexed to, uint256 amount);
    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event OperatorUpdated(address indexed operator, bool status);

    // ============ Modifiers ============
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateTime = _lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = _earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address admin_,
        address operator,
        address governance,
        string memory name_,
        string memory symbol_,
        uint256 initialMintRate
    ) {
        if (admin_ == address(0) || operator == address(0) || governance == address(0)) revert ZeroAddress();
        if (initialMintRate > MAX_MINT_RATE) revert MintRateExceeded();

        admin = admin_;
        isOperator[operator] = true;
        governanceToken = IERC20(governance);
        name = name_;
        symbol = symbol_;
        mintRate = initialMintRate;
        _status = _NOT_ENTERED;

        emit AdminUpdated(address(0), admin_);
        emit OperatorUpdated(operator, true);
        emit MintRateUpdated(0, initialMintRate);
    }

    // ============ Admin / operator management ============
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminUpdated(admin, newAdmin);
        admin = newAdmin;
    }

    function setOperator(address operator, bool status) external onlyAdmin {
        if (operator == address(0)) revert ZeroAddress();
        isOperator[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    // ============ Reserve management ============
    function addReserve(address reserve) external onlyOperator {
        if (reserve == address(0)) revert ZeroAddress();
        if (approvedReserves[reserve]) revert ReserveAlreadyApproved();
        approvedReserves[reserve] = true;
        reserveList.push(reserve);
        emit ReserveAdded(reserve);
    }

    function removeReserve(address reserve) external onlyOperator {
        if (!approvedReserves[reserve]) revert ReserveNotApproved();
        approvedReserves[reserve] = false;
        uint256 len = reserveList.length;
        for (uint256 i = 0; i < len; i++) {
            if (reserveList[i] == reserve) {
                reserveList[i] = reserveList[len - 1];
                reserveList.pop();
                break;
            }
        }
        emit ReserveRemoved(reserve);
    }

    function setMintRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_MINT_RATE) revert MintRateExceeded();
        uint256 old = mintRate;
        mintRate = newRate;
        emit MintRateUpdated(old, newRate);
    }

    function distributeRewards(uint256 amount, uint256 duration)
        external
        onlyOperator
        updateReward(address(0))
        nonReentrant
    {
        if (amount == 0 || duration == 0) revert DurationCannotBeZero();

        // Effects: compute new reward parameters before the external interaction.
        uint256 leftover = 0;
        if (block.timestamp < periodFinish) {
            leftover = rewardRate * (periodFinish - block.timestamp);
        }
        rewardRate = (amount + leftover) / duration;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        // Interaction: pull reward tokens from the operator.
        _safeTransferFrom(governanceToken, msg.sender, address(this), amount);

        emit RewardsDistributed(amount, duration);
    }

    // ============ User operations ============
    function deposit(address reserve, uint256 reserveAmount) external nonReentrant {
        if (!approvedReserves[reserve]) revert ReserveNotApproved();
        if (reserveAmount == 0) revert ZeroAmount();

        // Interaction: transfer reserve tokens in. Standard ERC20 transfers move
        // the exact requested amount, so `reserveAmount` is the received amount.
        IERC20 token = IERC20(reserve);
        _safeTransferFrom(token, msg.sender, address(this), reserveAmount);

        // Effects: update treasury and mint stable asset after the transfer.
        treasury[reserve] += reserveAmount;
        uint256 mintAmount = (reserveAmount * mintRate) / 1e18;
        if (mintAmount < 1) revert ZeroAmount();

        _mint(msg.sender, mintAmount);
        emit Minted(msg.sender, reserve, reserveAmount, mintAmount);
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        uint256 fee = (amount * UNSTAKE_FEE_BPS) / BPS_DENOM;
        uint256 toReturn = amount - fee;

        _transfer(address(this), msg.sender, toReturn);
        if (fee > 0) {
            _burn(address(this), fee);
        }
        emit Unstaked(msg.sender, amount, fee);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        if (reward > 0) {
            _safeTransfer(governanceToken, msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // ============ Admin: recover ============
    function recover(address token, address to, uint256 amount) external onlyAdmin {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (approvedReserves[token] || token == address(governanceToken)) revert CannotRecover();
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientBalance();
        _safeTransfer(IERC20(token), to, amount);
        emit Recovered(token, to, amount);
    }

    // ============ Views ============
    function reserveCount() external view returns (uint256) {
        return reserveList.length;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _lastTimeRewardApplicable();
    }

    function rewardPerToken() public view returns (uint256) {
        return _rewardPerToken();
    }

    function earned(address account) public view returns (uint256) {
        return _earned(account);
    }

    function _lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function _rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((_lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) /
            totalStaked;
    }

    function _earned(address account) internal view returns (uint256) {
        return
            (stakedBalance[account] * (_rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    // ============ ERC20 internal ============
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        unchecked {
            balanceOf[to] += value;
        }
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - value;
            totalSupply -= value;
        }
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner_, address spender, uint256 value) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }

    // ============ ERC20 public ============
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - value;
            }
        }
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    // ============ Safe ERC20 helpers ============
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
