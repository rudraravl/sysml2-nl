// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract CollateralizedStablecoin {
    // ---------- Metadata ----------
    string public constant name = "Collateralized Stablecoin";
    string public constant symbol = "cUSD";
    uint8 public constant decimals = 18;

    // ---------- ERC20 State ----------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------- Collateral & Parameters ----------
    IERC20 public immutable collateralToken;
    address public treasury;
    address public operator;

    uint256 public totalCollateral;

    uint256 public collateralRatioNumerator = 105;
    uint256 public collateralRatioDenominator = 100;

    uint256 public constant FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    bool public paused;

    // ---------- Events ----------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, address indexed to, uint256 amount, uint256 collateralDeposited);
    event Burn(address indexed burner, uint256 amount, uint256 collateralReturned);
    event CollateralRatioUpdated(uint256 newNumerator, uint256 newDenominator);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------- Errors ----------
    error NotOperator();
    error PausedMintBurn();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientCollateral();
    error CollateralTransferFailed();
    error InvalidRatio();
    error AmountZero();

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (paused) revert PausedMintBurn();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _collateralToken, address _treasury, address _operator) {
        if (_collateralToken == address(0) || _treasury == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = IERC20(_collateralToken);
        treasury = _treasury;
        operator = _operator;
    }

    // ---------- Admin ----------
    function setCollateralRatio(uint256 _numerator, uint256 _denominator) external onlyOperator {
        if (_denominator == 0 || _numerator == 0) revert InvalidRatio();
        collateralRatioNumerator = _numerator;
        collateralRatioDenominator = _denominator;
        emit CollateralRatioUpdated(_numerator, _denominator);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    // ---------- Views ----------
    function collateralReserve() external view returns (uint256) {
        return collateralToken.balanceOf(address(this));
    }

    function collateralRequiredFor(uint256 amount) public view returns (uint256) {
        return (amount * collateralRatioNumerator) / collateralRatioDenominator;
    }

    function collateralReturnableFor(uint256 amount) public view returns (uint256) {
        return (amount * collateralRatioDenominator) / collateralRatioNumerator;
    }

    // ---------- ERC20 ----------
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferWithFee(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowed - amount);
        }

        _transferWithFee(from, to, amount);
        return true;
    }

    function _transferWithFee(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += net;
        if (fee > 0) {
            balanceOf[treasury] += fee;
        }

        emit Transfer(from, to, net);
        if (fee > 0) {
            emit Transfer(from, treasury, fee);
        }
    }

    // ---------- Internal: Safe Collateral Transfer ----------
    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert CollateralTransferFailed();
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert CollateralTransferFailed();
        }
    }

    // ---------- Mint / Burn ----------
    function mint(address to, uint256 amount) external notPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        uint256 collateralNeeded = collateralRequiredFor(amount);
        if (collateralNeeded == 0) revert AmountZero();

        _safeTransferFrom(address(collateralToken), msg.sender, address(this), collateralNeeded);

        totalCollateral += collateralNeeded;
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(msg.sender, to, amount, collateralNeeded);
        return true;
    }

    function burn(uint256 amount) external notPaused returns (uint256 collateralReturned) {
        if (amount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        collateralReturned = collateralReturnableFor(amount);
        if (totalCollateral < collateralReturned) revert InsufficientCollateral();

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        totalCollateral -= collateralReturned;

        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount, collateralReturned);

        if (collateralReturned > 0) {
            _safeTransfer(address(collateralToken), msg.sender, collateralReturned);
        }
        return collateralReturned;
    }

    function burnFrom(address from, uint256 amount) external notPaused returns (uint256 collateralReturned) {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowed - amount);
        }

        collateralReturned = collateralReturnableFor(amount);
        if (totalCollateral < collateralReturned) revert InsufficientCollateral();

        balanceOf[from] -= amount;
        totalSupply -= amount;
        totalCollateral -= collateralReturned;

        emit Transfer(from, address(0), amount);
        emit Burn(from, amount, collateralReturned);

        if (collateralReturned > 0) {
            _safeTransfer(address(collateralToken), msg.sender, collateralReturned);
        }
        return collateralReturned;
    }
}
