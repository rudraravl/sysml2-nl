// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MemeToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _initialHolder
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        balanceOf[_initialHolder] = _initialSupply;
        emit Transfer(address(0), _initialHolder, _initialSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "Insufficient allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(to != address(0), "Transfer to zero address");

        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }

        emit Transfer(from, to, value);
    }
}

contract MemeTokenFactory {
    address public owner;
    uint256 public creationFee;
    uint256 public constant MAX_TOKENS_PER_CREATOR = 100;
    uint256 public constant DEFAULT_CREATION_FEE = 0.1 ether;

    struct TokenConfig {
        address tokenAddress;
        string name;
        string symbol;
        uint256 totalSupply;
        address creator;
        bool exists;
    }

    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => uint256) public creatorTokenCount;
    mapping(address => bool) public isLaunchedToken;
    mapping(address => bool) public submittedToMemeBattle;
    mapping(address => bool) public isMemeBattleWinner;

    address[] public allLaunchedTokens;
    address[] public memeBattleSubmissions;
    address[] public memeBattleWinners;

    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 totalSupply
    );
    event MemeBattleSubmitted(address indexed tokenAddress, address indexed submitter);
    event MemeBattleWinnerDesignated(address indexed tokenAddress, address indexed creator);
    event CreationFeeUpdated(uint256 previousFee, uint256 newFee);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    error NotOwner();
    error InsufficientFee(uint256 required, uint256 provided);
    error MaxTokensPerCreatorReached(address creator, uint256 limit);
    error InvalidTokenMetadata();
    error InvalidInitialSupply();
    error TokenNotLaunched(address token);
    error NotTokenCreator(address token, address caller);
    error TokenAlreadySubmitted(address token);
    error TokenNotSubmitted(address token);
    error TokenAlreadyWinner(address token);
    error WithdrawalFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        creationFee = DEFAULT_CREATION_FEE;
    }

    receive() external payable {}

    function createToken(
        string calldata name_,
        string calldata symbol_,
        uint256 initialSupply
    ) external payable returns (address tokenAddress) {
        uint256 fee = creationFee;
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);
        if (bytes(name_).length == 0 || bytes(symbol_).length == 0) revert InvalidTokenMetadata();
        if (initialSupply == 0) revert InvalidInitialSupply();
        if (creatorTokenCount[msg.sender] >= MAX_TOKENS_PER_CREATOR) {
            revert MaxTokensPerCreatorReached(msg.sender, MAX_TOKENS_PER_CREATOR);
        }

        MemeToken newToken = new MemeToken(name_, symbol_, initialSupply, address(this));
        tokenAddress = address(newToken);

        tokenConfigs[tokenAddress] = TokenConfig({
            tokenAddress: tokenAddress,
            name: name_,
            symbol: symbol_,
            totalSupply: initialSupply,
            creator: msg.sender,
            exists: true
        });

        isLaunchedToken[tokenAddress] = true;
        creatorTokenCount[msg.sender] += 1;
        allLaunchedTokens.push(tokenAddress);

        emit TokenCreated(tokenAddress, msg.sender, name_, symbol_, initialSupply);
    }

    function submitToMemeBattle(address tokenAddress) external {
        TokenConfig storage config = tokenConfigs[tokenAddress];
        if (!config.exists) revert TokenNotLaunched(tokenAddress);
        if (config.creator != msg.sender) revert NotTokenCreator(tokenAddress, msg.sender);
        if (submittedToMemeBattle[tokenAddress]) revert TokenAlreadySubmitted(tokenAddress);

        submittedToMemeBattle[tokenAddress] = true;
        memeBattleSubmissions.push(tokenAddress);

        emit MemeBattleSubmitted(tokenAddress, msg.sender);
    }

    function designateMemeBattleWinner(address tokenAddress) external onlyOwner {
        TokenConfig storage config = tokenConfigs[tokenAddress];
        if (!config.exists) revert TokenNotLaunched(tokenAddress);
        if (!submittedToMemeBattle[tokenAddress]) revert TokenNotSubmitted(tokenAddress);
        if (isMemeBattleWinner[tokenAddress]) revert TokenAlreadyWinner(tokenAddress);

        isMemeBattleWinner[tokenAddress] = true;
        memeBattleWinners.push(tokenAddress);

        emit MemeBattleWinnerDesignated(tokenAddress, config.creator);
    }

    function setCreationFee(uint256 newFee) external onlyOwner {
        uint256 previousFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(previousFee, newFee);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = address(this).balance;

        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit FeesWithdrawn(owner, amount);
    }

    function getAllLaunchedTokens() external view returns (address[] memory) {
        return allLaunchedTokens;
    }

    function getMemeBattleSubmissions() external view returns (address[] memory) {
        return memeBattleSubmissions;
    }

    function getMemeBattleWinners() external view returns (address[] memory) {
        return memeBattleWinners;
    }

    function getLaunchedTokenCount() external view returns (uint256) {
        return allLaunchedTokens.length;
    }

    function getTokenConfig(address tokenAddress) external view returns (TokenConfig memory) {
        return tokenConfigs[tokenAddress];
    }
}
