// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TokenizedPortfolioManager
/// @notice Creates and manages tokenized portfolios whose tokens are backed by
///         baskets of underlying ERC-20 component tokens. Each portfolio token
///         represents a fixed quantity of each underlying component, minted by
///         depositing those components and redeemed for a proportional share.
contract TokenizedPortfolioManager {
    using SafeERC20 for IERC20;

    /* ==================== CONSTANTS ==================== */
    uint256 public constant MAX_COMPONENTS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap

    /* ==================== STATE ==================== */
    address public owner;
    address public operator;
    uint256 public creationFeeBps;
    uint256 public nextPortfolioId;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    struct Portfolio {
        address[] components;
        uint256[] quantities;
        uint256 totalSupply;
        bool active;
    }

    mapping(uint256 => Portfolio) private portfolios;
    mapping(uint256 => mapping(address => uint256)) private portfolioBalances;
    mapping(uint256 => mapping(address => mapping(address => uint256))) private portfolioAllowances;
    uint256[] public allPortfolioIds;

    /* ==================== EVENTS ==================== */
    event PortfolioCreated(uint256 indexed id, address[] components, uint256[] quantities);
    event Minted(
        uint256 indexed id,
        address indexed caller,
        address indexed to,
        uint256 amount,
        uint256[] amountsDeposited,
        uint256[] feesCollected
    );
    event Redeemed(
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256[] amountsWithdrawn
    );
    event Rebalanced(uint256 indexed id, address[] newComponents, uint256[] newQuantities);
    event CreationFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PortfolioTransfer(uint256 indexed id, address indexed from, address indexed to, uint256 amount);
    event PortfolioApproval(uint256 indexed id, address indexed tokenOwner, address indexed spender, uint256 amount);

    /* ==================== ERRORS ==================== */
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error PortfolioNotFound();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidFee();
    error ArrayLengthMismatch();
    error TooManyComponents();
    error DuplicateComponent();
    error ReentrantCall();

    /* ==================== MODIFIERS ==================== */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier portfolioExists(uint256 id) {
        if (!portfolios[id].active) revert PortfolioNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /* ==================== CONSTRUCTOR ==================== */
    /// @param _operator Address authorized to rebalance portfolios.
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        creationFeeBps = 10; // 0.1%
        nextPortfolioId = 1;
        _reentrancyStatus = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit CreationFeeUpdated(0, creationFeeBps);
    }

    /* ==================== PORTFOLIO CREATION ==================== */
    /// @notice Creates a new tokenized portfolio with the given composition.
    /// @param components Component token addresses (max 10, distinct, non-zero).
    /// @param quantities Amount of each component backing a single portfolio token.
    /// @return id Newly assigned portfolio id.
    function createPortfolio(
        address[] calldata components,
        uint256[] calldata quantities
    ) external returns (uint256 id) {
        _validateComposition(components, quantities);

        id = nextPortfolioId++;
        Portfolio storage p = portfolios[id];
        p.components = components;
        p.quantities = quantities;
        p.totalSupply = 0;
        p.active = true;

        allPortfolioIds.push(id);

        emit PortfolioCreated(id, components, quantities);
    }

    /* ==================== MINT ==================== */
    /// @notice Mints `amount` portfolio tokens to `to` by pulling required components.
    ///         A creation fee (in component tokens) is also pulled and sent to the owner.
    /// @param id Portfolio id.
    /// @param amount Number of portfolio tokens to mint.
    /// @param to Recipient of minted portfolio tokens.
    function mint(
        uint256 id,
        uint256 amount,
        address to
    ) external nonReentrant portfolioExists(id) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        Portfolio storage p = portfolios[id];
        uint256 len = p.components.length;
        uint256[] memory deposited = new uint256[](len);
        uint256[] memory fees = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            address component = p.components[i];
            uint256 required = p.quantities[i] * amount;
            uint256 fee = (required * creationFeeBps) / FEE_DENOMINATOR;
            uint256 totalNeeded = required + fee;

            IERC20(component).safeTransferFrom(msg.sender, address(this), totalNeeded);
            if (fee > 0) {
                IERC20(component).safeTransfer(owner, fee);
            }
            deposited[i] = required;
            fees[i] = fee;
        }

        p.totalSupply += amount;
        portfolioBalances[id][to] += amount;

        emit Minted(id, msg.sender, to, amount, deposited, fees);
        emit PortfolioTransfer(id, address(0), to, amount);
    }

    /* ==================== REDEEM ==================== */
    /// @notice Burns `amount` portfolio tokens from the caller and returns the
    ///         proportional underlying components to `to`.
    /// @param id Portfolio id.
    /// @param amount Number of portfolio tokens to redeem.
    /// @param to Recipient of the underlying components.
    function redeem(
        uint256 id,
        uint256 amount,
        address to
    ) external nonReentrant portfolioExists(id) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        Portfolio storage p = portfolios[id];
        if (portfolioBalances[id][msg.sender] < amount) revert InsufficientBalance();

        uint256 len = p.components.length;
        uint256[] memory withdrawn = new uint256[](len);

        // Effects: burn first to follow checks-effects-interactions ordering
        portfolioBalances[id][msg.sender] -= amount;
        p.totalSupply -= amount;

        for (uint256 i = 0; i < len; ++i) {
            address component = p.components[i];
            uint256 outAmount = p.quantities[i] * amount;
            withdrawn[i] = outAmount;
            IERC20(component).safeTransfer(to, outAmount);
        }

        emit Redeemed(id, msg.sender, to, amount, withdrawn);
        emit PortfolioTransfer(id, msg.sender, address(0), amount);
    }

    /* ==================== REBALANCE ==================== */
    /// @notice Replaces an existing portfolio's composition. Only the operator may call.
    /// @param id Portfolio id.
    /// @param newComponents New component token addresses.
    /// @param newQuantities New per-token quantities backing a single portfolio token.
    function rebalance(
        uint256 id,
        address[] calldata newComponents,
        uint256[] calldata newQuantities
    ) external onlyOperator portfolioExists(id) {
        _validateComposition(newComponents, newQuantities);

        Portfolio storage p = portfolios[id];
        p.components = newComponents;
        p.quantities = newQuantities;

        emit Rebalanced(id, newComponents, newQuantities);
    }

    /* ==================== PORTFOLIO TOKEN TRANSFERS ==================== */
    function transferPortfolio(
        uint256 id,
        address to,
        uint256 amount
    ) external portfolioExists(id) returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (portfolioBalances[id][msg.sender] < amount) revert InsufficientBalance();

        portfolioBalances[id][msg.sender] -= amount;
        portfolioBalances[id][to] += amount;

        emit PortfolioTransfer(id, msg.sender, to, amount);
        return true;
    }

    function approvePortfolio(
        uint256 id,
        address spender,
        uint256 amount
    ) external portfolioExists(id) returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        portfolioAllowances[id][msg.sender][spender] = amount;
        emit PortfolioApproval(id, msg.sender, spender, amount);
        return true;
    }

    function transferFromPortfolio(
        uint256 id,
        address from,
        address to,
        uint256 amount
    ) external portfolioExists(id) returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (portfolioBalances[id][from] < amount) revert InsufficientBalance();

        uint256 allowed = portfolioAllowances[id][from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            portfolioAllowances[id][from][msg.sender] = allowed - amount;
        }

        portfolioBalances[id][from] -= amount;
        portfolioBalances[id][to] += amount;

        emit PortfolioTransfer(id, from, to, amount);
        return true;
    }

    /* ==================== VIEWS ==================== */
    function getPortfolio(
        uint256 id
    ) external view returns (address[] memory components, uint256[] memory quantities, uint256 totalSupply, bool active) {
        Portfolio storage p = portfolios[id];
        return (p.components, p.quantities, p.totalSupply, p.active);
    }

    function portfolioBalanceOf(uint256 id, address account) external view returns (uint256) {
        return portfolioBalances[id][account];
    }

    function portfolioAllowanceOf(uint256 id, address accountOwner, address spender) external view returns (uint256) {
        return portfolioAllowances[id][accountOwner][spender];
    }

    function allPortfoliosLength() external view returns (uint256) {
        return allPortfolioIds.length;
    }

    function getPortfolioIdAt(uint256 index) external view returns (uint256) {
        return allPortfolioIds[index];
    }

    /* ==================== ADMIN ==================== */
    /// @notice Sets the creation fee in basis points. Capped at MAX_FEE_BPS.
    function setCreationFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        emit CreationFeeUpdated(creationFeeBps, newFeeBps);
        creationFeeBps = newFeeBps;
    }

    /// @notice Sets the operator authorized to rebalance portfolios.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Transfers contract ownership to a new address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /* ==================== INTERNAL ==================== */
    function _validateComposition(
        address[] calldata components,
        uint256[] calldata quantities
    ) internal pure {
        if (components.length != quantities.length) revert ArrayLengthMismatch();
        if (components.length == 0 || components.length > MAX_COMPONENTS) revert TooManyComponents();
        for (uint256 i = 0; i < components.length; ++i) {
            if (components[i] == address(0)) revert ZeroAddress();
            if (quantities[i] == 0) revert ZeroAmount();
            for (uint256 j = i + 1; j < components.length; ++j) {
                if (components[i] == components[j]) revert DuplicateComponent();
            }
        }
    }
}
