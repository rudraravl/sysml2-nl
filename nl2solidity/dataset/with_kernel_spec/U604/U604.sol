// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

contract CollateralBasketStable {
    struct CollateralAsset {
        address token;
        uint256 amount;
        address oracle;
    }

    error Unauthorized();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error BasketSizeExceeded();
    error DuplicateToken();
    error ZeroAddress();
    error CollateralTransferFailed();
    error FeeTransferFailed();
    error EmptyBasket();
    error IndexOutOfBounds();
    error ArrayLengthMismatch();
    error ReentrantCall();
    error InvalidOracle();
    error InvalidDecimals();

    event Mint(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BasketUpdated(address indexed operator, uint256 size);
    event OracleUpdated(address indexed token, address indexed oldOracle, address indexed newOracle);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MAX_BASKET_SIZE = 10;
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant MAX_DECIMALS = 18;

    address public owner;
    address public operator;
    address public feeRecipient;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    CollateralAsset[] public basket;
    mapping(address => bool) internal _inBasket;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        address[] memory _tokens,
        uint256[] memory _amounts,
        address[] memory _oracles,
        address _feeRecipient
    ) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_decimals > MAX_DECIMALS) revert InvalidDecimals();
        if (_tokens.length != _amounts.length || _tokens.length != _oracles.length) {
            revert ArrayLengthMismatch();
        }
        if (_tokens.length == 0) revert EmptyBasket();
        if (_tokens.length > MAX_BASKET_SIZE) revert BasketSizeExceeded();

        name = _name;
        symbol = _symbol;
        decimals = uint8(_decimals);
        owner = msg.sender;
        operator = msg.sender;
        feeRecipient = _feeRecipient;

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) revert ZeroAddress();
            if (_oracles[i] == address(0)) revert InvalidOracle();
            if (_inBasket[_tokens[i]]) revert DuplicateToken();
            _inBasket[_tokens[i]] = true;
            basket.push(
                CollateralAsset({
                    token: _tokens[i],
                    amount: _amounts[i],
                    oracle: _oracles[i]
                })
            );
        }

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit BasketUpdated(msg.sender, basket.length);
    }

    function basketSize() external view returns (uint256) {
        return basket.length;
    }

    function getBasketAsset(uint256 index)
        external
        view
        returns (address token, uint256 amount, address oracle)
    {
        if (index >= basket.length) revert IndexOutOfBounds();
        CollateralAsset memory asset = basket[index];
        return (asset.token, asset.amount, asset.oracle);
    }

    function getBasket() external view returns (CollateralAsset[] memory) {
        return basket;
    }

    function mint(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 basketLen = basket.length;
        if (basketLen == 0) revert EmptyBasket();

        for (uint256 i = 0; i < basketLen; i++) {
            CollateralAsset memory asset = basket[i];
            uint256 required = amount * asset.amount;
            if (required == 0) continue;

            bool success = IERC20(asset.token).transferFrom(
                msg.sender,
                address(this),
                required
            );
            if (!success) revert CollateralTransferFailed();
        }

        balanceOf[msg.sender] += amount;
        totalSupply += amount;

        emit Mint(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    function redeem(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 basketLen = basket.length;
        if (basketLen == 0) revert EmptyBasket();

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        for (uint256 i = 0; i < basketLen; i++) {
            CollateralAsset memory asset = basket[i];
            uint256 collateralAmount = amount * asset.amount;
            if (collateralAmount == 0) continue;

            uint256 fee = (collateralAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
            uint256 payout = collateralAmount - fee;

            if (fee > 0) {
                bool feeOk = IERC20(asset.token).transfer(feeRecipient, fee);
                if (!feeOk) revert FeeTransferFailed();
            }
            if (payout > 0) {
                bool ok = IERC20(asset.token).transfer(msg.sender, payout);
                if (!ok) revert CollateralTransferFailed();
            }
        }

        emit Redeem(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        if (recipient == address(0)) revert ZeroAddress();

        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[sender] < amount) revert InsufficientBalance();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 allowed = allowance[sender][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[sender][msg.sender] -= amount;
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function setBasket(
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        address[] calldata _oracles
    ) external onlyOperator nonReentrant {
        if (_tokens.length != _amounts.length || _tokens.length != _oracles.length) {
            revert ArrayLengthMismatch();
        }
        if (_tokens.length == 0) revert EmptyBasket();
        if (_tokens.length > MAX_BASKET_SIZE) revert BasketSizeExceeded();

        uint256 oldLen = basket.length;
        for (uint256 i = 0; i < oldLen; i++) {
            _inBasket[basket[i].token] = false;
        }

        while (basket.length > 0) {
            basket.pop();
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) revert ZeroAddress();
            if (_oracles[i] == address(0)) revert InvalidOracle();
            if (_inBasket[_tokens[i]]) revert DuplicateToken();
            _inBasket[_tokens[i]] = true;
            basket.push(
                CollateralAsset({
                    token: _tokens[i],
                    amount: _amounts[i],
                    oracle: _oracles[i]
                })
            );
        }

        emit BasketUpdated(msg.sender, basket.length);
    }

    function setOracle(address token, address newOracle) external onlyOperator {
        if (!_inBasket[token]) revert IndexOutOfBounds();
        if (newOracle == address(0)) revert InvalidOracle();
        uint256 basketLen = basket.length;
        for (uint256 i = 0; i < basketLen; i++) {
            if (basket[i].token == token) {
                address oldOracle = basket[i].oracle;
                basket[i].oracle = newOracle;
                emit OracleUpdated(token, oldOracle, newOracle);
                return;
            }
        }
        revert IndexOutOfBounds();
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}
