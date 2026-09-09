// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SocialProfileTrading
/// @notice Manages fractional ownership of social network profiles via a linear bonding curve.
///         Users can buy and sell shares of a profile, with a global fee applied to every trade.
///         Sellers' proceeds accumulate on-chain and can be withdrawn at any time.
contract SocialProfileTrading {
    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error NotAuthorized();
    error WhenPaused();
    error ZeroAmount();
    error InsufficientPayment();
    error InsufficientShares();
    error ZeroAddress();
    error InvalidFeePercentage();
    error NothingToWithdraw();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event SharesBought(uint256 indexed profileId, address indexed buyer, uint256 amount, uint256 netCost, uint256 fee);
    event SharesSold(uint256 indexed profileId, address indexed seller, uint256 amount, uint256 netProceeds, uint256 fee);
    event FeePercentageUpdated(uint256 oldFeePercentage, uint256 newFeePercentage);
    event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);
    event PausedStateChanged(bool paused);
    event EarningsWithdrawn(address indexed account, uint256 amount);
    event FeesWithdrawn(address indexed beneficiary, uint256 amount);
    event ProfileOwnerUpdated(uint256 indexed profileId, address indexed oldOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant BASE_PRICE = 0.001 ether;
    uint256 public constant PRICE_SLOPE = 0.0001 ether;
    uint256 public constant FEE_DENOMINATOR = 100;
    uint256 public constant INITIAL_FEE_PERCENTAGE = 5;
    uint256 public constant MIN_SHARES = 1;

    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------
    address public owner;
    address public beneficiary;
    uint256 public feePercentage;
    bool public paused;

    uint256 private _locked = 1;

    struct Profile {
        uint256 totalShares;
        address currentOwner;
    }

    /// @dev profileId => profile data (unique digital asset)
    mapping(uint256 => Profile) public profiles;
    /// @dev profileId => account => shares currently held.
    mapping(uint256 => mapping(address => uint256)) public shares;
    /// @dev account => accumulated, unwithdrawn sell proceeds (in wei).
    mapping(address => uint256) public accumulatedEarnings;
    /// @dev Total accumulated fees owed to the beneficiary (in wei).
    uint256 public accumulatedFees;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _beneficiary) {
        if (_beneficiary == address(0)) revert ZeroAddress();
        owner = msg.sender;
        beneficiary = _beneficiary;
        feePercentage = INITIAL_FEE_PERCENTAGE;
        emit FeePercentageUpdated(0, INITIAL_FEE_PERCENTAGE);
        emit BeneficiaryUpdated(address(0), _beneficiary);
    }

    // ---------------------------------------------------------------------
    // Owner / Admin Functions
    // ---------------------------------------------------------------------
    /// @notice Updates the global fee percentage applied to every trade.
    /// @param _feePercentage New fee percentage; must be <= 100 (i.e. <= 100%).
    function updateFeePercentage(uint256 _feePercentage) external onlyOwner {
        if (_feePercentage > FEE_DENOMINATOR) revert InvalidFeePercentage();
        uint256 old = feePercentage;
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(old, _feePercentage);
    }

    /// @notice Updates the address that receives collected fees.
    /// @param _beneficiary New beneficiary; cannot be the zero address.
    function setBeneficiary(address _beneficiary) external onlyOwner {
        if (_beneficiary == address(0)) revert ZeroAddress();
        address old = beneficiary;
        beneficiary = _beneficiary;
        emit BeneficiaryUpdated(old, _beneficiary);
    }

    /// @notice Pauses or unpauses all trading activity (buy/sell).
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // ---------------------------------------------------------------------
    // Pricing (Linear Bonding Curve)
    // ---------------------------------------------------------------------
    /// @notice Computes the gross cost, fee, and net cost to buy `amount` shares of `profileId`.
    function getBuyPrice(uint256 profileId, uint256 amount)
        public
        view
        returns (uint256 grossCost, uint256 fee, uint256 netCost)
    {
        if (amount < MIN_SHARES) revert ZeroAmount();
        uint256 s = profiles[profileId].totalShares;
        netCost = amount * BASE_PRICE + PRICE_SLOPE * (s * amount + (amount * (amount - 1)) / 2);
        fee = (netCost * feePercentage) / FEE_DENOMINATOR;
        grossCost = netCost + fee;
    }

    /// @notice Computes the gross proceeds, fee, and net proceeds for selling `amount` shares of `profileId`.
    function getSellPrice(uint256 profileId, uint256 amount)
        public
        view
        returns (uint256 grossProceeds, uint256 fee, uint256 netProceeds)
    {
        if (amount < MIN_SHARES) revert ZeroAmount();
        uint256 s = profiles[profileId].totalShares;
        if (amount > s) revert InsufficientShares();
        grossProceeds = amount * BASE_PRICE + PRICE_SLOPE * ((s - 1) * amount - (amount * (amount - 1)) / 2);
        fee = (grossProceeds * feePercentage) / FEE_DENOMINATOR;
        netProceeds = grossProceeds - fee;
    }

    // ---------------------------------------------------------------------
    // Trading
    // ---------------------------------------------------------------------
    /// @notice Buys `amount` shares of `profileId`. Excess ETH is refunded to the caller.
    function buyShares(uint256 profileId, uint256 amount) external payable whenNotPaused nonReentrant {
        if (amount < MIN_SHARES) revert ZeroAmount();
        (uint256 grossCost, uint256 fee, uint256 netCost) = getBuyPrice(profileId, amount);
        if (msg.value < grossCost) revert InsufficientPayment();

        // Effects
        profiles[profileId].totalShares += amount;
        shares[profileId][msg.sender] += amount;
        accumulatedFees += fee;

        // Update "current owner" of the profile if the buyer now holds more shares
        address oldOwner = profiles[profileId].currentOwner;
        if (oldOwner == address(0) || shares[profileId][msg.sender] > shares[profileId][oldOwner]) {
            profiles[profileId].currentOwner = msg.sender;
            emit ProfileOwnerUpdated(profileId, oldOwner, msg.sender);
        }

        emit SharesBought(profileId, msg.sender, amount, netCost, fee);

        // Interactions: refund any excess ETH sent.
        if (msg.value > grossCost) {
            uint256 refund = msg.value - grossCost;
            (bool ok, ) = msg.sender.call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
    }

    /// @notice Sells `amount` shares of `profileId`. Net proceeds are credited to the
    ///         seller's accumulated earnings and may be withdrawn via `withdrawEarnings`.
    function sellShares(uint256 profileId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount < MIN_SHARES) revert ZeroAmount();
        if (shares[profileId][msg.sender] < amount) revert InsufficientShares();

        (, uint256 fee, uint256 netProceeds) = getSellPrice(profileId, amount);

        // Effects
        shares[profileId][msg.sender] -= amount;
        profiles[profileId].totalShares -= amount;
        accumulatedEarnings[msg.sender] += netProceeds;
        accumulatedFees += fee;

        emit SharesSold(profileId, msg.sender, amount, netProceeds, fee);
    }

    // ---------------------------------------------------------------------
    // Withdrawals
    // ---------------------------------------------------------------------
    /// @notice Withdraws the caller's full accumulated sell earnings.
    function withdrawEarnings() external nonReentrant {
        uint256 amount = accumulatedEarnings[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        accumulatedEarnings[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit EarningsWithdrawn(msg.sender, amount);
    }

    /// @notice Withdraws all accumulated fees to the current beneficiary.
    ///         Callable by the beneficiary or the contract owner.
    function withdrawFees() external nonReentrant {
        if (msg.sender != beneficiary && msg.sender != owner) revert NotAuthorized();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool ok, ) = beneficiary.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(beneficiary, amount);
    }
}
