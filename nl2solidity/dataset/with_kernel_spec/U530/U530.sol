// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedBridge {
    /*//////////////////////////////////////////////////////////////
                              METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public operator;
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Maximum wrapped tokens mintable in a single deposit call (10,000 whole units).
    uint256 public constant MAX_DEPOSIT = 10_000 ether;
    /// @dev Withdrawal fee in basis points. 10 bps == 0.1%.
    uint256 public constant FEE_RATE = 10;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                            REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _reentrancy = NOT_ENTERED;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed user, uint256 amount, uint256 minted);
    event Withdrawal(address indexed user, uint256 amountBurned, uint256 fee, uint256 received);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesSwept(address indexed operator, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ContractPaused();
    error NotPaused();
    error ZeroAmount();
    error ZeroAddress();
    error Unauthorized();
    error DepositCapExceeded(uint256 amount, uint256 cap);
    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address owner, address spender, uint256 allowed, uint256 needed);
    error TransferFailed();
    error Reentrancy();
    error NoFeesToSweep();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancy == ENTERED) revert Reentrancy();
        _reentrancy = ENTERED;
        _;
        _reentrancy = NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/
    /// @notice Deposit native tokens to mint an equal amount of wrapped tokens 1:1.
    /// @return minted The number of wrapped tokens minted to the caller.
    function deposit() external payable whenNotPaused returns (uint256 minted) {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_DEPOSIT) revert DepositCapExceeded(amount, MAX_DEPOSIT);

        minted = amount;
        _mint(msg.sender, minted);

        emit Deposit(msg.sender, amount, minted);
    }

    /*//////////////////////////////////////////////////////////////
                                REDEEM
    //////////////////////////////////////////////////////////////*/
    /// @notice Burn wrapped tokens to redeem native tokens back on the source chain.
    ///         A 0.1% fee is retained inside the contract for the operator to sweep.
    /// @return received The amount of native tokens sent back to the caller.
    function redeem(uint256 amount) external whenNotPaused nonReentrant returns (uint256 received) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(msg.sender, balanceOf[msg.sender], amount);
        }

        uint256 fee = (amount * FEE_RATE) / FEE_DENOMINATOR;
        received = amount - fee;

        // Effects: burn the redeemed wrapped tokens first.
        _burn(msg.sender, amount);

        // Interactions: send native to the caller. The fee stays locked in the contract.
        (bool ok, ) = msg.sender.call{value: received}("");
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount, fee, received);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20-LIKE LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if (allowed < amount) {
                    revert InsufficientAllowance(from, msg.sender, allowed, amount);
                }
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNALS
    //////////////////////////////////////////////////////////////*/
    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(from, balanceOf[from], amount);
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(from, balanceOf[from], amount);
        }
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR CONTROLS
    //////////////////////////////////////////////////////////////*/
    /// @notice Pause all deposit and withdrawal operations.
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause deposit and withdrawal operations.
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Transfer operator rights to a new address.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /// @notice Sweep accumulated withdrawal fees (and any excess native) to the operator.
    function sweepFees() external onlyOperator nonReentrant {
        uint256 bal = address(this).balance;
        // Use a safe comparison to avoid underflow and avoid strict equality on
        // potentially manipulated balances. Only sweep when there is a true surplus.
        if (bal <= totalSupply) revert NoFeesToSweep();
        uint256 excess = bal - totalSupply;

        (bool ok, ) = operator.call{value: excess}("");
        if (!ok) revert TransferFailed();

        emit FeesSwept(msg.sender, excess);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/
    /// @notice Total native tokens currently held by the contract (locked assets plus accumulated fees).
    function totalAssets() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Accumulated withdrawal fees available for the operator to sweep.
    function accumulatedFees() external view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > totalSupply ? bal - totalSupply : 0;
    }
}
