// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenBasketRebalancer {
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address[] tokens, uint256[] amounts, uint256 shares);
    event RebalanceCompleted(address[] tokens, uint256[] newBalances, uint256 fee);
    event TargetWeightsUpdated(address[] tokens, uint256[] weights);
    event RebalanceFeeUpdated(uint256 newFeeBps);
    event OperatorChanged(address indexed newOperator);
    event BasketInitialized(address[] tokens, uint256[] amounts, uint256 totalShares);
    event RouterApproved(address indexed token, address indexed spender, uint256 amount);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error UnsupportedToken();
    error DuplicateToken();
    error TokenNotInitialized();
    error InsufficientShares();
    error InsufficientBaseBalance();
    error LengthMismatch();
    error WeightsMustSumTo10000();
    error FeeTooHigh();
    error AlreadyInitialized();
    error InsufficientFeeBalance();
    error ReentrancyDetected();
    error NoTokens();
    error BaseTokenNotFound();
    error SafeTransferFailed();
    error SafeApproveFailed();

    uint256 public constant MIN_BASE_BALANCE = 100;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MAX_FEE_BPS = 1000;

    address public owner;
    address public operator;
    address[] public basketTokens;
    address public immutable baseToken;
    uint256 public baseTokenIndex;

    mapping(address => bool) public isSupportedToken;
    mapping(address => uint256) public targetWeights;
    mapping(address => uint256) public totalAmounts;
    mapping(address => uint256) public userShares;
    uint256 public totalShares;
    uint256 public rebalanceFeeBps = 50;

    bool public initialized;
    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address[] memory tokens_,
        uint256[] memory weights_,
        address baseToken_,
        address operator_
    ) {
        if (tokens_.length == 0) revert NoTokens();
        if (tokens_.length != weights_.length) revert LengthMismatch();
        if (baseToken_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();

        owner = msg.sender;
        operator = operator_;
        baseToken = baseToken_;

        bool baseFound = false;
        for (uint256 i = 0; i < tokens_.length; i++) {
            if (tokens_[i] == baseToken_) {
                baseTokenIndex = i;
                baseFound = true;
                break;
            }
        }
        if (!baseFound) revert BaseTokenNotFound();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokens_.length; i++) {
            address token = tokens_[i];
            if (token == address(0)) revert ZeroAddress();
            if (isSupportedToken[token]) revert DuplicateToken();
            if (weights_[i] == 0) revert ZeroAmount();

            isSupportedToken[token] = true;
            targetWeights[token] = weights_[i];
            basketTokens.push(token);
            totalWeight += weights_[i];
        }

        if (totalWeight != 10000) revert WeightsMustSumTo10000();
    }

    function initializeBasket(uint256[] calldata amounts) external onlyOperator nonReentrant {
        if (initialized) revert AlreadyInitialized();
        if (amounts.length != basketTokens.length) revert LengthMismatch();

        uint256 sharesToMint = amounts[baseTokenIndex];
        if (sharesToMint == 0) revert ZeroAmount();

        for (uint256 i = 0; i < basketTokens.length; i++) {
            if (amounts[i] == 0) revert ZeroAmount();
        }

        // Effects before interactions
        for (uint256 i = 0; i < basketTokens.length; i++) {
            totalAmounts[basketTokens[i]] = amounts[i];
        }
        totalShares = sharesToMint;
        userShares[msg.sender] = sharesToMint;
        initialized = true;

        // Interactions
        for (uint256 i = 0; i < basketTokens.length; i++) {
            _safeTransferFrom(basketTokens[i], msg.sender, address(this), amounts[i]);
        }

        emit BasketInitialized(basketTokens, amounts, sharesToMint);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!isSupportedToken[token]) revert UnsupportedToken();
        if (amount == 0) revert ZeroAmount();
        if (totalAmounts[token] == 0) revert TokenNotInitialized();

        uint256 shares = (amount * totalShares) / totalAmounts[token];
        if (shares == 0) revert ZeroAmount();

        // Effects before interactions
        totalAmounts[token] += amount;
        userShares[msg.sender] += shares;
        totalShares += shares;

        // Interactions
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount, shares);
    }

    function withdraw(uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert ZeroAmount();
        if (userShares[msg.sender] < shareAmount) revert InsufficientShares();

        uint256 oldTotalShares = totalShares;
        uint256 tokenCount = basketTokens.length;
        uint256[] memory amounts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            amounts[i] = (shareAmount * totalAmounts[basketTokens[i]]) / oldTotalShares;
        }

        // Effects before interactions
        userShares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        for (uint256 i = 0; i < tokenCount; i++) {
            totalAmounts[basketTokens[i]] -= amounts[i];
        }

        // Interactions
        for (uint256 i = 0; i < tokenCount; i++) {
            if (amounts[i] > 0) {
                _safeTransfer(basketTokens[i], msg.sender, amounts[i]);
            }
        }

        emit Withdraw(msg.sender, basketTokens, amounts, shareAmount);
    }

    function rebalance() external onlyOperator nonReentrant {
        uint256 actualBaseBalance = IERC20(baseToken).balanceOf(address(this));
        if (actualBaseBalance < MIN_BASE_BALANCE) revert InsufficientBaseBalance();

        uint256 tokenCount = basketTokens.length;
        uint256[] memory newBalances = new uint256[](tokenCount);
        uint256 totalValueRebalanced = 0;

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 actual = IERC20(basketTokens[i]).balanceOf(address(this));
            uint256 recorded = totalAmounts[basketTokens[i]];
            newBalances[i] = actual;

            if (actual >= recorded) {
                totalValueRebalanced += (actual - recorded);
            } else {
                totalValueRebalanced += (recorded - actual);
            }
        }

        uint256 fee = (totalValueRebalanced * rebalanceFeeBps) / FEE_PRECISION;

        if (fee > 0) {
            if (newBalances[baseTokenIndex] < fee) revert InsufficientFeeBalance();
            newBalances[baseTokenIndex] -= fee;
        }

        // Effects before interactions
        for (uint256 i = 0; i < tokenCount; i++) {
            totalAmounts[basketTokens[i]] = newBalances[i];
        }

        // Interactions
        if (fee > 0) {
            _safeTransfer(baseToken, operator, fee);
        }

        emit RebalanceCompleted(basketTokens, newBalances, fee);
    }

    function setTargetWeights(uint256[] calldata weights) external onlyOperator {
        if (weights.length != basketTokens.length) revert LengthMismatch();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            if (weights[i] == 0) revert ZeroAmount();
            targetWeights[basketTokens[i]] = weights[i];
            totalWeight += weights[i];
        }

        if (totalWeight != 10000) revert WeightsMustSumTo10000();

        emit TargetWeightsUpdated(basketTokens, weights);
    }

    function setRebalanceFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        rebalanceFeeBps = newFeeBps;
        emit RebalanceFeeUpdated(newFeeBps);
    }

    function approveRouter(address token, address spender, uint256 amount) external onlyOperator {
        if (!isSupportedToken[token]) revert UnsupportedToken();
        if (spender == address(0)) revert ZeroAddress();
        _safeApprove(token, spender, amount);
        emit RouterApproved(token, spender, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorChanged(newOperator);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (isSupportedToken[token]) revert UnsupportedToken();
        _safeTransfer(token, to, amount);
        emit TokenRescued(token, to, amount);
    }

    function getBasketTokens() external view returns (address[] memory) {
        return basketTokens;
    }

    function getBasketComposition()
        external
        view
        returns (address[] memory tokens, uint256[] memory balances, uint256[] memory weights)
    {
        uint256 tokenCount = basketTokens.length;
        tokens = new address[](tokenCount);
        balances = new uint256[](tokenCount);
        weights = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            address token = basketTokens[i];
            tokens[i] = token;
            balances[i] = totalAmounts[token];
            weights[i] = targetWeights[token];
        }
    }

    function getActualBalances() external view returns (uint256[] memory balances) {
        uint256 tokenCount = basketTokens.length;
        balances = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            balances[i] = IERC20(basketTokens[i]).balanceOf(address(this));
        }
    }

    function canRebalance() external view returns (bool) {
        return IERC20(baseToken).balanceOf(address(this)) >= MIN_BASE_BALANCE;
    }

    // -----------------------------------------------------------------------
    // Internal safe transfer helpers
    // -----------------------------------------------------------------------

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeApproveFailed();
        }
    }
}
