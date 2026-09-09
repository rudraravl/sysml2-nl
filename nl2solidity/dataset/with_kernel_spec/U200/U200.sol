// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);
        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        _callOptionalReturnBool(token, data);
    }

    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (success) {
            if (returndata.length == 0) {
                return true;
            }
            return abi.decode(returndata, (bool));
        }
        if (returndata.length > 0) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
        revert("SafeERC20: low-level call failed");
    }
}

library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            if (toDeleteIndex != lastIndex) {
                address lastValue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastValue;
                set._indexes[lastValue] = valueIndex;
            }
            set._values.pop();
            delete set._indexes[value];
            return true;
        }
        return false;
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract DeFiBatcher is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant MAX_STEPS = 5;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000;

    struct Step {
        address target;
        bytes4 selector;
    }

    struct Recipe {
        bool exists;
        string name;
        address tokenIn;
        address tokenOut;
        Step[] steps;
    }

    EnumerableSet.AddressSet private _supportedTokens;
    EnumerableSet.AddressSet private _approvedProtocols;

    mapping(uint256 => Recipe) private _recipes;
    uint256 public nextRecipeId;

    mapping(address => mapping(address => uint256)) private _userBalances;

    uint256 public feeBps;
    mapping(address => uint256) public feesCollected;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event BatchExecuted(
        address indexed user,
        uint256 indexed recipeId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event RecipeAdded(uint256 indexed recipeId, string name, address tokenIn, address tokenOut);
    event RecipeModified(uint256 indexed recipeId, string name, address tokenIn, address tokenOut);
    event ProtocolApproved(address indexed protocol, bool approved);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesCollected(address indexed token, address indexed recipient, uint256 amount);
    event SupportedTokenAdded(address indexed token);
    event SupportedTokenRemoved(address indexed token);

    error RecipeNotFound(uint256 recipeId);
    error StepCountExceedsMax(uint256 count, uint256 max);
    error ProtocolNotApproved(address protocol);
    error ProtocolAlreadyApproved(address protocol);
    error ProtocolNotRegistered(address protocol);
    error InsufficientBalance(address token, uint256 available, uint256 required);
    error ZeroAmount();
    error ZeroAddress();
    error InvalidFee(uint256 feeBps);
    error NoSteps();
    error ExecutionFailed(uint256 stepIndex);
    error SelectorMismatch(uint256 stepIndex);
    error MismatchedLength();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);

    constructor(address[] memory supportedTokens_) Ownable(msg.sender) {
        for (uint256 i = 0; i < supportedTokens_.length; i++) {
            if (supportedTokens_[i] == address(0)) revert ZeroAddress();
            if (!_supportedTokens.add(supportedTokens_[i])) revert TokenAlreadySupported(supportedTokens_[i]);
            emit SupportedTokenAdded(supportedTokens_[i]);
        }
        feeBps = 10;
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (!_supportedTokens.add(token)) revert TokenAlreadySupported(token);
        emit SupportedTokenAdded(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!_supportedTokens.remove(token)) revert TokenNotSupported(token);
        emit SupportedTokenRemoved(token);
    }

    function approveProtocol(address protocol) external onlyOwner {
        if (protocol == address(0)) revert ZeroAddress();
        if (!_approvedProtocols.add(protocol)) revert ProtocolAlreadyApproved(protocol);
        emit ProtocolApproved(protocol, true);
    }

    function removeProtocol(address protocol) external onlyOwner {
        if (!_approvedProtocols.remove(protocol)) revert ProtocolNotRegistered(protocol);
        emit ProtocolApproved(protocol, false);
    }

    function addRecipe(
        string calldata name,
        address tokenIn,
        address tokenOut,
        Step[] calldata steps
    ) external onlyOwner returns (uint256 recipeId) {
        if (steps.length == 0) revert NoSteps();
        if (steps.length > MAX_STEPS) revert StepCountExceedsMax(steps.length, MAX_STEPS);
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (!_supportedTokens.contains(tokenIn)) revert TokenNotSupported(tokenIn);
        if (!_supportedTokens.contains(tokenOut)) revert TokenNotSupported(tokenOut);

        recipeId = nextRecipeId++;
        Recipe storage recipe = _recipes[recipeId];
        recipe.exists = true;
        recipe.name = name;
        recipe.tokenIn = tokenIn;
        recipe.tokenOut = tokenOut;

        for (uint256 i = 0; i < steps.length; i++) {
            if (steps[i].target == address(0)) revert ZeroAddress();
            if (!_approvedProtocols.contains(steps[i].target)) revert ProtocolNotApproved(steps[i].target);
            recipe.steps.push(steps[i]);
        }

        emit RecipeAdded(recipeId, name, tokenIn, tokenOut);
    }

    function modifyRecipe(
        uint256 recipeId,
        string calldata name,
        address tokenIn,
        address tokenOut,
        Step[] calldata steps
    ) external onlyOwner {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.exists) revert RecipeNotFound(recipeId);
        if (steps.length == 0) revert NoSteps();
        if (steps.length > MAX_STEPS) revert StepCountExceedsMax(steps.length, MAX_STEPS);
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (!_supportedTokens.contains(tokenIn)) revert TokenNotSupported(tokenIn);
        if (!_supportedTokens.contains(tokenOut)) revert TokenNotSupported(tokenOut);

        delete recipe.steps;
        recipe.name = name;
        recipe.tokenIn = tokenIn;
        recipe.tokenOut = tokenOut;

        for (uint256 i = 0; i < steps.length; i++) {
            if (steps[i].target == address(0)) revert ZeroAddress();
            if (!_approvedProtocols.contains(steps[i].target)) revert ProtocolNotApproved(steps[i].target);
            recipe.steps.push(steps[i]);
        }

        emit RecipeModified(recipeId, name, tokenIn, tokenOut);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps);
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 amount = feesCollected[token];
        if (amount == 0) revert ZeroAmount();
        feesCollected[token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit FeesCollected(token, msg.sender, amount);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!_supportedTokens.contains(token)) revert TokenNotSupported(token);
        if (amount == 0) revert ZeroAmount();

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;

        _userBalances[token][msg.sender] += received;
        emit Deposited(msg.sender, token, received);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 available = _userBalances[token][msg.sender];
        if (available < amount) revert InsufficientBalance(token, available, amount);

        _userBalances[token][msg.sender] = available - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    function executeBatch(
        uint256 recipeId,
        uint256 amountIn,
        bytes[] calldata stepData
    ) external nonReentrant {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.exists) revert RecipeNotFound(recipeId);
        if (amountIn == 0) revert ZeroAmount();
        uint256 stepCount = recipe.steps.length;
        if (stepData.length != stepCount) revert MismatchedLength();

        address tokenIn = recipe.tokenIn;
        address tokenOut = recipe.tokenOut;

        if (!_supportedTokens.contains(tokenIn)) revert TokenNotSupported(tokenIn);
        if (!_supportedTokens.contains(tokenOut)) revert TokenNotSupported(tokenOut);

        for (uint256 i = 0; i < stepCount; i++) {
            if (!_approvedProtocols.contains(recipe.steps[i].target)) {
                revert ProtocolNotApproved(recipe.steps[i].target);
            }
        }

        uint256 available = _userBalances[tokenIn][msg.sender];
        if (available < amountIn) revert InsufficientBalance(tokenIn, available, amountIn);
        _userBalances[tokenIn][msg.sender] = available - amountIn;

        uint256 fee = (amountIn * feeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amountIn - fee;
        feesCollected[tokenIn] += fee;

        IERC20 _tokenIn = IERC20(tokenIn);
        address firstTarget = recipe.steps[0].target;
        _tokenIn.forceApprove(firstTarget, netAmount);

        uint256 inBalanceBefore = _tokenIn.balanceOf(address(this));
        uint256 outBalanceBefore = IERC20(tokenOut).balanceOf(address(this));

        _runSteps(recipe, stepData, stepCount);

        _tokenIn.forceApprove(firstTarget, 0);

        uint256 inBalanceAfter = _tokenIn.balanceOf(address(this));
        uint256 outBalanceAfter = IERC20(tokenOut).balanceOf(address(this));

        (uint256 amountOut, uint256 unusedIn) = _computeDeltas(
            tokenIn,
            tokenOut,
            netAmount,
            inBalanceBefore,
            inBalanceAfter,
            outBalanceBefore,
            outBalanceAfter
        );

        _userBalances[tokenOut][msg.sender] += amountOut;
        if (unusedIn > 0) {
            _userBalances[tokenIn][msg.sender] += unusedIn;
        }

        emit BatchExecuted(msg.sender, recipeId, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    function _runSteps(Recipe storage recipe, bytes[] calldata stepData, uint256 stepCount) private {
        for (uint256 i = 0; i < stepCount; i++) {
            if (stepData[i].length < 4 || bytes4(stepData[i][0:4]) != recipe.steps[i].selector) {
                revert SelectorMismatch(i);
            }
            (bool success, bytes memory returndata) = recipe.steps[i].target.call(stepData[i]);
            if (!success) {
                if (returndata.length > 0) {
                    assembly {
                        revert(add(returndata, 0x20), mload(returndata))
                    }
                }
                revert ExecutionFailed(i);
            }
        }
    }

    function _computeDeltas(
        address tokenIn,
        address tokenOut,
        uint256 netAmount,
        uint256 inBalanceBefore,
        uint256 inBalanceAfter,
        uint256 outBalanceBefore,
        uint256 outBalanceAfter
    ) private pure returns (uint256 amountOut, uint256 unusedIn) {
        if (tokenIn == tokenOut) {
            if (outBalanceAfter >= outBalanceBefore) {
                amountOut = netAmount + (outBalanceAfter - outBalanceBefore);
            } else {
                uint256 netConsumed = outBalanceBefore - outBalanceAfter;
                amountOut = netAmount > netConsumed ? netAmount - netConsumed : 0;
            }
            unusedIn = 0;
        } else {
            amountOut = outBalanceAfter > outBalanceBefore ? outBalanceAfter - outBalanceBefore : 0;
            uint256 inConsumed = inBalanceBefore > inBalanceAfter ? inBalanceBefore - inBalanceAfter : 0;
            unusedIn = netAmount > inConsumed ? netAmount - inConsumed : 0;
        }
    }

    function userBalance(address token, address user) external view returns (uint256) {
        return _userBalances[token][user];
    }

    function isSupportedToken(address token) external view returns (bool) {
        return _supportedTokens.contains(token);
    }

    function supportedTokens() external view returns (address[] memory) {
        return _supportedTokens.values();
    }

    function isApprovedProtocol(address protocol) external view returns (bool) {
        return _approvedProtocols.contains(protocol);
    }

    function approvedProtocols() external view returns (address[] memory) {
        return _approvedProtocols.values();
    }

    function getRecipeExists(uint256 recipeId) external view returns (bool) {
        return _recipes[recipeId].exists;
    }

    function getRecipeName(uint256 recipeId) external view returns (string memory) {
        return _recipes[recipeId].name;
    }

    function getRecipeTokens(uint256 recipeId) external view returns (address tokenIn, address tokenOut) {
        return (_recipes[recipeId].tokenIn, _recipes[recipeId].tokenOut);
    }

    function getRecipeSteps(uint256 recipeId) external view returns (Step[] memory) {
        return _recipes[recipeId].steps;
    }

    function getRecipeStepCount(uint256 recipeId) external view returns (uint256) {
        return _recipes[recipeId].steps.length;
    }
}
