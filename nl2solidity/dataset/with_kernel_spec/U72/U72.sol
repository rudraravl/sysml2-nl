// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStablecoin {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenizedGovDebtFund {
    string public constant name = "Tokenized Government Debt Fund";
    string public constant symbol = "tGDF";
    uint8 public constant decimals = 18;

    uint256 public constant REDEMPTION_FEE_BPS = 5; // 0.05%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 100 * 10**18;

    IStablecoin public immutable stablecoin;
    address public operator;
    bool public paused;
    bool private _initialized;

    uint256 public totalShares;
    uint256 public reserveBalance;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private _guard;

    event SharesMinted(address indexed account, uint256 stablecoinAmount, uint256 sharesMinted);
    event SharesRedeemed(address indexed account, uint256 sharesBurned, uint256 stablecoinReturned, uint256 feeCharged);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event ReserveUpdated(address indexed by, uint256 previousBalance, uint256 newBalance);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error FundPaused();
    error InsufficientDeposit();
    error InsufficientShares();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error ZeroAddress();
    error ZeroAmount();
    error StablecoinTransferFailed();
    error ReentrantCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert FundPaused();
        _;
    }

    modifier nonReentrant() {
        if (_guard != 1) revert ReentrantCall();
        _guard = 2;
        _;
        _guard = 1;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IStablecoin(_stablecoin);
        operator = _operator;
        paused = false;
        _initialized = false;
        _guard = 1;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();
        if (_initialized && reserveBalance == 0) revert InsufficientReserve();

        uint256 sharesToMint;
        if (!_initialized) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / reserveBalance;
        }
        if (sharesToMint < 1) revert ZeroAmount();

        // Effects before interactions
        if (!_initialized) {
            _initialized = true;
        }
        balanceOf[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        reserveBalance += amount;

        // Interaction
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert StablecoinTransferFailed();

        emit SharesMinted(msg.sender, amount, sharesToMint);
        emit Transfer(address(0), msg.sender, sharesToMint);
    }

    function redeem(uint256 shares) external whenNotPaused nonReentrant {
        if (shares < 1) revert ZeroAmount();
        if (totalShares < 1) revert InsufficientShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        // Avoid divide-before-multiply: compute fee directly from raw quantities.
        // grossAmount = (shares * reserveBalance) / totalShares
        // fee = grossAmount * REDEMPTION_FEE_BPS / BPS_DENOMINATOR
        //     = (shares * reserveBalance * REDEMPTION_FEE_BPS) / (totalShares * BPS_DENOMINATOR)
        uint256 grossAmount = (shares * reserveBalance) / totalShares;
        uint256 fee = (shares * reserveBalance * REDEMPTION_FEE_BPS) / (totalShares * BPS_DENOMINATOR);
        uint256 netOut = grossAmount - fee;
        if (netOut < 1) revert ZeroAmount();

        if (stablecoin.balanceOf(address(this)) < netOut) revert InsufficientReserve();

        // Effects before interactions
        balanceOf[msg.sender] -= shares;
        totalShares -= shares;
        reserveBalance -= grossAmount;

        // Interaction
        bool ok = stablecoin.transfer(msg.sender, netOut);
        if (!ok) revert StablecoinTransferFailed();

        emit SharesRedeemed(msg.sender, shares, netOut, fee);
        emit Transfer(msg.sender, address(0), shares);
    }

    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external nonReentrant returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[msg.sender][spender];
        if (allowed < subtractedValue) revert InsufficientAllowance();
        allowance[msg.sender][spender] = allowed - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function updateReserve(uint256 newReserveBalance) external onlyOperator {
        uint256 previous = reserveBalance;
        reserveBalance = newReserveBalance;
        emit ReserveUpdated(msg.sender, previous, newReserveBalance);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function totalSupply() external view returns (uint256) {
        return totalShares;
    }
}
