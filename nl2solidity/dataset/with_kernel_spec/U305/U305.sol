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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract CommunityMutualFund {
    using SafeERC20 for IERC20;

    // ---------- Custom Errors ----------
    error Unauthorized();
    error ZeroAddress();
    error AssetNotSupported(address asset);
    error AssetAlreadySupported(address asset);
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error ZeroSharesMinted(uint256 amount);
    error InsufficientShares(uint256 have, uint256 want);
    error InvalidTargetAllocation();
    error AlreadyVoted();
    error NoShares();
    error StrategyNotFound(uint256 strategyId);
    error ReentrantCall();

    // ---------- Events ----------
    event Deposit(address indexed participant, address indexed asset, uint256 amount, uint256 shares);
    event Redemption(address indexed participant, uint256 shares, uint256 feeShares, uint256 totalAssetsTransferred);
    event AssetTransferred(address indexed participant, address indexed asset, uint256 amount);
    event AssetSupported(address indexed asset);
    event StrategyProposed(uint256 indexed strategyId, string name, uint256 targetAllocation);
    event StrategyUpdated(uint256 indexed strategyId, string name, uint256 targetAllocation);
    event StrategyActivated(uint256 indexed strategyId);
    event Voted(address indexed voter, uint256 indexed strategyId, uint256 votes);
    event RebalanceInitiated(address indexed initiator, uint256 indexed strategyId, string name, uint256 targetAllocation);
    event RebalanceAssetTarget(address indexed asset, uint256 currentBalance, uint256 targetBalance);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // ---------- Constants ----------
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_ALLOCATION_BPS = 10000; // 100%

    // ---------- State ----------
    address public operator;
    uint256 public totalShares;
    uint256 public totalAssetValue;

    mapping(address => uint256) public shareBalances;
    mapping(address => bool) public supportedAssets;
    mapping(address => uint256) public assetBalances;
    address[] public assetList;

    struct Strategy {
        string name;
        uint256 targetAllocation; // in basis points (0 - 10000)
        uint256 votes;
        bool active;
    }
    mapping(uint256 => Strategy) public strategies;
    uint256 public nextStrategyId;

    mapping(uint256 => mapping(address => uint256)) public strategyAssetWeights;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnStrategy;

    uint256 private _status = 1;

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    // ---------- Constructor ----------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // ---------- Operator Management ----------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorChanged(prev, newOperator);
    }

    // ---------- Asset Management ----------
    function addSupportedAsset(address asset) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (supportedAssets[asset]) revert AssetAlreadySupported(asset);
        supportedAssets[asset] = true;
        assetList.push(asset);
        emit AssetSupported(asset);
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return supportedAssets[asset];
    }

    function getAssetListLength() external view returns (uint256) {
        return assetList.length;
    }

    function getAssetAt(uint256 index) external view returns (address) {
        return assetList[index];
    }

    // ---------- Deposit ----------
    function deposit(address asset, uint256 amount) external nonReentrant {
        if (!supportedAssets[asset]) revert AssetNotSupported(asset);
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        uint256 sharesToMint;
        if (totalShares == 0 || totalAssetValue == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / totalAssetValue;
        }
        if (sharesToMint == 0) revert ZeroSharesMinted(amount);

        // Effects
        assetBalances[asset] += amount;
        shareBalances[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssetValue += amount;

        // Interactions
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount, sharesToMint);
    }

    // ---------- Redemption ----------
    function redeem(uint256 shares) external nonReentrant {
        if (shares == 0) revert InsufficientShares(0, shares);
        uint256 userShares = shareBalances[msg.sender];
        if (userShares < shares) revert InsufficientShares(userShares, shares);

        uint256 supply = totalShares;
        uint256 feeShares = (shares * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 redeemableShares = shares - feeShares;

        uint256 len = assetList.length;
        uint256[] memory amounts = new uint256[](len);
        uint256 totalTransferred = 0;
        for (uint256 i = 0; i < len; i++) {
            address asset = assetList[i];
            uint256 balance = assetBalances[asset];
            uint256 amt = (balance * redeemableShares) / supply;
            amounts[i] = amt;
            totalTransferred += amt;
        }

        // Effects
        shareBalances[msg.sender] -= shares;
        totalShares -= redeemableShares;
        if (feeShares > 0) {
            shareBalances[operator] += feeShares;
        }
        totalAssetValue -= totalTransferred;
        for (uint256 i = 0; i < len; i++) {
            assetBalances[assetList[i]] -= amounts[i];
        }

        // Interactions
        for (uint256 i = 0; i < len; i++) {
            if (amounts[i] > 0) {
                IERC20(assetList[i]).safeTransfer(msg.sender, amounts[i]);
                emit AssetTransferred(msg.sender, assetList[i], amounts[i]);
            }
        }

        emit Redemption(msg.sender, redeemableShares, feeShares, totalTransferred);
    }

    // ---------- Strategy Management ----------
    function proposeStrategy(string calldata name, uint256 targetAllocation) external onlyOperator {
        if (targetAllocation > MAX_ALLOCATION_BPS) revert InvalidTargetAllocation();
        uint256 strategyId = nextStrategyId++;
        strategies[strategyId] = Strategy({
            name: name,
            targetAllocation: targetAllocation,
            votes: 0,
            active: false
        });
        emit StrategyProposed(strategyId, name, targetAllocation);
    }

    function updateStrategy(uint256 strategyId, string calldata name, uint256 targetAllocation) external onlyOperator {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        if (targetAllocation > MAX_ALLOCATION_BPS) revert InvalidTargetAllocation();
        Strategy storage s = strategies[strategyId];
        s.name = name;
        s.targetAllocation = targetAllocation;
        emit StrategyUpdated(strategyId, name, targetAllocation);
    }

    function setStrategyAssetWeight(uint256 strategyId, address asset, uint256 weightBps) external onlyOperator {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        if (!supportedAssets[asset]) revert AssetNotSupported(asset);
        if (weightBps > MAX_ALLOCATION_BPS) revert InvalidTargetAllocation();
        strategyAssetWeights[strategyId][asset] = weightBps;
    }

    function voteStrategy(uint256 strategyId) external {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        if (hasVotedOnStrategy[strategyId][msg.sender]) revert AlreadyVoted();
        uint256 voterShares = shareBalances[msg.sender];
        if (voterShares == 0) revert NoShares();

        hasVotedOnStrategy[strategyId][msg.sender] = true;
        strategies[strategyId].votes += voterShares;

        emit Voted(msg.sender, strategyId, voterShares);
    }

    function activateStrategy(uint256 strategyId) external onlyOperator {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        strategies[strategyId].active = true;
        emit StrategyActivated(strategyId);
    }

    // ---------- Rebalancing ----------
    function initiateRebalance(uint256 strategyId) external onlyOperator {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        Strategy storage s = strategies[strategyId];
        s.active = true;

        uint256 total = totalAssetValue;
        uint256 len = assetList.length;
        for (uint256 i = 0; i < len; i++) {
            address asset = assetList[i];
            uint256 currentBalance = assetBalances[asset];
            uint256 weight = strategyAssetWeights[strategyId][asset];
            uint256 targetBalance = (total * weight) / MAX_ALLOCATION_BPS;
            emit RebalanceAssetTarget(asset, currentBalance, targetBalance);
        }

        emit RebalanceInitiated(msg.sender, strategyId, s.name, s.targetAllocation);
    }

    // ---------- Views ----------
    function totalAssets() external view returns (uint256) {
        return totalAssetValue;
    }

    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        return strategies[strategyId];
    }

    function getStrategyVotes(uint256 strategyId) external view returns (uint256) {
        if (strategyId >= nextStrategyId) revert StrategyNotFound(strategyId);
        return strategies[strategyId].votes;
    }

    function getStrategyAssetWeight(uint256 strategyId, address asset) external view returns (uint256) {
        return strategyAssetWeights[strategyId][asset];
    }
}
