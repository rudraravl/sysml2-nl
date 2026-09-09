// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ReserveCurrency is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public owner;

    mapping(address => bool) public isAcceptedAsset;
    mapping(address => uint256) public mintRatio;
    mapping(address => uint256) public treasuryBalance;
    address[] public acceptedAssets;

    uint256 public constant REWARD_RATE = 5e14; // 0.05% per block in 1e18 precision
    uint256 public constant MIN_DEPOSIT = 10;
    uint256 public constant PRECISION = 1e18;

    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardDebt;
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;

    struct BondOffering {
        address asset;
        uint256 price;
        uint256 capacity;
        uint256 sold;
        bool active;
        uint256 endBlock;
    }
    BondOffering[] public bondOfferings;

    uint256 private _locked = 1;

    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 minted);
    event Withdraw(address indexed caller, address indexed asset, uint256 amount, address indexed to);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event AssetAccepted(address indexed asset, uint256 ratio);
    event MintRatioUpdated(address indexed asset, uint256 oldRatio, uint256 newRatio);
    event BondOfferingInitiated(uint256 indexed offeringId, address indexed asset, uint256 price, uint256 capacity, uint256 endBlock);
    event BondPurchased(uint256 indexed offeringId, address indexed user, address indexed asset, uint256 amount, uint256 reserve);
    event BondOfferingClosed(uint256 indexed offeringId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotAccepted();
    error AssetAlreadyAccepted();
    error ZeroRatio();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientStaked();
    error InsufficientTreasury();
    error InsufficientAllowance();
    error OfferingInactive();
    error OfferingEnded();
    error OfferingCapacityExceeded();
    error ZeroPrice();
    error ZeroCapacity();
    error InvalidEndBlock();
    error NoMint();
    error TransferFailed();
    error Reentrancy();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        lastRewardBlock = block.number;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocksPassed = block.number - lastRewardBlock;
        accRewardPerShare += blocksPassed * REWARD_RATE;
        lastRewardBlock = block.number;
    }

    function _claimRewards(address user) internal {
        uint256 staked = stakedBalance[user];
        uint256 pending = staked > 0
            ? (staked * accRewardPerShare / PRECISION) - userRewardDebt[user]
            : 0;
        userRewardDebt[user] = staked * accRewardPerShare / PRECISION;
        if (pending > 0) {
            _mint(user, pending);
            emit RewardPaid(user, pending);
        }
    }

    function pendingReward(address user) external view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        uint256 acc = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            acc += blocksPassed * REWARD_RATE;
        }
        return (stakedBalance[user] * acc / PRECISION) - userRewardDebt[user];
    }

    function deposit(address asset, uint256 amount) external nonReentrant {
        if (!isAcceptedAsset[asset]) revert AssetNotAccepted();
        if (amount < MIN_DEPOSIT) revert DepositTooSmall();

        uint256 minted = amount * mintRatio[asset] / PRECISION;
        if (minted == 0) revert NoMint();

        // Effects
        treasuryBalance[asset] += amount;
        _mint(msg.sender, minted);

        // Interactions
        _safeTransferFrom(asset, msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount, minted);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _updatePool();
        _claimRewards(msg.sender);

        _balances[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        userRewardDebt[msg.sender] = stakedBalance[msg.sender] * accRewardPerShare / PRECISION;

        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStaked();

        _updatePool();
        _claimRewards(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        _balances[msg.sender] += amount;
        userRewardDebt[msg.sender] = stakedBalance[msg.sender] * accRewardPerShare / PRECISION;

        emit Unstake(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updatePool();
        _claimRewards(msg.sender);
    }

    function addAcceptedAsset(address asset, uint256 ratio) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (isAcceptedAsset[asset]) revert AssetAlreadyAccepted();
        if (ratio == 0) revert ZeroRatio();

        isAcceptedAsset[asset] = true;
        mintRatio[asset] = ratio;
        acceptedAssets.push(asset);

        emit AssetAccepted(asset, ratio);
    }

    function adjustMintRatio(address asset, uint256 newRatio) external onlyOwner {
        if (!isAcceptedAsset[asset]) revert AssetNotAccepted();
        if (newRatio == 0) revert ZeroRatio();

        uint256 oldRatio = mintRatio[asset];
        mintRatio[asset] = newRatio;

        emit MintRatioUpdated(asset, oldRatio, newRatio);
    }

    function withdrawTreasury(address asset, uint256 amount, address to) external onlyOwner {
        if (!isAcceptedAsset[asset]) revert AssetNotAccepted();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (treasuryBalance[asset] < amount) revert InsufficientTreasury();

        // Effects
        treasuryBalance[asset] -= amount;

        // Interactions
        _safeTransfer(asset, to, amount);

        emit Withdraw(msg.sender, asset, amount, to);
    }

    function initiateBondOffering(
        address asset,
        uint256 price,
        uint256 capacity,
        uint256 endBlock
    ) external onlyOwner returns (uint256 offeringId) {
        if (!isAcceptedAsset[asset]) revert AssetNotAccepted();
        if (price == 0) revert ZeroPrice();
        if (capacity == 0) revert ZeroCapacity();
        if (endBlock <= block.number) revert InvalidEndBlock();

        offeringId = bondOfferings.length;
        bondOfferings.push(BondOffering({
            asset: asset,
            price: price,
            capacity: capacity,
            sold: 0,
            active: true,
            endBlock: endBlock
        }));

        emit BondOfferingInitiated(offeringId, asset, price, capacity, endBlock);
    }

    function closeBondOffering(uint256 offeringId) external onlyOwner {
        if (offeringId >= bondOfferings.length) revert OfferingInactive();
        BondOffering storage o = bondOfferings[offeringId];
        if (!o.active) revert OfferingInactive();
        o.active = false;
        emit BondOfferingClosed(offeringId);
    }

    function purchaseBond(uint256 offeringId, uint256 amount) external nonReentrant {
        if (offeringId >= bondOfferings.length) revert OfferingInactive();
        BondOffering storage o = bondOfferings[offeringId];
        if (!o.active) revert OfferingInactive();
        if (block.number > o.endBlock) revert OfferingEnded();
        if (amount == 0) revert ZeroAmount();
        if (o.sold + amount > o.capacity) revert OfferingCapacityExceeded();

        uint256 reserve = amount * o.price / PRECISION;
        if (reserve == 0) revert NoMint();

        // Effects: update all state before the external call
        o.sold += amount;
        treasuryBalance[o.asset] += amount;
        _mint(msg.sender, reserve);

        // Interactions
        _safeTransferFrom(o.asset, msg.sender, address(this), amount);

        emit BondPurchased(offeringId, msg.sender, o.asset, amount, reserve);
    }

    function acceptedAssetCount() external view returns (uint256) {
        return acceptedAssets.length;
    }

    function bondOfferingCount() external view returns (uint256) {
        return bondOfferings.length;
    }

    function getAcceptedAssets() external view returns (address[] memory) {
        return acceptedAssets;
    }

    function getBondOffering(uint256 offeringId)
        external
        view
        returns (
            address asset,
            uint256 price,
            uint256 capacity,
            uint256 sold,
            bool active,
            uint256 endBlock
        )
    {
        if (offeringId >= bondOfferings.length) revert OfferingInactive();
        BondOffering storage o = bondOfferings[offeringId];
        return (o.asset, o.price, o.capacity, o.sold, o.active, o.endBlock);
    }
}
