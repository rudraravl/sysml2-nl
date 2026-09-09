// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MinimalERC20
 * @dev A minimal ERC-20 implementation used as the template token deployed by the launchpad.
 */
contract MinimalERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply, address _mintTo) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        balanceOf[_mintTo] = _initialSupply;
        emit Transfer(address(0), _mintTo, _initialSupply);
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
            require(allowed >= value, "ERC20: insufficient allowance");
            unchecked {
                allowance[from][msg.sender] = allowed - value;
            }
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "ERC20: insufficient balance");
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}

/**
 * @title TokenLaunchpad
 * @dev Facilitates the creation and initial distribution of new fungible tokens.
 *      Charges a fixed platform fee in native currency for each launch and holds
 *      the newly minted tokens until the creator claims their allocated portion.
 */
contract TokenLaunchpad {
    // ---------------------------------------------------------------------
    //                            Constants
    // ---------------------------------------------------------------------
    uint256 public constant PLATFORM_FEE = 0.08 ether;
    uint256 public constant MIN_SUPPLY = 1_000_000;
    uint256 public constant MAX_SUPPLY = 1_000_000_000;
    uint256 public constant BASIS_POINTS = 10_000;

    // ---------------------------------------------------------------------
    //                            Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error InvalidSupply(uint256 supply);
    error IncorrectFee(uint256 provided, uint256 required);
    error EmptyName();
    error EmptySymbol();
    error TokenNotFound(uint256 tokenId);
    error NotCreator(uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error NothingToWithdraw();
    error InvalidFeePercentage(uint256 percentage);
    error TransferFailed();

    // ---------------------------------------------------------------------
    //                            Events
    // ---------------------------------------------------------------------
    event TokenLaunched(
        uint256 indexed tokenId,
        address indexed creator,
        address tokenAddress,
        string name,
        string symbol,
        uint256 totalSupply
    );
    event TokensClaimed(uint256 indexed tokenId, address indexed creator, uint256 amount);
    event PlatformFeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event PlatformFeesWithdrawn(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    //                            Storage
    // ---------------------------------------------------------------------
    struct TokenConfig {
        address creator;
        address tokenAddress;
        uint256 totalSupply;
        uint256 feePercentage; // basis points captured at launch time
        bool claimed;
    }

    address public operator;
    uint256 public platformFeePercentage; // basis points (e.g., 100 = 1%)
    uint256 public platformFeeBalance;
    uint256 public nextTokenId;

    mapping(uint256 => TokenConfig) private s_tokens;

    // ---------------------------------------------------------------------
    //                            Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    //                            Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, uint256 _platformFeePercentage) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_platformFeePercentage > BASIS_POINTS) revert InvalidFeePercentage(_platformFeePercentage);
        operator = _operator;
        platformFeePercentage = _platformFeePercentage;
        nextTokenId = 1;
    }

    // ---------------------------------------------------------------------
    //                       External / Public Logic
    // ---------------------------------------------------------------------

    /**
     * @notice Launches a new ERC-20 token and holds the minted supply.
     * @dev Caller must send exactly PLATFORM_FEE native currency.
     * @param name      Name of the new token.
     * @param symbol    Symbol of the new token.
     * @param initialSupply Total supply (must be within [MIN_SUPPLY, MAX_SUPPLY]).
     * @return tokenId  Unique identifier assigned to the launched token.
     */
    function launchToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply
    ) external payable returns (uint256 tokenId) {
        if (bytes(name).length == 0) revert EmptyName();
        if (bytes(symbol).length == 0) revert EmptySymbol();
        if (initialSupply < MIN_SUPPLY || initialSupply > MAX_SUPPLY) revert InvalidSupply(initialSupply);
        if (msg.value != PLATFORM_FEE) revert IncorrectFee(msg.value, PLATFORM_FEE);

        MinimalERC20 newToken = new MinimalERC20(name, symbol, initialSupply, address(this));

        tokenId = nextTokenId++;
        s_tokens[tokenId] = TokenConfig({
            creator: msg.sender,
            tokenAddress: address(newToken),
            totalSupply: initialSupply,
            feePercentage: platformFeePercentage,
            claimed: false
        });

        platformFeeBalance += msg.value;

        emit TokenLaunched(tokenId, msg.sender, address(newToken), name, symbol, initialSupply);
    }

    /**
     * @notice Allows the token creator to claim their allocated portion.
     * @dev The platform retains a percentage (basis points) of the supply; the
     *      remainder is transferred to the creator. The platform's portion remains
     *      held by this contract for the operator to retrieve separately.
     * @param tokenId Identifier of the launched token.
     */
    function claimTokens(uint256 tokenId) external {
        TokenConfig storage config = s_tokens[tokenId];
        if (config.tokenAddress == address(0)) revert TokenNotFound(tokenId);
        if (msg.sender != config.creator) revert NotCreator(tokenId);
        if (config.claimed) revert AlreadyClaimed(tokenId);

        config.claimed = true;

        uint256 creatorAmount = (config.totalSupply * (BASIS_POINTS - config.feePercentage)) / BASIS_POINTS;

        // Checks-effects-interactions: state updated before external call.
        bool success = MinimalERC20(config.tokenAddress).transfer(msg.sender, creatorAmount);
        if (!success) revert TransferFailed();

        emit TokensClaimed(tokenId, msg.sender, creatorAmount);
    }

    /**
     * @notice Updates the platform fee percentage applied to future launches.
     * @param newPercentage New fee in basis points (0 - 10_000).
     */
    function setPlatformFeePercentage(uint256 newPercentage) external onlyOperator {
        if (newPercentage > BASIS_POINTS) revert InvalidFeePercentage(newPercentage);
        uint256 oldPercentage = platformFeePercentage;
        platformFeePercentage = newPercentage;
        emit PlatformFeePercentageUpdated(oldPercentage, newPercentage);
    }

    /**
     * @notice Withdraws all accumulated native-currency platform fees to the operator.
     */
    function withdrawPlatformFees() external onlyOperator {
        uint256 amount = platformFeeBalance;
        if (amount == 0) revert NothingToWithdraw();

        platformFeeBalance = 0;

        (bool success, ) = payable(operator).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit PlatformFeesWithdrawn(operator, amount);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(previousOperator, newOperator);
    }

    /**
     * @notice Retrieves the configuration of a launched token.
     * @param tokenId Identifier of the token.
     */
    function getTokenConfig(uint256 tokenId)
        external
        view
        returns (
            address creator,
            address tokenAddress,
            uint256 totalSupply,
            uint256 feePercentage,
            bool claimed
        )
    {
        TokenConfig storage config = s_tokens[tokenId];
        if (config.tokenAddress == address(0)) revert TokenNotFound(tokenId);
        return (config.creator, config.tokenAddress, config.totalSupply, config.feePercentage, config.claimed);
    }

    /**
     * @notice Returns the platform's retained token balance for a given launched token.
     * @param tokenId Identifier of the token.
     */
    function getPlatformTokenBalance(uint256 tokenId) external view returns (uint256) {
        TokenConfig storage config = s_tokens[tokenId];
        if (config.tokenAddress == address(0)) revert TokenNotFound(tokenId);
        return MinimalERC20(config.tokenAddress).balanceOf(address(this));
    }

    /**
     * @notice Allows the operator to retrieve the platform's retained portion of a token.
     * @param tokenId Identifier of the token.
     */
    function withdrawPlatformTokens(uint256 tokenId) external onlyOperator {
        TokenConfig storage config = s_tokens[tokenId];
        if (config.tokenAddress == address(0)) revert TokenNotFound(tokenId);

        uint256 platformAmount = (config.totalSupply * config.feePercentage) / BASIS_POINTS;
        if (platformAmount == 0) revert NothingToWithdraw();

        // Zero out the recorded allocation so it can only be retrieved once.
        config.totalSupply = 0;

        bool success = MinimalERC20(config.tokenAddress).transfer(operator, platformAmount);
        if (!success) revert TransferFailed();
    }

    receive() external payable {
        platformFeeBalance += msg.value;
    }
}
