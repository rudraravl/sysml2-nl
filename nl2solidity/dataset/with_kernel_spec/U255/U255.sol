// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ParimutuelPredictionMarket {
    enum Outcome {
        None,
        Up,
        Down
    }

    struct Pool {
        bytes32 assetId;
        uint256 targetPrice;
        uint256 expiry;
        uint256 totalUp;
        uint256 totalDown;
        uint256 totalStaked;
        bool settled;
        Outcome finalOutcome;
        uint256 finalPrice;
        uint256 feeReserve;
    }

    struct UserStake {
        uint256 amountUp;
        uint256 amountDown;
        bool withdrawn;
    }

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;
    uint256 public constant DEFAULT_FEE_BPS = 100; // 1%

    IERC20 public immutable baseCurrency;
    address public owner;
    address public operator;
    uint256 public feeBps;

    uint256 public poolCount;
    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => UserStake)) public userStakes;

    uint256 private _locked = 1;

    event PoolCreated(
        uint256 indexed poolId,
        bytes32 indexed assetId,
        uint256 targetPrice,
        uint256 expiry,
        address indexed creator,
        uint256 initialDeposit,
        Outcome outcome
    );
    event Deposited(
        uint256 indexed poolId,
        address indexed user,
        Outcome outcome,
        uint256 amount
    );
    event PoolSettled(
        uint256 indexed poolId,
        uint256 finalPrice,
        Outcome finalOutcome,
        uint256 feeCollected
    );
    event Withdrawn(uint256 indexed poolId, address indexed user, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesClaimed(address indexed to, uint256 amount);

    error Unauthorized();
    error NotOperator();
    error ZeroAddress();
    error PoolDoesNotExist();
    error PoolExpired();
    error PoolNotExpired();
    error PoolAlreadySettled();
    error PoolNotSettled();
    error InvalidOutcome();
    error DepositTooLow();
    error ExpiryInPast();
    error ZeroAmount();
    error FeeTooHigh();
    error NoFeesToClaim();
    error AlreadyWithdrawn();
    error NoStake();
    error TransferFailed();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _baseCurrency, address _operator) {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(_baseCurrency);
        owner = msg.sender;
        operator = _operator;
        feeBps = DEFAULT_FEE_BPS;
        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, feeBps);
    }

    function createPool(
        bytes32 assetId,
        uint256 targetPrice,
        uint256 expiry,
        uint256 initialDeposit,
        Outcome outcome
    ) external nonReentrant returns (uint256 poolId) {
        if (initialDeposit < MIN_DEPOSIT) revert DepositTooLow();
        if (expiry <= block.timestamp) revert ExpiryInPast();
        if (outcome != Outcome.Up && outcome != Outcome.Down) revert InvalidOutcome();

        poolId = poolCount++;
        Pool storage p = pools[poolId];
        p.assetId = assetId;
        p.targetPrice = targetPrice;
        p.expiry = expiry;
        p.totalStaked = initialDeposit;

        UserStake storage u = userStakes[poolId][msg.sender];
        if (outcome == Outcome.Up) {
            p.totalUp = initialDeposit;
            u.amountUp = initialDeposit;
        } else {
            p.totalDown = initialDeposit;
            u.amountDown = initialDeposit;
        }

        _safeTransferFrom(msg.sender, address(this), initialDeposit);

        emit PoolCreated(poolId, assetId, targetPrice, expiry, msg.sender, initialDeposit, outcome);
        emit Deposited(poolId, msg.sender, outcome, initialDeposit);
    }

    function deposit(uint256 poolId, Outcome outcome, uint256 amount) external nonReentrant {
        if (poolId >= poolCount) revert PoolDoesNotExist();
        if (amount == 0) revert ZeroAmount();
        if (outcome != Outcome.Up && outcome != Outcome.Down) revert InvalidOutcome();

        Pool storage p = pools[poolId];
        if (block.timestamp >= p.expiry) revert PoolExpired();
        if (p.settled) revert PoolAlreadySettled();

        UserStake storage u = userStakes[poolId][msg.sender];
        if (outcome == Outcome.Up) {
            u.amountUp += amount;
            p.totalUp += amount;
        } else {
            u.amountDown += amount;
            p.totalDown += amount;
        }
        p.totalStaked += amount;

        _safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(poolId, msg.sender, outcome, amount);
    }

    function settle(uint256 poolId, uint256 finalPrice) external onlyOperator nonReentrant {
        if (poolId >= poolCount) revert PoolDoesNotExist();

        Pool storage p = pools[poolId];
        if (block.timestamp < p.expiry) revert PoolNotExpired();
        if (p.settled) revert PoolAlreadySettled();

        p.finalPrice = finalPrice;
        if (finalPrice > p.targetPrice) {
            p.finalOutcome = Outcome.Up;
        } else if (finalPrice < p.targetPrice) {
            p.finalOutcome = Outcome.Down;
        } else {
            p.finalOutcome = Outcome.None;
        }
        p.settled = true;

        uint256 fee = 0;
        if (p.finalOutcome != Outcome.None) {
            fee = (p.totalStaked * feeBps) / BPS_DENOMINATOR;
        }
        p.feeReserve = fee;

        emit PoolSettled(poolId, finalPrice, p.finalOutcome, fee);
    }

    function withdraw(uint256 poolId) external nonReentrant {
        if (poolId >= poolCount) revert PoolDoesNotExist();

        Pool storage p = pools[poolId];
        if (!p.settled) revert PoolNotSettled();

        UserStake storage u = userStakes[poolId][msg.sender];
        if (u.withdrawn) revert AlreadyWithdrawn();

        uint256 userUp = u.amountUp;
        uint256 userDown = u.amountDown;
        if (userUp == 0 && userDown == 0) revert NoStake();

        u.withdrawn = true;

        uint256 payout = 0;
        if (p.finalOutcome == Outcome.None) {
            payout = userUp + userDown;
        } else if (p.finalOutcome == Outcome.Up) {
            if (userUp > 0 && p.totalUp > 0) {
                uint256 distributable = p.totalStaked - p.feeReserve;
                payout = (userUp * distributable) / p.totalUp;
            }
        } else {
            if (userDown > 0 && p.totalDown > 0) {
                uint256 distributable = p.totalStaked - p.feeReserve;
                payout = (userDown * distributable) / p.totalDown;
            }
        }

        if (payout > 0) {
            _safeTransfer(msg.sender, payout);
        }

        emit Withdrawn(poolId, msg.sender, payout);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function claimFees(uint256[] calldata poolIds) external onlyOwner nonReentrant {
        uint256 total = 0;
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];
            if (poolId >= poolCount) revert PoolDoesNotExist();
            Pool storage p = pools[poolId];
            uint256 f = p.feeReserve;
            if (f > 0) {
                p.feeReserve = 0;
                total += f;
            }
        }
        if (total == 0) revert NoFeesToClaim();

        _safeTransfer(owner, total);
        emit FeesClaimed(owner, total);
    }

    function getPool(uint256 poolId) external view returns (Pool memory) {
        if (poolId >= poolCount) revert PoolDoesNotExist();
        return pools[poolId];
    }

    function getUserStake(uint256 poolId, address user)
        external
        view
        returns (uint256 amountUp, uint256 amountDown, bool withdrawn)
    {
        UserStake storage u = userStakes[poolId][user];
        return (u.amountUp, u.amountDown, u.withdrawn);
    }

    function getUserPayout(uint256 poolId, address user) external view returns (uint256) {
        if (poolId >= poolCount) return 0;
        Pool storage p = pools[poolId];
        if (!p.settled) return 0;

        UserStake storage u = userStakes[poolId][user];
        if (u.withdrawn) return 0;

        uint256 userUp = u.amountUp;
        uint256 userDown = u.amountDown;
        if (userUp == 0 && userDown == 0) return 0;

        if (p.finalOutcome == Outcome.None) {
            return userUp + userDown;
        } else if (p.finalOutcome == Outcome.Up) {
            if (userUp == 0 || p.totalUp == 0) return 0;
            uint256 distributable = p.totalStaked - p.feeReserve;
            return (userUp * distributable) / p.totalUp;
        } else {
            if (userDown == 0 || p.totalDown == 0) return 0;
            uint256 distributable = p.totalStaked - p.feeReserve;
            return (userDown * distributable) / p.totalDown;
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(baseCurrency).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(baseCurrency).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
