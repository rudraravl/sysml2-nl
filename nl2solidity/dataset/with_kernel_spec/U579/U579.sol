// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CollectibleDrawing {
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }

    struct Collectible {
        Rarity rarity;
        uint8 power;
        uint8 speed;
        uint8 intelligence;
        uint8 luck;
        address owner;
    }

    address private _owner;
    uint256 private _totalMinted;
    uint256 private _totalDraws;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public drawPrice = 0.01 ether;

    uint256[5] public rarityWeights;
    uint256 public totalWeight;

    mapping(uint256 => Collectible) private _collectibles;
    mapping(address => uint256) private _balances;
    mapping(address => uint8[]) private _pendingRarities;
    mapping(address => uint256) private _claimIndex;

    event CollectibleMinted(uint256 indexed tokenId, address indexed owner, Rarity rarity);
    event CollectibleTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event DrawEntered(address indexed user, Rarity rarity, uint256 drawNumber);
    event DrawPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event RarityWeightsUpdated(uint256[5] weights);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawn(address indexed to, uint256 amount);

    error NotOwner();
    error NotCollectibleOwner();
    error InvalidPayment();
    error MaxSupplyReached();
    error NoPendingDraw();
    error InvalidAddress();
    error InvalidWeights();
    error InvalidQuantity();
    error TokenDoesNotExist();
    error TransferFailed();
    error NothingToWithdraw();

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    constructor() {
        _owner = msg.sender;
        rarityWeights[0] = 5000;
        rarityWeights[1] = 2500;
        rarityWeights[2] = 1500;
        rarityWeights[3] = 700;
        rarityWeights[4] = 300;
        totalWeight = 10000;
        emit OwnershipTransferred(address(0), _owner);
        emit RarityWeightsUpdated(rarityWeights);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    function setDrawPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = drawPrice;
        drawPrice = newPrice;
        emit DrawPriceUpdated(oldPrice, newPrice);
    }

    function setRarityWeights(uint256[5] calldata weights) external onlyOwner {
        uint256 sum = 0;
        for (uint8 i = 0; i < 5; i++) {
            if (weights[i] == 0) revert InvalidWeights();
            uint256 newSum = sum + weights[i];
            if (newSum < sum) revert InvalidWeights();
            sum = newSum;
        }
        rarityWeights = weights;
        totalWeight = sum;
        emit RarityWeightsUpdated(weights);
    }

    function mint(address to, Rarity rarity) external onlyOwner {
        if (_totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        if (to == address(0)) revert InvalidAddress();
        _mintCollectible(to, uint8(rarity));
    }

    function batchMint(address to, Rarity rarity, uint256 count) external onlyOwner {
        if (count == 0) revert InvalidQuantity();
        if (_totalMinted + count > MAX_SUPPLY) revert MaxSupplyReached();
        if (to == address(0)) revert InvalidAddress();
        for (uint256 i = 0; i < count; i++) {
            _mintCollectible(to, uint8(rarity));
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance < 1) revert NothingToWithdraw();
        (bool success, ) = payable(_owner).call{value: balance}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(_owner, balance);
    }

    function draw() external payable {
        if (msg.value < drawPrice) revert InvalidPayment();
        if (_totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        uint8 rarity = _rollRarity(msg.sender);
        _pendingRarities[msg.sender].push(rarity);
        _totalDraws += 1;
        emit DrawEntered(msg.sender, Rarity(rarity), _totalDraws);
    }

    function drawMultiple(uint256 count) external payable {
        if (count == 0) revert InvalidQuantity();
        if (count > MAX_SUPPLY) revert InvalidQuantity();
        if (msg.value < drawPrice * count) revert InvalidPayment();
        for (uint256 i = 0; i < count; i++) {
            if (_totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
            uint8 rarity = _rollRarity(msg.sender);
            _pendingRarities[msg.sender].push(rarity);
            _totalDraws += 1;
            emit DrawEntered(msg.sender, Rarity(rarity), _totalDraws);
        }
    }

    function claim() external {
        uint8[] storage pending = _pendingRarities[msg.sender];
        uint256 idx = _claimIndex[msg.sender];
        if (idx >= pending.length) revert NoPendingDraw();
        if (_totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        uint8 rarity = pending[idx];
        _claimIndex[msg.sender] = idx + 1;
        _mintCollectible(msg.sender, rarity);
    }

    function claimAll() external {
        uint8[] storage pending = _pendingRarities[msg.sender];
        uint256 idx = _claimIndex[msg.sender];
        if (idx >= pending.length) revert NoPendingDraw();
        while (idx < pending.length && _totalMinted < MAX_SUPPLY) {
            uint8 rarity = pending[idx];
            _mintCollectible(msg.sender, rarity);
            idx += 1;
        }
        _claimIndex[msg.sender] = idx;
    }

    function transfer(address to, uint256 tokenId) external {
        if (to == address(0)) revert InvalidAddress();
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        if (_collectibles[tokenId].owner != msg.sender) revert NotCollectibleOwner();
        address from = msg.sender;
        _collectibles[tokenId].owner = to;
        _balances[from] -= 1;
        _balances[to] += 1;
        emit CollectibleTransferred(tokenId, from, to);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _collectibles[tokenId].owner;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function totalDraws() external view returns (uint256) {
        return _totalDraws;
    }

    function getCollectible(uint256 tokenId)
        external
        view
        returns (Rarity rarity, uint8 power, uint8 speed, uint8 intelligence, uint8 luck, address tokenOwner)
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        Collectible storage c = _collectibles[tokenId];
        return (c.rarity, c.power, c.speed, c.intelligence, c.luck, c.owner);
    }

    function pendingDrawCount(address user) external view returns (uint256) {
        return _pendingRarities[user].length - _claimIndex[user];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < _totalMinted;
    }

    function _mintCollectible(address to, uint8 rarity) internal {
        uint256 tokenId = _totalMinted;
        (uint8 power, uint8 speed, uint8 intelligence, uint8 luck) = _generateAttributes(tokenId, rarity);
        _collectibles[tokenId] = Collectible({
            rarity: Rarity(rarity),
            power: power,
            speed: speed,
            intelligence: intelligence,
            luck: luck,
            owner: to
        });
        _balances[to] += 1;
        _totalMinted += 1;
        emit CollectibleMinted(tokenId, to, Rarity(rarity));
    }

    function _rollRarity(address user) internal view returns (uint8) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    user,
                    _totalMinted,
                    _pendingRarities[user].length,
                    _totalDraws,
                    blockhash(block.number - 1),
                    tx.gasprice
                )
            )
        );
        uint256 roll = seed % totalWeight;
        uint256 cumulative = 0;
        for (uint8 i = 0; i < 5; i++) {
            cumulative += rarityWeights[i];
            if (roll < cumulative) return i;
        }
        return 4;
    }

    function _generateAttributes(uint256 tokenId, uint8 rarity)
        internal
        view
        returns (uint8 power, uint8 speed, uint8 intelligence, uint8 luck)
    {
        uint8 base = rarity * 40;
        bytes32 baseHash = keccak256(abi.encodePacked(tokenId, rarity, block.timestamp, block.prevrandao, _totalMinted));
        
        power = uint8(base + (uint256(keccak256(abi.encodePacked(baseHash, "power"))) % 96));
        speed = uint8(base + (uint256(keccak256(abi.encodePacked(baseHash, "speed"))) % 96));
        intelligence = uint8(base + (uint256(keccak256(abi.encodePacked(baseHash, "intelligence"))) % 96));
        luck = uint8(base + (uint256(keccak256(abi.encodePacked(baseHash, "luck"))) % 96));
    }

    receive() external payable {}
}
