// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract ConcentratedLiquidityManager {
    // -------- Constants --------
    /// @notice Maximum protocol fee in basis points (0.5% = 50 bps)
    uint256 public constant MAX_PROTOCOL_FEE = 50;
    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10_000;
    /// @notice Minimum upper price multiplier over lower price (1.1x => 11/10)
    uint256 public constant MIN_PRICE_RANGE_MULTIPLIER = 11;

    // -------- State Variables --------
    address public operator;
    address public oracle;
    uint256 public protocolFee;

    uint256 private _status;

    // -------- Position Tracking --------
    struct Position {
        address token0;
        address token1;
        uint256 priceLower;
        uint256 priceUpper;
        uint256 amount0;
        uint256 amount1;
        bool active;
    }

    mapping(address => Position[]) public positions;

    // -------- Events --------
    event Deposit(
        address indexed user,
        uint256 indexed positionId,
        address token0,
        address token1,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 amount0,
        uint256 amount1
    );
    event IncreaseLiquidity(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );
    event DecreaseLiquidity(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );
    event Withdraw(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event OracleUpdated(address oldOracle, address newOracle);
    event OperatorChanged(address oldOperator, address newOperator);

    // -------- Custom Errors --------
    error Unauthorized();
    error ZeroAddress();
    error FeeExceedsCap();
    error InvalidTokens();
    error InvalidPriceRange();
    error PositionNotActive();
    error InsufficientAmount();
    error InsufficientBalance();
    error ReentrancyDetected();
    error TransferFailed();
    error InvalidPositionId();

    // -------- Modifiers --------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrancyDetected();
        _status = 2;
        _;
        _status = 1;
    }

    // -------- Constructor --------
    constructor(address _operator, address _oracle, uint256 _protocolFee) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_protocolFee > MAX_PROTOCOL_FEE) revert FeeExceedsCap();

        operator = _operator;
        oracle = _oracle;
        protocolFee = _protocolFee;
        _status = 1;

        emit OperatorChanged(address(0), _operator);
        emit ProtocolFeeUpdated(0, _protocolFee);
        if (_oracle != address(0)) {
            emit OracleUpdated(address(0), _oracle);
        }
    }

    // -------- Operator Functions --------
    function setProtocolFee(uint256 _fee) external onlyOperator {
        if (_fee > MAX_PROTOCOL_FEE) revert FeeExceedsCap();
        uint256 oldFee = protocolFee;
        protocolFee = _fee;
        emit ProtocolFeeUpdated(oldFee, _fee);
    }

    function setOracle(address _oracle) external onlyOperator {
        if (_oracle == address(0)) revert ZeroAddress();
        address oldOracle = oracle;
        oracle = _oracle;
        emit OracleUpdated(oldOracle, _oracle);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = _operator;
        emit OperatorChanged(oldOperator, _operator);
    }

    // -------- User Liquidity Functions --------
    function deposit(
        address token0,
        address token1,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant returns (uint256 positionId) {
        if (token0 == address(0) || token1 == address(0)) revert InvalidTokens();
        if (token0 == token1) revert InvalidTokens();
        _validatePriceRange(priceLower, priceUpper);
        if (amount0 == 0 && amount1 == 0) revert InsufficientAmount();

        // Record state before external transfers (checks-effects-interactions)
        positions[msg.sender].push(
            Position({
                token0: token0,
                token1: token1,
                priceLower: priceLower,
                priceUpper: priceUpper,
                amount0: amount0,
                amount1: amount1,
                active: true
            })
        );
        positionId = positions[msg.sender].length - 1;

        if (amount0 > 0) {
            _safeTransferFrom(token0, msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            _safeTransferFrom(token1, msg.sender, address(this), amount1);
        }

        emit Deposit(
            msg.sender,
            positionId,
            token0,
            token1,
            priceLower,
            priceUpper,
            amount0,
            amount1
        );
    }

    function increaseLiquidity(
        uint256 positionId,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant {
        if (positionId >= positions[msg.sender].length) revert InvalidPositionId();
        Position storage p = positions[msg.sender][positionId];
        if (!p.active) revert PositionNotActive();
        if (amount0 == 0 && amount1 == 0) revert InsufficientAmount();

        // Effects before interactions
        p.amount0 += amount0;
        p.amount1 += amount1;

        if (amount0 > 0) {
            _safeTransferFrom(p.token0, msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            _safeTransferFrom(p.token1, msg.sender, address(this), amount1);
        }

        emit IncreaseLiquidity(msg.sender, positionId, amount0, amount1);
    }

    function decreaseLiquidity(
        uint256 positionId,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant {
        if (positionId >= positions[msg.sender].length) revert InvalidPositionId();
        Position storage p = positions[msg.sender][positionId];
        if (!p.active) revert PositionNotActive();
        if (amount0 == 0 && amount1 == 0) revert InsufficientAmount();
        if (p.amount0 < amount0 || p.amount1 < amount1) revert InsufficientBalance();

        // Effects before interactions
        p.amount0 -= amount0;
        p.amount1 -= amount1;

        if (amount0 > 0) {
            _safeTransfer(p.token0, msg.sender, amount0);
        }
        if (amount1 > 0) {
            _safeTransfer(p.token1, msg.sender, amount1);
        }

        emit DecreaseLiquidity(msg.sender, positionId, amount0, amount1);
    }

    function withdraw(uint256 positionId) external nonReentrant {
        if (positionId >= positions[msg.sender].length) revert InvalidPositionId();
        Position storage p = positions[msg.sender][positionId];
        if (!p.active) revert PositionNotActive();

        uint256 amount0 = p.amount0;
        uint256 amount1 = p.amount1;

        // Effects before interactions
        p.amount0 = 0;
        p.amount1 = 0;
        p.active = false;

        if (amount0 > 0) {
            _safeTransfer(p.token0, msg.sender, amount0);
        }
        if (amount1 > 0) {
            _safeTransfer(p.token1, msg.sender, amount1);
        }

        emit Withdraw(msg.sender, positionId, amount0, amount1);
    }

    // -------- View Functions --------
    function getPosition(address user, uint256 positionId)
        external
        view
        returns (
            address token0,
            address token1,
            uint256 priceLower,
            uint256 priceUpper,
            uint256 amount0,
            uint256 amount1,
            bool active
        )
    {
        if (positionId >= positions[user].length) revert InvalidPositionId();
        Position storage p = positions[user][positionId];
        return (
            p.token0,
            p.token1,
            p.priceLower,
            p.priceUpper,
            p.amount0,
            p.amount1,
            p.active
        );
    }

    function getUserPositionCount(address user) external view returns (uint256) {
        return positions[user].length;
    }

    // -------- Internal Helpers --------
    function _validatePriceRange(uint256 lowerPrice, uint256 upperPrice) internal pure {
        if (lowerPrice == 0) revert InvalidPriceRange();
        // Require upperPrice >= lowerPrice * 1.1
        // Equivalent to: upperPrice * 10 >= lowerPrice * 11
        if (upperPrice * 10 < lowerPrice * MIN_PRICE_RANGE_MULTIPLIER) {
            revert InvalidPriceRange();
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
