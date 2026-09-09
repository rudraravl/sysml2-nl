// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal ERC-20 interface used by the DETFManager.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Minimal SafeERC20 implementation that wraps IERC20 calls with
 *      revert-on-failure semantics, avoiding external dependencies.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
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
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @title DETFManager
 * @notice Manages a registry of decentralized exchange-traded funds (dETFs).
 *         Each dETF is defined by a composition of underlying ERC-20 tokens and
 *         per-unit weightings. Users mint dETF tokens by depositing the required
 *         underlying assets and redeem them for a proportional share of the
 *         underlying assets, net of a 0.2% redemption fee. A governance committee
 *         approves new dETF proposals within a 72-hour window, and a designated
 *         operator may update the composition of existing dETFs.
 */
contract DETFManager {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Redemption fee in basis points (0.2%).
    uint256 public constant REDEMPTION_FEE_BPS = 20;
    /// @dev Basis points denominator.
    uint256 public constant BPS_DENOM = 10000;
    /// @dev One full dETF unit, analogous to 1e18 of an ERC-20.
    uint256 public constant UNIT = 1e18;
    /// @dev Window during which a proposed dETF may be approved by governance.
    uint256 public constant APPROVAL_WINDOW = 72 hours;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAdmin();
    error NotOperator();
    error NotGovernor();
    error ETFNotFound();
    error ETFNotApproved();
    error ETFNotActive();
    error ETFAlreadyApproved();
    error ETFProposalExpired();
    error ETFAlreadyVoted();
    error InvalidComposition();
    error DuplicateToken();
    error ZeroAddress();
    error InsufficientBalance();
    error AmountZero();
    error AlreadyGovernor();
    error GovernorNotFound();
    error TransferToZeroAddress();
    error Reentrancy();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ETFProposed(
        uint256 indexed etfId,
        address indexed proposer,
        string name,
        string symbol,
        address[] tokens,
        uint256[] weights
    );
    event ETFApproved(uint256 indexed etfId, address indexed governor, uint256 approvalCount);
    event ETFActivated(uint256 indexed etfId);
    event ETFMinted(uint256 indexed etfId, address indexed account, uint256 amount);
    event ETFBurned(uint256 indexed etfId, address indexed account, uint256 amount);
    event CompositionUpdated(
        uint256 indexed etfId,
        address indexed operator,
        address[] tokens,
        uint256[] weights
    );
    event ETFTransfer(uint256 indexed etfId, address indexed from, address indexed to, uint256 amount);
    event FeeCollected(uint256 indexed etfId, address indexed feeRecipient, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event GovernorAdded(address indexed governor);
    event GovernorRemoved(address indexed governor);

    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    struct ETF {
        string name;
        string symbol;
        address[] tokens;
        uint256[] weights; // amount of underlying per UNIT (1e18) of dETF
        bool active;
        bool approved;
        uint256 proposedAt;
        uint256 approvalCount;
        uint256 totalSupply;
        mapping(address => bool) approvals;
        mapping(address => uint256) balances;
    }

    /*//////////////////////////////////////////////////////////////
                              STATE
    //////////////////////////////////////////////////////////////*/

    address public admin;
    address public operator;
    address public feeRecipient;

    address[] private _governors;
    mapping(address => bool) public isGovernor;

    uint256 public nextEtfId;
    mapping(uint256 => ETF) internal _etfs;

    /// @dev Reentrancy guard slot. Non-zero while a protected function is executing.
    uint256 private _locked;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyGovernor() {
        if (!isGovernor[msg.sender]) revert NotGovernor();
        _;
    }

    modifier etfExists(uint256 etfId) {
        if (etfId >= nextEtfId) revert ETFNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert Reentrancy();
        _locked = 1;
        _;
        _locked = 0;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address operator_,
        address feeRecipient_,
        address[] memory governors_
    ) {
        if (operator_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();

        admin = msg.sender;
        operator = operator_;
        feeRecipient = feeRecipient_;

        for (uint256 i = 0; i < governors_.length; ) {
            address g = governors_[i];
            if (g == address(0)) revert ZeroAddress();
            if (isGovernor[g]) revert AlreadyGovernor();
            isGovernor[g] = true;
            _governors.push(g);
            emit GovernorAdded(g);
            unchecked {
                ++i;
            }
        }

        // Reserve id 0 as a sentinel; first real dETF starts at 1.
        nextEtfId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE / ADMIN
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyAdmin {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyAdmin {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function addGovernor(address governor) external onlyAdmin {
        if (governor == address(0)) revert ZeroAddress();
        if (isGovernor[governor]) revert AlreadyGovernor();
        isGovernor[governor] = true;
        _governors.push(governor);
        emit GovernorAdded(governor);
    }

    function removeGovernor(address governor) external onlyAdmin {
        if (!isGovernor[governor]) revert GovernorNotFound();
        isGovernor[governor] = false;
        uint256 len = _governors.length;
        for (uint256 i = 0; i < len; ) {
            if (_governors[i] == governor) {
                _governors[i] = _governors[len - 1];
                _governors.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit GovernorRemoved(governor);
    }

    function governorCount() external view returns (uint256) {
        return _governors.length;
    }

    /*//////////////////////////////////////////////////////////////
                         dETF LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Proposes a new dETF composition. The proposal must be approved by
     *         a majority of the governance committee within 72 hours.
     */
    function proposeETF(
        string calldata name,
        string calldata symbol,
        address[] calldata tokens,
        uint256[] calldata weights
    ) external nonReentrant returns (uint256 etfId) {
        _validateComposition(tokens, weights);

        etfId = nextEtfId++;
        ETF storage etf = _etfs[etfId];
        etf.name = name;
        etf.symbol = symbol;
        etf.tokens = tokens;
        etf.weights = weights;
        etf.proposedAt = block.timestamp;
        etf.active = false;
        etf.approved = false;

        emit ETFProposed(etfId, msg.sender, name, symbol, tokens, weights);
    }

    /**
     * @notice Records a governance vote in favor of a proposed dETF. Once a
     *         majority of governors have voted within the approval window, the
     *         dETF is activated and becomes mintable.
     */
    function approveETF(uint256 etfId) external etfExists(etfId) onlyGovernor nonReentrant {
        ETF storage etf = _etfs[etfId];
        if (etf.approved) revert ETFAlreadyApproved();
        if (block.timestamp > etf.proposedAt + APPROVAL_WINDOW) revert ETFProposalExpired();
        if (etf.approvals[msg.sender]) revert ETFAlreadyVoted();

        etf.approvals[msg.sender] = true;
        etf.approvalCount += 1;

        emit ETFApproved(etfId, msg.sender, etf.approvalCount);

        // Majority threshold: strictly more than half of the committee.
        if (etf.approvalCount * 2 > _governors.length) {
            etf.approved = true;
            etf.active = true;
            emit ETFActivated(etfId);
        }
    }

    /**
     * @notice Updates the composition of an existing, approved dETF. Only the
     *         designated operator may call this.
     */
    function updateComposition(
        uint256 etfId,
        address[] calldata tokens,
        uint256[] calldata weights
    ) external etfExists(etfId) onlyOperator nonReentrant {
        ETF storage etf = _etfs[etfId];
        if (!etf.approved) revert ETFNotApproved();
        _validateComposition(tokens, weights);

        etf.tokens = tokens;
        etf.weights = weights;

        emit CompositionUpdated(etfId, msg.sender, tokens, weights);
    }

    /*//////////////////////////////////////////////////////////////
                         MINT / REDEEM / TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints `amount` dETF units of `etfId` to the caller by pulling the
     *         required underlying assets from the caller's balance. State is
     *         updated before external token transfers to follow the
     *         checks-effects-interactions pattern and prevent reentrancy.
     */
    function mint(uint256 etfId, uint256 amount) external etfExists(etfId) nonReentrant {
        if (amount == 0) revert AmountZero();
        ETF storage etf = _etfs[etfId];
        if (!etf.active) revert ETFNotActive();

        // Effects: credit the caller and increase total supply before
        // pulling underlying tokens so that any reentrant call observes
        // the already-updated state.
        etf.balances[msg.sender] += amount;
        etf.totalSupply += amount;

        // Interactions: pull the required underlying assets.
        address[] storage tokens = etf.tokens;
        uint256[] storage weights = etf.weights;
        uint256 len = tokens.length;

        for (uint256 i = 0; i < len; ) {
            uint256 required = (weights[i] * amount) / UNIT;
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), required);
            unchecked {
                ++i;
            }
        }

        emit ETFMinted(etfId, msg.sender, amount);
        emit ETFTransfer(etfId, address(0), msg.sender, amount);
    }

    /**
     * @notice Redeems `amount` dETF units of `etfId`, returning a proportional
     *         share of the underlying assets net of a 0.2% fee. The fee portion
     *         of the underlying assets is forwarded to the fee recipient.
     */
    function redeem(uint256 etfId, uint256 amount) external etfExists(etfId) nonReentrant {
        if (amount == 0) revert AmountZero();
        ETF storage etf = _etfs[etfId];
        if (!etf.active) revert ETFNotActive();

        uint256 balance = etf.balances[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        // Effects.
        etf.balances[msg.sender] = balance - amount;
        etf.totalSupply -= amount;

        uint256 feeAmount = (amount * REDEMPTION_FEE_BPS) / BPS_DENOM;
        uint256 netAmount = amount - feeAmount;

        address[] storage tokens = etf.tokens;
        uint256[] storage weights = etf.weights;
        uint256 len = tokens.length;

        for (uint256 i = 0; i < len; ) {
            uint256 gross = weights[i] * amount;
            uint256 userShare = (weights[i] * netAmount) / UNIT;
            uint256 feeShare = (gross / UNIT) - userShare;

            if (userShare > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, userShare);
            }
            if (feeShare > 0) {
                IERC20(tokens[i]).safeTransfer(feeRecipient, feeShare);
            }
            unchecked {
                ++i;
            }
        }

        emit ETFBurned(etfId, msg.sender, amount);
        emit ETFTransfer(etfId, msg.sender, address(0), amount);
        if (feeAmount > 0) {
            emit FeeCollected(etfId, feeRecipient, feeAmount);
        }
    }

    /**
     * @notice Transfers `amount` dETF units of `etfId` from the caller to `to`.
     */
    function transfer(uint256 etfId, address to, uint256 amount) external etfExists(etfId) nonReentrant {
        if (to == address(0)) revert TransferToZeroAddress();
        if (amount == 0) revert AmountZero();

        ETF storage etf = _etfs[etfId];
        uint256 balance = etf.balances[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        etf.balances[msg.sender] = balance - amount;
        etf.balances[to] += amount;

        emit ETFTransfer(etfId, msg.sender, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(uint256 etfId, address account) external view etfExists(etfId) returns (uint256) {
        return _etfs[etfId].balances[account];
    }

    function totalSupplyOf(uint256 etfId) external view etfExists(etfId) returns (uint256) {
        return _etfs[etfId].totalSupply;
    }

    function getETF(uint256 etfId)
        external
        view
        etfExists(etfId)
        returns (
            string memory name,
            string memory symbol,
            address[] memory tokens,
            uint256[] memory weights,
            bool active,
            bool approved,
            uint256 proposedAt,
            uint256 approvalCount,
            uint256 totalSupply
        )
    {
        ETF storage etf = _etfs[etfId];
        return (
            etf.name,
            etf.symbol,
            etf.tokens,
            etf.weights,
            etf.active,
            etf.approved,
            etf.proposedAt,
            etf.approvalCount,
            etf.totalSupply
        );
    }

    function hasVoted(uint256 etfId, address governor) external view etfExists(etfId) returns (bool) {
        return _etfs[etfId].approvals[governor];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _validateComposition(address[] calldata tokens, uint256[] calldata weights) internal pure {
        uint256 len = tokens.length;
        if (len == 0) revert InvalidComposition();
        if (weights.length != len) revert InvalidComposition();

        for (uint256 i = 0; i < len; ) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (weights[i] == 0) revert InvalidComposition();
            // Ensure no duplicate tokens.
            for (uint256 j = i + 1; j < len; ) {
                if (tokens[i] == tokens[j]) revert DuplicateToken();
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
