// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success;
        bytes memory data;
        (success, data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success;
        bytes memory data;
        (success, data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_msgSender() != _owner) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract ERC20 is Context {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidSpender(address spender);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view virtual returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address owner_ = _msgSender();
        _transfer(owner_, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address owner_ = _msgSender();
        if (spender == address(0)) revert ERC20InvalidSpender(spender);
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);
        _update(from, to, amount);
    }

    function _update(address from, address to, uint256 amount) internal virtual {
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert ERC20InsufficientBalance(from, fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(account);
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert ERC20InsufficientBalance(account, accountBalance, amount);
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = _allowances[owner_][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            unchecked {
                _allowances[owner_][spender] = currentAllowance - amount;
            }
        }
    }
}

/**
 * @title ReserveCurrency
 * @notice A decentralized reserve currency protocol that custodies a basket of
 *         approved stablecoin assets. Users mint reserve tokens by depositing
 *         stablecoins, burn reserve tokens to redeem a proportional share of
 *         the treasury, and stake reserve tokens to earn rebase rewards.
 */
contract ReserveCurrency is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ////////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////////
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT_UNITS = 10; // 10 units in native decimals
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////
    error StablecoinNotApproved();
    error StablecoinAlreadyApproved();
    error StablecoinHasBalance();
    error BelowMinimumDeposit();
    error NoBacking();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientStakedBalance();
    error NoStakedTokens();
    error InvalidDecimals();
    error TransferFailed();
    error InsufficientEtherBalance();

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////
    event StablecoinAdded(address indexed token, uint8 decimals);
    event StablecoinRemoved(address indexed token);
    event Minted(address indexed user, address indexed stablecoin, uint256 amountDeposited, uint256 reserveTokensMinted);
    event Burned(address indexed user, uint256 reserveTokensBurned, uint256 totalRedeemed18);
    event StablecoinRedeemed(address indexed user, address indexed stablecoin, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);
    event RebaseUpdated(uint256 newRebaseIndex, uint256 timestamp);
    event RebaseRateUpdated(uint256 oldRate, uint256 newRate);
    event BackingUpdated(uint256 totalSupply, uint256 backingPerToken);
    event TreasuryWithdrawal(address indexed token, uint256 amount, address indexed recipient);
    event EtherWithdrawal(address indexed recipient, uint256 amount);

    ////////////////////////////////////////////////////////////////////////////
    // Stablecoin registry
    ////////////////////////////////////////////////////////////////////////////
    mapping(address => bool) public isApprovedStablecoin;
    mapping(address => uint8) public stablecoinDecimals;
    mapping(address => uint256) public treasuryBalance; // in native decimals
    address[] private _approvedStablecoins;
    mapping(address => uint256) private _stablecoinIndex; // 1-based

    ////////////////////////////////////////////////////////////////////////////
    // Staking / Rebase
    ////////////////////////////////////////////////////////////////////////////
    uint256 public rebaseRate; // annual rate in basis points (e.g. 500 = 5%)
    uint256 public rebaseIndex; // starts at WAD (1e18)
    uint256 public lastRebase;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardIndex;

    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_, 18)
        Ownable(msg.sender)
    {
        rebaseIndex = WAD;
        lastRebase = block.timestamp;
        emit BackingUpdated(0, WAD);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Modifiers
    ////////////////////////////////////////////////////////////////////////////
    modifier stablecoinApproved(address token) {
        if (!isApprovedStablecoin[token]) revert StablecoinNotApproved();
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Decimal normalization
    ////////////////////////////////////////////////////////////////////////////
    function _to18(address token, uint256 amount) internal view returns (uint256) {
        uint8 dec = stablecoinDecimals[token];
        if (dec == 18) return amount;
        if (dec < 18) return amount * (10 ** (18 - dec));
        return amount / (10 ** (dec - 18));
    }

    ////////////////////////////////////////////////////////////////////////////
    // Treasury accounting
    ////////////////////////////////////////////////////////////////////////////
    function _getTotalValue18() internal view returns (uint256 total) {
        uint256 len = _approvedStablecoins.length;
        for (uint256 i = 0; i < len; ) {
            address token = _approvedStablecoins[i];
            total += _to18(token, treasuryBalance[token]);
            unchecked {
                ++i;
            }
        }
    }

    function _currentBackingPerToken() internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply < 1) return WAD;
        return (_getTotalValue18() * WAD) / supply;
    }

    function _updateBacking() internal {
        emit BackingUpdated(totalSupply(), _currentBackingPerToken());
    }

    ////////////////////////////////////////////////////////////////////////////
    // Rebase logic
    ////////////////////////////////////////////////////////////////////////////
    function _updateRebaseIndex() internal {
        uint256 timeElapsed = block.timestamp - lastRebase;
        if (timeElapsed < 1) return;
        lastRebase = block.timestamp;
        if (rebaseRate < 1) return;
        // Single expression: multiply before divide to avoid precision loss
        rebaseIndex = rebaseIndex + (rebaseIndex * rebaseRate * timeElapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        emit RebaseUpdated(rebaseIndex, lastRebase);
    }

    function _syncUserReward(address user) internal {
        _updateRebaseIndex();
        uint256 staked = stakedBalance[user];
        if (staked > 0) {
            uint256 currentIdx = rebaseIndex;
            uint256 userIdx = userRewardIndex[user];
            if (currentIdx > userIdx) {
                uint256 reward = (staked * (currentIdx - userIdx)) / WAD;
                if (reward > 0) {
                    _mint(user, reward);
                    emit RewardsClaimed(user, reward);
                    _updateBacking();
                }
            }
        }
        userRewardIndex[user] = rebaseIndex;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Mint
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Mint reserve tokens by depositing an approved stablecoin.
     * @param stablecoin Address of the approved stablecoin
     * @param amount     Amount to deposit (native decimals); must be >= 10 units
     */
    function mint(address stablecoin, uint256 amount)
        external
        nonReentrant
        stablecoinApproved(stablecoin)
    {
        if (amount < 1) revert ZeroAmount();
        uint8 dec = stablecoinDecimals[stablecoin];
        if (amount < MIN_DEPOSIT_UNITS * (10 ** dec)) revert BelowMinimumDeposit();

        uint256 normalizedDeposit = _to18(stablecoin, amount);
        uint256 supplyBefore = totalSupply();
        uint256 valueBefore = _getTotalValue18();

        uint256 mintAmount;
        if (supplyBefore < 1) {
            mintAmount = normalizedDeposit;
        } else {
            if (valueBefore < 1) revert NoBacking();
            mintAmount = (normalizedDeposit * supplyBefore) / valueBefore;
        }

        // Effects (CEI: update state before external calls)
        treasuryBalance[stablecoin] += amount;
        _mint(msg.sender, mintAmount);

        // Interactions
        IERC20(stablecoin).safeTransferFrom(msg.sender, address(this), amount);

        emit Minted(msg.sender, stablecoin, amount, mintAmount);
        _updateBacking();
    }

    ////////////////////////////////////////////////////////////////////////////
    // Burn / Redeem
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Burn reserve tokens and redeem a proportional share of all
     *         treasury stablecoins, minus a 0.5% redemption fee.
     * @param amount Amount of reserve tokens to burn
     */
    function burn(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        uint256 supplyBefore = totalSupply();
        uint256 valueBefore = _getTotalValue18();
        if (valueBefore < 1) revert NoBacking();

        // Effects: burn reserve tokens first
        _burn(msg.sender, amount);

        uint256 len = _approvedStablecoins.length;
        uint256[] memory nets = new uint256[](len);
        uint256 totalRedeemed18;

        // Compute and apply all state changes before any external calls
        for (uint256 i = 0; i < len; ) {
            address token = _approvedStablecoins[i];
            uint256 tokenBal = treasuryBalance[token];
            if (tokenBal > 0) {
                // Combined expression: net = tokenBal * amount * (1 - fee_bps) / (supplyBefore * BPS_DENOMINATOR)
                // Multiply before divide to avoid precision loss from intermediate division
                uint256 net = (tokenBal * amount * (BPS_DENOMINATOR - REDEMPTION_FEE_BPS)) /
                    (supplyBefore * BPS_DENOMINATOR);
                if (net > 0) {
                    treasuryBalance[token] -= net;
                    nets[i] = net;
                    totalRedeemed18 += _to18(token, net);
                }
            }
            unchecked {
                ++i;
            }
        }

        // Interactions: transfer stablecoins only after all state is settled
        for (uint256 i = 0; i < len; ) {
            if (nets[i] > 0) {
                address token = _approvedStablecoins[i];
                IERC20(token).safeTransfer(msg.sender, nets[i]);
                emit StablecoinRedeemed(msg.sender, token, nets[i]);
            }
            unchecked {
                ++i;
            }
        }

        emit Burned(msg.sender, amount, totalRedeemed18);
        _updateBacking();
    }

    ////////////////////////////////////////////////////////////////////////////
    // Staking
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Stake reserve tokens to earn rebase rewards.
     * @param amount Amount of reserve tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        _syncUserReward(msg.sender);

        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake reserve tokens and claim pending rewards.
     * @param amount Amount of reserve tokens to unstake
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStakedBalance();

        _syncUserReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim pending rebase rewards without unstaking.
     */
    function claimRewards() external nonReentrant {
        if (stakedBalance[msg.sender] < 1) revert NoStakedTokens();
        _syncUserReward(msg.sender);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner: stablecoin management
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Add a stablecoin to the approved basket.
     * @param token Address of the stablecoin ERC20
     */
    function addStablecoin(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isApprovedStablecoin[token]) revert StablecoinAlreadyApproved();

        uint8 dec = IERC20(token).decimals();
        if (dec > 18) revert InvalidDecimals();

        isApprovedStablecoin[token] = true;
        stablecoinDecimals[token] = dec;
        _stablecoinIndex[token] = _approvedStablecoins.length + 1;
        _approvedStablecoins.push(token);

        emit StablecoinAdded(token, dec);
    }

    /**
     * @notice Remove a stablecoin from the approved basket. Treasury must hold
     *         no balance of it.
     * @param token Address of the stablecoin to remove
     */
    function removeStablecoin(address token) external onlyOwner {
        if (!isApprovedStablecoin[token]) revert StablecoinNotApproved();
        if (treasuryBalance[token] > 0) revert StablecoinHasBalance();

        isApprovedStablecoin[token] = false;
        uint256 idx = _stablecoinIndex[token] - 1; // 0-based
        uint256 lastIdx = _approvedStablecoins.length - 1;
        if (idx != lastIdx) {
            address lastToken = _approvedStablecoins[lastIdx];
            _approvedStablecoins[idx] = lastToken;
            _stablecoinIndex[lastToken] = idx + 1;
        }
        _approvedStablecoins.pop();
        delete _stablecoinIndex[token];
        delete stablecoinDecimals[token];

        emit StablecoinRemoved(token);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner: rebase rate
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Set the annual rebase rate in basis points (e.g. 500 = 5% / year).
     * @param newRate New rebase rate in basis points
     */
    function setRebaseRate(uint256 newRate) external onlyOwner {
        _updateRebaseIndex();
        uint256 oldRate = rebaseRate;
        rebaseRate = newRate;
        emit RebaseRateUpdated(oldRate, newRate);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner: treasury operations
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Transfer stablecoin assets out of the treasury for protocol operations.
     * @param token     Approved stablecoin address
     * @param recipient Recipient of the assets
     * @param amount    Amount to withdraw (native decimals)
     */
    function withdrawTreasury(address token, address recipient, uint256 amount)
        external
        onlyOwner
        nonReentrant
        stablecoinApproved(token)
    {
        if (amount < 1) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (treasuryBalance[token] < amount) revert InsufficientBalance();

        treasuryBalance[token] -= amount;
        IERC20(token).safeTransfer(recipient, amount);

        emit TreasuryWithdrawal(token, amount, recipient);
        _updateBacking();
    }

    /**
     * @notice Withdraw any Ether held by the contract (e.g. from force-sends).
     * @param recipient Recipient of the Ether
     * @param amount    Amount of Ether to withdraw
     */
    function withdrawEther(address payable recipient, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < 1) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientEtherBalance();

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EtherWithdrawal(recipient, amount);
    }

    ////////////////////////////////////////////////////////////////////////////
    // View functions
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Returns the list of approved stablecoin addresses.
     */
    function getApprovedStablecoins() external view returns (address[] memory) {
        return _approvedStablecoins;
    }

    /**
     * @notice Returns the number of approved stablecoins.
     */
    function approvedStablecoinCount() external view returns (uint256) {
        return _approvedStablecoins.length;
    }

    /**
     * @notice Total normalized (18-decimal) value of all treasury stablecoins.
     */
    function totalTreasuryValue18() external view returns (uint256) {
        return _getTotalValue18();
    }

    /**
     * @notice Current backing per reserve token (18 decimals). Returns WAD if
     *         total supply is zero.
     */
    function backingPerToken() external view returns (uint256) {
        return _currentBackingPerToken();
    }

    /**
     * @notice Pending rebase rewards for a user based on current rebase index.
     * @param user Address of the staker
     */
    function pendingRewards(address user) external view returns (uint256) {
        uint256 staked = stakedBalance[user];
        if (staked < 1) return 0;
        uint256 currentIdx = rebaseIndex;
        uint256 userIdx = userRewardIndex[user];
        if (currentIdx <= userIdx) return 0;
        return (staked * (currentIdx - userIdx)) / WAD;
    }

    /**
     * @notice Projected rebase index if a rebase were triggered now.
     */
    function projectedRebaseIndex() external view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastRebase;
        if (timeElapsed < 1 || rebaseRate < 1) return rebaseIndex;
        // Single expression: multiply before divide to avoid precision loss
        return rebaseIndex + (rebaseIndex * rebaseRate * timeElapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
    }
}
