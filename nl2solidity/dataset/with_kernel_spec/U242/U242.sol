// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract ConcentratedLiquidityManager {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address indexed baseToken,
        address quoteToken,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountBase,
        uint256 amountQuote
    );

    event LiquidityAdded(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amountBase,
        uint256 amountQuote
    );

    event LiquidityRemoved(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amountBase,
        uint256 amountQuote
    );

    event FeesClaimed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 feesBase,
        uint256 feesQuote
    );

    event FeesRecorded(
        uint256 indexed positionId,
        uint256 feesBase,
        uint256 feesQuote
    );

    event TradingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedStateChanged(bool paused);
    event ImplementationUpgraded(address oldImplementation, address newImplementation);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnerUpdated(address oldOwner, address newOwner);
    event TokenRecovered(address token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ErrZeroAddress();
    error ErrUnauthorized();
    error ErrPaused();
    error ErrFeeTooHigh();
    error ErrInsufficientDeposit();
    error ErrPositionNotFound();
    error ErrNotPositionOwner();
    error ErrInvalidTickRange();
    error ErrZeroAmount();
    error ErrSameTokens();
    error ErrInsufficientBalance();
    error ErrTransferFailed();
    error ErrReentrancy();
    error ErrNoFeesToClaim();
    error ErrSameImplementation();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT = 100; // 100 base or 100 quote tokens

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Position {
        address owner;
        address baseToken;
        address quoteToken;
        int24 tickLower;
        int24 tickUpper;
        uint256 amountBase;
        uint256 amountQuote;
        uint256 feesBase;
        uint256 feesQuote;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public operator;
    address public implementation;
    uint256 public tradingFeeBps;
    bool public paused;
    uint256 public nextPositionId;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;
    uint256 private _locked;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrUnauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrUnauthorized();
        _;
    }

    modifier notPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert ErrReentrancy();
        _locked = 1;
        _;
        _locked = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address owner_,
        address operator_,
        address implementation_,
        uint256 tradingFeeBps_
    ) {
        if (owner_ == address(0) || operator_ == address(0) || implementation_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (tradingFeeBps_ > MAX_FEE_BPS) revert ErrFeeTooHigh();
        owner = owner_;
        operator = operator_;
        implementation = implementation_;
        tradingFeeBps = tradingFeeBps_;
        nextPositionId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                       POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function createPosition(
        address baseToken,
        address quoteToken,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountBase,
        uint256 amountQuote
    ) external notPaused nonReentrant returns (uint256 positionId) {
        if (baseToken == address(0) || quoteToken == address(0)) revert ErrZeroAddress();
        if (baseToken == quoteToken) revert ErrSameTokens();
        if (tickLower >= tickUpper) revert ErrInvalidTickRange();
        if (amountBase == 0 && amountQuote == 0) revert ErrZeroAmount();
        if (amountBase < MIN_DEPOSIT && amountQuote < MIN_DEPOSIT) revert ErrInsufficientDeposit();

        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amountBase: amountBase,
            amountQuote: amountQuote,
            feesBase: 0,
            feesQuote: 0
        });
        userPositionIds[msg.sender].push(positionId);

        if (amountBase > 0) {
            _safeTransferFrom(baseToken, msg.sender, address(this), amountBase);
        }
        if (amountQuote > 0) {
            _safeTransferFrom(quoteToken, msg.sender, address(this), amountQuote);
        }

        emit PositionCreated(
            positionId,
            msg.sender,
            baseToken,
            quoteToken,
            tickLower,
            tickUpper,
            amountBase,
            amountQuote
        );
    }

    function addLiquidity(
        uint256 positionId,
        uint256 amountBase,
        uint256 amountQuote
    ) external notPaused nonReentrant {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert ErrPositionNotFound();
        if (pos.owner != msg.sender) revert ErrNotPositionOwner();
        if (amountBase == 0 && amountQuote == 0) revert ErrZeroAmount();

        pos.amountBase += amountBase;
        pos.amountQuote += amountQuote;

        if (amountBase > 0) {
            _safeTransferFrom(pos.baseToken, msg.sender, address(this), amountBase);
        }
        if (amountQuote > 0) {
            _safeTransferFrom(pos.quoteToken, msg.sender, address(this), amountQuote);
        }

        emit LiquidityAdded(positionId, msg.sender, amountBase, amountQuote);
    }

    function removeLiquidity(
        uint256 positionId,
        uint256 amountBase,
        uint256 amountQuote
    ) external notPaused nonReentrant {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert ErrPositionNotFound();
        if (pos.owner != msg.sender) revert ErrNotPositionOwner();
        if (amountBase == 0 && amountQuote == 0) revert ErrZeroAmount();
        if (amountBase > pos.amountBase || amountQuote > pos.amountQuote) {
            revert ErrInsufficientBalance();
        }

        pos.amountBase -= amountBase;
        pos.amountQuote -= amountQuote;

        if (amountBase > 0) {
            _safeTransfer(pos.baseToken, msg.sender, amountBase);
        }
        if (amountQuote > 0) {
            _safeTransfer(pos.quoteToken, msg.sender, amountQuote);
        }

        emit LiquidityRemoved(positionId, msg.sender, amountBase, amountQuote);
    }

    function claimFees(uint256 positionId) external notPaused nonReentrant {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert ErrPositionNotFound();
        if (pos.owner != msg.sender) revert ErrNotPositionOwner();

        uint256 feesBase = pos.feesBase;
        uint256 feesQuote = pos.feesQuote;
        if (feesBase == 0 && feesQuote == 0) revert ErrNoFeesToClaim();

        pos.feesBase = 0;
        pos.feesQuote = 0;

        if (feesBase > 0) {
            _safeTransfer(pos.baseToken, msg.sender, feesBase);
        }
        if (feesQuote > 0) {
            _safeTransfer(pos.quoteToken, msg.sender, feesQuote);
        }

        emit FeesClaimed(positionId, msg.sender, feesBase, feesQuote);
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function recordFees(
        uint256 positionId,
        uint256 feesBase,
        uint256 feesQuote
    ) external onlyOperator {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert ErrPositionNotFound();
        pos.feesBase += feesBase;
        pos.feesQuote += feesQuote;
        emit FeesRecorded(positionId, feesBase, feesQuote);
    }

    function setTradingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        uint256 oldFee = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(oldFee, newFeeBps);
    }

    function setPaused(bool state) external onlyOperator {
        paused = state;
        emit PausedStateChanged(state);
    }

    function upgradeImplementation(address newImplementation) external onlyOperator {
        if (newImplementation == address(0)) revert ErrZeroAddress();
        if (newImplementation == implementation) revert ErrSameImplementation();
        address old = implementation;
        implementation = newImplementation;
        emit ImplementationUpgraded(old, newImplementation);
    }

    /*//////////////////////////////////////////////////////////////
                         OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerUpdated(old, newOwner);
    }

    function recoverToken(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ErrZeroAddress();
        _safeTransfer(token, owner, amount);
        emit TokenRecovered(token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function getUserPositionCount(address user) external view returns (uint256) {
        return userPositionIds[user].length;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _safeTransfer(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert ErrTransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        if (amount == 0) return;
        bool success = IERC20(token).transferFrom(from, to, amount);
        if (!success) revert ErrTransferFailed();
    }
}
