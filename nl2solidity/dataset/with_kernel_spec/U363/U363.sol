// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract LSDBasket {
    error ZeroAddress();
    error ZeroAmount();
    error LengthMismatch();
    error EmptyBasket();
    error DuplicateToken();
    error InvalidWeights();
    error NotBasketToken();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeTooHigh();
    error NoShares();
    error ReentrantCall();
    error Unauthorized();
    error NoRouter();
    error InvalidShares();
    error TransferFailed();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256[] amounts);
    event CompositionChanged(address[] tokens, uint256[] weights);
    event FeesUpdated(uint256 withdrawalFee);
    event BasketValueUpdated(uint256 newValue);
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event RewardsNotified(uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);
    event RouterUpdated(address indexed router);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant DEPOSIT_FEE = 50;
    uint256 public constant MAX_WITHDRAWAL_FEE = 200;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant ACC_REWARD_PRECISION = 1e18;

    address public owner;
    address public operator;
    address public feeRecipient;

    IERC20 public immutable baseToken;
    IERC20 public immutable rewardToken;
    address[] public basketTokens;
    mapping(address => uint256) public basketWeights;
    uint256 public basketValue;
    address public router;
    uint256 public withdrawalFee;

    string public name = "LSD Basket Share";
    string public symbol = "LSDS";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public accumulatedRewardPerShare;
    mapping(address => uint256) public lastRewardPerShare;
    mapping(address => uint256) public unclaimedRewards;

    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        address _baseToken,
        address _rewardToken,
        address _feeRecipient,
        address _operator,
        address[] memory _basketTokens,
        uint256[] memory _weights
    ) {
        if (_baseToken == address(0) || _rewardToken == address(0) || _feeRecipient == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        owner = msg.sender;
        baseToken = IERC20(_baseToken);
        rewardToken = IERC20(_rewardToken);
        feeRecipient = _feeRecipient;
        operator = _operator;
        withdrawalFee = 0;
        _setComposition(_basketTokens, _weights);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setComposition(address[] calldata tokens, uint256[] calldata weights) external onlyOperator {
        _setComposition(tokens, weights);
    }

    function setWithdrawalFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_WITHDRAWAL_FEE) revert FeeTooHigh();
        withdrawalFee = newFee;
        emit FeesUpdated(newFee);
    }

    function setRouter(address newRouter) external onlyOperator {
        if (newRouter == address(0)) revert ZeroAddress();
        router = newRouter;
        emit RouterUpdated(newRouter);
    }

    function updateBasketValue(uint256 newValue) external onlyOperator {
        basketValue = newValue;
        emit BasketValueUpdated(newValue);
    }

    function swapBasketToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external onlyOperator nonReentrant returns (uint256 amountOut) {
        if (!isBasketToken(tokenIn) || !isBasketToken(tokenOut)) revert NotBasketToken();
        if (amountIn == 0) revert ZeroAmount();
        if (router == address(0)) revert NoRouter();

        _safeApprove(IERC20(tokenIn), router, amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = IUniswapV2Router(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );
        amountOut = amounts[amounts.length - 1];
        _safeApprove(IERC20(tokenIn), router, 0);
        emit Swap(tokenIn, tokenOut, amountIn, amountOut);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);

        uint256 fee = (amount * DEPOSIT_FEE) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        _safeTransferFrom(baseToken, msg.sender, address(this), amount);
        if (fee > 0) {
            _safeTransfer(baseToken, feeRecipient, fee);
        }

        uint256 shares;
        uint256 supply = totalSupply;
        if (supply < 1) {
            shares = net;
        } else {
            uint256 totalAssets = totalAssetsValue();
            if (totalAssets < 1) revert ZeroAmount();
            shares = (net * supply) / totalAssets;
        }
        if (shares < 1) revert InvalidShares();

        _mint(msg.sender, shares);
        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf[msg.sender]) revert InsufficientBalance();
        uint256 supply = totalSupply;
        if (supply < 1) revert NoShares();
        _updateReward(msg.sender);

        _burn(msg.sender, shares);

        uint256 len = basketTokens.length;
        uint256[] memory amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            address token = basketTokens[i];
            uint256 bal = IERC20(token).balanceOf(address(this));
            uint256 amountOut = (bal * shares) / supply;
            if (amountOut > 0) {
                uint256 fee = (amountOut * withdrawalFee) / BPS_DENOMINATOR;
                uint256 toUser = amountOut - fee;
                if (toUser > 0) {
                    _safeTransfer(IERC20(token), msg.sender, toUser);
                }
                if (fee > 0) {
                    _safeTransfer(IERC20(token), feeRecipient, fee);
                }
                amounts[i] = toUser;
            }
        }

        uint256 valueReduction = (basketValue * shares) / supply;
        if (valueReduction > basketValue) {
            basketValue = 0;
        } else {
            basketValue -= valueReduction;
        }
        emit Withdraw(msg.sender, shares, amounts);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 amount = unclaimedRewards[msg.sender];
        if (amount > 0) {
            unclaimedRewards[msg.sender] = 0;
            _safeTransfer(rewardToken, msg.sender, amount);
            emit RewardsClaimed(msg.sender, amount);
        }
    }

    function notifyRewards(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = totalSupply;
        if (supply < 1) revert NoShares();
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        accumulatedRewardPerShare += (amount * ACC_REWARD_PRECISION) / supply;
        emit RewardsNotified(amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function getBasketTokens() external view returns (address[] memory) {
        return basketTokens;
    }

    function getBasketWeights() external view returns (uint256[] memory weights) {
        uint256 len = basketTokens.length;
        weights = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            weights[i] = basketWeights[basketTokens[i]];
        }
    }

    function isBasketToken(address token) public view returns (bool) {
        for (uint256 i = 0; i < basketTokens.length; i++) {
            if (basketTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function totalAssetsValue() public view returns (uint256) {
        return basketValue + baseToken.balanceOf(address(this));
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 owed = 0;
        if (accumulatedRewardPerShare > lastRewardPerShare[user]) {
            owed = (balanceOf[user] * (accumulatedRewardPerShare - lastRewardPerShare[user])) / ACC_REWARD_PRECISION;
        }
        return unclaimedRewards[user] + owed;
    }

    function _setComposition(address[] memory tokens, uint256[] memory weights) internal {
        if (tokens.length != weights.length) revert LengthMismatch();
        if (tokens.length == 0) revert EmptyBasket();

        uint256 totalWeight;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (weights[i] == 0) revert ZeroAmount();
            totalWeight += weights[i];
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] == tokens[j]) revert DuplicateToken();
            }
        }
        if (totalWeight != BPS_DENOMINATOR) revert InvalidWeights();

        for (uint256 i = 0; i < basketTokens.length; i++) {
            basketWeights[basketTokens[i]] = 0;
        }

        basketTokens = tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            basketWeights[tokens[i]] = weights[i];
        }

        emit CompositionChanged(tokens, weights);
    }

    function _updateReward(address user) internal {
        if (user != address(0)) {
            uint256 owed = 0;
            if (accumulatedRewardPerShare > lastRewardPerShare[user]) {
                owed = (balanceOf[user] * (accumulatedRewardPerShare - lastRewardPerShare[user])) / ACC_REWARD_PRECISION;
            }
            if (owed > 0) {
                unclaimedRewards[user] += owed;
            }
            lastRewardPerShare[user] = accumulatedRewardPerShare;
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        _updateReward(from);
        _updateReward(to);

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool success = token.approve(spender, amount);
        if (!success) revert TransferFailed();
    }
}
