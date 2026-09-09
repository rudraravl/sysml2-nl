// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
                    let size := mload(returndata)
                    revert(add(returndata, 32), size)
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

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddressOwner();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddressOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressOwner();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

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
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert("ERC20: insufficient allowance");
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert("ERC20: transfer from the zero address");
        if (to == address(0)) revert("ERC20: transfer to the zero address");
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert("ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert("ERC20: mint to the zero address");
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert("ERC20: burn from the zero address");
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert("ERC20: burn amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert("ERC20: approve from the zero address");
        if (spender == address(0)) revert("ERC20: approve to the zero address");
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}

/// @title FiatStablecoinWrapper
/// @notice A wrapper token that holds a single underlying fiat-pegged stablecoin as its sole asset.
///         Holders may deposit the underlying stablecoin to mint wrapper tokens and redeem wrapper
///         tokens to receive the underlying stablecoin. A designated operator may update the exchange
///         rate at most once every 24 hours. Redemptions are charged a fixed 0.1% fee.
contract FiatStablecoinWrapper is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------------------------
    error UnauthorizedOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidExchangeRate();
    error RateUpdateTooSoon(uint256 timeRemaining);
    error InsufficientUnderlyingBalance(uint256 required, uint256 available);

    // ---------------------------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------------------------
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_UPDATE_INTERVAL = 24 hours;
    uint256 public constant FEE_DIVISOR = EXCHANGE_RATE_PRECISION * BPS_DENOMINATOR;

    // ---------------------------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------------------------
    IERC20 public immutable underlying;
    address public operator;
    uint256 public exchangeRate;
    uint256 public lastRateUpdate;

    // ---------------------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------------------
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event Minted(address indexed account, uint256 underlyingIn, uint256 wrapperMinted);
    event Burned(address indexed account, uint256 wrapperBurnt, uint256 underlyingOut, uint256 fee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert UnauthorizedOperator();
        _;
    }

    // ---------------------------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------------------------
    constructor(
        string memory name_,
        string memory symbol_,
        IERC20 underlying_,
        address initialOwner,
        address initialOperator
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        if (address(underlying_) == address(0)) revert ZeroAddress();
        if (initialOperator == address(0)) revert ZeroAddress();

        underlying = underlying_;
        operator = initialOperator;
        exchangeRate = EXCHANGE_RATE_PRECISION; // 1:1 initially
        lastRateUpdate = block.timestamp;

        emit OperatorUpdated(address(0), initialOperator);
        emit ExchangeRateUpdated(0, EXCHANGE_RATE_PRECISION, block.timestamp);
    }

    // ---------------------------------------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------------------------------------

    /// @notice Deposit underlying stablecoin to mint wrapper tokens.
    /// @param underlyingAmount Amount of underlying stablecoin to deposit.
    /// @return wrapperAmount Amount of wrapper tokens minted.
    function deposit(uint256 underlyingAmount) external returns (uint256 wrapperAmount) {
        if (underlyingAmount == 0) revert ZeroAmount();

        wrapperAmount = (underlyingAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
        if (wrapperAmount == 0) revert ZeroAmount();

        // Effects
        _mint(msg.sender, wrapperAmount);

        // Interactions
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        emit Minted(msg.sender, underlyingAmount, wrapperAmount);
    }

    /// @notice Redeem wrapper tokens for the underlying stablecoin, net of the 0.1% redemption fee.
    /// @param wrapperAmount Amount of wrapper tokens to burn.
    /// @return underlyingOut Amount of underlying stablecoin transferred to the caller.
    function redeem(uint256 wrapperAmount) external returns (uint256 underlyingOut) {
        if (wrapperAmount == 0) revert ZeroAmount();

        // Compute gross underlying and fee from the raw product to avoid
        // divide-before-multiply precision loss.
        uint256 raw = wrapperAmount * exchangeRate;
        uint256 grossUnderlying = raw / EXCHANGE_RATE_PRECISION;
        uint256 fee = (raw * REDEMPTION_FEE_BPS) / FEE_DIVISOR;
        underlyingOut = grossUnderlying - fee;

        // Effects
        _burn(msg.sender, wrapperAmount);

        // Interactions
        uint256 available = underlying.balanceOf(address(this));
        if (available < underlyingOut) {
            revert InsufficientUnderlyingBalance(underlyingOut, available);
        }
        underlying.safeTransfer(msg.sender, underlyingOut);

        emit Burned(msg.sender, wrapperAmount, underlyingOut, fee);
    }

    /// @notice Update the exchange rate between the wrapper token and the underlying stablecoin.
    ///         Callable only by the operator and at most once every 24 hours.
    /// @param newRate New exchange rate scaled by EXCHANGE_RATE_PRECISION.
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();

        uint256 elapsed;
        unchecked {
            elapsed = block.timestamp - lastRateUpdate;
        }
        if (elapsed < MIN_UPDATE_INTERVAL) {
            revert RateUpdateTooSoon(MIN_UPDATE_INTERVAL - elapsed);
        }

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        lastRateUpdate = block.timestamp;

        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }

    /// @notice Set the designated operator. Callable only by the owner.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ---------------------------------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------------------------------

    /// @notice Preview how many wrapper tokens would be minted for a given underlying deposit.
    function previewDeposit(uint256 underlyingAmount) external view returns (uint256) {
        return (underlyingAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
    }

    /// @notice Preview the net underlying output and fee for a given wrapper redemption.
    function previewRedeem(uint256 wrapperAmount) external view returns (uint256 underlyingOut, uint256 fee) {
        // Compute from the raw product to avoid divide-before-multiply precision loss.
        uint256 raw = wrapperAmount * exchangeRate;
        uint256 grossUnderlying = raw / EXCHANGE_RATE_PRECISION;
        fee = (raw * REDEMPTION_FEE_BPS) / FEE_DIVISOR;
        underlyingOut = grossUnderlying - fee;
    }

    /// @notice Returns the timestamp after which the exchange rate may next be updated.
    function nextRateUpdateWindow() external view returns (uint256) {
        return lastRateUpdate + MIN_UPDATE_INTERVAL;
    }
}
