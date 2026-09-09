// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
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
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 current = allowance[owner_][spender];
        if (current != type(uint256).max) {
            require(current >= amount, "ERC20: insufficient allowance");
            unchecked {
                allowance[owner_][spender] = current - amount;
            }
        }
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

/**
 * @title LiquidStakingToken
 * @notice Tokenized representation of staked network tokens. Users deposit a
 *         network token and receive liquid staking tokens (LST) that can be
 *         transferred and later redeemed for the underlying network tokens.
 *         A 0.5% fee is charged on every withdrawal/redemption. A designated
 *         operator is responsible for keeping the exchange rate in sync with
 *         external oracle data and for pausing withdrawals if necessary.
 */
contract LiquidStakingToken is ERC20, Ownable {
    // ---------------------------------------------------------------------
    //  Custom errors
    // ---------------------------------------------------------------------
    error ZeroAmount();
    error ZeroAddress();
    error DepositExceedsMax(uint256 amount, uint256 maxAllowed);
    error InsufficientLiquidTokens(uint256 requested, uint256 available);
    error InsufficientNetworkTokens(uint256 requested, uint256 available);
    error InvalidExchangeRate(uint256 rate);
    error WithdrawalsArePaused();
    error NotOperator();
    error TransferFailed();

    // ---------------------------------------------------------------------
    //  Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 networkAmount, uint256 liquidMinted);
    event Withdrawn(address indexed user, uint256 liquidBurned, uint256 networkReturned, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event WithdrawalsPauseChanged(bool paused);

    // ---------------------------------------------------------------------
    //  Constants
    // ---------------------------------------------------------------------
    /// @notice Maximum amount of network tokens that can be deposited in a single transaction.
    uint256 public constant MAX_DEPOSIT_PER_TX = 1000 ether;
    /// @notice Withdrawal fee in basis points (50 bps == 0.5%).
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    /// @notice Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10000;
    /// @notice Precision used for the exchange rate.
    uint256 public constant RATE_PRECISION = 1e18;

    // ---------------------------------------------------------------------
    //  State variables
    // ---------------------------------------------------------------------
    IERC20 public immutable networkToken;
    address public operator;
    /// @notice Network tokens per 1 LST, scaled by 1e18.
    uint256 public exchangeRate;
    /// @notice Whether withdrawals are currently paused by the operator.
    bool public withdrawalsPaused;
    /// @notice Lifetime record of network tokens deposited by each user.
    mapping(address => uint256) public depositedNetworkTokens;

    // ---------------------------------------------------------------------
    //  Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        _;
    }

    // ---------------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------------
    /**
     * @param _networkToken         Address of the ERC20 network token being staked.
     * @param _operator             Address authorized to update the exchange rate and pause withdrawals.
     * @param _initialExchangeRate  Initial exchange rate (network tokens per 1 LST, scaled by 1e18).
     */
    constructor(
        address _networkToken,
        address _operator,
        uint256 _initialExchangeRate
    ) ERC20("Liquid Staking Token", "LST") {
        if (_networkToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialExchangeRate == 0) revert InvalidExchangeRate(_initialExchangeRate);

        networkToken = IERC20(_networkToken);
        operator = _operator;
        exchangeRate = _initialExchangeRate;

        emit ExchangeRateUpdated(0, _initialExchangeRate);
        emit OperatorUpdated(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    //  Internal helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Pull network tokens from the caller (msg.sender) into this contract.
     * @dev Inlined to avoid a generic safeTransferFrom library that accepts an
     *      arbitrary `from` parameter, which static analyzers flag as
     *      arbitrary-send-erc20.
     */
    function _pullNetworkTokens(uint256 amount) internal {
        bool ok = networkToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    /**
     * @notice Send network tokens to a recipient, reverting on failure.
     */
    function _sendNetworkTokens(address to, uint256 amount) internal {
        bool ok = networkToken.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    //  Core staking functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit network tokens and receive minted LST at the current exchange rate.
     * @param networkAmount Amount of network tokens to deposit (in wei).
     * @return liquidMinted Amount of LST minted to the caller.
     */
    function deposit(uint256 networkAmount) external returns (uint256 liquidMinted) {
        if (networkAmount == 0) revert ZeroAmount();
        if (networkAmount > MAX_DEPOSIT_PER_TX) revert DepositExceedsMax(networkAmount, MAX_DEPOSIT_PER_TX);

        // Calculate LST to mint: LST = networkAmount * RATE_PRECISION / exchangeRate
        liquidMinted = (networkAmount * RATE_PRECISION) / exchangeRate;
        if (liquidMinted == 0) revert ZeroAmount();

        // Effects: update record before external interactions.
        depositedNetworkTokens[msg.sender] += networkAmount;
        _mint(msg.sender, liquidMinted);

        // Interaction: pull network tokens from the depositor (msg.sender only).
        _pullNetworkTokens(networkAmount);

        emit Deposited(msg.sender, networkAmount, liquidMinted);
    }

    /**
     * @notice Withdraw a specific amount of network tokens by burning the
     *         corresponding amount of LST. A 0.5% fee is retained by the contract.
     * @param networkAmount The exact amount of network tokens the caller wants to receive.
     * @return liquidBurned Amount of LST burned from the caller.
     */
    function withdraw(uint256 networkAmount) external whenWithdrawalsNotPaused returns (uint256 liquidBurned) {
        if (networkAmount == 0) revert ZeroAmount();

        // Compute the LST to burn in a single ceiling division to avoid
        // divide-before-multiply precision loss.
        //
        // Original two-step:
        //   grossNetwork = ceil(networkAmount * BPS / denom)
        //   liquidBurned = ceil(grossNetwork * RATE_PRECISION / exchangeRate)
        //
        // Combined (multiply-then-divide):
        //   liquidBurned = ceil(networkAmount * BPS * RATE_PRECISION / (denom * exchangeRate))
        uint256 denom = BPS_DENOMINATOR - WITHDRAWAL_FEE_BPS;
        uint256 numerator = networkAmount * BPS_DENOMINATOR * RATE_PRECISION;
        uint256 divisor = denom * exchangeRate;
        liquidBurned = (numerator + divisor - 1) / divisor;
        if (liquidBurned == 0) revert ZeroAmount();

        // Derive the gross network amount from the LST burned (floor division).
        uint256 grossNetwork = (liquidBurned * exchangeRate) / RATE_PRECISION;
        // grossNetwork is guaranteed >= networkAmount because BPS/denom > 1.
        uint256 fee = grossNetwork - networkAmount;

        uint256 lstBalance = balanceOf[msg.sender];
        if (lstBalance < liquidBurned) revert InsufficientLiquidTokens(liquidBurned, lstBalance);

        uint256 available = depositedNetworkTokens[msg.sender];
        if (available < grossNetwork) revert InsufficientNetworkTokens(grossNetwork, available);

        // Effects
        depositedNetworkTokens[msg.sender] = available - grossNetwork;
        _burn(msg.sender, liquidBurned);

        // Interaction
        _sendNetworkTokens(msg.sender, networkAmount);

        emit Withdrawn(msg.sender, liquidBurned, networkAmount, fee);
    }

    /**
     * @notice Redeem a specific amount of LST for network tokens. A 0.5% fee is
     *         retained by the contract.
     * @param liquidAmount Amount of LST to burn.
     * @return networkReturned Net network tokens transferred to the caller.
     */
    function redeem(uint256 liquidAmount) external whenWithdrawalsNotPaused returns (uint256 networkReturned) {
        if (liquidAmount == 0) revert ZeroAmount();

        uint256 lstBalance = balanceOf[msg.sender];
        if (lstBalance < liquidAmount) revert InsufficientLiquidTokens(liquidAmount, lstBalance);

        // Compute fee from the pre-division product to avoid
        // divide-before-multiply precision loss.
        //
        // Original:
        //   grossNetwork = (liquidAmount * exchangeRate) / RATE_PRECISION
        //   fee = (grossNetwork * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR
        //
        // Fixed (multiply-then-divide):
        //   fee = (liquidAmount * exchangeRate * WITHDRAWAL_FEE_BPS) / (RATE_PRECISION * BPS_DENOMINATOR)
        uint256 fee = (liquidAmount * exchangeRate * WITHDRAWAL_FEE_BPS) / (RATE_PRECISION * BPS_DENOMINATOR);
        uint256 grossNetwork = (liquidAmount * exchangeRate) / RATE_PRECISION;
        if (grossNetwork == 0) revert ZeroAmount();
        networkReturned = grossNetwork - fee;

        uint256 available = depositedNetworkTokens[msg.sender];
        if (available < grossNetwork) revert InsufficientNetworkTokens(grossNetwork, available);

        // Effects
        depositedNetworkTokens[msg.sender] = available - grossNetwork;
        _burn(msg.sender, liquidAmount);

        // Interaction
        _sendNetworkTokens(msg.sender, networkReturned);

        emit Withdrawn(msg.sender, liquidAmount, networkReturned, fee);
    }

    // ---------------------------------------------------------------------
    //  Operator functions
    // ---------------------------------------------------------------------

    /**
     * @notice Update the exchange rate between network tokens and LST.
     *         Only callable by the operator (e.g., an oracle-fed bot).
     * @param newRate New exchange rate (network tokens per 1 LST, scaled by 1e18).
     */
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate(newRate);
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Pause or resume all withdrawals/redemptions.
     * @param paused True to pause, false to unpause.
     */
    function setWithdrawalsPaused(bool paused) external onlyOperator {
        withdrawalsPaused = paused;
        emit WithdrawalsPauseChanged(paused);
    }

    /**
     * @notice Transfer the operator role to a new address. Only callable by the owner.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    // ---------------------------------------------------------------------
    //  View helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Preview how many LST would be minted for a given network token deposit.
     */
    function previewDeposit(uint256 networkAmount) external view returns (uint256) {
        return (networkAmount * RATE_PRECISION) / exchangeRate;
    }

    /**
     * @notice Preview the net network tokens returned and fee charged for redeeming
     *         a given amount of LST.
     */
    function previewRedeem(uint256 liquidAmount) external view returns (uint256 networkReturned, uint256 fee) {
        // Multiply-then-divide to avoid divide-before-multiply.
        fee = (liquidAmount * exchangeRate * WITHDRAWAL_FEE_BPS) / (RATE_PRECISION * BPS_DENOMINATOR);
        uint256 grossNetwork = (liquidAmount * exchangeRate) / RATE_PRECISION;
        networkReturned = grossNetwork - fee;
    }

    /**
     * @notice Preview how many LST must be burned and what fee is charged to receive
     *         a specific amount of network tokens via `withdraw`.
     */
    function previewWithdraw(uint256 networkAmount) external view returns (uint256 liquidBurned, uint256 fee) {
        // Combined ceiling division to avoid divide-before-multiply.
        uint256 denom = BPS_DENOMINATOR - WITHDRAWAL_FEE_BPS;
        uint256 numerator = networkAmount * BPS_DENOMINATOR * RATE_PRECISION;
        uint256 divisor = denom * exchangeRate;
        liquidBurned = (numerator + divisor - 1) / divisor;
        uint256 grossNetwork = (liquidBurned * exchangeRate) / RATE_PRECISION;
        fee = grossNetwork - networkAmount;
    }

    /**
     * @notice Total network tokens currently held by the contract.
     */
    function totalNetworkTokens() external view returns (uint256) {
        return networkToken.balanceOf(address(this));
    }
}
