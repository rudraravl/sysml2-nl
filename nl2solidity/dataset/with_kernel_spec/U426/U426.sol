// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title TreasuryBillFund
 * @notice Tokenized fund representing fractional ownership of a portfolio of
 *         short-term US Treasury bills and repurchase agreements. Users deposit
 *         stablecoins to mint fund tokens and redeem tokens for stablecoins
 *         after a 24-hour processing delay. A daily NAV per token is set by a
 *         designated operator.
 */
contract TreasuryBillFund {
    /* ------------------------------------------------------------- */
    /*  Metadata                                                      */
    /* ------------------------------------------------------------- */
    string public constant name = "Treasury Bill Fund";
    string public constant symbol = "TBF";
    uint8 public constant decimals = 18;

    /* ------------------------------------------------------------- */
    /*  Token storage                                                */
    /* ------------------------------------------------------------- */
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    /* ------------------------------------------------------------- */
    /*  Fund configuration                                           */
    /* ------------------------------------------------------------- */
    IERC20 public immutable stablecoin;

    /// @notice Net asset value per whole fund token, expressed in the
    ///         stablecoin's native units. Example: if 1 fund token is worth
    ///         1.05 USDC (1.05e6 units for a 6-decimal USDC), the NAV is
    ///         stored as 1_050_000.
    uint256 public nav;

    /// @notice Redemption fee in basis points. Default 0.05% = 5 bps.
    uint256 public redemptionFeeBps = 5;
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 1000; // 10% cap
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice 24-hour processing delay for redemptions.
    uint256 public constant REDEMPTION_DELAY = 24 hours;

    bool public depositsPaused;
    bool public redemptionsPaused;

    address public operator;
    address public pendingOperator;
    address public feeRecipient;

    /* ------------------------------------------------------------- */
    /*  Redemption requests                                          */
    /* ------------------------------------------------------------- */
    struct RedemptionRequest {
        address owner;
        uint256 tokenAmount;
        uint256 stablecoinGross;
        uint256 stablecoinNet;
        uint256 fee;
        uint256 requestedAt;
        bool claimed;
    }

    uint256 public nextRequestId = 1;
    mapping(uint256 => RedemptionRequest) public redemptionRequests;
    mapping(address => uint256[]) internal _userRequestIds;

    /* ------------------------------------------------------------- */
    /*  Events                                                       */
    /* ------------------------------------------------------------- */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed caller, address indexed owner, uint256 stablecoinAmount, uint256 tokensMinted);
    event RedemptionRequested(
        address indexed caller,
        address indexed owner,
        uint256 indexed requestId,
        uint256 tokensBurned,
        uint256 stablecoinGross,
        uint256 stablecoinNet,
        uint256 fee
    );
    event RedemptionClaimed(address indexed caller, uint256 indexed requestId, uint256 stablecoinAmount);

    event NavUpdated(uint256 oldNav, uint256 newNav);
    event DepositsPaused();
    event DepositsUnpaused();
    event RedemptionsPaused();
    event RedemptionsUnpaused();
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OperatorTransferRequested(address indexed currentOperator, address indexed newOperator);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /* ------------------------------------------------------------- */
    /*  Custom errors                                                */
    /* ------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroAmount();
    error DepositsArePaused();
    error RedemptionsArePaused();
    error NotOperator();
    error NotPendingOperator();
    error NavNotSet();
    error FeeTooHigh();
    error RedemptionNotReady();
    error RedemptionAlreadyClaimed();
    error NotRequestOwner();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserves();
    error InvalidRequest();
    error StablecoinTransferFailed();

    /* ------------------------------------------------------------- */
    /*  Modifiers                                                    */
    /* ------------------------------------------------------------- */
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier whenRedemptionsNotPaused() {
        if (redemptionsPaused) revert RedemptionsArePaused();
        _;
    }

    /* ------------------------------------------------------------- */
    /*  Constructor                                                  */
    /* ------------------------------------------------------------- */
    constructor(
        address _stablecoin,
        uint256 _initialNav,
        address _feeRecipient,
        address _operator
    ) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialNav == 0) revert NavNotSet();

        stablecoin = IERC20(_stablecoin);
        nav = _initialNav;
        feeRecipient = _feeRecipient;
        operator = _operator;

        emit NavUpdated(0, _initialNav);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit OperatorUpdated(address(0), _operator);
    }

    /* ------------------------------------------------------------- */
    /*  ERC-20 views                                                 */
    /* ------------------------------------------------------------- */
    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowance[owner_][spender];
    }

    /* ------------------------------------------------------------- */
    /*  ERC-20 transfers                                             */
    /* ------------------------------------------------------------- */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            unchecked {
                _allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowed - amount);
        }

        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = _allowance[msg.sender][spender] + addedValue;
        _allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = _allowance[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientAllowance();
        unchecked {
            current -= subtractedValue;
        }
        _allowance[msg.sender][spender] = current;
        emit Approval(msg.sender, spender, current);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    /* ------------------------------------------------------------- */
    /*  Internal mint / burn                                         */
    /* ------------------------------------------------------------- */
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    /* ------------------------------------------------------------- */
    /*  Conversion helpers                                          */
    /* ------------------------------------------------------------- */
    /**
     * @notice Converts a stablecoin amount into fund token base units (18
     *         decimals) at the current NAV.
     */
    function stablecoinToTokens(uint256 stablecoinAmount) public view returns (uint256) {
        if (nav == 0) revert NavNotSet();
        // tokens = stablecoinAmount * 1e18 / nav
        return (stablecoinAmount * 1e18) / nav;
    }

    /**
     * @notice Converts fund token base units into the stablecoin amount
     *         (gross of fees) redeemable at the current NAV.
     */
    function tokensToStablecoin(uint256 tokenAmount) public view returns (uint256) {
        if (nav == 0) revert NavNotSet();
        // stablecoin = tokenAmount * nav / 1e18
        return (tokenAmount * nav) / 1e18;
    }

    /* ------------------------------------------------------------- */
    /*  Deposit                                                     */
    /* ------------------------------------------------------------- */
    /**
     * @notice Deposit stablecoins to mint fund tokens for `receiver`.
     * @param stablecoinAmount Amount of stablecoin units to deposit.
     * @param receiver Recipient of the newly minted fund tokens.
     * @return tokensMinted Number of fund token base units minted.
     */
    function deposit(uint256 stablecoinAmount, address receiver)
        external
        whenDepositsNotPaused
        returns (uint256 tokensMinted)
    {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (nav == 0) revert NavNotSet();

        tokensMinted = stablecoinToTokens(stablecoinAmount);
        if (tokensMinted == 0) revert ZeroAmount();

        // Effects
        _mint(receiver, tokensMinted);

        // Interactions
        bool ok = stablecoin.transferFrom(msg.sender, address(this), stablecoinAmount);
        if (!ok) revert StablecoinTransferFailed();

        emit Deposit(msg.sender, receiver, stablecoinAmount, tokensMinted);
    }

    /* ------------------------------------------------------------- */
    /*  Redemption                                                  */
    /* ------------------------------------------------------------- */
    /**
     * @notice Request redemption of fund tokens. Tokens are burned immediately
     *         and a redemption request is created. The stablecoin payout can be
     *         claimed after the 24-hour processing delay.
     * @param tokenAmount Number of fund token base units to redeem.
     * @return requestId Identifier of the created redemption request.
     */
    function requestRedemption(uint256 tokenAmount)
        external
        whenRedemptionsNotPaused
        returns (uint256 requestId)
    {
        if (tokenAmount == 0) revert ZeroAmount();
        if (nav == 0) revert NavNotSet();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        uint256 gross = tokensToStablecoin(tokenAmount);
        if (gross == 0) revert ZeroAmount();

        uint256 fee = (gross * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        // Ensure the contract holds enough stablecoins to cover the net payout
        if (stablecoin.balanceOf(address(this)) < net) revert InsufficientReserves();

        // Effects: burn tokens and record request
        _burn(msg.sender, tokenAmount);

        requestId = nextRequestId++;
        redemptionRequests[requestId] = RedemptionRequest({
            owner: msg.sender,
            tokenAmount: tokenAmount,
            stablecoinGross: gross,
            stablecoinNet: net,
            fee: fee,
            requestedAt: block.timestamp,
            claimed: false
        });
        _userRequestIds[msg.sender].push(requestId);

        emit RedemptionRequested(msg.sender, msg.sender, requestId, tokenAmount, gross, net, fee);
    }

    /**
     * @notice Claim a matured redemption request and receive stablecoins.
     * @param requestId Identifier of the redemption request to claim.
     */
    function claimRedemption(uint256 requestId) external returns (uint256 payout) {
        RedemptionRequest storage req = redemptionRequests[requestId];
        if (req.owner == address(0)) revert InvalidRequest();
        if (req.claimed) revert RedemptionAlreadyClaimed();
        if (block.timestamp < req.requestedAt + REDEMPTION_DELAY) revert RedemptionNotReady();
        if (msg.sender != req.owner) revert NotRequestOwner();

        // Effects
        payout = req.stablecoinNet;
        req.claimed = true;

        // Interactions: transfer net payout to the owner
        bool ok = stablecoin.transfer(msg.sender, payout);
        if (!ok) revert StablecoinTransferFailed();

        // Transfer fee to fee recipient if configured
        if (feeRecipient != address(0) && req.fee > 0) {
            bool feeOk = stablecoin.transfer(feeRecipient, req.fee);
            if (!feeOk) revert StablecoinTransferFailed();
        }

        emit RedemptionClaimed(msg.sender, requestId, payout);
    }

    /* ------------------------------------------------------------- */
    /*  Redemption request views                                    */
    /* ------------------------------------------------------------- */
    function getRedemptionRequest(uint256 requestId)
        external
        view
        returns (
            address owner,
            uint256 tokenAmount,
            uint256 stablecoinGross,
            uint256 stablecoinNet,
            uint256 fee,
            uint256 requestedAt,
            bool claimed,
            uint256 claimableAt
        )
    {
        RedemptionRequest storage req = redemptionRequests[requestId];
        return (
            req.owner,
            req.tokenAmount,
            req.stablecoinGross,
            req.stablecoinNet,
            req.fee,
            req.requestedAt,
            req.claimed,
            req.requestedAt + REDEMPTION_DELAY
        );
    }

    function userRequestCount(address user) external view returns (uint256) {
        return _userRequestIds[user].length;
    }

    function userRequestAt(address user, uint256 index) external view returns (uint256) {
        return _userRequestIds[user][index];
    }

    function isRedemptionClaimable(uint256 requestId) external view returns (bool) {
        RedemptionRequest storage req = redemptionRequests[requestId];
        return (
            req.owner != address(0) &&
            !req.claimed &&
            block.timestamp >= req.requestedAt + REDEMPTION_DELAY
        );
    }

    /* ------------------------------------------------------------- */
    /*  Operator: NAV                                               */
    /* ------------------------------------------------------------- */
    function updateNav(uint256 newNav) external onlyOperator {
        if (newNav == 0) revert NavNotSet();
        uint256 old = nav;
        nav = newNav;
        emit NavUpdated(old, newNav);
    }

    /* ------------------------------------------------------------- */
    /*  Operator: pause controls                                    */
    /* ------------------------------------------------------------- */
    function pauseDeposits() external onlyOperator {
        if (depositsPaused) return;
        depositsPaused = true;
        emit DepositsPaused();
    }

    function unpauseDeposits() external onlyOperator {
        if (!depositsPaused) return;
        depositsPaused = false;
        emit DepositsUnpaused();
    }

    function pauseRedemptions() external onlyOperator {
        if (redemptionsPaused) return;
        redemptionsPaused = true;
        emit RedemptionsPaused();
    }

    function unpauseRedemptions() external onlyOperator {
        if (!redemptionsPaused) return;
        redemptionsPaused = false;
        emit RedemptionsUnpaused();
    }

    /* ------------------------------------------------------------- */
    /*  Operator: redemption fee                                     */
    /* ------------------------------------------------------------- */
    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_REDEMPTION_FEE_BPS) revert FeeTooHigh();
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(old, newFeeBps);
    }

    /* ------------------------------------------------------------- */
    /*  Operator: fee recipient                                     */
    /* ------------------------------------------------------------- */
    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    /* ------------------------------------------------------------- */
    /*  Operator: transfer / accept                                  */
    /* ------------------------------------------------------------- */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
        emit OperatorTransferRequested(operator, newOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();
        address old = operator;
        operator = pendingOperator;
        pendingOperator = address(0);
        emit OperatorUpdated(old, operator);
    }

    /* ------------------------------------------------------------- */
    /*  Operator: rescue mis-sent tokens                            */
    /* ------------------------------------------------------------- */
    function rescueERC20(address token, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert StablecoinTransferFailed();
    }
}
