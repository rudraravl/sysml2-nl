// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
}

/// @title LaunchToken
/// @notice Minimal ERC20 minted at construction and held by the launchpad until distribution.
contract LaunchToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address mintTo
    ) {
        require(totalSupply_ > 0, "LaunchToken: zero supply");
        require(mintTo != address(0), "LaunchToken: mint to zero");
        name = name_;
        symbol = symbol_;
        _totalSupply = totalSupply_;
        _balances[mintTo] = totalSupply_;
        emit Transfer(address(0), mintTo, totalSupply_);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "LaunchToken: insufficient allowance");
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(_balances[from] >= amount, "LaunchToken: insufficient balance");
        require(to != address(0), "LaunchToken: transfer to zero");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @title TokenLaunchpad
/// @notice Allows creators to launch new ERC20 tokens and raise base currency for initial liquidity.
/// @dev A platform fee of 0.5% (default) is charged on the total base currency committed for each
///      successful launch. Each launch must raise at least 1000 base currency to be successful.
contract TokenLaunchpad {
    error NotOwner();
    error PausedLaunchpad();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroSupply();
    error FeeTooHigh();
    error LaunchNotActive();
    error LaunchAlreadyFinalized();
    error LaunchNotFinalized();
    error NoCommitment();
    error TransferFailed();

    address public owner;
    bool public paused;
    uint256 public platformFeeBps; // in basis points, 50 = 0.5%
    uint256 public constant MIN_COMMITMENT = 1000; // minimum base currency for a successful launch
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint256 public constant FEE_DENOMINATOR = 10000;

    IERC20 public immutable baseCurrency;

    struct Launch {
        address creator;
        address token;
        uint256 totalSupply;
        uint256 totalCommitted;
        bool finalized;
        bool successful;
        bool active;
    }

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public commitments;
    uint256 public launchCount;

    event LaunchInitiated(uint256 indexed launchId, address indexed creator, address token, uint256 totalSupply);
    event LaunchFinalized(uint256 indexed launchId, bool successful, uint256 totalCommitted, uint256 fee);
    event Contributed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event TokensClaimed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event Refunded(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event PlatformFeeUpdated(uint256 oldBps, uint256 newBps);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedLaunchpad();
        _;
    }

    constructor(address baseCurrency_) {
        if (baseCurrency_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        baseCurrency = IERC20(baseCurrency_);
        platformFeeBps = 50; // 0.5%
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Sets the platform fee (in basis points) charged on successful launches.
    function setPlatformFee(uint256 bps) external onlyOwner {
        if (bps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = platformFeeBps;
        platformFeeBps = bps;
        emit PlatformFeeUpdated(old, bps);
    }

    /// @notice Pauses or unpauses the initiation of new token launches.
    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    /// @notice Transfers contract ownership to a new address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Initiates a new token launch, deploying a fresh ERC20 token.
    /// @param name_ The name of the new token.
    /// @param symbol_ The symbol of the new token.
    /// @param totalSupply_ The total supply of tokens to be distributed to contributors.
    /// @return launchId The unique identifier of the newly created launch.
    function launch(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) external whenNotPaused returns (uint256 launchId) {
        if (totalSupply_ == 0) revert ZeroSupply();
        launchId = launchCount++;
        address token = address(new LaunchToken(name_, symbol_, totalSupply_, address(this)));
        launches[launchId] = Launch({
            creator: msg.sender,
            token: token,
            totalSupply: totalSupply_,
            totalCommitted: 0,
            finalized: false,
            successful: false,
            active: true
        });
        emit LaunchInitiated(launchId, msg.sender, token, totalSupply_);
    }

    /// @notice Contributes base currency to an ongoing launch.
    /// @param launchId The identifier of the launch to contribute to.
    /// @param amount The amount of base currency to commit.
    function contribute(uint256 launchId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Launch storage l = launches[launchId];
        if (!l.active) revert LaunchNotActive();
        if (l.finalized) revert LaunchAlreadyFinalized();

        // Effects: update state before the external transfer to prevent reentrancy.
        commitments[launchId][msg.sender] += amount;
        l.totalCommitted += amount;

        // Interactions: pull base currency from the contributor.
        if (!baseCurrency.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Contributed(launchId, msg.sender, amount);
    }

    /// @notice Finalizes a launch, determining success based on the minimum commitment threshold.
    /// @dev On success, the platform fee is sent to the owner and the remaining base currency
    ///      is sent to the creator to establish initial liquidity. On failure, contributors
    ///      may reclaim their committed base currency via `claim`.
    function finalize(uint256 launchId) external {
        Launch storage l = launches[launchId];
        if (!l.active) revert LaunchNotActive();
        if (l.finalized) revert LaunchAlreadyFinalized();

        // Effects: mark finalized before any external transfers.
        l.finalized = true;
        l.active = false;
        bool success = l.totalCommitted >= MIN_COMMITMENT;
        l.successful = success;

        uint256 fee = 0;
        if (success) {
            fee = (l.totalCommitted * platformFeeBps) / FEE_DENOMINATOR;
            uint256 creatorShare = l.totalCommitted - fee;

            // Interactions: distribute base currency after state is finalized.
            if (fee > 0) {
                if (!baseCurrency.transfer(owner, fee)) revert TransferFailed();
            }
            if (creatorShare > 0) {
                if (!baseCurrency.transfer(l.creator, creatorShare)) revert TransferFailed();
            }
        }

        emit LaunchFinalized(launchId, success, l.totalCommitted, fee);
    }

    /// @notice Claims a contributor's share of tokens after a successful launch,
    ///         or refunds their committed base currency if the launch failed.
    /// @param launchId The identifier of the finalized launch.
    function claim(uint256 launchId) external {
        Launch storage l = launches[launchId];
        if (!l.finalized) revert LaunchNotFinalized();

        uint256 userCommit = commitments[launchId][msg.sender];
        if (userCommit == 0) revert NoCommitment();

        // Effects: zero out the commitment before transferring.
        commitments[launchId][msg.sender] = 0;

        if (l.successful) {
            uint256 tokenShare = (userCommit * l.totalSupply) / l.totalCommitted;
            // Interactions: distribute tokens after state update.
            if (!LaunchToken(l.token).transfer(msg.sender, tokenShare)) revert TransferFailed();
            emit TokensClaimed(launchId, msg.sender, tokenShare);
        } else {
            // Interactions: refund base currency after state update.
            if (!baseCurrency.transfer(msg.sender, userCommit)) revert TransferFailed();
            emit Refunded(launchId, msg.sender, userCommit);
        }
    }

    /// @notice Retrieves the full details of a launch.
    function getLaunch(uint256 launchId) external view returns (Launch memory) {
        return launches[launchId];
    }

    /// @notice Retrieves the amount of base currency a contributor has committed to a launch.
    function getCommitment(uint256 launchId, address contributor) external view returns (uint256) {
        return commitments[launchId][contributor];
    }
}
