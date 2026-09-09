// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

error TransferFailed();
error NotOwner();
error NotOperator();
error VaultNotFound();
error VaultNotActive();
error AssetNotSupported();
error MaxAssetsExceeded();
error ZeroAmount();
error ZeroShares();
error InsufficientShares();
error StrategyNotFound();
error StrategyNotPending();
error StrategyAlreadyVoted();
error VotingClosed();
error AllocationMismatch();
error NotEnoughVotingPower();
error AlreadySupported();
error InvalidAllocation();
error StrategyNotApproved();
error ReentrantCall();

contract CrossChainPortfolioVault {
    uint256 public constant MAX_ASSETS_PER_VAULT = 10;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant MIN_VOTE_BPS = 5000; // 50% of total shares required

    address public owner;
    address public operator;

    struct Vault {
        uint256 id;
        string name;
        address[] assets;
        mapping(address => bool) isSupported;
        mapping(address => uint256) targetAllocationBps;
        mapping(address => uint256) totalDeposited;
        uint256 totalShares;
        bool active;
    }

    struct UserData {
        uint256 shares;
        mapping(address => uint256) deposited;
        uint256[] performanceSnapshots;
        mapping(uint256 => uint256) shareAtBlock;
    }

    enum StrategyStatus { Pending, Approved, Rejected, Executed }

    struct Strategy {
        uint256 id;
        uint256 vaultId;
        address proposer;
        address[] assets;
        uint256[] newAllocationsBps;
        string metadataURI;
        uint256 proposedAt;
        uint256 votingDeadline;
        uint256 yesVotes;
        StrategyStatus status;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Vault) private vaults;
    mapping(uint256 => mapping(address => UserData)) private userData;
    mapping(uint256 => Strategy) private strategies;

    uint256 public nextVaultId = 1;
    uint256 public nextStrategyId = 1;

    uint256 private _reentrancyStatus = 1;

    event VaultCreated(uint256 indexed vaultId, string name, address[] assets, uint256[] allocations);
    event AssetSupported(uint256 indexed vaultId, address indexed asset);
    event AssetRemoved(uint256 indexed vaultId, address indexed asset);
    event Deposited(uint256 indexed vaultId, address indexed user, address indexed asset, uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 indexed vaultId, address indexed user, address indexed asset, uint256 sharesBurned, uint256 amountReturned, uint256 fee);
    event StrategyProposed(uint256 indexed strategyId, uint256 indexed vaultId, address indexed proposer, string metadataURI);
    event Voted(uint256 indexed strategyId, address indexed voter, uint256 shares);
    event StrategyApproved(uint256 indexed strategyId, uint256 indexed vaultId);
    event StrategyRejected(uint256 indexed strategyId);
    event Rebalanced(uint256 indexed vaultId, uint256 indexed strategyId, address[] assets, uint256[] newAllocations);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PerformanceSnapshot(uint256 indexed vaultId, address indexed user, uint256 blockNumber, uint256 shares);

    modifier nonReentrant() {
        if (_reentrancyStatus != 1) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier vaultExists(uint256 vaultId) {
        if (vaultId == 0 || vaultId >= nextVaultId) revert VaultNotFound();
        _;
    }

    modifier vaultActive(uint256 vaultId) {
        if (!vaults[vaultId].active) revert VaultNotActive();
        _;
    }

    constructor(address operator_) {
        owner = msg.sender;
        operator = operator_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    function _safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function createVault(
        string calldata name,
        address[] calldata assets,
        uint256[] calldata allocations
    ) external onlyOperator returns (uint256 vaultId) {
        if (assets.length == 0) revert ZeroAmount();
        if (assets.length > MAX_ASSETS_PER_VAULT) revert MaxAssetsExceeded();
        if (assets.length != allocations.length) revert AllocationMismatch();

        uint256 sum = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            sum += allocations[i];
        }
        if (sum != BPS_DENOMINATOR) revert InvalidAllocation();

        vaultId = nextVaultId++;
        Vault storage v = vaults[vaultId];
        v.id = vaultId;
        v.name = name;
        v.active = true;

        for (uint256 i = 0; i < assets.length; i++) {
            address a = assets[i];
            if (a == address(0)) revert InvalidAllocation();
            if (v.isSupported[a]) revert AlreadySupported();
            v.isSupported[a] = true;
            v.targetAllocationBps[a] = allocations[i];
            v.assets.push(a);
        }

        emit VaultCreated(vaultId, name, assets, allocations);
    }

    function setVaultActive(uint256 vaultId, bool active) external onlyOperator vaultExists(vaultId) {
        vaults[vaultId].active = active;
    }

    function addSupportedAsset(uint256 vaultId, address asset, uint256 allocationBps)
        external
        onlyOperator
        vaultExists(vaultId)
    {
        Vault storage v = vaults[vaultId];
        if (v.assets.length >= MAX_ASSETS_PER_VAULT) revert MaxAssetsExceeded();
        if (asset == address(0)) revert InvalidAllocation();
        if (v.isSupported[asset]) revert AlreadySupported();

        v.isSupported[asset] = true;
        v.targetAllocationBps[asset] = allocationBps;
        v.assets.push(asset);

        emit AssetSupported(vaultId, asset);
    }

    function removeSupportedAsset(uint256 vaultId, address asset)
        external
        onlyOperator
        vaultExists(vaultId)
    {
        Vault storage v = vaults[vaultId];
        if (!v.isSupported[asset]) revert AssetNotSupported();
        if (v.totalDeposited[asset] > 0) revert AssetNotSupported();

        v.isSupported[asset] = false;
        v.targetAllocationBps[asset] = 0;

        address[] storage arr = v.assets;
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == asset) {
                arr[i] = arr[len - 1];
                arr.pop();
                break;
            }
        }

        emit AssetRemoved(vaultId, asset);
    }

    function deposit(uint256 vaultId, address asset, uint256 amount, address receiver)
        external
        nonReentrant
        vaultExists(vaultId)
        vaultActive(vaultId)
        returns (uint256 sharesMinted)
    {
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidAllocation();
        Vault storage v = vaults[vaultId];
        if (!v.isSupported[asset]) revert AssetNotSupported();

        uint256 totalAsset = v.totalDeposited[asset];
        if (totalAsset == 0) {
            sharesMinted = (amount * 1e18) / (10 ** IERC20(asset).decimals());
            if (sharesMinted == 0) revert ZeroShares();
        } else {
            sharesMinted = (amount * v.totalShares) / totalAsset;
            if (sharesMinted == 0) revert ZeroShares();
        }

        // Effects before interactions
        v.totalDeposited[asset] += amount;
        v.totalShares += sharesMinted;

        UserData storage u = userData[vaultId][receiver];
        u.shares += sharesMinted;
        u.deposited[asset] += amount;

        // Interactions
        _safeTransferFrom(IERC20(asset), address(this), amount);

        emit Deposited(vaultId, receiver, asset, amount, sharesMinted);
    }

    function withdraw(uint256 vaultId, address asset, uint256 sharesToBurn, address receiver)
        external
        nonReentrant
        vaultExists(vaultId)
        returns (uint256 amountReturned, uint256 fee)
    {
        if (sharesToBurn == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidAllocation();
        Vault storage v = vaults[vaultId];
        if (!v.isSupported[asset]) revert AssetNotSupported();

        UserData storage u = userData[vaultId][msg.sender];
        if (u.shares < sharesToBurn) revert InsufficientShares();

        uint256 totalAsset = v.totalDeposited[asset];
        if (totalAsset == 0) revert ZeroAmount();
        if (v.totalShares == 0) revert ZeroAmount();

        // Compute fee without divide-before-multiply:
        // fee = sharesToBurn * totalAsset * WITHDRAWAL_FEE_BPS / (totalShares * BPS_DENOMINATOR)
        fee = (sharesToBurn * totalAsset * WITHDRAWAL_FEE_BPS) / (v.totalShares * BPS_DENOMINATOR);
        uint256 gross = (sharesToBurn * totalAsset) / v.totalShares;
        if (gross == 0) revert ZeroAmount();
        amountReturned = gross - fee;

        // Effects before interactions
        u.shares -= sharesToBurn;
        u.deposited[asset] = u.deposited[asset] > gross ? u.deposited[asset] - gross : 0;
        v.totalShares -= sharesToBurn;
        v.totalDeposited[asset] -= gross;

        // Interactions
        if (amountReturned > 0) {
            _safeTransfer(IERC20(asset), receiver, amountReturned);
        }
        if (fee > 0) {
            _safeTransfer(IERC20(asset), operator, fee);
        }

        emit Withdrawn(vaultId, msg.sender, asset, sharesToBurn, amountReturned, fee);
    }

    function proposeStrategy(
        uint256 vaultId,
        address[] calldata assets,
        uint256[] calldata newAllocationsBps,
        string calldata metadataURI
    ) external vaultExists(vaultId) vaultActive(vaultId) returns (uint256 strategyId) {
        if (assets.length == 0) revert ZeroAmount();
        if (assets.length != newAllocationsBps.length) revert AllocationMismatch();

        Vault storage v = vaults[vaultId];
        uint256 sum = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!v.isSupported[assets[i]]) revert AssetNotSupported();
            sum += newAllocationsBps[i];
        }
        if (sum != BPS_DENOMINATOR) revert InvalidAllocation();

        strategyId = nextStrategyId++;
        Strategy storage s = strategies[strategyId];
        s.id = strategyId;
        s.vaultId = vaultId;
        s.proposer = msg.sender;
        s.metadataURI = metadataURI;
        s.proposedAt = block.timestamp;
        s.votingDeadline = block.timestamp + VOTING_PERIOD;
        s.status = StrategyStatus.Pending;

        for (uint256 i = 0; i < assets.length; i++) {
            s.assets.push(assets[i]);
            s.newAllocationsBps.push(newAllocationsBps[i]);
        }

        emit StrategyProposed(strategyId, vaultId, msg.sender, metadataURI);
    }

    function voteOnStrategy(uint256 strategyId) external nonReentrant {
        Strategy storage s = strategies[strategyId];
        if (s.id == 0) revert StrategyNotFound();
        if (s.status != StrategyStatus.Pending) revert StrategyNotPending();
        if (block.timestamp > s.votingDeadline) revert VotingClosed();

        UserData storage u = userData[s.vaultId][msg.sender];
        uint256 voterShares = u.shares;
        if (voterShares == 0) revert NotEnoughVotingPower();
        if (s.hasVoted[msg.sender]) revert StrategyAlreadyVoted();

        s.hasVoted[msg.sender] = true;
        s.yesVotes += voterShares;

        emit Voted(strategyId, msg.sender, voterShares);
    }

    function approveStrategy(uint256 strategyId) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (s.id == 0) revert StrategyNotFound();
        if (s.status != StrategyStatus.Pending) revert StrategyNotPending();
        if (block.timestamp <= s.votingDeadline) revert VotingClosed();

        Vault storage v = vaults[s.vaultId];
        if (v.totalShares == 0) revert NotEnoughVotingPower();
        if (s.yesVotes * BPS_DENOMINATOR < v.totalShares * MIN_VOTE_BPS) {
            s.status = StrategyStatus.Rejected;
            emit StrategyRejected(strategyId);
            return;
        }

        s.status = StrategyStatus.Approved;
        emit StrategyApproved(strategyId, s.vaultId);
    }

    function executeStrategy(uint256 strategyId) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (s.id == 0) revert StrategyNotFound();
        if (s.status != StrategyStatus.Approved) revert StrategyNotApproved();

        Vault storage v = vaults[s.vaultId];
        address[] storage current = v.assets;
        for (uint256 i = 0; i < current.length; i++) {
            v.targetAllocationBps[current[i]] = 0;
        }

        for (uint256 i = 0; i < s.assets.length; i++) {
            v.targetAllocationBps[s.assets[i]] = s.newAllocationsBps[i];
        }

        s.status = StrategyStatus.Executed;
        emit Rebalanced(s.vaultId, strategyId, s.assets, s.newAllocationsBps);
    }

    function snapshotPerformance(uint256 vaultId) external vaultExists(vaultId) {
        UserData storage u = userData[vaultId][msg.sender];
        u.performanceSnapshots.push(block.number);
        u.shareAtBlock[block.number] = u.shares;
        emit PerformanceSnapshot(vaultId, msg.sender, block.number, u.shares);
    }

    function getVaultAssets(uint256 vaultId) external view vaultExists(vaultId) returns (address[] memory) {
        return vaults[vaultId].assets;
    }

    function getVaultAllocation(uint256 vaultId, address asset)
        external
        view
        vaultExists(vaultId)
        returns (uint256)
    {
        return vaults[vaultId].targetAllocationBps[asset];
    }

    function getVaultTotals(uint256 vaultId)
        external
        view
        vaultExists(vaultId)
        returns (uint256 totalShares, bool active, string memory name)
    {
        Vault storage v = vaults[vaultId];
        return (v.totalShares, v.active, v.name);
    }

    function getAssetDepositTotal(uint256 vaultId, address asset)
        external
        view
        vaultExists(vaultId)
        returns (uint256)
    {
        return vaults[vaultId].totalDeposited[asset];
    }

    function getUserShares(uint256 vaultId, address user)
        external
        view
        vaultExists(vaultId)
        returns (uint256)
    {
        return userData[vaultId][user].shares;
    }

    function getUserDeposit(uint256 vaultId, address user, address asset)
        external
        view
        vaultExists(vaultId)
        returns (uint256)
    {
        return userData[vaultId][user].deposited[asset];
    }

    function getUserSnapshots(uint256 vaultId, address user)
        external
        view
        vaultExists(vaultId)
        returns (uint256[] memory)
    {
        return userData[vaultId][user].performanceSnapshots;
    }

    function getUserShareAtBlock(uint256 vaultId, address user, uint256 blockNumber)
        external
        view
        vaultExists(vaultId)
        returns (uint256)
    {
        return userData[vaultId][user].shareAtBlock[blockNumber];
    }

    function getStrategyInfo(uint256 strategyId)
        external
        view
        returns (
            uint256 vaultId,
            address proposer,
            string memory metadataURI,
            uint256 proposedAt,
            uint256 votingDeadline,
            uint256 yesVotes,
            StrategyStatus status
        )
    {
        Strategy storage s = strategies[strategyId];
        if (s.id == 0) revert StrategyNotFound();
        return (s.vaultId, s.proposer, s.metadataURI, s.proposedAt, s.votingDeadline, s.yesVotes, s.status);
    }

    function getStrategyAssets(uint256 strategyId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        Strategy storage s = strategies[strategyId];
        if (s.id == 0) revert StrategyNotFound();
        uint256 len = s.assets.length;
        address[] memory assets = new address[](len);
        uint256[] memory allocs = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            assets[i] = s.assets[i];
            allocs[i] = s.newAllocationsBps[i];
        }
        return (assets, allocs);
    }

    function hasVoted(uint256 strategyId, address voter) external view returns (bool) {
        return strategies[strategyId].hasVoted[voter];
    }

    function isAssetSupported(uint256 vaultId, address asset)
        external
        view
        vaultExists(vaultId)
        returns (bool)
    {
        return vaults[vaultId].isSupported[asset];
    }

    function vaultCount() external view returns (uint256) {
        return nextVaultId - 1;
    }

    function strategyCount() external view returns (uint256) {
        return nextStrategyId - 1;
    }
}
