// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Uranium Concentrate Fractional Ownership Token
/// @notice Tokenizes fractional ownership of physical uranium concentrate.
///         Users acquire shares by depositing ETH at the operator-set price.
///         Transfers incur a 0.5% fee sent to the operator.
///         Only the operator can mint, burn, and update the custodian.
contract UraniumConcentrateToken {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientPayment(uint256 sent, uint256 required);
    error BelowMinimumRedemption(uint256 amount, uint256 minimum);
    error ZeroAddress();
    error ZeroAmount();
    error TransferToSelf();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event CustodianUpdated(address indexed previousCustodian, address indexed newCustodian);
    event SharesAcquired(address indexed buyer, uint256 amountPaid, uint256 sharesMinted);
    event SharesRedeemed(address indexed redeemer, uint256 sharesBurned);
    event FundsWithdrawn(address indexed operator, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    string public constant name = "Uranium Concentrate Share";
    string public constant symbol = "UCS";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    address public operator;
    address public custodian;

    /// @notice Price per share in wei (1 share = pricePerShare wei)
    uint256 public pricePerShare;

    /// @notice Transfer fee in basis points: 0.5% = 50 bps
    uint256 public constant TRANSFER_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Minimum redemption amount (100 shares with 18 decimals)
    uint256 public constant MINIMUM_REDEMPTION = 100 * 10 ** 18;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param _custodian Initial custodian address (holder of physical uranium)
    /// @param _pricePerShare Initial price per share in wei
    constructor(address _custodian, uint256 _pricePerShare) notZeroAddress(_custodian) {
        if (_pricePerShare == 0) revert ZeroAmount();

        operator = msg.sender;
        custodian = _custodian;
        pricePerShare = _pricePerShare;

        emit CustodianUpdated(address(0), _custodian);
        emit PriceUpdated(0, _pricePerShare);
        emit OperatorTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         ACQUIRE / REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Acquire new shares by sending ETH. Shares are minted to the caller.
    function acquireShares() external payable {
        if (msg.value == 0) revert ZeroAmount();

        uint256 sharesToMint = (msg.value * 10 ** decimals) / pricePerShare;
        if (sharesToMint == 0) revert InsufficientPayment(msg.value, pricePerShare);

        _mint(msg.sender, sharesToMint);

        emit SharesAcquired(msg.sender, msg.value, sharesToMint);
    }

    /// @notice Redeem shares for physical uranium concentrate. Burns shares.
    /// @param amount The number of shares to redeem.
    function redeemShares(uint256 amount) external {
        if (amount < MINIMUM_REDEMPTION) {
            revert BelowMinimumRedemption(amount, MINIMUM_REDEMPTION);
        }
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(balanceOf[msg.sender], amount);
        }

        _burn(msg.sender, amount);

        emit SharesRedeemed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer shares to another account. A 0.5% fee is deducted and sent to the operator.
    /// @param to The recipient address.
    /// @param amount The number of shares to transfer (before fee).
    function transfer(address to, uint256 amount) external notZeroAddress(to) returns (bool) {
        if (to == msg.sender) revert TransferToSelf();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(balanceOf[msg.sender], amount);
        }

        uint256 fee = (amount * TRANSFER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += netAmount;
        if (fee > 0) {
            balanceOf[operator] += fee;
        }

        emit Transfer(msg.sender, to, netAmount, fee);
        if (fee > 0) {
            emit Transfer(msg.sender, operator, fee, 0);
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint new shares to a specified account. Only callable by the operator.
    /// @param to The recipient address.
    /// @param amount The number of shares to mint.
    function mint(address to, uint256 amount) external onlyOperator notZeroAddress(to) {
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
    }

    /// @notice Burn existing shares from a specified account. Only callable by the operator.
    /// @param from The account whose shares are burned.
    /// @param amount The number of shares to burn.
    function burn(address from, uint256 amount) external onlyOperator notZeroAddress(from) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(balanceOf[from], amount);
        }
        _burn(from, amount);
    }

    /// @notice Update the custodian address. Only callable by the operator.
    /// @param newCustodian The new custodian address.
    function updateCustodian(address newCustodian) external onlyOperator notZeroAddress(newCustodian) {
        address previous = custodian;
        custodian = newCustodian;
        emit CustodianUpdated(previous, newCustodian);
    }

    /// @notice Update the price per share. Only callable by the operator.
    /// @param newPrice The new price per share in wei.
    function updatePrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert ZeroAmount();
        uint256 oldPrice = pricePerShare;
        pricePerShare = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    /// @notice Withdraw accumulated funds from share acquisitions. Only callable by the operator.
    /// @param recipient The address to receive the funds.
    /// @param amount The amount of ETH to withdraw.
    function withdrawFunds(address payable recipient, uint256 amount) external onlyOperator notZeroAddress(recipient) {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) {
            revert InsufficientPayment(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert InsufficientPayment(amount, amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    /// @notice Transfer the operator role to a new address. Only callable by the current operator.
    /// @param newOperator The new operator address.
    function transferOperator(address newOperator) external onlyOperator notZeroAddress(newOperator) {
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL MINT/BURN
    //////////////////////////////////////////////////////////////*/
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount, 0);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Burn(from, amount);
        emit Transfer(from, address(0), amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the ETH balance held by this contract.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
