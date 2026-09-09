// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialTokenBondingCurve {
    address public operator;
    address payable public treasury;
    
    uint256 public initialPrice;
    uint256 public slope;
    uint256 public totalSupply;
    
    bool public priceInitialized;
    
    uint256 public constant FEE_PERCENT = 5;
    uint256 public constant DEFAULT_INITIAL_PRICE = 0.001 ether;
    
    mapping(address => uint256) public balances;
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public claimableNative;
    
    event Purchased(address indexed buyer, uint256 tokenAmount, uint256 nativeAmount);
    event Sold(address indexed seller, uint256 tokenAmount, uint256 nativeAmount);
    event Claimed(address indexed user, uint256 nativeAmount);
    event PriceSet(uint256 initialPrice);
    event SlopeUpdated(uint256 newSlope);
    event TreasuryUpdated(address newTreasury);
    
    error NotOperator();
    error ZeroAddress();
    error PriceNotInitialized();
    error PriceAlreadyInitialized();
    error InsufficientTokens();
    error InsufficientFunds();
    error ZeroAmount();
    error TransferFailed();
    
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }
    
    constructor(address _operator, address payable _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
    }
    
    function setInitialPrice(uint256 _price) external onlyOperator {
        if (priceInitialized) revert PriceAlreadyInitialized();
        if (_price == 0) revert ZeroAmount();
        initialPrice = _price;
        priceInitialized = true;
        emit PriceSet(_price);
    }
    
    function setDefaultInitialPrice() external onlyOperator {
        if (priceInitialized) revert PriceAlreadyInitialized();
        initialPrice = DEFAULT_INITIAL_PRICE;
        priceInitialized = true;
        emit PriceSet(DEFAULT_INITIAL_PRICE);
    }
    
    function setSlope(uint256 _slope) external onlyOperator {
        slope = _slope;
        emit SlopeUpdated(_slope);
    }
    
    function setTreasury(address payable _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
    
    function currentPrice() public view returns (uint256) {
        return initialPrice + (slope * totalSupply);
    }
    
    function buy() external payable {
        if (!priceInitialized) revert PriceNotInitialized();
        if (msg.value == 0) revert ZeroAmount();
        
        uint256 price = currentPrice();
        if (price == 0) revert ZeroAmount();
        
        uint256 tokenAmount = msg.value / price;
        if (tokenAmount == 0) revert ZeroAmount();
        
        balances[msg.sender] += tokenAmount;
        contributions[msg.sender] += msg.value;
        totalSupply += tokenAmount;
        
        emit Purchased(msg.sender, tokenAmount, msg.value);
    }
    
    function sell(uint256 tokenAmount) external {
        if (!priceInitialized) revert PriceNotInitialized();
        if (tokenAmount == 0) revert ZeroAmount();
        if (balances[msg.sender] < tokenAmount) revert InsufficientTokens();
        
        uint256 price = currentPrice();
        uint256 nativeAmount = tokenAmount * price;
        
        if (address(this).balance < nativeAmount) revert InsufficientFunds();
        
        balances[msg.sender] -= tokenAmount;
        totalSupply -= tokenAmount;
        
        uint256 fee = (nativeAmount * FEE_PERCENT) / 100;
        uint256 payout = nativeAmount - fee;
        
        claimableNative[msg.sender] += payout;
        
        if (fee > 0) {
            (bool success, ) = treasury.call{value: fee}("");
            if (!success) revert TransferFailed();
        }
        
        emit Sold(msg.sender, tokenAmount, nativeAmount);
    }
    
    function claim() external {
        uint256 amount = claimableNative[msg.sender];
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientFunds();
        
        claimableNative[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
        
        emit Claimed(msg.sender, amount);
    }
    
    receive() external payable {}
}
