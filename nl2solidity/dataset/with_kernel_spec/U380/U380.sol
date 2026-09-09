// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ERC20 {
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 32), returndata_size)
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
 * @title WrappedBitcoinIndex
 * @notice A liquid, index-backed ERC-20 token representing a diversified basket of wrapped Bitcoin assets.
 *
 * Users deposit the full basket of supported wrapped Bitcoin tokens (in target weight proportions)
 * to mint index tokens 1:1 with BTC (18-decimal units), and redeem index tokens to receive a
 * proportional slice of the underlying basket minus a 0.1% redemption fee. Fees accrue per-token
 * and may be recovered by the designated operator. The operator also manages basket composition
 * (adding/removing tokens, adjusting weights) and may sweep balances of tokens removed from the basket.
 *
 * Index token decimals: 18 (1e18 ~= 1 BTC when basket weights sum to WEIGHT_PRECISION).
 * Minimum deposit: 0.001 BTC equivalent (1e15 index-token wei).
 * Redemption fee: 0.1% (10 basis points), deducted from each underlying token transferred out.
 */
contract WrappedBitcoinIndex is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //-----------------------------------------------------------------------//
    //                              Constants                                //
    //-----------------------------------------------------------------------//

    /// @dev Weight precision in basis points (1e4 = 100%).
    uint256 public constant WEIGHT_PRECISION = 1e4;

    /// @dev Redemption fee in basis points (10 = 0.1%).
    uint256 public constant FEE_BASIS_POINTS = 10;

    /// @dev Minimum deposit in index-token wei (1e15 = 0.001 in 18-decimal terms).
    uint256 public constant MIN_DEPOSIT = 1e15;

    //-----------------------------------------------------------------------//
    //                              Errors                                   //
    //-----------------------------------------------------------------------//

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinDeposit();
    error EmptyBasket();
    error TokenAlreadySupported();
    error TokenNotSupported();
    error TokenStillSupported();
    error InvalidWeight();
    error InsufficientBalance();
    error AmountRoundsToZero();

    //-----------------------------------------------------------------------//
    //                              Events                                   //
    //-----------------------------------------------------------------------//

    event Deposited(address indexed user, uint256 indexAmount, address[] tokens, uint256[] amounts);
    event Redeemed(
        address indexed user,
        uint256 indexAmount,
        address[] tokens,
        uint256[] amounts,
        uint256[] feeAmounts
    );
    event TokenAdded(address indexed token, uint8 decimals, uint256 weight);
    event TokenRemoved(address indexed token);
    event WeightAdjusted(address indexed token, uint256 oldWeight, uint256 newWeight);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesRecovered(address indexed token, address indexed recipient, uint256 amount);
    event TokenSwept(address indexed token, address indexed recipient, uint256 amount);
    event BasketAnnounced(
        uint256 totalSupply,
        address[] tokens,
        uint256[] weights,
        uint256[] balances,
        uint256[] fees
    );

    //-----------------------------------------------------------------------//
    //                            State Variables                            //
    //-----------------------------------------------------------------------//

    /// @notice The designated operator managing basket composition.
    address public operator;

    /// @dev Array of currently supported basket token addresses.
    address[] internal _basketTokens;

    /// @notice Weight of each basket token in basis points (1e4 = 100%).
    mapping(address => uint256) public weight;

    /// @notice Whether a token is currently part of the basket.
    mapping(address => bool) public isSupported;

    /// @notice Decimals of each basket token (cached at addition time).
    mapping(address => uint8) public tokenDecimals;

    /// @notice Accumulated redemption fees per basket token, recoverable by the operator.
    mapping(address => uint256) public accumulatedFees;

    /// @notice Sum of all basket weights.
    uint256 public totalWeight;

    //-----------------------------------------------------------------------//
    //                             Modifiers                                 //
    //-----------------------------------------------------------------------//

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    //-----------------------------------------------------------------------//
    //                             Constructor                               //
    //-----------------------------------------------------------------------//

    constructor(string memory name_, string memory symbol_, address operator_) ERC20(name_, symbol_) {
        if (operator_ == address(0)) revert ZeroAddress();
        operator = operator_;
    }

    //-----------------------------------------------------------------------//
    //                           ERC-20 Overrides                            //
    //-----------------------------------------------------------------------//

    /// @dev The index token always uses 18 decimals.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    //-----------------------------------------------------------------------//
    //                         Deposit / Redemption                         //
    //-----------------------------------------------------------------------//

    /**
     * @notice Deposit the basket of wrapped Bitcoin tokens (in weight proportions) to mint index tokens.
     * @param indexAmount The amount of index tokens to mint, in 18-decimal wei (1e18 ~= 1 BTC).
     * @dev The caller must approve this contract for each basket token. Reverts if the basket
     *      is empty, the amount is below the minimum, or any computed deposit amount rounds to zero.
     */
    function deposit(uint256 indexAmount) external nonReentrant {
        if (indexAmount == 0) revert ZeroAmount();
        if (indexAmount < MIN_DEPOSIT) revert BelowMinDeposit();

        uint256 len = _basketTokens.length;
        if (len == 0 || totalWeight == 0) revert EmptyBasket();

        address[] memory tokens = new address[](len);
        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            address token = _basketTokens[i];
            uint8 d = tokenDecimals[token];
            // Convert indexAmount (18 dec) into the token's native decimals using its weight.
            // amount = indexAmount * weight * 10^d / (totalWeight * 1e18)
            uint256 amount = (indexAmount * weight[token] * (10 ** d)) / (totalWeight * 1e18);
            if (amount == 0) revert AmountRoundsToZero();
            tokens[i] = token;
            amounts[i] = amount;
        }

        for (uint256 i = 0; i < len; ++i) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);
        }

        _mint(msg.sender, indexAmount);
        emit Deposited(msg.sender, indexAmount, tokens, amounts);
    }

    /**
     * @notice Redeem index tokens to receive a proportional slice of the underlying basket, minus a 0.1% fee.
     * @param indexAmount The amount of index tokens to burn.
     * @dev The 0.1% fee is deducted from each underlying token's gross redemption amount and
     *      accrues in {accumulatedFees}. The operator may recover accumulated fees via {recoverFees}.
     *      The fee is computed at full precision (multiply before divide) to avoid rounding loss.
     */
    function redeem(uint256 indexAmount) external nonReentrant {
        if (indexAmount == 0) revert ZeroAmount();

        uint256 len = _basketTokens.length;
        if (len == 0) revert EmptyBasket();
        if (balanceOf(msg.sender) < indexAmount) revert InsufficientBalance();

        uint256 supply = totalSupply();

        address[] memory tokens = new address[](len);
        uint256[] memory amounts = new uint256[](len);
        uint256[] memory feeAmounts = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            address token = _basketTokens[i];
            tokens[i] = token;

            uint256 bal = IERC20(token).balanceOf(address(this));
            uint256 fees = accumulatedFees[token];
            uint256 redeemable = bal > fees ? bal - fees : 0;

            // Gross redemption amount for this token (rounded down).
            uint256 gross = (indexAmount * redeemable) / supply;
            // Compute fee at full precision to avoid divide-before-multiply rounding loss.
            // fee = indexAmount * redeemable * FEE_BASIS_POINTS / (supply * WEIGHT_PRECISION)
            // Since FEE_BASIS_POINTS (10) < WEIGHT_PRECISION (10000), fee <= gross always holds.
            uint256 fee = (indexAmount * redeemable * FEE_BASIS_POINTS) / (supply * WEIGHT_PRECISION);
            amounts[i] = gross - fee;
            feeAmounts[i] = fee;

            accumulatedFees[token] = fees + fee;
        }

        _burn(msg.sender, indexAmount);

        for (uint256 i = 0; i < len; ++i) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, amounts[i]);
            }
        }

        emit Redeemed(msg.sender, indexAmount, tokens, amounts, feeAmounts);
    }

    //-----------------------------------------------------------------------//
    //                     Basket Management (Operator)                      //
    //-----------------------------------------------------------------------//

    /**
     * @notice Add a new wrapped Bitcoin token to the basket with a given weight.
     * @param token    The token address to add.
     * @param weight_  The weight in basis points (1e4 = 100%). Must be > 0 and <= WEIGHT_PRECISION.
     * @dev Decimals are auto-detected from the token; if detection fails, 18 is assumed.
     */
    function addToken(address token, uint256 weight_) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isSupported[token]) revert TokenAlreadySupported();
        if (weight_ == 0 || weight_ > WEIGHT_PRECISION) revert InvalidWeight();

        uint8 d = _getTokenDecimals(token);

        isSupported[token] = true;
        tokenDecimals[token] = d;
        weight[token] = weight_;
        _basketTokens.push(token);
        totalWeight += weight_;

        emit TokenAdded(token, d, weight_);
        _announceBasket();
    }

    /**
     * @notice Remove a token from the basket. The token will no longer be accepted for deposits
     *         or included in redemptions. Remaining balances may be swept via {sweepToken}.
     * @param token The token address to remove.
     */
    function removeToken(address token) external onlyOperator {
        if (!isSupported[token]) revert TokenNotSupported();

        isSupported[token] = false;
        uint256 w = weight[token];
        totalWeight -= w;
        delete weight[token];
        delete tokenDecimals[token];
        delete accumulatedFees[token];

        // Remove from the array (order not preserved).
        uint256 len = _basketTokens.length;
        for (uint256 i = 0; i < len; ++i) {
            if (_basketTokens[i] == token) {
                _basketTokens[i] = _basketTokens[len - 1];
                _basketTokens.pop();
                break;
            }
        }

        emit TokenRemoved(token);
        _announceBasket();
    }

    /**
     * @notice Adjust the weight of a single basket token.
     * @param token     The token address to adjust.
     * @param newWeight The new weight in basis points (1e4 = 100%).
     */
    function setWeight(address token, uint256 newWeight) external onlyOperator {
        if (!isSupported[token]) revert TokenNotSupported();
        if (newWeight == 0 || newWeight > WEIGHT_PRECISION) revert InvalidWeight();

        uint256 old = weight[token];
        if (old == newWeight) return;

        weight[token] = newWeight;
        totalWeight = totalWeight - old + newWeight;

        emit WeightAdjusted(token, old, newWeight);
        _announceBasket();
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Recover accumulated redemption fees for a basket token to a recipient.
     * @param token     The basket token whose fees to recover.
     * @param recipient The address to receive the fees.
     */
    function recoverFees(address token, address recipient) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert ZeroAmount();

        accumulatedFees[token] = 0;
        IERC20(token).safeTransfer(recipient, amount);

        emit FeesRecovered(token, recipient, amount);
    }

    /**
     * @notice Sweep the full balance of a token that is no longer in the basket.
     * @param token     The token address to sweep (must not be currently supported).
     * @param recipient The address to receive the swept tokens.
     */
    function sweepToken(address token, address recipient) external onlyOperator nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (isSupported[token]) revert TokenStillSupported();

        uint256 amount = IERC20(token).balanceOf(address(this));
        // Use range comparison instead of strict equality to avoid incorrect-equality finding.
        if (amount < 1) revert ZeroAmount();

        IERC20(token).safeTransfer(recipient, amount);

        emit TokenSwept(token, recipient, amount);
    }

    //-----------------------------------------------------------------------//
    //                              Views                                    //
    //-----------------------------------------------------------------------//

    /// @notice Returns the list of basket token addresses.
    function basketTokens() external view returns (address[] memory) {
        return _basketTokens;
    }

    /// @notice Returns the number of tokens in the basket.
    function basketSize() external view returns (uint256) {
        return _basketTokens.length;
    }

    /**
     * @notice Returns the full basket composition: tokens, weights, decimals, raw balances, and fees.
     */
    function getBasketInfo()
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory weights_,
            uint8[] memory decimalsArr,
            uint256[] memory balances,
            uint256[] memory fees
        )
    {
        uint256 len = _basketTokens.length;
        tokens = new address[](len);
        weights_ = new uint256[](len);
        decimalsArr = new uint8[](len);
        balances = new uint256[](len);
        fees = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            address t = _basketTokens[i];
            tokens[i] = t;
            weights_[i] = weight[t];
            decimalsArr[i] = tokenDecimals[t];
            fees[i] = accumulatedFees[t];
            balances[i] = IERC20(t).balanceOf(address(this));
        }
    }

    /**
     * @notice Emit a {BasketAnnounced} event containing the current index total supply
     *         and the underlying wrapped Bitcoin basket composition. Callable by anyone.
     */
    function announceBasket() external {
        _announceBasket();
    }

    //-----------------------------------------------------------------------//
    //                            Internal Helpers                           //
    //-----------------------------------------------------------------------//

    /// @dev Emits the current total supply and basket composition (tokens, weights, balances, fees).
    function _announceBasket() internal {
        uint256 len = _basketTokens.length;

        address[] memory tokens = new address[](len);
        uint256[] memory weights_ = new uint256[](len);
        uint256[] memory balances = new uint256[](len);
        uint256[] memory fees = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            address t = _basketTokens[i];
            tokens[i] = t;
            weights_[i] = weight[t];
            fees[i] = accumulatedFees[t];
            balances[i] = IERC20(t).balanceOf(address(this));
        }

        emit BasketAnnounced(totalSupply(), tokens, weights_, balances, fees);
    }

    /// @dev Attempts to read the decimals of a token via a low-level staticcall.
    ///      Falls back to 18 if the call fails or returns an invalid value.
    function _getTokenDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (success && data.length >= 32) {
            uint256 d = abi.decode(data, (uint256));
            if (d <= type(uint8).max) {
                return uint8(d);
            }
        }
        return 18;
    }
}
