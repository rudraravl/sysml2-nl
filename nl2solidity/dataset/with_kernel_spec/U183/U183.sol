// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract GameCurrencyManager {
    // ──────────────────────────── Events ────────────────────────────
    event ConvertedToInGame(address indexed player, uint256 primaryAmount, uint256 inGameAmount);
    event ConvertedFromInGame(address indexed player, uint256 inGameAmount, uint256 primaryAmount, uint256 fee);
    event ConversionRateUpdated(uint256 oldRate, uint256 newRate);
    event InGameMinted(address indexed to, uint256 amount);
    event ReserveWithdrawn(address indexed to, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ────────────────────────── Custom Errors ───────────────────────
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidConversionRate();
    error InsufficientInGameBalance();
    error InsufficientReserve();
    error TransferFailed();
    error ReentrantCall();

    // ─────────────────────────── Constants ─────────────────────────
    uint256 public constant FEE_BASIS_POINTS = 500;          // 5% fee
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant INITIAL_CONVERSION_RATE = 100;   // 1 primary token = 100 in-game
    uint256 public constant MAX_CONVERSION_RATE = 1e18;     // upper bound to prevent overflow

    // ───────────────────────── State Variables ──────────────────────
    IERC20 public immutable primaryGameToken;
    uint256 public conversionRate;
    mapping(address => uint256) public inGameBalance;
    uint256 public totalInGameSupply;
    uint256 public feesAccrued;
    address public owner;
    address public operator;
    uint256 private _locked = 1;

    // ─────────────────────────── Modifiers ─────────────────────────
    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ─────────────────────────── Constructor ────────────────────────
    constructor(address _primaryGameToken, address _operator) {
        if (_primaryGameToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        primaryGameToken = IERC20(_primaryGameToken);
        owner = msg.sender;
        operator = _operator;
        conversionRate = INITIAL_CONVERSION_RATE;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit ConversionRateUpdated(0, conversionRate);
    }

    // ────────────────────────── Conversion Logic ────────────────────

    /// @notice Convert primary game tokens into in-game currency at the current rate.
    /// @param primaryAmount Amount of primary game tokens to deposit.
    /// @return inGameAmount Amount of in-game currency credited.
    function convertToInGame(uint256 primaryAmount)
        external
        nonReentrant
        returns (uint256 inGameAmount)
    {
        if (primaryAmount == 0) revert ZeroAmount();

        inGameAmount = primaryAmount * conversionRate;
        if (inGameAmount == 0) revert ZeroAmount();

        // Effects
        inGameBalance[msg.sender] += inGameAmount;
        totalInGameSupply += inGameAmount;

        // Interactions
        _safeTransferFrom(
            address(primaryGameToken),
            msg.sender,
            address(this),
            primaryAmount
        );

        emit ConvertedToInGame(msg.sender, primaryAmount, inGameAmount);
    }

    /// @notice Convert in-game currency back to primary game tokens, deducting a 5% fee.
    /// @param inGameAmount Amount of in-game currency to burn.
    /// @return primaryAmount Net primary tokens received after fee.
    /// @return fee Fee deducted (in primary token units).
    function convertFromInGame(uint256 inGameAmount)
        external
        nonReentrant
        returns (uint256 primaryAmount, uint256 fee)
    {
        if (inGameAmount == 0) revert ZeroAmount();
        if (inGameBalance[msg.sender] < inGameAmount) revert InsufficientInGameBalance();

        uint256 grossPrimary = inGameAmount / conversionRate;
        if (grossPrimary == 0) revert ZeroAmount();

        // Compute fee directly from the raw in-game amount to avoid
        // divide-before-multiply precision loss:
        //   fee = (inGameAmount / conversionRate) * FEE_BASIS_POINTS / BASIS_POINTS
        // reordered as:
        //   fee =  inGameAmount * FEE_BASIS_POINTS / (conversionRate * BASIS_POINTS)
        // Because FEE_BASIS_POINTS < BASIS_POINTS, fee <= grossPrimary always holds.
        fee = (inGameAmount * FEE_BASIS_POINTS) / (conversionRate * BASIS_POINTS);
        primaryAmount = grossPrimary - fee;
        if (primaryAmount == 0) revert ZeroAmount();

        if (primaryGameToken.balanceOf(address(this)) < primaryAmount) {
            revert InsufficientReserve();
        }

        // Effects
        inGameBalance[msg.sender] -= inGameAmount;
        totalInGameSupply -= inGameAmount;
        feesAccrued += fee;

        // Interactions
        _safeTransfer(address(primaryGameToken), msg.sender, primaryAmount);

        emit ConvertedFromInGame(msg.sender, inGameAmount, primaryAmount, fee);
    }

    // ────────────────────────── Operator Functions ──────────────────

    /// @notice Update the conversion rate (in-game currency per primary token).
    /// @param newRate New conversion rate; must be non-zero and bounded by MAX_CONVERSION_RATE.
    function setConversionRate(uint256 newRate) external onlyOperator {
        if (newRate == 0 || newRate > MAX_CONVERSION_RATE) revert InvalidConversionRate();
        uint256 oldRate = conversionRate;
        conversionRate = newRate;
        emit ConversionRateUpdated(oldRate, newRate);
    }

    /// @notice Mint additional in-game currency to a specified account.
    /// @param to Recipient address.
    /// @param amount Amount of in-game currency to mint.
    function mintInGame(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        inGameBalance[to] += amount;
        totalInGameSupply += amount;

        emit InGameMinted(to, amount);
    }

    // ─────────────────────────── Owner Functions ───────────────────

    /// @notice Transfer operator role to a new address.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /// @notice Transfer contract ownership to a new address.
    /// @param newOwner Address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /// @notice Withdraw accumulated primary game tokens from the reserve.
    /// @param to Recipient address.
    /// @param amount Amount of primary tokens to withdraw.
    function withdrawReserve(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (primaryGameToken.balanceOf(address(this)) < amount) revert InsufficientReserve();

        _safeTransfer(address(primaryGameToken), to, amount);

        emit ReserveWithdrawn(to, amount);
    }

    // ─────────────────────────── View Functions ─────────────────────

    /// @notice Returns the current reserve of primary game tokens held by this contract.
    function reserveBalance() external view returns (uint256) {
        return primaryGameToken.balanceOf(address(this));
    }

    /// @notice Preview the in-game currency received for a given primary amount.
    function previewConvertToInGame(uint256 primaryAmount)
        external
        view
        returns (uint256 inGameAmount)
    {
        inGameAmount = primaryAmount * conversionRate;
    }

    /// @notice Preview the net primary tokens and fee for converting a given in-game amount.
    function previewConvertFromInGame(uint256 inGameAmount)
        external
        view
        returns (uint256 primaryAmount, uint256 fee)
    {
        uint256 gross = inGameAmount / conversionRate;
        // Multiply-before-divide to avoid divide-before-multiply precision loss:
        //   fee = (inGameAmount / conversionRate) * FEE_BASIS_POINTS / BASIS_POINTS
        // reordered as:
        //   fee = inGameAmount * FEE_BASIS_POINTS / (conversionRate * BASIS_POINTS)
        fee = (inGameAmount * FEE_BASIS_POINTS) / (conversionRate * BASIS_POINTS);
        // Since FEE_BASIS_POINTS < BASIS_POINTS, fee <= gross holds, so no underflow.
        primaryAmount = gross - fee;
    }

    // ─────────────────────── Internal Safe Transfers ─────────────────

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
