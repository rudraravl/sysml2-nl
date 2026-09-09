// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AgentLaunchpad {
    struct Launch {
        address creator;
        uint256 supply;
        uint256 slope;
        uint256 poolBalance;
        bool active;
    }

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant INITIAL_LAUNCH_FEE_BPS = 50; // 0.5%

    address public operator;
    bool public paused;
    uint256 public launchFeeBps;

    uint256 public launchCount;
    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public tokenBalances;

    event LaunchCreated(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 slope,
        uint256 initialDeposit
    );
    event Deposited(
        uint256 indexed tokenId,
        address indexed depositor,
        uint256 nativeAmount,
        uint256 tokenAmount
    );
    event Withdrawn(
        uint256 indexed tokenId,
        address indexed withdrawer,
        uint256 nativeAmount,
        uint256 tokenAmount
    );
    event Traded(
        uint256 indexed tokenId,
        address indexed trader,
        bool isBuy,
        uint256 nativeAmount,
        uint256 tokenAmount
    );
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event LaunchFeeUpdated(address indexed operator, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error OnlyOperator();
    error TradingPaused();
    error LaunchNotActive();
    error ZeroAmount();
    error ExceedsMaxSupply();
    error InsufficientBalance();
    error InvalidSlope();
    error InvalidFee();
    error InvalidOperator();
    error SlippageExceeded();
    error InsufficientPoolLiquidity();
    error TransferFailed();
    error DirectDepositsNotAllowed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier launchActive(uint256 tokenId) {
        if (!launches[tokenId].active) revert LaunchNotActive();
        _;
    }

    constructor(address _operator, uint256 _launchFeeBps) {
        if (_operator == address(0)) revert InvalidOperator();
        if (_launchFeeBps > BASIS_POINTS) revert InvalidFee();
        operator = _operator;
        launchFeeBps = _launchFeeBps == 0 ? INITIAL_LAUNCH_FEE_BPS : _launchFeeBps;
    }

    receive() external payable {
        revert DirectDepositsNotAllowed();
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setLaunchFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > BASIS_POINTS) revert InvalidFee();
        launchFeeBps = _feeBps;
        emit LaunchFeeUpdated(msg.sender, _feeBps);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert InvalidOperator();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function getLaunch(uint256 tokenId)
        external
        view
        returns (
            address creator,
            uint256 supply,
            uint256 slope,
            uint256 poolBalance,
            bool active
        )
    {
        Launch storage l = launches[tokenId];
        return (l.creator, l.supply, l.slope, l.poolBalance, l.active);
    }

    function balanceOf(uint256 tokenId, address account) external view returns (uint256) {
        return tokenBalances[tokenId][account];
    }

    function createLaunch(uint256 slope) external payable whenNotPaused returns (uint256 tokenId) {
        if (slope == 0) revert InvalidSlope();
        if (msg.value == 0) revert ZeroAmount();

        uint256 fee = (msg.value * launchFeeBps) / BASIS_POINTS;
        uint256 depositAmount = msg.value - fee;

        tokenId = launchCount++;

        Launch storage l = launches[tokenId];
        l.creator = msg.sender;
        l.slope = slope;
        l.poolBalance = depositAmount;
        l.active = true;

        // Bonding curve: cost = (slope / 2) * S^2
        // Initial supply S = sqrt(2 * depositAmount / slope)
        uint256 initialSupply = _sqrt((2 * depositAmount * 10 ** 18) / slope);
        if (initialSupply == 0) revert ZeroAmount();
        if (initialSupply > MAX_SUPPLY) revert ExceedsMaxSupply();

        l.supply = initialSupply;
        tokenBalances[tokenId][msg.sender] = initialSupply;

        emit LaunchCreated(tokenId, msg.sender, slope, depositAmount);
        emit Deposited(tokenId, msg.sender, depositAmount, initialSupply);
    }

    function deposit(uint256 tokenId) external payable whenNotPaused launchActive(tokenId) {
        if (msg.value == 0) revert ZeroAmount();

        Launch storage l = launches[tokenId];

        uint256 fee = (msg.value * launchFeeBps) / BASIS_POINTS;
        uint256 depositAmount = msg.value - fee;

        uint256 oldSupply = l.supply;
        uint256 newSupply = _sqrt(oldSupply * oldSupply + (2 * depositAmount * 10 ** 18) / l.slope);
        if (newSupply > MAX_SUPPLY) revert ExceedsMaxSupply();

        uint256 tokenAmount = newSupply - oldSupply;
        if (tokenAmount == 0) revert ZeroAmount();

        l.supply = newSupply;
        l.poolBalance += depositAmount;
        tokenBalances[tokenId][msg.sender] += tokenAmount;

        emit Deposited(tokenId, msg.sender, depositAmount, tokenAmount);
    }

    function withdraw(uint256 tokenId, uint256 tokenAmount) external whenNotPaused launchActive(tokenId) {
        if (tokenAmount == 0) revert ZeroAmount();

        Launch storage l = launches[tokenId];
        uint256 userBal = tokenBalances[tokenId][msg.sender];
        if (userBal < tokenAmount) revert InsufficientBalance();

        uint256 oldSupply = l.supply;
        uint256 newSupply = oldSupply - tokenAmount;

        uint256 nativeAmount = (l.slope * (oldSupply * oldSupply - newSupply * newSupply)) / (2 * 10 ** 18);
        if (nativeAmount == 0) revert ZeroAmount();
        if (l.poolBalance < nativeAmount) revert InsufficientPoolLiquidity();

        tokenBalances[tokenId][msg.sender] -= tokenAmount;
        l.supply = newSupply;
        l.poolBalance -= nativeAmount;

        (bool success, ) = payable(msg.sender).call{value: nativeAmount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(tokenId, msg.sender, nativeAmount, tokenAmount);
    }

    function buy(uint256 tokenId, uint256 minTokenAmount) external payable whenNotPaused launchActive(tokenId) {
        if (msg.value == 0) revert ZeroAmount();

        Launch storage l = launches[tokenId];

        uint256 fee = (msg.value * launchFeeBps) / BASIS_POINTS;
        uint256 costAmount = msg.value - fee;

        uint256 oldSupply = l.supply;
        uint256 newSupply = _sqrt(oldSupply * oldSupply + (2 * costAmount * 10 ** 18) / l.slope);
        if (newSupply > MAX_SUPPLY) revert ExceedsMaxSupply();

        uint256 tokenAmount = newSupply - oldSupply;
        if (tokenAmount == 0) revert ZeroAmount();
        if (tokenAmount < minTokenAmount) revert SlippageExceeded();

        l.supply = newSupply;
        l.poolBalance += costAmount;
        tokenBalances[tokenId][msg.sender] += tokenAmount;

        emit Traded(tokenId, msg.sender, true, costAmount, tokenAmount);
    }

    function sell(uint256 tokenId, uint256 tokenAmount, uint256 minNativeAmount) external whenNotPaused launchActive(tokenId) {
        if (tokenAmount == 0) revert ZeroAmount();

        Launch storage l = launches[tokenId];
        uint256 userBal = tokenBalances[tokenId][msg.sender];
        if (userBal < tokenAmount) revert InsufficientBalance();

        uint256 oldSupply = l.supply;
        uint256 newSupply = oldSupply - tokenAmount;

        uint256 nativeAmount = (l.slope * (oldSupply * oldSupply - newSupply * newSupply)) / (2 * 10 ** 18);
        if (nativeAmount == 0) revert ZeroAmount();
        if (nativeAmount < minNativeAmount) revert SlippageExceeded();
        if (l.poolBalance < nativeAmount) revert InsufficientPoolLiquidity();

        tokenBalances[tokenId][msg.sender] -= tokenAmount;
        l.supply = newSupply;
        l.poolBalance -= nativeAmount;

        (bool success, ) = payable(msg.sender).call{value: nativeAmount}("");
        if (!success) revert TransferFailed();

        emit Traded(tokenId, msg.sender, false, nativeAmount, tokenAmount);
    }

    function getBuyCost(uint256 tokenId, uint256 tokenAmount) external view launchActive(tokenId) returns (uint256) {
        Launch storage l = launches[tokenId];
        uint256 oldSupply = l.supply;
        uint256 newSupply = oldSupply + tokenAmount;
        return (l.slope * (newSupply * newSupply - oldSupply * oldSupply)) / (2 * 10 ** 18);
    }

    function getSellReturn(uint256 tokenId, uint256 tokenAmount) external view launchActive(tokenId) returns (uint256) {
        Launch storage l = launches[tokenId];
        uint256 oldSupply = l.supply;
        uint256 newSupply = oldSupply - tokenAmount;
        return (l.slope * (oldSupply * oldSupply - newSupply * newSupply)) / (2 * 10 ** 18);
    }

    function currentPrice(uint256 tokenId) external view launchActive(tokenId) returns (uint256) {
        Launch storage l = launches[tokenId];
        return (l.slope * l.supply) / 10 ** 18;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
