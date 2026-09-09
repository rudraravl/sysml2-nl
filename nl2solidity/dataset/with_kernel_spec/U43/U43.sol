// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title PrivateCreditPortfolio
 * @notice Tokenized real-world asset vault representing fractional ownership in a
 *         diversified portfolio of private credit investments. Investors deposit
 *         stablecoins to mint asset tokens 1:1 and redeem them through a two-step
 *         operator-approved process. A per-investor holding cap and a redemption
 *         fee are enforced.
 */
contract PrivateCreditPortfolio {
    // ------------------------------------------------------------------
    //  Constants
    // ------------------------------------------------------------------
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_MAX_HOLDING = 10_000_000 * 1e18; // 10M stablecoins
    uint16 public constant DEFAULT_REDEMPTION_FEE_BPS = 50; // 0.5%

    string public constant name = "Private Credit Asset Token";
    string public constant symbol = "PCAT";
    uint8 public constant decimals = 18;

    // ------------------------------------------------------------------
    //  Custom errors
    // ------------------------------------------------------------------
    error ZeroAmount();
    error ZeroAddress();
    error Unauthorized();
    error Reentrancy();
    error ExceedsMaxHolding(address investor, uint256 attempted, uint256 max);
    error InsufficientBalance(address investor, uint256 required, uint256 available);
    error InsufficientAllowance(address owner, address spender, uint256 required, uint256 available);
    error RequestNotFound(uint256 requestId);
    error RequestAlreadyProcessed(uint256 requestId);
    error RequestNotApproved(uint256 requestId);
    error NotRequestOwner(uint256 requestId, address caller);
    error InvalidFeeBps(uint256 feeBps);
    error AssetNotFound(uint256 assetId);
    error InvalidWeight(uint16 weightBps);
    error DepositsPaused();
    error EmptyAssetName();
    error TransferFailed();

    // ------------------------------------------------------------------
    //  Events
    // ------------------------------------------------------------------
    event Deposit(address indexed investor, uint256 stableAmount, uint256 assetTokensMinted);
    event RedemptionRequested(address indexed investor, uint256 requestId, uint256 assetTokens);
    event RedemptionApproved(uint256 indexed requestId, address indexed investor, uint256 grossAmount, uint256 fee, uint256 netAmount);
    event RedemptionRejected(uint256 indexed requestId, address indexed investor, uint256 assetTokens);
    event RedemptionClaimed(uint256 indexed requestId, address indexed investor, uint256 grossAmount, uint256 fee, uint256 netAmount);
    event AssetAdded(uint256 indexed assetId, string name, uint256 valuation, uint16 weightBps);
    event AssetUpdated(uint256 indexed assetId, bool active);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event MaxHoldingUpdated(uint256 newMax);
    event RedemptionFeeUpdated(uint16 newFeeBps);
    event DepositsPausedChanged(bool paused);
    event FeesCollected(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ------------------------------------------------------------------
    //  Structs
    // ------------------------------------------------------------------
    struct InvestorRecord {
        uint256 assetBalance;
        uint256 stableDeposited;
        uint256 pendingRedemptionTokens;
    }

    struct RealWorldAsset {
        uint256 id;
        string name;
        uint256 valuation;   // notional value in stablecoin units
        uint16 weightBps;    // portfolio weight in basis points
        bool active;
        bool exists;
        uint64 addedAt;
    }

    struct RedemptionRequest {
        address investor;
        uint256 assetTokens;
        uint256 stableValueLocked;
        uint64 requestedAt;
        bool approved;
        bool rejected;
        bool processed;
    }

    // ------------------------------------------------------------------
    //  State variables
    // ------------------------------------------------------------------
    IERC20 public immutable stablecoin;

    address public owner;
    address public operator;
    uint256 public maxIndividualHolding;
    uint16 public redemptionFeeBps;
    bool public depositsPaused;

    uint256 public totalSupply;
    uint256 public totalValueLocked; // total stablecoins custodied
    uint256 public accumulatedFees;  // fees available for collection

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => InvestorRecord) public investors;

    mapping(uint256 => RealWorldAsset) public assets;
    uint256[] public assetIds;
    uint256 public nextAssetId = 1;

    mapping(uint256 => RedemptionRequest) public redemptions;
    uint256 public nextRedemptionId = 1;

    uint256 private _locked = 1;

    // ------------------------------------------------------------------
    //  Modifiers
    // ------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notZeroAddress(address a) {
        if (a == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ------------------------------------------------------------------
    //  Constructor
    // ------------------------------------------------------------------
    constructor(address _stablecoin, address _operator)
        notZeroAddress(_stablecoin)
        notZeroAddress(_operator)
    {
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        maxIndividualHolding = DEFAULT_MAX_HOLDING;
        redemptionFeeBps = DEFAULT_REDEMPTION_FEE_BPS;
        emit OperatorUpdated(address(0), _operator);
        emit MaxHoldingUpdated(DEFAULT_MAX_HOLDING);
        emit RedemptionFeeUpdated(DEFAULT_REDEMPTION_FEE_BPS);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ------------------------------------------------------------------
    //  ERC20 Core
    // ------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(from, msg.sender, amount, allowed);
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance(from, amount, balanceOf[from]);

        // Enforce holding cap on recipient (skip if from is contract itself, e.g. rejectRedemption)
        if (from != address(this) && to != address(0)) {
            uint256 newRecipientBalance = balanceOf[to] + amount;
            if (newRecipientBalance > maxIndividualHolding) {
                revert ExceedsMaxHolding(to, newRecipientBalance, maxIndividualHolding);
            }
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        investors[from].assetBalance = balanceOf[from];
        investors[to].assetBalance = balanceOf[to];

        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        if (ownerAddr == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        uint256 newBalance = balanceOf[to] + amount;
        if (newBalance > maxIndividualHolding) {
            revert ExceedsMaxHolding(to, newBalance, maxIndividualHolding);
        }

        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        investors[to].assetBalance = balanceOf[to];
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance(from, amount, balanceOf[from]);

        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        investors[from].assetBalance = balanceOf[from];
        emit Transfer(from, address(0), amount);
    }

    // ------------------------------------------------------------------
    //  Deposit
    // ------------------------------------------------------------------
    /**
     * @notice Deposit stablecoins to mint asset tokens at 1:1 ratio.
     * @param stableAmount Amount of stablecoins to deposit.
     * @return minted Number of asset tokens minted.
     */
    function deposit(uint256 stableAmount) external nonReentrant returns (uint256 minted) {
        if (depositsPaused) revert DepositsPaused();
        if (stableAmount == 0) revert ZeroAmount();

        uint256 newBalance = balanceOf[msg.sender] + stableAmount;
        if (newBalance > maxIndividualHolding) {
            revert ExceedsMaxHolding(msg.sender, newBalance, maxIndividualHolding);
        }

        // Effects: update all state before the external call (checks-effects-interactions)
        minted = stableAmount;
        _mint(msg.sender, minted);
        investors[msg.sender].stableDeposited += stableAmount;
        totalValueLocked += stableAmount;

        // Interactions: pull stablecoins from the investor
        bool ok = stablecoin.transferFrom(msg.sender, address(this), stableAmount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, stableAmount, minted);
    }

    // ------------------------------------------------------------------
    //  Redemption (two-step: request → operator approve/reject → claim)
    // ------------------------------------------------------------------
    /**
     * @notice Request a redemption of asset tokens. Tokens are burned and the
     *         request is queued for operator approval.
     * @param assetTokens Amount of asset tokens to redeem.
     * @return requestId The identifier of the created redemption request.
     */
    function requestRedemption(uint256 assetTokens) external nonReentrant returns (uint256 requestId) {
        if (assetTokens == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < assetTokens) {
            revert InsufficientBalance(msg.sender, assetTokens, balanceOf[msg.sender]);
        }

        // Effects: burn tokens and record pending
        investors[msg.sender].pendingRedemptionTokens += assetTokens;
        _burn(msg.sender, assetTokens);

        requestId = nextRedemptionId++;
        redemptions[requestId] = RedemptionRequest({
            investor: msg.sender,
            assetTokens: assetTokens,
            stableValueLocked: assetTokens, // 1:1 at request time
            requestedAt: uint64(block.timestamp),
            approved: false,
            rejected: false,
            processed: false
        });

        emit RedemptionRequested(msg.sender, requestId, assetTokens);
    }

    /**
     * @notice Operator approves a redemption request. The stablecoins (minus fee)
     *         become claimable by the investor.
     * @param requestId ID of the redemption request to approve.
     */
    function approveRedemption(uint256 requestId) external onlyOperator {
        RedemptionRequest storage r = redemptions[requestId];
        if (r.investor == address(0)) revert RequestNotFound(requestId);
        if (r.processed) revert RequestAlreadyProcessed(requestId);
        if (r.rejected) revert RequestAlreadyProcessed(requestId);

        r.approved = true;
        r.processed = true;

        uint256 gross = r.stableValueLocked;
        uint256 fee = (gross * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        // Effects
        investors[r.investor].pendingRedemptionTokens -= r.assetTokens;
        totalValueLocked -= gross;
        accumulatedFees += fee;

        emit RedemptionApproved(requestId, r.investor, gross, fee, net);
    }

    /**
     * @notice Operator rejects a redemption request. Locked tokens are returned
     *         to the investor.
     * @param requestId ID of the redemption request to reject.
     */
    function rejectRedemption(uint256 requestId) external onlyOperator {
        RedemptionRequest storage r = redemptions[requestId];
        if (r.investor == address(0)) revert RequestNotFound(requestId);
        if (r.processed) revert RequestAlreadyProcessed(requestId);

        r.rejected = true;
        r.processed = true;

        // Return locked tokens to investor (no cap check needed: from = address(this))
        investors[r.investor].pendingRedemptionTokens -= r.assetTokens;
        _mint(r.investor, r.assetTokens);

        emit RedemptionRejected(requestId, r.investor, r.assetTokens);
    }

    /**
     * @notice Investor claims the stablecoins from an approved redemption request.
     * @param requestId ID of the approved redemption request.
     */
    function claimRedemption(uint256 requestId) external nonReentrant {
        RedemptionRequest storage r = redemptions[requestId];
        if (r.investor == address(0)) revert RequestNotFound(requestId);
        if (r.investor != msg.sender) revert NotRequestOwner(requestId, msg.sender);
        if (!r.approved) revert RequestNotApproved(requestId);

        uint256 gross = r.stableValueLocked;
        if (gross == 0) revert RequestAlreadyProcessed(requestId);

        uint256 fee = (gross * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        // Mark as claimed by zeroing stableValueLocked (guard against double-claim)
        r.stableValueLocked = 0;

        // Interactions
        bool ok = stablecoin.transfer(msg.sender, net);
        if (!ok) revert TransferFailed();

        emit RedemptionClaimed(requestId, msg.sender, gross, fee, net);
    }

    // ------------------------------------------------------------------
    //  Asset management (operator)
    // ------------------------------------------------------------------
    /**
     * @notice Add a new real-world asset to the portfolio.
     * @param assetName  Human-readable name of the asset.
     * @param valuation  Notional value in stablecoin units.
     * @param weightBps  Portfolio weight in basis points (must be <= 10000).
     * @return assetId The newly assigned asset ID.
     */
    function addAsset(
        string calldata assetName,
        uint256 valuation,
        uint16 weightBps
    ) external onlyOperator returns (uint256 assetId) {
        if (bytes(assetName).length == 0) revert EmptyAssetName();
        if (weightBps > BPS_DENOMINATOR) revert InvalidWeight(weightBps);

        assetId = nextAssetId++;
        assets[assetId] = RealWorldAsset({
            id: assetId,
            name: assetName,
            valuation: valuation,
            weightBps: weightBps,
            active: true,
            exists: true,
            addedAt: uint64(block.timestamp)
        });
        assetIds.push(assetId);

        emit AssetAdded(assetId, assetName, valuation, weightBps);
    }

    /**
     * @notice Toggle the active status of an existing asset.
     * @param assetId ID of the asset to update.
     * @param active  New active status.
     */
    function setAssetActive(uint256 assetId, bool active) external onlyOperator {
        if (!assets[assetId].exists) revert AssetNotFound(assetId);
        assets[assetId].active = active;
        emit AssetUpdated(assetId, active);
    }

    // ------------------------------------------------------------------
    //  Admin (owner)
    // ------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner notZeroAddress(newOperator) {
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setMaxHolding(uint256 newMax) external onlyOwner {
        if (newMax == 0) revert ZeroAmount();
        maxIndividualHolding = newMax;
        emit MaxHoldingUpdated(newMax);
    }

    function setRedemptionFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFeeBps(newFeeBps);
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(newFeeBps);
    }

    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    /**
     * @notice Collect accumulated redemption fees to a recipient.
     * @param to     Recipient address.
     * @param amount Amount of stablecoins to collect (must be <= accumulatedFees).
     */
    function collectFees(address to, uint256 amount) external onlyOwner notZeroAddress(to) {
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientBalance(address(this), amount, accumulatedFees);

        accumulatedFees -= amount;
        bool ok = stablecoin.transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit FeesCollected(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner notZeroAddress(newOwner) {
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // ------------------------------------------------------------------
    //  Views
    // ------------------------------------------------------------------
    function getInvestorRecord(address investor) external view returns (InvestorRecord memory) {
        return investors[investor];
    }

    function getRedemptionRequest(uint256 requestId) external view returns (RedemptionRequest memory) {
        return redemptions[requestId];
    }

    function getAsset(uint256 assetId) external view returns (RealWorldAsset memory) {
        if (!assets[assetId].exists) revert AssetNotFound(assetId);
        return assets[assetId];
    }

    function getAssetCount() external view returns (uint256) {
        return assetIds.length;
    }

    function getAllAssetIds() external view returns (uint256[] memory) {
        return assetIds;
    }

    function previewRedemption(uint256 assetTokens) external view returns (uint256 net, uint256 fee) {
        uint256 gross = assetTokens;
        fee = (gross * redemptionFeeBps) / BPS_DENOMINATOR;
        net = gross - fee;
    }
}
