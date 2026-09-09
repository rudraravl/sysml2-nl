// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256 price, uint8 decimals);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: failed transfer");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: failed transferFrom");
    }
}

/**
 * @title AlgorithmicStablecoin
 * @notice A decentralized algorithmic stablecoin backed by a basket of
 *         yield-bearing collateral assets. Users mint the stablecoin by
 *         depositing whitelisted collateral, redeem stablecoins for a chosen
 *         collateral asset, and stake stablecoins to earn yield distributed
 *         by the protocol owner.
 */
contract AlgorithmicStablecoin {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // ERC20 metadata & storage
    // ---------------------------------------------------------------------

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_MINT_CAPACITY = 100_000_000 * 10 ** 18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant REWARD_SCALE = 1e18;
    uint256 private constant MIN_MINT = 1e15; // minimum 0.001 stablecoins

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------

    struct CollateralAsset {
        bool whitelisted;
        uint8 decimals;
        uint256 collateralRatio; // required over-collateralization ratio in bps (>= 10000)
        uint256 totalDeposited; // total collateral units held for this asset
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    mapping(address => CollateralAsset) public collateralAssets;
    address[] public collateralList;

    uint256 public mintFeeBps;
    uint256 public accruedFees;

    address public owner;
    address public operator;
    IPriceOracle public oracle;

    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    uint256 public rewardIndex;
    mapping(address => uint256) public userRewardIndex;
    mapping(address => uint256) public accruedReward;

    bool private _paused;
    bool private _locked;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Minted(
        address indexed caller,
        address indexed receiver,
        address indexed collateralAsset,
        uint256 collateralAmount,
        uint256 stableAmount,
        uint256 fee
    );
    event Redeemed(
        address indexed caller,
        address indexed receiver,
        address indexed collateralAsset,
        uint256 stableAmount,
        uint256 collateralReturned,
        uint256 fee
    );
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event YieldDistributed(address indexed caller, uint256 amount);

    event CollateralWhitelisted(address indexed asset, uint256 decimals, uint256 collateralRatio);
    event CollateralRemoved(address indexed asset);
    event CollateralRatioUpdated(address indexed asset, uint256 newRatio);

    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event FeesClaimed(address indexed to, uint256 amount);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error NotWhitelisted(address asset);
    error AlreadyWhitelisted(address asset);
    error AssetNotFound(address asset);
    error InsufficientBalance(address user, uint256 needed, uint256 available);
    error InsufficientAllowance(address spender, uint256 needed, uint256 available);
    error MintCapacityExceeded(uint256 requested, uint256 cap, uint256 currentSupply);
    error CollateralRatioNotMet(uint256 requiredValue, uint256 providedValue);
    error ZeroAmount();
    error InvalidDecimals();
    error InvalidFee(uint256 fee);
    error InvalidRatio(uint256 ratio);
    error NothingToClaim(address user);
    error PriceStaleOrZero(address asset);
    error InsufficientCollateral(address asset, uint256 needed, uint256 available);
    error NotOperator();
    error NotOwner();
    error EnforcedPause();
    error ReentrancyDetected();
    error InsufficientMint(uint256 mintable, uint256 minimum);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyWhitelisted(address asset) {
        if (!collateralAssets[asset].whitelisted) revert NotWhitelisted(asset);
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        string memory name_,
        string memory symbol_,
        address oracle_,
        address operator_,
        uint256 mintFeeBps_
    ) {
        if (oracle_ == address(0) || operator_ == address(0)) revert ZeroAddress();
        if (mintFeeBps_ > BPS_DENOMINATOR) revert InvalidFee(mintFeeBps_);

        name = name_;
        symbol = symbol_;
        oracle = IPriceOracle(oracle_);
        operator = operator_;
        mintFeeBps = mintFeeBps_;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OracleUpdated(address(0), oracle_);
        emit OperatorUpdated(address(0), operator_);
        emit MintFeeUpdated(0, mintFeeBps_);
    }

    // ---------------------------------------------------------------------
    // ERC20 view & external functions
    // ---------------------------------------------------------------------

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(msg.sender, amount, allowed);
        if (allowed != type(uint256).max) {
            unchecked {
                _allowances[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    // ERC20 internals — zero-amount transfers allowed (no strict equality)
    // ---------------------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, amount, fromBalance);

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        uint256 newSupply = _totalSupply + amount;
        if (newSupply > MAX_MINT_CAPACITY) {
            revert MintCapacityExceeded(newSupply, MAX_MINT_CAPACITY, _totalSupply);
        }

        _totalSupply = newSupply;
        unchecked {
            _balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, amount, fromBalance);

        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    // ---------------------------------------------------------------------
    // Pause
    // ---------------------------------------------------------------------

    function paused() external view returns (bool) {
        return _paused;
    }

    function _pause() internal {
        if (_paused) revert EnforcedPause();
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        if (!_paused) revert EnforcedPause();
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // ---------------------------------------------------------------------
    // Price helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the stablecoin-denominated value of `amount` units of `asset`.
     */
    function assetValueInStable(address asset, uint256 amount) public view returns (uint256) {
        (uint256 price, uint8 priceDecimals) = oracle.getPrice(asset);
        if (price == 0) revert PriceStaleOrZero(asset);

        CollateralAsset storage ca = collateralAssets[asset];
        uint256 denominator = (10 ** uint256(ca.decimals)) * (10 ** uint256(priceDecimals));
        return (amount * price * (10 ** uint256(decimals))) / denominator;
    }

    /**
     * @notice Converts a stablecoin-denominated value back into `asset` units.
     */
    function stableValueToAsset(address asset, uint256 stableValue) public view returns (uint256) {
        (uint256 price, uint8 priceDecimals) = oracle.getPrice(asset);
        if (price == 0) revert PriceStaleOrZero(asset);

        CollateralAsset storage ca = collateralAssets[asset];
        uint256 denominator = (10 ** uint256(ca.decimals)) * (10 ** uint256(priceDecimals));
        return (stableValue * denominator) / (price * (10 ** uint256(decimals)));
    }

    // ---------------------------------------------------------------------
    // Minting — CEI pattern: all state updated before external transfer
    // ---------------------------------------------------------------------

    /**
     * @notice Mint stablecoins by depositing whitelisted collateral.
     * @param asset      Collateral asset address.
     * @param amount     Amount of collateral to deposit (in asset units).
     * @param receiver   Recipient of minted stablecoins.
     */
    function mint(address asset, uint256 amount, address receiver)
        external
        nonReentrant
        whenNotPaused
        onlyWhitelisted(asset)
        returns (uint256 minted)
    {
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        CollateralAsset storage ca = collateralAssets[asset];

        // --- Compute collateral value from `amount` (before any external call) ---
        uint256 collateralValue = assetValueInStable(asset, amount);

        // --- Compute mintable and fee without divide-before-multiply ---
        // mintable = collateralValue * BPS / ratio
        // fee = collateralValue * feeBps / ratio  (avoids multiplying a rounded quotient)
        uint256 mintable = (collateralValue * BPS_DENOMINATOR) / ca.collateralRatio;
        if (mintable < MIN_MINT) revert InsufficientMint(mintable, MIN_MINT);

        uint256 fee = (collateralValue * mintFeeBps) / ca.collateralRatio;
        minted = mintable - fee;

        // --- Check mint capacity ---
        uint256 newSupply = _totalSupply + mintable;
        if (newSupply > MAX_MINT_CAPACITY) {
            revert MintCapacityExceeded(newSupply, MAX_MINT_CAPACITY, _totalSupply);
        }

        // --- Effects: update all state BEFORE the external transfer ---
        ca.totalDeposited += amount;
        if (fee > 0) {
            accruedFees += fee;
        }
        _mint(receiver, minted);
        if (fee > 0) {
            _mint(address(this), fee);
        }

        // --- Interactions: pull collateral from caller (last) ---
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Minted(msg.sender, receiver, asset, amount, minted, fee);
    }

    // ---------------------------------------------------------------------
    // Redemption — CEI pattern
    // ---------------------------------------------------------------------

    /**
     * @notice Redeem stablecoins for a chosen collateral asset.
     * @param asset         Collateral asset to receive.
     * @param stableAmount  Amount of stablecoins to redeem.
     * @param receiver      Recipient of the collateral.
     */
    function redeem(address asset, uint256 stableAmount, address receiver)
        external
        nonReentrant
        whenNotPaused
        onlyWhitelisted(asset)
        returns (uint256 collateralReturned)
    {
        if (stableAmount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        uint256 callerBalance = _balances[msg.sender];
        if (callerBalance < stableAmount) {
            revert InsufficientBalance(msg.sender, stableAmount, callerBalance);
        }

        // Redemption fee is fixed at 0.5% of the redeemed amount.
        uint256 fee = (stableAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 redeemable = stableAmount - fee;

        uint256 grossCollateral = stableValueToAsset(asset, redeemable);
        if (grossCollateral == 0) revert ZeroAmount();

        CollateralAsset storage ca = collateralAssets[asset];
        if (grossCollateral > ca.totalDeposited) {
            revert InsufficientCollateral(asset, grossCollateral, ca.totalDeposited);
        }

        // --- Effects: burn stablecoins, mint fee, update collateral ---
        _burn(msg.sender, stableAmount);
        if (fee > 0) {
            _mint(address(this), fee);
            accruedFees += fee;
        }
        ca.totalDeposited -= grossCollateral;

        // --- Interactions: transfer collateral to receiver (last) ---
        IERC20(asset).safeTransfer(receiver, grossCollateral);

        collateralReturned = grossCollateral;
        emit Redeemed(msg.sender, receiver, asset, stableAmount, collateralReturned, fee);
    }

    // ---------------------------------------------------------------------
    // Staking
    // ---------------------------------------------------------------------

    /**
     * @notice Stake stablecoins to earn yield.
     * @param amount The amount of stablecoins to stake.
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 callerBalance = _balances[msg.sender];
        if (callerBalance < amount) {
            revert InsufficientBalance(msg.sender, amount, callerBalance);
        }

        _updateReward(msg.sender);

        // Effects (internal transfer — no external call)
        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake stablecoins.
     * @param amount The amount of stablecoins to unstake.
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 staked = stakedBalance[msg.sender];
        if (staked < amount) {
            revert InsufficientBalance(msg.sender, amount, staked);
        }

        _updateReward(msg.sender);

        // Effects (internal transfer — no external call)
        stakedBalance[msg.sender] = staked - amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated staking yield.
     */
    function claimYield() external nonReentrant returns (uint256 claimed) {
        _updateReward(msg.sender);

        claimed = accruedReward[msg.sender];
        if (claimed > 0) {
            // Effects
            accruedReward[msg.sender] = 0;

            uint256 contractBalance = _balances[address(this)];
            if (contractBalance < claimed) {
                revert InsufficientBalance(address(this), claimed, contractBalance);
            }

            // Internal transfer (no external call)
            _transfer(address(this), msg.sender, claimed);
            emit YieldClaimed(msg.sender, claimed);
        } else {
            revert NothingToClaim(msg.sender);
        }
    }

    /**
     * @notice Deposit yield rewards to be distributed to stakers.
     * @dev Only callable by the owner. Stablecoins must be held by the caller.
     */
    function depositYield(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Internal transfer — no external call involved
        _transfer(msg.sender, address(this), amount);

        if (totalStaked > 0) {
            rewardIndex += (amount * REWARD_SCALE) / totalStaked;
        }

        emit YieldDistributed(msg.sender, amount);
    }

    function pendingYield(address user) external view returns (uint256) {
        if (stakedBalance[user] > 0) {
            uint256 delta = rewardIndex - userRewardIndex[user];
            return accruedReward[user] + ((stakedBalance[user] * delta) / REWARD_SCALE);
        }
        return accruedReward[user];
    }

    function _updateReward(address user) internal {
        if (stakedBalance[user] > 0) {
            uint256 delta = rewardIndex - userRewardIndex[user];
            if (delta > 0) {
                accruedReward[user] += (stakedBalance[user] * delta) / REWARD_SCALE;
            }
        }
        userRewardIndex[user] = rewardIndex;
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    /**
     * @notice Whitelist a new collateral asset.
     * @param asset            Asset address.
     * @param decimals_        Asset decimals.
     * @param collateralRatio  Required collateral ratio in bps (>= 10000).
     */
    function whitelistCollateral(address asset, uint256 decimals_, uint256 collateralRatio)
        external
        onlyOperator
    {
        if (asset == address(0)) revert ZeroAddress();
        if (decimals_ == 0 || decimals_ > 36) revert InvalidDecimals();
        if (collateralRatio < BPS_DENOMINATOR) revert InvalidRatio(collateralRatio);

        CollateralAsset storage ca = collateralAssets[asset];
        if (ca.whitelisted) revert AlreadyWhitelisted(asset);

        ca.whitelisted = true;
        ca.decimals = uint8(decimals_);
        ca.collateralRatio = collateralRatio;

        collateralList.push(asset);

        emit CollateralWhitelisted(asset, decimals_, collateralRatio);
    }

    /**
     * @notice Remove a collateral asset from the whitelist.
     */
    function removeCollateral(address asset) external onlyOperator {
        CollateralAsset storage ca = collateralAssets[asset];
        if (!ca.whitelisted) revert AssetNotFound(asset);

        ca.whitelisted = false;

        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; i++) {
            if (collateralList[i] == asset) {
                collateralList[i] = collateralList[len - 1];
                collateralList.pop();
                break;
            }
        }

        emit CollateralRemoved(asset);
    }

    /**
     * @notice Update the required collateral ratio for an asset.
     */
    function setCollateralRatio(address asset, uint256 newRatio) external onlyOperator {
        CollateralAsset storage ca = collateralAssets[asset];
        if (!ca.whitelisted) revert AssetNotFound(asset);
        if (newRatio < BPS_DENOMINATOR) revert InvalidRatio(newRatio);

        ca.collateralRatio = newRatio;
        emit CollateralRatioUpdated(asset, newRatio);
    }

    /**
     * @notice Update the oracle contract.
     */
    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------

    function setMintFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFee(newFeeBps);
        uint256 old = mintFeeBps;
        mintFeeBps = newFeeBps;
        emit MintFeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Claim accrued protocol fees (in stablecoin units).
     */
    function claimFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        if (amount == 0) revert ZeroAmount();

        // Effects
        accruedFees = 0;

        uint256 contractBalance = _balances[address(this)];
        if (contractBalance < amount) {
            revert InsufficientBalance(address(this), amount, contractBalance);
        }

        // Internal transfer (no external call)
        _transfer(address(this), to, amount);
        emit FeesClaimed(to, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function collateralCount() external view returns (uint256) {
        return collateralList.length;
    }

    function getCollateral(address asset)
        external
        view
        returns (bool whitelisted, uint8 assetDecimals, uint256 totalDeposited, uint256 collateralRatio)
    {
        CollateralAsset storage ca = collateralAssets[asset];
        return (ca.whitelisted, ca.decimals, ca.totalDeposited, ca.collateralRatio);
    }

    function totalBalanceOf(address user) external view returns (uint256) {
        return _balances[user] + stakedBalance[user];
    }
}
