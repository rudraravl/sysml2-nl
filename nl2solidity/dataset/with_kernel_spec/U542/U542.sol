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

interface IStrategy {
    function deposit(uint256 baseAmount) external returns (uint256 yieldTokens);
    function withdraw(uint256 yieldTokens) external returns (uint256 baseRecovered);
    function totalValueInBase() external view returns (uint256);
}

contract LiquidRestakingVault {
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error FeeExceedsMax();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientIdleBase();
    error TransferFailed();
    error ReentrantCall();
    error StrategyNotActive();
    error InsufficientYieldTokens();

    event Deposit(address indexed depositor, uint256 baseAmount, uint256 sharesMinted, uint256 newLrtBalance);
    event Redeem(address indexed redeemer, uint256 sharesBurned, uint256 baseReturned, uint256 feeTaken, uint256 newLrtBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event StrategyInitiated(
        address indexed strategy,
        uint256 strategyId,
        uint256 baseAllocated,
        uint256 yieldTokensReceived
    );
    event StrategyResolved(
        uint256 indexed strategyId,
        uint256 yieldTokensReturned,
        uint256 baseRecovered,
        uint256 profit,
        uint256 loss
    );

    uint256 public constant FEE_BASIS_POINTS_MAX = 10000;
    uint256 public constant FEE_BASIS_POINTS_CAP = 100;
    uint256 public constant INITIAL_FEE_BASIS_POINTS = 10;
    uint8 public constant LRT_DECIMALS = 18;
    uint256 private constant VIRTUAL_SHARES = 1000;
    uint256 private constant VIRTUAL_ASSETS = 1000;

    IERC20 public immutable baseToken;

    address public owner;
    address public operator;
    uint256 public redemptionFeeBps;

    uint256 public totalSupply;
    uint256 public totalBaseTokens;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct Strategy {
        address strategyAddress;
        uint256 baseAllocated;
        uint256 yieldTokensReceived;
        uint256 yieldTokensReturned;
        uint256 baseRecovered;
        bool active;
    }

    mapping(uint256 => Strategy) public strategies;
    uint256[] public strategyIds;
    uint256 public nextStrategyId;

    bool private locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor(address baseToken_) {
        if (baseToken_ == address(0)) revert ZeroAddress();
        baseToken = IERC20(baseToken_);
        owner = msg.sender;
        operator = msg.sender;
        redemptionFeeBps = INITIAL_FEE_BASIS_POINTS;
        emit OperatorUpdated(address(0), operator);
        emit RedemptionFeeUpdated(0, redemptionFeeBps);
    }

    function name() external pure returns (string memory) {
        return "Liquid Restaked Token";
    }

    function symbol() external pure returns (string memory) {
        return "LRT";
    }

    function decimals() external pure returns (uint8) {
        return LRT_DECIMALS;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setRedemptionFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_BASIS_POINTS_CAP) revert FeeExceedsMax();
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(old, newFeeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnerUpdated(previous, newOwner);
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
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function totalValueInBase() public view returns (uint256) {
        uint256 value = totalBaseTokens;
        for (uint256 i = 0; i < strategyIds.length; i++) {
            uint256 id = strategyIds[i];
            Strategy storage s = strategies[id];
            if (!s.active) continue;
            value += IStrategy(s.strategyAddress).totalValueInBase();
        }
        return value;
    }

    function convertToShares(uint256 baseAmount) public view returns (uint256) {
        uint256 supply = totalSupply + VIRTUAL_SHARES;
        uint256 totalVal = totalValueInBase() + VIRTUAL_ASSETS;
        return (baseAmount * supply) / totalVal;
    }

    function convertToBase(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply + VIRTUAL_SHARES;
        uint256 totalVal = totalValueInBase() + VIRTUAL_ASSETS;
        return (shares * totalVal) / supply;
    }

    function deposit(uint256 baseAmount) external nonReentrant returns (uint256 sharesMinted) {
        if (baseAmount == 0) revert ZeroAmount();

        sharesMinted = convertToShares(baseAmount);
        if (sharesMinted < 1) revert ZeroShares();

        // Effects before interactions: update accounting and mint shares first.
        totalBaseTokens += baseAmount;
        _mint(msg.sender, sharesMinted);

        // Interaction: pull base tokens from depositor.
        bool okPull = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!okPull) revert TransferFailed();

        emit Deposit(msg.sender, baseAmount, sharesMinted, balanceOf[msg.sender]);
    }

    function redeem(uint256 shares) external nonReentrant returns (uint256 baseReturned) {
        if (shares == 0) revert ZeroShares();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();

        uint256 baseGross = convertToBase(shares);
        if (baseGross < 1) revert ZeroAmount();

        uint256 fee = (baseGross * redemptionFeeBps) / FEE_BASIS_POINTS_MAX;
        baseReturned = baseGross - fee;

        if (totalBaseTokens < baseGross) revert InsufficientIdleBase();

        // Effects before interactions: burn shares and reduce idle base accounting.
        _burn(msg.sender, shares);
        totalBaseTokens -= baseReturned;

        // Interaction: send base tokens to redeemer. Fee remains in vault for remaining shareholders.
        bool okSend = baseToken.transfer(msg.sender, baseReturned);
        if (!okSend) revert TransferFailed();

        emit Redeem(msg.sender, shares, baseReturned, fee, balanceOf[msg.sender]);
    }

    function initiateStrategy(address strategy, uint256 baseAmount)
        external
        onlyOperator
        nonReentrant
        returns (uint256 strategyId)
    {
        if (strategy == address(0)) revert ZeroAddress();
        if (baseAmount == 0) revert ZeroAmount();
        if (totalBaseTokens < baseAmount) revert InsufficientIdleBase();

        // Effect: reduce idle base before sending out.
        totalBaseTokens -= baseAmount;

        // Interactions: transfer base tokens to strategy and deposit them.
        bool okTransfer = baseToken.transfer(strategy, baseAmount);
        if (!okTransfer) revert TransferFailed();

        uint256 yieldTokensReceived = IStrategy(strategy).deposit(baseAmount);
        if (yieldTokensReceived < 1) revert ZeroShares();

        // Effect: record the strategy allocation.
        strategyId = nextStrategyId++;
        strategies[strategyId] = Strategy({
            strategyAddress: strategy,
            baseAllocated: baseAmount,
            yieldTokensReceived: yieldTokensReceived,
            yieldTokensReturned: 0,
            baseRecovered: 0,
            active: true
        });
        strategyIds.push(strategyId);

        emit StrategyInitiated(strategy, strategyId, baseAmount, yieldTokensReceived);
    }

    function resolveStrategy(uint256 strategyId, uint256 yieldTokensToReturn)
        external
        onlyOperator
        nonReentrant
        returns (uint256 baseRecovered)
    {
        Strategy storage s = strategies[strategyId];
        if (!s.active) revert StrategyNotActive();
        if (yieldTokensToReturn == 0) revert ZeroAmount();

        uint256 available = s.yieldTokensReceived - s.yieldTokensReturned;
        if (available < yieldTokensToReturn) revert InsufficientYieldTokens();

        // Effects before interactions: update yield-token accounting and deactivate
        // the strategy when fully withdrawn so it cannot be re-resolved during reentrancy.
        s.yieldTokensReturned += yieldTokensToReturn;
        if (s.yieldTokensReturned >= s.yieldTokensReceived) {
            s.active = false;
        }

        // Interaction: withdraw yield tokens from the strategy, receiving base tokens back.
        baseRecovered = IStrategy(s.strategyAddress).withdraw(yieldTokensToReturn);
        if (baseRecovered < 1) revert ZeroAmount();

        // Effect: credit recovered base back to idle holdings.
        s.baseRecovered += baseRecovered;
        totalBaseTokens += baseRecovered;

        uint256 profit = 0;
        uint256 loss = 0;
        uint256 proportionalBase = (s.baseAllocated * yieldTokensToReturn) / s.yieldTokensReceived;
        if (baseRecovered > proportionalBase) {
            profit = baseRecovered - proportionalBase;
        } else if (baseRecovered < proportionalBase) {
            loss = proportionalBase - baseRecovered;
        }

        emit StrategyResolved(strategyId, yieldTokensToReturn, baseRecovered, profit, loss);
    }

    function strategyCount() external view returns (uint256) {
        return strategyIds.length;
    }

    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        return strategies[strategyId];
    }

    function totalAssets() external view returns (uint256) {
        return totalValueInBase();
    }
}
