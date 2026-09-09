// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
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

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let size := mload(returndata)
                    revert(add(returndata, 32), size)
                }
            } else {
                revert("SafeERC20: operation failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: transfer exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        require(to != address(0), "ERC20: mint to zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: burn from zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

contract Pausable {
    bool public paused;

    event Pause(address indexed account);
    event Unpause(address indexed account);

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        paused = true;
        emit Pause(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        paused = false;
        emit Unpause(msg.sender);
    }
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract DiversifiedPortfolio is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_TOKENS = 3;
    uint256 public constant MAX_TOKENS = 20;

    error NotApprovedToken();
    error TokenAlreadyApproved();
    error TooFewTokens();
    error TooManyTokens();
    error TokenHasBalance();
    error TokenWeightNotZero();
    error WeightMismatch();
    error LengthMismatch();
    error TokenSetMismatch();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error NotOperator();
    error InvalidWeight();
    error DuplicateToken();

    address public operator;
    address[] public portfolioTokens;
    mapping(address => bool) public isApproved;
    mapping(address => uint256) public targetWeight; // basis points
    mapping(address => mapping(address => uint256)) public userDepositedAssets;

    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 fee, uint256 sharesMinted);
    event Withdraw(address indexed user, address indexed token, uint256 sharesBurned, uint256 amountOut);
    event Redeem(address indexed user, address indexed sharesBurned, address[] tokens, uint256[] amounts);
    event Rebalance(address indexed operator, address[] tokens, uint256[] weights);
    event TokenAdded(address indexed operator, address indexed token);
    event TokenRemoved(address indexed operator, address indexed token);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator, address[] memory _initialTokens, uint256[] memory _initialWeights)
        ERC20("Diversified Portfolio Token", "DPT")
    {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialTokens.length != _initialWeights.length) revert LengthMismatch();
        if (_initialTokens.length < MIN_TOKENS) revert TooFewTokens();

        operator = _operator;
        emit OperatorSet(address(0), _operator);

        uint256 totalWeight;
        for (uint256 i = 0; i < _initialTokens.length; i++) {
            address token = _initialTokens[i];
            if (token == address(0)) revert ZeroAddress();
            if (isApproved[token]) revert TokenAlreadyApproved();
            if (_initialWeights[i] > BPS_DENOMINATOR) revert InvalidWeight();

            isApproved[token] = true;
            targetWeight[token] = _initialWeights[i];
            portfolioTokens.push(token);
            totalWeight += _initialWeights[i];

            emit TokenAdded(_operator, token);
        }

        if (totalWeight != BPS_DENOMINATOR) revert WeightMismatch();
        emit Rebalance(_operator, _initialTokens, _initialWeights);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorSet(previous, newOperator);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isApproved[token]) revert TokenAlreadyApproved();
        if (portfolioTokens.length >= MAX_TOKENS) revert TooManyTokens();

        isApproved[token] = true;
        targetWeight[token] = 0;
        portfolioTokens.push(token);

        emit TokenAdded(msg.sender, token);
    }

    function removeToken(address token) external onlyOperator {
        if (!isApproved[token]) revert NotApprovedToken();
        if (portfolioTokens.length <= MIN_TOKENS) revert TooFewTokens();
        if (IERC20(token).balanceOf(address(this)) != 0) revert TokenHasBalance();
        if (targetWeight[token] != 0) revert TokenWeightNotZero();

        isApproved[token] = false;
        delete targetWeight[token];
        _removeFromPortfolio(token);

        emit TokenRemoved(msg.sender, token);
    }

    function rebalance(address[] calldata tokens, uint256[] calldata weights) external onlyOperator {
        if (tokens.length != weights.length) revert LengthMismatch();
        if (tokens.length != portfolioTokens.length) revert TokenSetMismatch();

        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] == tokens[j]) revert DuplicateToken();
            }
        }

        for (uint256 i = 0; i < portfolioTokens.length; i++) {
            bool found;
            for (uint256 j = 0; j < tokens.length; j++) {
                if (tokens[j] == portfolioTokens[i]) {
                    found = true;
                    break;
                }
            }
            if (!found) revert TokenSetMismatch();
        }

        uint256 totalWeight;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!isApproved[tokens[i]]) revert NotApprovedToken();
            if (weights[i] > BPS_DENOMINATOR) revert InvalidWeight();

            targetWeight[tokens[i]] = weights[i];
            totalWeight += weights[i];
        }

        if (totalWeight != BPS_DENOMINATOR) revert WeightMismatch();
        emit Rebalance(msg.sender, tokens, weights);
    }

    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant returns (uint256 shares) {
        if (!isApproved[token]) revert NotApprovedToken();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        uint256 supply = totalSupply;
        uint256 value = portfolioValue();
        if (supply == 0 || value == 0) {
            shares = netAmount;
        } else {
            shares = (netAmount * supply) / value;
        }
        if (shares == 0) revert ZeroShares();

        userDepositedAssets[msg.sender][token] += amount;
        _mint(msg.sender, shares);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount, fee, shares);
    }

    function withdraw(address token, uint256 shares) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (!isApproved[token]) revert NotApprovedToken();
        if (shares == 0) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        uint256 supply = totalSupply;
        if (supply == 0) revert InsufficientShares();
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        amountOut = (shares * tokenBalance) / supply;
        if (amountOut == 0) revert ZeroAmount();

        _burn(msg.sender, shares);
        IERC20(token).safeTransfer(msg.sender, amountOut);

        emit Withdraw(msg.sender, token, shares, amountOut);
    }

    function redeem(uint256 shares)
        external
        whenNotPaused
        nonReentrant
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        if (shares == 0) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        uint256 supply = totalSupply;
        if (supply == 0) revert InsufficientShares();
        uint256 tokenCount = portfolioTokens.length;
        tokens = new address[](tokenCount);
        amounts = new uint256[](tokenCount);
        bool anyNonZero;

        for (uint256 i = 0; i < tokenCount; i++) {
            address token = portfolioTokens[i];
            tokens[i] = token;
            uint256 balance = IERC20(token).balanceOf(address(this));
            amounts[i] = (shares * balance) / supply;
            if (amounts[i] > 0) {
                anyNonZero = true;
            }
        }

        if (!anyNonZero) revert ZeroAmount();

        _burn(msg.sender, shares);

        for (uint256 i = 0; i < tokenCount; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, amounts[i]);
            }
        }

        emit Redeem(msg.sender, shares, tokens, amounts);
    }

    function portfolioTokenCount() external view returns (uint256) {
        return portfolioTokens.length;
    }

    function getPortfolioTokens() external view returns (address[] memory) {
        uint256 len = portfolioTokens.length;
        address[] memory tokens = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = portfolioTokens[i];
        }
        return tokens;
    }

    function getPortfolioWeights() external view returns (address[] memory tokens, uint256[] memory weights) {
        uint256 len = portfolioTokens.length;
        tokens = new address[](len);
        weights = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = portfolioTokens[i];
            weights[i] = targetWeight[tokens[i]];
        }
    }

    function portfolioValue() public view returns (uint256 total) {
        uint256 len = portfolioTokens.length;
        for (uint256 i = 0; i < len; i++) {
            total += IERC20(portfolioTokens[i]).balanceOf(address(this));
        }
    }

    function totalTargetWeight() external view returns (uint256 total) {
        uint256 len = portfolioTokens.length;
        for (uint256 i = 0; i < len; i++) {
            total += targetWeight[portfolioTokens[i]];
        }
    }

    function _removeFromPortfolio(address token) internal {
        uint256 len = portfolioTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (portfolioTokens[i] == token) {
                portfolioTokens[i] = portfolioTokens[len - 1];
                portfolioTokens.pop();
                return;
            }
        }
    }
}
