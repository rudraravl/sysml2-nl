// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialEngagementToken {
    // --- Custom errors ---
    error ZeroAddress();
    error PriceTooLow();
    error NotOperator();
    error Paused();
    error InsufficientBalance();
    error ZeroAmount();
    error NoNativeSent();
    error TransferFailed();
    error ReentrantCall();

    // --- Events ---
    event Mint(address indexed creator, address indexed user, uint256 tokenAmount, uint256 nativeAmount);
    event Burn(address indexed creator, address indexed user, uint256 tokenAmount, uint256 nativeReturned, uint256 fee);
    event EngagementTransfer(address indexed creator, address indexed from, address indexed to, uint256 amount);
    event NativeDeposited(address indexed creator, address indexed user, uint256 nativeAmount);
    event NativeWithdrawn(address indexed creator, address indexed user, uint256 nativeReturned, uint256 fee);
    event PriceUpdated(address indexed creator, uint256 price);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // --- Constants ---
    uint256 public constant MIN_PRICE = 10 ** 15; // 0.001 native currency per token
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant DECIMALS = 18;

    // --- State ---
    address public operator;
    bool public paused;
    bool private _locked;

    // creator => price per engagement token (in native wei)
    mapping(address => uint256) public pricePerCreator;

    // creator => user => engagement token balance
    mapping(address => mapping(address => uint256)) public balanceOf;

    // creator => total supply of engagement tokens
    mapping(address => uint256) public totalSupply;

    // creator => user => native currency deposited
    mapping(address => mapping(address => uint256)) public depositedBalanceOf;

    // creator => total native currency deposited
    mapping(address => uint256) public totalDeposited;

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // --- Constructor ---
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // --- Operator functions ---
    function setPrice(address creator, uint256 _price) external onlyOperator {
        if (creator == address(0)) revert ZeroAddress();
        if (_price < MIN_PRICE) revert PriceTooLow();
        pricePerCreator[creator] = _price;
        emit PriceUpdated(creator, _price);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // --- User functions ---
    function deposit(address creator) external payable whenNotPaused nonReentrant {
        if (creator == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert NoNativeSent();
        uint256 price = pricePerCreator[creator];
        if (price < MIN_PRICE) revert PriceTooLow();

        uint256 factor = 10 ** uint256(DECIMALS);
        uint256 tokenAmount = (msg.value * factor) / price;
        if (tokenAmount == 0) revert ZeroAmount();

        // Compute the exact native cost backing the minted tokens without
        // multiplying the result of a division (avoids divide-before-multiply).
        uint256 remainder = (msg.value * factor) % price;
        uint256 cost = (msg.value * factor - remainder) / factor;
        uint256 refund = msg.value - cost;

        // Effects
        balanceOf[creator][msg.sender] += tokenAmount;
        totalSupply[creator] += tokenAmount;
        depositedBalanceOf[creator][msg.sender] += cost;
        totalDeposited[creator] += cost;

        emit NativeDeposited(creator, msg.sender, cost);
        emit Mint(creator, msg.sender, tokenAmount, cost);

        // Interactions
        if (refund > 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert TransferFailed();
        }
    }

    function transfer(address creator, address to, uint256 amount) external nonReentrant {
        if (creator == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 senderBalance = balanceOf[creator][msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 supply = totalSupply[creator];
        // Move proportional deposited native balance alongside tokens
        uint256 share = (amount * totalDeposited[creator]) / supply;

        // Effects
        balanceOf[creator][msg.sender] = senderBalance - amount;
        balanceOf[creator][to] += amount;
        depositedBalanceOf[creator][msg.sender] -= share;
        depositedBalanceOf[creator][to] += share;

        emit EngagementTransfer(creator, msg.sender, to, amount);
    }

    function withdraw(address creator, uint256 tokenAmount) external whenNotPaused nonReentrant {
        if (creator == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert ZeroAmount();
        uint256 price = pricePerCreator[creator];
        if (price < MIN_PRICE) revert PriceTooLow();

        uint256 userBalance = balanceOf[creator][msg.sender];
        if (userBalance < tokenAmount) revert InsufficientBalance();

        uint256 supply = totalSupply[creator];
        uint256 deposited = totalDeposited[creator];
        if (supply == 0) revert InsufficientBalance();

        // Native currency corresponding to the burned tokens (proportional share)
        uint256 nativeGross = (tokenAmount * deposited) / supply;
        if (nativeGross == 0) revert ZeroAmount();

        // Compute fee without multiplying the result of a division.
        uint256 fee = (tokenAmount * deposited * FEE_BASIS_POINTS) / (supply * BPS_DENOMINATOR);
        uint256 nativeToReturn = nativeGross - fee;

        // Effects
        balanceOf[creator][msg.sender] = userBalance - tokenAmount;
        totalSupply[creator] = supply - tokenAmount;
        totalDeposited[creator] = deposited - nativeGross;
        depositedBalanceOf[creator][msg.sender] -= nativeGross;

        emit Burn(creator, msg.sender, tokenAmount, nativeToReturn, fee);
        emit NativeWithdrawn(creator, msg.sender, nativeToReturn, fee);

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: nativeToReturn}("");
        if (!success) revert TransferFailed();

        if (fee > 0) {
            (bool feeSuccess, ) = payable(operator).call{value: fee}("");
            if (!feeSuccess) revert TransferFailed();
        }
    }

    // --- Views ---
    function getBalance(address creator, address user) external view returns (uint256) {
        return balanceOf[creator][user];
    }

    function getTotalSupply(address creator) external view returns (uint256) {
        return totalSupply[creator];
    }

    function getPrice(address creator) external view returns (uint256) {
        return pricePerCreator[creator];
    }

    function getDepositedBalance(address creator, address user) external view returns (uint256) {
        return depositedBalanceOf[creator][user];
    }

    function getTotalDeposited(address creator) external view returns (uint256) {
        return totalDeposited[creator];
    }

    function quoteDeposit(address creator, uint256 nativeAmount) external view returns (uint256) {
        uint256 price = pricePerCreator[creator];
        if (price == 0) return 0;
        return (nativeAmount * (10 ** uint256(DECIMALS))) / price;
    }

    function quoteWithdraw(address creator, uint256 tokenAmount) external view returns (uint256 nativeToReturn, uint256 fee) {
        uint256 supply = totalSupply[creator];
        uint256 deposited = totalDeposited[creator];
        if (supply == 0) return (0, 0);
        uint256 nativeGross = (tokenAmount * deposited) / supply;
        // Compute fee without multiplying the result of a division.
        fee = (tokenAmount * deposited * FEE_BASIS_POINTS) / (supply * BPS_DENOMINATOR);
        nativeToReturn = nativeGross - fee;
    }

    receive() external payable {
        // Reject direct native transfers; use deposit()
        revert NoNativeSent();
    }
}
