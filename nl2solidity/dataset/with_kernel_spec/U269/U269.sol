// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LiquidStakingDerivative
/// @notice A liquid staking derivative token representing staked Ether that accrues yield.
///         Users deposit Ether to mint the derivative token and can redeem it back for Ether.
///         A designated operator manages the staked Ether balance and exchange rate.
contract LiquidStakingDerivative {
    ////////////////////////////////////////////////////////////////
    //                         Custom Errors                      //
    ////////////////////////////////////////////////////////////////
    error LiquidStakingDerivative__OnlyOperator();
    error LiquidStakingDerivative__DepositTooSmall(uint256 amount, uint256 minimum);
    error LiquidStakingDerivative__InsufficientBalance(uint256 available, uint256 required);
    error LiquidStakingDerivative__ZeroAddress();
    error LiquidStakingDerivative__ZeroAmount();
    error LiquidStakingDerivative__InsufficientContractBalance();
    error LiquidStakingDerivative__TransferFailed();
    error LiquidStakingDerivative__InvalidMintAmount();
    error LiquidStakingDerivative__InvalidBurnAmount();
    error LiquidStakingDerivative__InsufficientAllowance(uint256 available, uint256 required);
    error LiquidStakingDerivative__InvalidRecipient();
    error LiquidStakingDerivative__Reentrancy();

    ////////////////////////////////////////////////////////////////
    //                        State Variables                     //
    ////////////////////////////////////////////////////////////////
    address public operator;
    uint256 public totalStakedEther;
    uint256 public exchangeRate;
    uint256 public totalFees;
    mapping(address => uint256) public userDeposits;

    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    ////////////////////////////////////////////////////////////////
    //                           Constants                        //
    ////////////////////////////////////////////////////////////////
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18;

    ////////////////////////////////////////////////////////////////
    //                            Events                           //
    ////////////////////////////////////////////////////////////////
    event Deposited(address indexed user, uint256 etherAmount, uint256 lsdAmount);
    event Redeemed(address indexed user, uint256 lsdAmount, uint256 etherReturned, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event StakedEtherUpdated(uint256 oldBalance, uint256 newBalance);
    event FeesClaimed(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    ////////////////////////////////////////////////////////////////
    //                          Modifiers                         //
    ////////////////////////////////////////////////////////////////
    modifier onlyOperator() {
        if (msg.sender != operator) revert LiquidStakingDerivative__OnlyOperator();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert LiquidStakingDerivative__ZeroAmount();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert LiquidStakingDerivative__Reentrancy();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    ////////////////////////////////////////////////////////////////
    //                          Constructor                       //
    ////////////////////////////////////////////////////////////////
    /// @param _operator The address designated to manage staked Ether and exchange rate
    constructor(address _operator) {
        if (_operator == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        _name = "Liquid Staked Ether";
        _symbol = "LSETH";
        operator = _operator;
        exchangeRate = INITIAL_EXCHANGE_RATE;
        _reentrancyStatus = _NOT_ENTERED;
    }

    ////////////////////////////////////////////////////////////////
    //                       Core Functions                       //
    ////////////////////////////////////////////////////////////////

    /// @notice Deposit Ether to mint LSD tokens at the current exchange rate
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) {
            revert LiquidStakingDerivative__DepositTooSmall(msg.value, MIN_DEPOSIT);
        }

        uint256 lsdAmount = (msg.value * EXCHANGE_RATE_PRECISION) / exchangeRate;
        if (lsdAmount == 0) revert LiquidStakingDerivative__ZeroAmount();

        userDeposits[msg.sender] += msg.value;
        totalStakedEther += msg.value;

        _mint(msg.sender, lsdAmount);

        emit Deposited(msg.sender, msg.value, lsdAmount);
    }

    /// @notice Redeem LSD tokens for Ether, subject to a 0.5% fee
    /// @param lsdAmount The amount of LSD tokens to redeem
    function redeem(uint256 lsdAmount) external nonReentrant nonZeroAmount(lsdAmount) {
        uint256 userBalance = balanceOf(msg.sender);
        if (userBalance < lsdAmount) {
            revert LiquidStakingDerivative__InsufficientBalance(userBalance, lsdAmount);
        }

        // Compute the fee using full precision before dividing, to avoid
        // divide-before-multiply rounding errors.
        uint256 grossEtherValue = lsdAmount * exchangeRate;
        uint256 fee = grossEtherValue * FEE_BASIS_POINTS / (EXCHANGE_RATE_PRECISION * BPS_DENOMINATOR);
        uint256 etherValue = grossEtherValue / EXCHANGE_RATE_PRECISION;
        if (etherValue == 0) revert LiquidStakingDerivative__ZeroAmount();

        uint256 returnAmount = etherValue - fee;

        if (returnAmount > totalStakedEther) {
            revert LiquidStakingDerivative__InsufficientContractBalance();
        }
        if (address(this).balance < returnAmount) {
            revert LiquidStakingDerivative__InsufficientContractBalance();
        }

        // Effects
        _burn(msg.sender, lsdAmount);
        totalStakedEther -= etherValue;
        totalFees += fee;

        // Interaction
        (bool success, ) = msg.sender.call{value: returnAmount}("");
        if (!success) revert LiquidStakingDerivative__TransferFailed();

        emit Redeemed(msg.sender, lsdAmount, returnAmount, fee);
    }

    ////////////////////////////////////////////////////////////////
    //                    Operator Functions                      //
    ////////////////////////////////////////////////////////////////

    /// @notice Update the total staked Ether balance and recalculate the exchange rate
    /// @param newBalance The new total staked Ether balance (e.g., after rewards or slashing)
    function updateStakedEtherBalance(uint256 newBalance) external onlyOperator {
        uint256 oldBalance = totalStakedEther;
        totalStakedEther = newBalance;

        if (totalSupply() > 0 && newBalance > 0) {
            uint256 newRate = (newBalance * EXCHANGE_RATE_PRECISION) / totalSupply();
            uint256 oldRate = exchangeRate;
            if (newRate != oldRate) {
                exchangeRate = newRate;
                emit ExchangeRateUpdated(oldRate, newRate);
            }
        }

        emit StakedEtherUpdated(oldBalance, newBalance);
    }

    /// @notice Directly adjust the exchange rate between LSD tokens and Ether
    /// @param newRate The new exchange rate expressed with EXCHANGE_RATE_PRECISION decimals
    function setExchangeRate(uint256 newRate) external onlyOperator nonZeroAmount(newRate) {
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    /// @notice Claim accumulated redemption fees to the operator address
    function claimFees() external onlyOperator nonReentrant {
        uint256 amount = totalFees;
        if (amount == 0) revert LiquidStakingDerivative__ZeroAmount();
        if (address(this).balance < amount) {
            revert LiquidStakingDerivative__InsufficientContractBalance();
        }

        totalFees = 0;

        (bool success, ) = operator.call{value: amount}("");
        if (!success) revert LiquidStakingDerivative__TransferFailed();

        emit FeesClaimed(operator, amount);
    }

    /// @notice Transfer the operator role to a new address
    /// @param newOperator The address of the new operator
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    ////////////////////////////////////////////////////////////////
    //                       View Functions                       //
    ////////////////////////////////////////////////////////////////

    /// @notice Get the current exchange rate (1 LSD = exchangeRate / PRECISION Ether)
    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }

    /// @notice Get the total staked Ether balance
    function getStakedEtherBalance() external view returns (uint256) {
        return totalStakedEther;
    }

    /// @notice Get a user's cumulative deposited Ether amount
    /// @param user The address to query
    function getUserDeposit(address user) external view returns (uint256) {
        return userDeposits[user];
    }

    /// @notice Get a user's proportional share of the total staked Ether
    /// @param user The address to query
    function getUserShare(address user) external view returns (uint256) {
        if (totalSupply() == 0) return 0;
        return (balanceOf(user) * totalStakedEther) / totalSupply();
    }

    /// @notice Get the total accumulated redemption fees
    function getTotalFees() external view returns (uint256) {
        return totalFees;
    }

    ////////////////////////////////////////////////////////////////
    //                        ERC20 Functions                     //
    ////////////////////////////////////////////////////////////////

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
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
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert LiquidStakingDerivative__InsufficientAllowance(currentAllowance, amount);
        }
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert LiquidStakingDerivative__InsufficientAllowance(currentAllowance, subtractedValue);
        }
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    ////////////////////////////////////////////////////////////////
    //                       Internal ERC20                       //
    ////////////////////////////////////////////////////////////////

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        if (to == address(0)) revert LiquidStakingDerivative__InvalidRecipient();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert LiquidStakingDerivative__InsufficientBalance(fromBalance, amount);
        }

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        if (amount == 0) revert LiquidStakingDerivative__InvalidMintAmount();

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        if (amount == 0) revert LiquidStakingDerivative__InvalidBurnAmount();

        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) {
            revert LiquidStakingDerivative__InsufficientBalance(accountBalance, amount);
        }

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert LiquidStakingDerivative__ZeroAddress();
        if (spender == address(0)) revert LiquidStakingDerivative__ZeroAddress();

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                        Receive Function                    //
    ////////////////////////////////////////////////////////////////

    /// @notice Allow the contract to receive Ether (e.g., staking rewards sent by operator)
    receive() external payable {}
}
