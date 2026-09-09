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

/**
 * @title PooledInvestmentFund
 * @dev A pooled fund that accepts multiple supported ERC-20 tokens and issues
 *      proportional shares. Redemptions incur a 0.5% fee. A fund manager controls
 *      the supported token list, investment strategy, and rebalancing operations.
 */
contract PooledInvestmentFund {
    /*//////////////////////////////////////////////////////////////
                          REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                          SAFE ERC20 HELPERS
    //////////////////////////////////////////////////////////////*/
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }

    /*//////////////////////////////////////////////////////////////
                               CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotManager();
    error ZeroAddress();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);
    error MaxTokensReached();
    error TokenBalanceNotZero();
    error ZeroAmount();
    error ZeroSharesMinted();
    error InsufficientShares();
    error EmptyStrategy();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed participant, address indexed token, uint256 amount, uint256 shares);
    event Redemption(address indexed participant, uint256 shares, uint256 fee, uint256 netShares);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event StrategyUpdated(string newStrategy);
    event RebalanceInitiated(uint256 timestamp);
    event ManagerUpdated(address indexed oldManager, address indexed newManager);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public fundManager;
    string public investmentStrategy;
    uint256 public totalShares;
    uint256 public lastRebalanceTimestamp;

    uint256 public constant MAX_TOKENS = 10;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    mapping(address => uint256) public shareBalances;
    mapping(address => bool) public isSupportedToken;
    mapping(address => uint256) public tokenBalances;
    address[] public supportedTokensList;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _manager, string memory _strategy) {
        if (_manager == address(0)) revert ZeroAddress();
        if (bytes(_strategy).length == 0) revert EmptyStrategy();
        fundManager = _manager;
        investmentStrategy = _strategy;
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyManager() {
        if (msg.sender != fundManager) revert NotManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         DEPOSIT / REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deposits a supported ERC-20 token into the fund and mints fund shares.
     * @param token The address of the ERC-20 token to deposit.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupportedToken[token]) revert TokenNotSupported(token);

        uint256 sharesToMint;
        uint256 currentTotalAssets = totalAssetsValue();
        uint256 currentTotalShares = totalShares;

        if (currentTotalShares == 0 || currentTotalAssets == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * currentTotalShares) / currentTotalAssets;
        }

        if (sharesToMint == 0) revert ZeroSharesMinted();

        // Effects
        shareBalances[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        tokenBalances[token] += amount;

        // Interactions
        _safeTransferFrom(IERC20(token), msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount, sharesToMint);
    }

    /**
     * @notice Redeems fund shares for a proportional amount of all underlying assets.
     *         A 0.5% fee is deducted and sent to the fund manager.
     * @param shares The number of fund shares to redeem.
     */
    function redeem(uint256 shares) external nonReentrant {
        if (shares == 0) revert ZeroAmount();
        if (shareBalances[msg.sender] < shares) revert InsufficientShares();

        uint256 fee = (shares * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netShares = shares - fee;

        uint256 currentTotalShares = totalShares; // total shares before burn

        // Effects
        shareBalances[msg.sender] -= shares;
        totalShares -= shares;

        // Interactions
        uint256 length = supportedTokensList.length;
        for (uint256 i = 0; i < length; i++) {
            address token = supportedTokensList[i];
            uint256 balance = tokenBalances[token];

            if (balance > 0) {
                // Full precision math to avoid divide-before-multiply
                uint256 feeAmount = (balance * shares * REDEMPTION_FEE_BPS) / (currentTotalShares * BPS_DENOMINATOR);
                uint256 userAmount = (balance * shares * (BPS_DENOMINATOR - REDEMPTION_FEE_BPS)) / (currentTotalShares * BPS_DENOMINATOR);

                // Effects before interactions
                tokenBalances[token] -= (userAmount + feeAmount);

                if (userAmount > 0) {
                    _safeTransfer(IERC20(token), msg.sender, userAmount);
                }
                if (feeAmount > 0) {
                    _safeTransfer(IERC20(token), fundManager, feeAmount);
                }
            }
        }

        emit Redemption(msg.sender, shares, fee, netShares);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Calculates the total value of all assets held in the fund.
     * @dev Assumes a 1:1 valuation across all supported tokens for simplicity.
     * @return total The sum of balances of all supported tokens.
     */
    function totalAssetsValue() public view returns (uint256 total) {
        uint256 length = supportedTokensList.length;
        for (uint256 i = 0; i < length; i++) {
            total += tokenBalances[supportedTokensList[i]];
        }
    }

    /**
     * @notice Gets the share balance of a specific participant.
     * @param account The address of the participant.
     * @return The share balance of the participant.
     */
    function getShareBalance(address account) external view returns (uint256) {
        return shareBalances[account];
    }

    /**
     * @notice Returns the list of currently supported tokens.
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokensList;
    }

    /**
     * @notice Returns the internal tracked balance of a supported token.
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /*//////////////////////////////////////////////////////////////
                       MANAGER OPERATIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Adds a new ERC-20 token to the list of supported tokens.
     * @param token The address of the token to add.
     */
    function addSupportedToken(address token) external onlyManager {
        if (token == address(0)) revert ZeroAddress();
        if (isSupportedToken[token]) revert TokenAlreadySupported(token);
        if (supportedTokensList.length >= MAX_TOKENS) revert MaxTokensReached();

        isSupportedToken[token] = true;
        supportedTokensList.push(token);

        emit TokenAdded(token);
    }

    /**
     * @notice Removes an ERC-20 token from the list of supported tokens.
     * @dev The fund must have a zero balance of the token before it can be removed.
     * @param token The address of the token to remove.
     */
    function removeSupportedToken(address token) external onlyManager {
        if (!isSupportedToken[token]) revert TokenNotSupported(token);
        if (tokenBalances[token] > 0) revert TokenBalanceNotZero();

        isSupportedToken[token] = false;

        uint256 length = supportedTokensList.length;
        for (uint256 i = 0; i < length; i++) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[length - 1];
                supportedTokensList.pop();
                break;
            }
        }

        delete tokenBalances[token];

        emit TokenRemoved(token);
    }

    /**
     * @notice Updates the fund's investment strategy description.
     * @param _strategy The new strategy description.
     */
    function updateStrategy(string memory _strategy) external onlyManager {
        if (bytes(_strategy).length == 0) revert EmptyStrategy();
        investmentStrategy = _strategy;
        emit StrategyUpdated(_strategy);
    }

    /**
     * @notice Initiates a rebalancing operation.
     * @dev This function records the timestamp and emits an event. Actual rebalancing
     *      logic can be implemented by the manager through external integrations.
     */
    function initiateRebalance() external onlyManager {
        lastRebalanceTimestamp = block.timestamp;
        emit RebalanceInitiated(block.timestamp);
    }

    /**
     * @notice Transfers the fund manager role to a new address.
     * @param newManager The address of the new fund manager.
     */
    function transferManager(address newManager) external onlyManager {
        if (newManager == address(0)) revert ZeroAddress();
        emit ManagerUpdated(fundManager, newManager);
        fundManager = newManager;
    }
}
