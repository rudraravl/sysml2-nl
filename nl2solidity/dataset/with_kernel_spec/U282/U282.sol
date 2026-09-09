// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LaunchToken
 * @notice Minimal ERC20 implementation used for bonding curve launches.
 *         Only the designated launchpad minter may mint new tokens.
 */
contract LaunchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error NotMinter();
    error TransferToZeroAddress();
    error InsufficientBalance(address from, uint256 available, uint256 required);
    error InsufficientAllowance(address spender, uint256 available, uint256 required);

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    constructor(string memory _name, string memory _symbol, address _minter) {
        if (_minter == address(0)) revert TransferToZeroAddress();
        name = _name;
        symbol = _symbol;
        minter = _minter;
        emit Transfer(address(0), address(0), 0);
    }

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
        if (allowed < amount) {
            revert InsufficientAllowance(msg.sender, allowed, amount);
        }
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(from, fromBalance, amount);
        }
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }
}

/**
 * @title BondingCurveLaunchpad
 * @notice Facilitates token launches via a linear bonding curve with price-gated
 *         escrow / vesting. Users deposit native currency to receive newly minted
 *         tokens, which remain locked until configured price milestones are crossed.
 */
contract BondingCurveLaunchpad {
    struct PriceMilestone {
        uint256 price;                // Price threshold (wei per token) that must be reached
        uint256 cumulativePercentage; // Cumulative unlock percentage in basis points (0..10000)
    }

    struct TokenLaunch {
        LaunchToken token;            // The deployed ERC20 token
        uint256 basePrice;            // Base price per token (wei)
        uint256 slope;                // Bonding curve slope (wei per token)
        uint256 totalSupply;          // Tokens minted so far
        uint256 nativeRaised;         // Net native currency raised (after fees)
        PriceMilestone[] milestones; // Sorted price milestones
        bool exists;                  // Whether the launch is registered
    }

    struct UserPosition {
        uint256 purchased;             // Total tokens purchased by the user
        uint256 claimed;               // Tokens already claimed
        uint256 lastClaimedCumulative; // Last cumulative unlock percentage claimed (bps)
    }

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MAX_PURCHASE = 100 ether;  // Max native currency per purchase
    uint256 public constant BPS_DENOMINATOR = 10000;   // Basis points denominator
    uint16 public constant MAX_FEE_BPS = 50;           // Fee cap (0.5%)

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    address public owner;
    address public operator;
    address public feeRecipient;
    uint16 public feeBps;                 // Protocol fee in bps (default 50 = 0.5%)
    uint256 public accumulatedFees;       // Fees awaiting withdrawal
    bool public paused;

    mapping(address => TokenLaunch) public launches;                       // token => launch
    mapping(address => mapping(address => UserPosition)) public positions;  // token => user => position

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event TokenLaunchRegistered(
        address indexed token,
        string name,
        string symbol,
        uint256 basePrice,
        uint256 slope,
        PriceMilestone[] milestones
    );
    event TokenMilestonesUpdated(address indexed token, PriceMilestone[] milestones);
    event TokenPurchased(
        address indexed token,
        address indexed buyer,
        uint256 nativeAmount,
        uint256 tokensMinted,
        uint256 fee
    );
    event TokensClaimed(address indexed token, address indexed claimer, uint256 amount);
    event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event RaisedWithdrawn(address indexed token, address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error AlreadyPaused();
    error NotPaused();
    error ReentrantCall();
    error ZeroAddress();
    error InvalidParams();
    error ExceedsMaxPurchase();
    error InsufficientNative();
    error NothingToClaim();
    error NotExists();
    error InvalidMilestones();
    error TransferFailed();

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

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor() {
        owner = msg.sender;
        operator = msg.sender;
        feeRecipient = msg.sender;
        feeBps = MAX_FEE_BPS; // 0.5%
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Register a new token launch by deploying a new LaunchToken.
     * @param name        Token name
     * @param symbol      Token symbol
     * @param basePrice   Base price per token (wei)
     * @param slope       Bonding curve slope (wei per token)
     * @param milestones  Sorted price milestones with cumulative unlock percentages
     * @return tokenAddress Address of the newly deployed token
     */
    function registerToken(
        string memory name,
        string memory symbol,
        uint256 basePrice,
        uint256 slope,
        PriceMilestone[] memory milestones
    ) external onlyOperator whenNotPaused returns (address tokenAddress) {
        if (basePrice == 0) revert InvalidParams();
        _validateMilestones(milestones);

        LaunchToken newToken = new LaunchToken(name, symbol, address(this));
        tokenAddress = address(newToken);

        TokenLaunch storage launch = launches[tokenAddress];
        launch.token = newToken;
        launch.basePrice = basePrice;
        launch.slope = slope;
        launch.totalSupply = 0;
        launch.nativeRaised = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            launch.milestones.push(milestones[i]);
        }
        launch.exists = true;

        emit TokenLaunchRegistered(tokenAddress, name, symbol, basePrice, slope, milestones);
    }

    /**
     * @notice Update the price milestones for an existing launch.
     * @param token       Token address
     * @param milestones  New sorted milestones
     */
    function updateMilestones(address token, PriceMilestone[] memory milestones)
        external
        onlyOperator
        whenNotPaused
    {
        TokenLaunch storage launch = launches[token];
        if (!launch.exists) revert NotExists();
        _validateMilestones(milestones);

        delete launch.milestones;
        for (uint256 i = 0; i < milestones.length; i++) {
            launch.milestones.push(milestones[i]);
        }

        emit TokenMilestonesUpdated(token, milestones);
    }

    /**
     * @notice Withdraw the net native currency raised for a launch.
     * @param token Token address
     * @param to   Recipient
     */
    function withdrawRaised(address token, address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        TokenLaunch storage launch = launches[token];
        if (!launch.exists) revert NotExists();
        uint256 amount = launch.nativeRaised;
        if (amount == 0) revert InvalidParams();
        launch.nativeRaised = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit RaisedWithdrawn(token, to, amount);
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------

    /**
     * @notice Purchase tokens by depositing native currency. Tokens are minted
     *         to the contract and locked for the buyer until price milestones are met.
     * @param token Token address to purchase
     */
    function purchase(address token) external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert InsufficientNative();
        if (msg.value > MAX_PURCHASE) revert ExceedsMaxPurchase();

        TokenLaunch storage launch = launches[token];
        if (!launch.exists) revert NotExists();

        uint256 fee = (msg.value * feeBps) / BPS_DENOMINATOR;
        uint256 netDeposit = msg.value - fee;
        accumulatedFees += fee;

        uint256 tokensMinted = _calculateTokens(
            netDeposit,
            launch.basePrice,
            launch.slope,
            launch.totalSupply
        );
        if (tokensMinted == 0) revert InsufficientNative();

        // Effects: update all state before the external mint call.
        launch.totalSupply += tokensMinted;
        launch.nativeRaised += netDeposit;
        positions[token][msg.sender].purchased += tokensMinted;

        // Interactions: mint tokens to the contract for escrow.
        launch.token.mint(address(this), tokensMinted);

        emit TokenPurchased(token, msg.sender, msg.value, tokensMinted, fee);
    }

    /**
     * @notice Claim unlocked tokens for a launch. Tokens become claimable when the
     *         bonding curve price reaches successive configured milestones.
     * @param token Token address
     */
    function claim(address token) external nonReentrant whenNotPaused {
        TokenLaunch storage launch = launches[token];
        if (!launch.exists) revert NotExists();

        UserPosition storage pos = positions[token][msg.sender];
        if (pos.purchased == 0) revert NothingToClaim();

        uint256 currentPrice = _getCurrentPrice(launch);
        uint256 milestonesLength = launch.milestones.length;
        if (milestonesLength == 0) revert InvalidMilestones();

        uint256 highestCumulative = 0;
        for (uint256 i = 0; i < milestonesLength; i++) {
            if (currentPrice >= launch.milestones[i].price) {
                highestCumulative = launch.milestones[i].cumulativePercentage;
            } else {
                break;
            }
        }

        if (highestCumulative <= pos.lastClaimedCumulative) revert NothingToClaim();

        uint256 additionalPercentage = highestCumulative - pos.lastClaimedCumulative;
        uint256 unlockable = (pos.purchased * additionalPercentage) / BPS_DENOMINATOR;
        if (unlockable == 0) revert NothingToClaim();

        // Effects: update position before external transfer.
        pos.claimed += unlockable;
        pos.lastClaimedCumulative = highestCumulative;

        // Interactions: transfer unlocked tokens to the claimer.
        if (!launch.token.transfer(msg.sender, unlockable)) revert TransferFailed();

        emit TokensClaimed(token, msg.sender, unlockable);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function getCurrentPrice(address token) external view returns (uint256) {
        TokenLaunch storage launch = launches[token];
        if (!launch.exists) revert NotExists();
        return _getCurrentPrice(launch);
    }

    function getMilestones(address token) external view returns (PriceMilestone[] memory) {
        return launches[token].milestones;
    }

    function getUserPosition(address token, address account) external view returns (UserPosition memory) {
        return positions[token][account];
    }

    function getLaunch(address token) external view returns (TokenLaunch memory) {
        return launches[token];
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------

    /**
     * @notice Set the protocol fee in basis points (capped at 0.5%).
     * @param _feeBps New fee (e.g., 50 = 0.5%)
     */
    function setFeeBps(uint16 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert InvalidParams();
        uint16 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    /**
     * @notice Set the address that receives protocol fees.
     * @param _feeRecipient New fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    /**
     * @notice Set the operator address (can register/update launches).
     * @param _operator New operator address
     */
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    /**
     * @notice Transfer contract ownership to a new address.
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Pause all purchase and claim operations.
     */
    function pause() external onlyOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract.
     */
    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Withdraw accumulated protocol fees to the fee recipient.
     */
    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert InvalidParams();
        accumulatedFees = 0;
        (bool ok, ) = payable(feeRecipient).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(feeRecipient, amount);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /**
     * @dev Validate milestones array: strictly increasing prices, non-decreasing
     *      cumulative percentages within [0, BPS_DENOMINATOR], and non-empty.
     */
    function _validateMilestones(PriceMilestone[] memory milestones) internal pure {
        if (milestones.length == 0) revert InvalidMilestones();
        uint256 prevPrice = 0;
        uint256 prevCumulative = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (milestones[i].price <= prevPrice) revert InvalidMilestones();
            if (milestones[i].cumulativePercentage < prevCumulative) revert InvalidMilestones();
            if (milestones[i].cumulativePercentage > BPS_DENOMINATOR) revert InvalidMilestones();
            prevPrice = milestones[i].price;
            prevCumulative = milestones[i].cumulativePercentage;
        }
    }

    /**
     * @dev Current bonding curve price: basePrice + slope * totalSupply.
     */
    function _getCurrentPrice(TokenLaunch storage launch) internal view returns (uint256) {
        return launch.basePrice + launch.slope * launch.totalSupply;
    }

    /**
     * @dev Solve the linear bonding curve integral for the number of tokens
     *      minted given a net native deposit `D`, base price `a`, slope `b`,
     *      and current supply `S`:
     *
     *      D = q*(a + b*S) + (b/2)*q^2
     *      => q = (sqrt((a + b*S)^2 + 2*b*D) - (a + b*S)) / b
     */
    function _calculateTokens(
        uint256 netDeposit,
        uint256 basePrice,
        uint256 slope,
        uint256 currentSupply
    ) internal pure returns (uint256) {
        if (netDeposit == 0) return 0;
        if (slope == 0) {
            return netDeposit / basePrice;
        }
        uint256 a_plus_bS = basePrice + slope * currentSupply;
        uint256 two_b_D = 2 * slope * netDeposit;
        uint256 discriminant = a_plus_bS * a_plus_bS + two_b_D;
        uint256 sqrtDisc = _sqrt(discriminant);
        uint256 numerator = sqrtDisc > a_plus_bS ? sqrtDisc - a_plus_bS : 0;
        return numerator / slope;
    }

    /**
     * @dev Integer square root (Babylonian method).
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
