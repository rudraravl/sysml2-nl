// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract DebtInstrumentManager {
    // --------- Custom Errors ---------
    error Unauthorized();
    error ContractPaused();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidPrincipal();
    error InvalidInterestRate();
    error InvalidMaturity();
    error CollateralNotSupported(address token);
    error CollateralAlreadySupported(address token);
    error CollateralTokenNotFound(address token);
    error MaxCollateralTokensReached();
    error BondNotFound(uint256 bondId);
    error NotBondIssuer(uint256 bondId);
    error NotBondHolder(uint256 bondId);
    error BondAlreadyRedeemed(uint256 bondId);
    error BondAlreadyDefaulted(uint256 bondId);
    error BondNotRepaid(uint256 bondId);
    error BondNotMatured(uint256 bondId);
    error BondAlreadyRepaid(uint256 bondId);
    error NoHolder(uint256 bondId);
    error AlreadyHolder(uint256 bondId);
    error TransferFailed();
    error ReentrantCall();

    // --------- Constants ---------
    uint256 public constant MAX_COLLATERAL_TOKENS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant ISSUANCE_FEE_BPS = 10; // 0.1%

    // --------- Structs ---------
    struct Bond {
        address issuer;
        address holder;
        address collateralToken;
        uint256 principal;
        uint256 interestRateBps;
        uint256 maturityDate;
        uint256 collateralAmount;
        uint256 issuanceTimestamp;
        bool issued;
        bool repaid;
        bool redeemed;
        bool defaultClaimed;
    }

    // --------- State Variables ---------
    address public operator;
    address public feeRecipient;
    bool public paused;

    mapping(address => bool) public supportedCollateral;
    address[] public collateralTokenList;

    mapping(uint256 => Bond) public bonds;
    uint256 public nextBondId;

    uint256 private _locked = 1;

    // --------- Events ---------
    event BondIssued(
        uint256 indexed bondId,
        address indexed issuer,
        address collateralToken,
        uint256 principal,
        uint256 interestRateBps,
        uint256 maturityDate,
        uint256 collateralAmount,
        uint256 fee
    );
    event CollateralDeposited(uint256 indexed bondId, address indexed depositor, uint256 amount);
    event BondPurchased(uint256 indexed bondId, address indexed holder, uint256 principalPaid);
    event BondRepaid(uint256 indexed bondId, address indexed issuer, uint256 repaymentAmount);
    event CollateralWithdrawn(uint256 indexed bondId, address indexed issuer, uint256 amount);
    event DefaultedCollateralClaimed(uint256 indexed bondId, address indexed holder, uint256 amount);
    event CollateralTokenAdded(address indexed token);
    event CollateralTokenRemoved(address indexed token);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    // --------- Modifiers ---------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --------- Constructor ---------
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    // --------- Operator Functions ---------
    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert InvalidAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function addCollateralToken(address token) external onlyOperator {
        if (token == address(0)) revert InvalidAddress();
        if (supportedCollateral[token]) revert CollateralAlreadySupported(token);
        if (collateralTokenList.length >= MAX_COLLATERAL_TOKENS) revert MaxCollateralTokensReached();
        supportedCollateral[token] = true;
        collateralTokenList.push(token);
        emit CollateralTokenAdded(token);
    }

    function removeCollateralToken(address token) external onlyOperator {
        if (!supportedCollateral[token]) revert CollateralTokenNotFound(token);
        supportedCollateral[token] = false;
        uint256 len = collateralTokenList.length;
        for (uint256 i = 0; i < len; ) {
            if (collateralTokenList[i] == token) {
                collateralTokenList[i] = collateralTokenList[len - 1];
                collateralTokenList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit CollateralTokenRemoved(token);
    }

    // --------- Bond Lifecycle ---------

    /**
     * @notice Issues a new bond, depositing collateral and paying an issuance fee.
     * @param collateralToken The ERC20 token used as collateral (must be supported).
     * @param principal The principal amount of the bond.
     * @param interestRateBps Interest rate in basis points (e.g., 500 = 5%).
     * @param maturityDate Unix timestamp when the bond matures.
     * @param collateralAmount Amount of collateral tokens to deposit.
     * @return bondId The ID of the newly created bond.
     */
    function issueBond(
        address collateralToken,
        uint256 principal,
        uint256 interestRateBps,
        uint256 maturityDate,
        uint256 collateralAmount
    ) external whenNotPaused nonReentrant returns (uint256 bondId) {
        if (collateralToken == address(0)) revert InvalidAddress();
        if (!supportedCollateral[collateralToken]) revert CollateralNotSupported(collateralToken);
        if (principal == 0) revert InvalidPrincipal();
        if (interestRateBps == 0 || interestRateBps > BPS_DENOMINATOR) revert InvalidInterestRate();
        if (maturityDate <= block.timestamp) revert InvalidMaturity();
        if (collateralAmount == 0) revert InvalidAmount();

        uint256 fee = (principal * ISSUANCE_FEE_BPS) / BPS_DENOMINATOR;

        // Effects: record bond state before any external interactions
        bondId = nextBondId++;
        Bond storage b = bonds[bondId];
        b.issuer = msg.sender;
        b.collateralToken = collateralToken;
        b.principal = principal;
        b.interestRateBps = interestRateBps;
        b.maturityDate = maturityDate;
        b.collateralAmount = collateralAmount;
        b.issuanceTimestamp = block.timestamp;
        b.issued = true;

        // Interactions: pull collateral from issuer
        _safeTransferFrom(collateralToken, msg.sender, address(this), collateralAmount);

        // Interactions: pull fee from issuer and forward to feeRecipient
        if (fee > 0) {
            _safeTransferFrom(collateralToken, msg.sender, feeRecipient, fee);
        }

        emit BondIssued(
            bondId,
            msg.sender,
            collateralToken,
            principal,
            interestRateBps,
            maturityDate,
            collateralAmount,
            fee
        );
    }

    /**
     * @notice Deposits additional collateral into an existing bond.
     * @param bondId The ID of the bond.
     * @param amount The amount of collateral tokens to deposit.
     */
    function depositCollateral(uint256 bondId, uint256 amount) external whenNotPaused nonReentrant {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        if (b.redeemed) revert BondAlreadyRedeemed(bondId);
        if (b.defaultClaimed) revert BondAlreadyDefaulted(bondId);
        if (amount == 0) revert InvalidAmount();

        // Effects: update collateral balance before external transfer
        b.collateralAmount += amount;

        // Interactions: pull collateral from depositor
        _safeTransferFrom(b.collateralToken, msg.sender, address(this), amount);

        emit CollateralDeposited(bondId, msg.sender, amount);
    }

    /**
     * @notice Allows a holder to purchase a bond by paying the principal to the issuer.
     * @param bondId The ID of the bond to purchase.
     */
    function purchaseBond(uint256 bondId) external whenNotPaused nonReentrant {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        if (b.holder != address(0)) revert AlreadyHolder(bondId);
        if (b.repaid) revert BondAlreadyRepaid(bondId);
        if (b.defaultClaimed) revert BondAlreadyDefaulted(bondId);

        uint256 principalPaid = b.principal;

        // Effects: assign holder before external transfer
        b.holder = msg.sender;

        // Interactions: holder pays principal to issuer in the collateral token
        _safeTransferFrom(b.collateralToken, msg.sender, b.issuer, principalPaid);

        emit BondPurchased(bondId, msg.sender, principalPaid);
    }

    /**
     * @notice Repays a bond: issuer pays principal + interest to the holder.
     * @param bondId The ID of the bond to repay.
     */
    function repayBond(uint256 bondId) external whenNotPaused nonReentrant {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        if (b.holder == address(0)) revert NoHolder(bondId);
        if (b.repaid) revert BondAlreadyRepaid(bondId);
        if (msg.sender != b.issuer) revert NotBondIssuer(bondId);

        uint256 repayment = b.principal + ((b.principal * b.interestRateBps) / BPS_DENOMINATOR);
        address holder = b.holder;

        // Effects: mark as repaid before external transfer
        b.repaid = true;

        // Interactions: issuer pays repayment to holder
        _safeTransferFrom(b.collateralToken, msg.sender, holder, repayment);

        emit BondRepaid(bondId, msg.sender, repayment);
    }

    /**
     * @notice Withdraws collateral after the bond has been repaid.
     * @param bondId The ID of the bond.
     */
    function withdrawCollateral(uint256 bondId) external whenNotPaused nonReentrant {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        if (msg.sender != b.issuer) revert NotBondIssuer(bondId);
        if (!b.repaid) revert BondNotRepaid(bondId);
        if (b.redeemed) revert BondAlreadyRedeemed(bondId);

        address issuer = b.issuer;
        address token = b.collateralToken;

        // Effects: finalize withdrawal state before external transfer
        uint256 amount = b.collateralAmount;
        b.redeemed = true;
        b.collateralAmount = 0;

        // Interactions: return collateral to issuer
        _safeTransfer(token, issuer, amount);

        emit CollateralWithdrawn(bondId, issuer, amount);
    }

    /**
     * @notice Claims collateral if the bond has defaulted (maturity passed without repayment).
     *         Only the bond holder may claim.
     * @param bondId The ID of the bond.
     */
    function claimDefaultedCollateral(uint256 bondId) external whenNotPaused nonReentrant {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        if (b.holder == address(0)) revert NoHolder(bondId);
        if (msg.sender != b.holder) revert NotBondHolder(bondId);
        if (b.repaid) revert BondAlreadyRepaid(bondId);
        if (block.timestamp < b.maturityDate) revert BondNotMatured(bondId);
        if (b.defaultClaimed) revert BondAlreadyDefaulted(bondId);

        address holder = b.holder;
        address token = b.collateralToken;

        // Effects: finalize default claim state before external transfer
        uint256 amount = b.collateralAmount;
        b.defaultClaimed = true;
        b.collateralAmount = 0;

        // Interactions: transfer collateral to holder
        _safeTransfer(token, holder, amount);

        emit DefaultedCollateralClaimed(bondId, holder, amount);
    }

    // --------- View Functions ---------

    function getBond(uint256 bondId) external view returns (Bond memory) {
        if (!bonds[bondId].issued) revert BondNotFound(bondId);
        return bonds[bondId];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return collateralTokenList;
    }

    function collateralTokenCount() external view returns (uint256) {
        return collateralTokenList.length;
    }

    function totalBonds() external view returns (uint256) {
        return nextBondId;
    }

    function repaymentAmount(uint256 bondId) external view returns (uint256) {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        return b.principal + ((b.principal * b.interestRateBps) / BPS_DENOMINATOR);
    }

    function issuanceFee(uint256 principal) external pure returns (uint256) {
        return (principal * ISSUANCE_FEE_BPS) / BPS_DENOMINATOR;
    }

    function isBondDefaulted(uint256 bondId) external view returns (bool) {
        Bond storage b = bonds[bondId];
        if (!b.issued) revert BondNotFound(bondId);
        return (!b.repaid && block.timestamp >= b.maturityDate);
    }

    // --------- Internal Helpers ---------

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
