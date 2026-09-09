// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal IERC20 interface (inline to avoid external imports).
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Minimal mintable ERC20 extension.
 */
interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @dev Inline SafeERC20 helpers.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Inline Ownable.
 */
abstract contract Ownable {
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
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @dev Inline ReentrancyGuard.
 */
abstract contract ReentrancyGuard {
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

/**
 * @title BondingCurveLaunch
 * @notice Facilitates token launches via a linear bonding curve with a 2% treasury fee.
 * @dev The bonding curve sells project tokens for a base currency; the price increases
 *      linearly from `startPrice` to a maximum of 10x `startPrice` as the minted supply
 *      grows. Project tokens must be mintable by this contract. Users deposit base
 *      currency to receive project tokens (minted to the contract and allocated to the
 *      user), then call `withdraw` to take the tokens. The operator may withdraw base
 *      currency for project funding while the project is active; once the operator
 *      concludes the project, participants can claim a proportional share of any
 *      remaining base currency still held by the contract.
 */
contract BondingCurveLaunch is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --------------------- Constants ---------------------
    uint256 public constant TREASURY_FEE_BPS = 200;       // 2% fee on purchases
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_PRICE_MULTIPLIER = 10;   // price caps at 10x startPrice
    uint256 public constant MAX_START_PRICE = 1e20;      // bound to prevent overflow
    uint256 public constant MAX_TOTAL_SUPPLY = 1e27;     // bound to prevent overflow

    // --------------------- State ---------------------
    enum ProjectState { Pending, Active, Concluded }

    IERC20 public immutable baseCurrency;
    address public operator;
    address public treasury;

    ProjectState public projectState;
    IMintableERC20 public projectToken;
    uint256 public startPrice;            // base units per 1 raw project token unit
    uint256 public maxPrice;              // = MAX_PRICE_MULTIPLIER * startPrice
    uint256 public projectTokenTotalSupply;
    uint256 public currentSupplyMinted;   // total project tokens allocated via the curve

    uint256 public totalBaseCurrencyDeposited; // gross base collected (incl. fees)
    uint256 public totalFeeCollected;          // cumulative fees sent to treasury
    uint256 public totalClaimableBase;         // snapshot of base balance at conclusion
    uint256 public concludedAt;                // timestamp of conclusion

    mapping(address => uint256) public userProjectTokens; // allocated tokens (not yet withdrawn)
    mapping(address => uint256) public userBaseDeposited;  // base deposited by user (gross)
    mapping(address => bool) public userClaimedBase;      // whether user has claimed base refund

    // --------------------- Events ---------------------
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event ProjectConfigured(
        address indexed projectToken,
        uint256 startPrice,
        uint256 maxPrice,
        uint256 totalSupply
    );
    event ProjectLaunched(
        address indexed projectToken,
        uint256 startPrice,
        uint256 maxPrice,
        uint256 totalSupply,
        uint256 timestamp
    );
    event Purchased(
        address indexed buyer,
        uint256 baseAmount,
        uint256 projectTokenAmount,
        uint256 fee,
        uint256 priceAfter
    );
    event ProjectTokensWithdrawn(address indexed user, uint256 amount);
    event ProjectConcluded(uint256 totalClaimableBase, uint256 timestamp);
    event BaseCurrencyClaimed(address indexed user, uint256 amount);
    event OperatorBaseWithdrawn(address indexed treasury, uint256 amount);

    // --------------------- Errors ---------------------
    error ZeroAddress();
    error ZeroAmount();
    error NotOperator();
    error InvalidState(ProjectState expected, ProjectState actual);
    error StartPriceOutOfRange();
    error TotalSupplyOutOfRange();
    error MaxPriceOverflow();
    error ExceedsTotalSupply();
    error InsufficientAllocatedTokens();
    error NothingToClaim();
    error AlreadyClaimed();
    error ProjectNotConfigured();
    error DepositTooSmall();

    // --------------------- Modifiers ---------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyState(ProjectState expected) {
        if (projectState != expected) revert InvalidState(expected, projectState);
        _;
    }

    // --------------------- Constructor ---------------------
    constructor(address baseCurrency_, address treasury_) Ownable(msg.sender) {
        if (baseCurrency_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(baseCurrency_);
        treasury = treasury_;
        operator = msg.sender;
        projectState = ProjectState.Pending;
    }

    // --------------------- Admin ---------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    // --------------------- Operator: project lifecycle ---------------------
    /**
     * @notice Configures the project token and bonding curve parameters.
     * @dev Can only be called once, while the project is in the Pending state.
     *      The operator must grant minting rights on `projectToken_` to this contract
     *      before calling `launchProject`.
     */
    function configureProject(
        address projectToken_,
        uint256 startPrice_,
        uint256 totalSupply_
    ) external onlyOperator onlyState(ProjectState.Pending) {
        if (projectToken_ == address(0)) revert ZeroAddress();
        if (startPrice_ == 0 || startPrice_ > MAX_START_PRICE) revert StartPriceOutOfRange();
        if (totalSupply_ == 0 || totalSupply_ > MAX_TOTAL_SUPPLY) revert TotalSupplyOutOfRange();

        uint256 maxPrice_ = startPrice_ * MAX_PRICE_MULTIPLIER;
        if (maxPrice_ / MAX_PRICE_MULTIPLIER != startPrice_) revert MaxPriceOverflow();

        projectToken = IMintableERC20(projectToken_);
        startPrice = startPrice_;
        maxPrice = maxPrice_;
        projectTokenTotalSupply = totalSupply_;
        currentSupplyMinted = 0;
        totalBaseCurrencyDeposited = 0;
        totalFeeCollected = 0;
        totalClaimableBase = 0;
        concludedAt = 0;

        emit ProjectConfigured(projectToken_, startPrice_, maxPrice_, totalSupply_);
    }

    /**
     * @notice Launches the configured project, enabling deposits.
     */
    function launchProject() external onlyOperator onlyState(ProjectState.Pending) {
        if (address(projectToken) == address(0)) revert ProjectNotConfigured();
        projectState = ProjectState.Active;
        emit ProjectLaunched(
            address(projectToken),
            startPrice,
            maxPrice,
            projectTokenTotalSupply,
            block.timestamp
        );
    }

    /**
     * @notice Allows the operator to withdraw base currency for project funding.
     * @dev Only callable while the project is Active. Whatever base remains in the
     *      contract at conclusion becomes the pool that participants can claim from.
     */
    function operatorWithdrawBase(uint256 amount)
        external
        onlyOperator
        onlyState(ProjectState.Active)
    {
        if (amount == 0) revert ZeroAmount();
        baseCurrency.safeTransfer(treasury, amount);
        emit OperatorBaseWithdrawn(treasury, amount);
    }

    /**
     * @notice Concludes the project, snapshotting the remaining base currency for refunds.
     */
    function concludeProject() external onlyOperator onlyState(ProjectState.Active) {
        projectState = ProjectState.Concluded;
        totalClaimableBase = baseCurrency.balanceOf(address(this));
        concludedAt = block.timestamp;
        emit ProjectConcluded(totalClaimableBase, block.timestamp);
    }

    // --------------------- User actions ---------------------
    /**
     * @notice Deposits `baseAmount` of base currency to purchase project tokens at the
     *         current bonding curve price. A 2% fee is forwarded to the treasury; the
     *         remaining amount is applied to the curve. Project tokens are minted to
     *         the contract and allocated to the caller, who must call `withdraw` to
     *         receive them.
     */
    function deposit(uint256 baseAmount)
        external
        nonReentrant
        onlyState(ProjectState.Active)
    {
        if (baseAmount == 0) revert ZeroAmount();

        // Pull base currency from the user (interaction).
        baseCurrency.safeTransferFrom(msg.sender, address(this), baseAmount);

        // Compute fee (2%) and amount applied to the bonding curve.
        uint256 fee = (baseAmount * TREASURY_FEE_BPS) / BPS_DENOMINATOR;
        uint256 curveAmount = baseAmount - fee;

        // Send the fee to the treasury (interaction).
        if (fee > 0) {
            baseCurrency.safeTransfer(treasury, fee);
        }

        // Compute project tokens to mint via the bonding curve (checks).
        uint256 tokensToMint = _computeTokensForBase(curveAmount);
        if (tokensToMint == 0) revert DepositTooSmall();
        if (currentSupplyMinted + tokensToMint > projectTokenTotalSupply) {
            revert ExceedsTotalSupply();
        }

        // Effects.
        currentSupplyMinted += tokensToMint;
        userProjectTokens[msg.sender] += tokensToMint;
        userBaseDeposited[msg.sender] += baseAmount;
        totalBaseCurrencyDeposited += baseAmount;
        totalFeeCollected += fee;

        // Mint project tokens to the contract; the user claims them via `withdraw`.
        projectToken.mint(address(this), tokensToMint);

        emit Purchased(msg.sender, baseAmount, tokensToMint, fee, _currentPrice());
    }

    /**
     * @notice Withdraws previously allocated project tokens to the caller's wallet.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (address(projectToken) == address(0)) revert ProjectNotConfigured();
        uint256 allocated = userProjectTokens[msg.sender];
        if (amount > allocated) revert InsufficientAllocatedTokens();

        // Effect.
        userProjectTokens[msg.sender] = allocated - amount;
        // Interaction.
        IERC20(address(projectToken)).safeTransfer(msg.sender, amount);

        emit ProjectTokensWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Claims the caller's proportional share of the remaining base currency
     *         after the project has been concluded. Can only be called once per user.
     */
    function claimBaseCurrency()
        external
        nonReentrant
        onlyState(ProjectState.Concluded)
    {
        if (userClaimedBase[msg.sender]) revert AlreadyClaimed();
        uint256 userDeposited = userBaseDeposited[msg.sender];
        if (userDeposited == 0) revert NothingToClaim();
        if (totalBaseCurrencyDeposited == 0) revert NothingToClaim();

        // Effect.
        userClaimedBase[msg.sender] = true;
        // Interaction.
        uint256 share = (totalClaimableBase * userDeposited) / totalBaseCurrencyDeposited;
        baseCurrency.safeTransfer(msg.sender, share);

        emit BaseCurrencyClaimed(msg.sender, share);
    }

    // --------------------- Views ---------------------
    function currentPrice() external view returns (uint256) {
        if (projectState == ProjectState.Pending) revert ProjectNotConfigured();
        return _currentPrice();
    }

    function getPriceAtSupply(uint256 supply) external view returns (uint256) {
        if (projectState == ProjectState.Pending) revert ProjectNotConfigured();
        return _priceAt(supply);
    }

    function getPurchaseCost(uint256 tokens) external view returns (uint256) {
        if (projectState == ProjectState.Pending) revert ProjectNotConfigured();
        if (currentSupplyMinted + tokens > projectTokenTotalSupply)
            revert ExceedsTotalSupply();
        return _computeCost(currentSupplyMinted, tokens);
    }

    function getTokensForBase(uint256 baseAmount) external view returns (uint256) {
        if (projectState == ProjectState.Pending) revert ProjectNotConfigured();
        uint256 fee = (baseAmount * TREASURY_FEE_BPS) / BPS_DENOMINATOR;
        return _computeTokensForBase(baseAmount - fee);
    }

    function getUserInfo(address user)
        external
        view
        returns (uint256 allocated, uint256 deposited, bool claimed)
    {
        return (userProjectTokens[user], userBaseDeposited[user], userClaimedBase[user]);
    }

    function remainingSupply() external view returns (uint256) {
        if (projectState == ProjectState.Pending) revert ProjectNotConfigured();
        return projectTokenTotalSupply - currentSupplyMinted;
    }

    // --------------------- Internal: bonding curve math ---------------------
    /**
     * @dev Price at a given minted supply:
     *      p(s) = startPrice + (maxPrice - startPrice) * s / T
     *      where T = projectTokenTotalSupply.
     */
    function _priceAt(uint256 supply) internal view returns (uint256) {
        return startPrice + ((maxPrice - startPrice) * supply) / projectTokenTotalSupply;
    }

    function _currentPrice() internal view returns (uint256) {
        return _priceAt(currentSupplyMinted);
    }

    /**
     * @dev Cost (in base currency) to mint `t` tokens starting from supply `s1`.
     *      cost = ∫_{s1}^{s1+t} p(s) ds
     *           = startPrice * t + (maxPrice - startPrice) * t * (2*s1 + t) / (2 * T)
     *      Overflow-safe for startPrice ≤ 1e20 and T ≤ 1e27 (bounded in `configureProject`).
     */
    function _computeCost(uint256 s1, uint256 t) internal view returns (uint256) {
        uint256 T = projectTokenTotalSupply;
        uint256 linearTerm = startPrice * t;
        // (maxPrice - startPrice) * t * (2*s1 + t) ≤ 9 * 1e20 * 1e27 * 3e27 = 2.7e75
        uint256 quadTerm = ((maxPrice - startPrice) * t * (2 * s1 + t)) / (2 * T);
        return linearTerm + quadTerm;
    }

    /**
     * @dev Number of project tokens minted for `baseAmount` starting from the current supply.
     *      Closed-form inversion of the linear curve. With u(s) = T + 9*s, the cost
     *      simplifies to startPrice * (u(s2)^2 - u(s1)^2) / (18 * T). Solving for s2:
     *          u2 = sqrt(u1^2 + baseAmount * 18 * T / startPrice)
     *          s2 = (u2 - T) / 9
     *      All intermediate values are bounded by ~2e56 (for T = 1e27), well within uint256.
     */
    function _computeTokensForBase(uint256 baseAmount) internal view returns (uint256) {
        if (baseAmount == 0) return 0;
        uint256 s1 = currentSupplyMinted;
        uint256 T = projectTokenTotalSupply;
        if (s1 >= T) return 0;
        uint256 remaining = T - s1;

        // Cap: if baseAmount can buy all remaining tokens, return remaining.
        uint256 maxCost = _computeCost(s1, remaining);
        if (baseAmount >= maxCost) {
            return remaining;
        }

        // u1 = T + 9*s1, bounded by 10*T ≤ 1e28.
        uint256 u1 = 9 * s1 + T;
        // u1² bounded by 100*T² ≤ 1e56.
        uint256 u1Squared = u1 * u1;
        // addend = baseAmount * 18 * T / startPrice; bounded by ~99*T² ≤ 9.9e75.
        uint256 addend = (baseAmount * 18 * T) / startPrice;
        // u2² bounded by ~200*T² ≤ 2e56.
        uint256 u2Squared = u1Squared + addend;
        // u2 bounded by ~14*T ≤ 1.5e28.
        uint256 u2 = _sqrt(u2Squared);

        if (u2 < T) return 0;            // defensive; u2 ≥ u1 ≥ T
        uint256 s2 = (u2 - T) / 9;
        if (s2 > T) s2 = T;              // defensive
        if (s2 < s1) return 0;            // defensive
        return s2 - s1;
    }

    /**
     * @dev Babylonian integer square root (floor). Adapted from Uniswap V2.
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
