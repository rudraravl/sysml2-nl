// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MonsterArena {
    enum ElementType { Fire, Water, Earth, Air, Light, Dark }

    struct MonsterType {
        string name;
        uint256 baseAttack;
        uint256 baseDefense;
        uint256 baseHealth;
        ElementType element;
        bool exists;
    }

    struct Monster {
        uint256 typeId;
        uint256 experience;
        uint256 evolutionLevel;
        bool exists;
    }

    uint256 public constant CAPTURE_FEE = 100 ether;
    uint256 public constant EVOLUTION_THRESHOLD = 500;
    uint256 public constant COMBAT_XP_REWARD = 250;
    uint256 public constant COMBAT_COOLDOWN = 1 hours;
    uint256 private constant EVOLUTION_STAT_BONUS_PER_LEVEL = 20;

    address public owner;
    address public operator;

    MonsterType[] public monsterTypes;
    mapping(uint256 => Monster) public monsters;
    mapping(address => uint256[]) private _playerTokens;
    mapping(uint256 => uint256) private _tokenIndex;
    mapping(uint8 => mapping(uint8 => uint256)) private _effectiveness;
    mapping(uint256 => uint256) public lastCombatAt;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    uint256 private _nextTokenId;

    string private _name;
    string private _symbol;

    event MonsterCaptured(address indexed captor, uint256 indexed tokenId, uint256 indexed typeId);
    event MonsterEvolved(uint256 indexed tokenId, uint256 newEvolutionLevel, uint256 experienceConsumed);
    event CombatOutcome(
        uint256 indexed attackerId,
        uint256 indexed defenderId,
        address indexed attackerOwner,
        address defenderOwner,
        bool attackerWon,
        uint256 attackerDamage,
        uint256 defenderDamage,
        uint256 xpAwarded
    );
    event MonsterTypeAdded(uint256 indexed typeId, string name, ElementType element, uint256 baseAttack, uint256 baseDefense, uint256 baseHealth);
    event TypeStatsAdjusted(uint256 indexed typeId, uint256 newAttack, uint256 newDefense, uint256 newHealth);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed tokenOwner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed tokenOwner, address indexed operatorAddr, bool approved);

    error WrongFee();
    error TypeNotFound();
    error MonsterNotFound();
    error NotMonsterOwner();
    error NotEnoughExperience();
    error CannotCombatSelf();
    error CombatOnCooldown(uint256 remaining);
    error Unauthorized();
    error ZeroAddress();
    error InvalidStats();
    error TransferFailed();
    error NonexistentToken();
    error TransferToZeroAddress();
    error CallerNotOwnerNorApproved();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _owner, address _operator) {
        if (_owner == address(0) || _operator == address(0)) revert ZeroAddress();
        _name = "Monster Arena";
        _symbol = "MNSTR";
        owner = _owner;
        operator = _operator;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
        _initEffectiveness();
    }

    function _initEffectiveness() private {
        _effectiveness[uint8(ElementType.Fire)][uint8(ElementType.Earth)] = 200;
        _effectiveness[uint8(ElementType.Earth)][uint8(ElementType.Air)] = 200;
        _effectiveness[uint8(ElementType.Air)][uint8(ElementType.Water)] = 200;
        _effectiveness[uint8(ElementType.Water)][uint8(ElementType.Fire)] = 200;
        _effectiveness[uint8(ElementType.Fire)][uint8(ElementType.Water)] = 50;
        _effectiveness[uint8(ElementType.Earth)][uint8(ElementType.Fire)] = 50;
        _effectiveness[uint8(ElementType.Air)][uint8(ElementType.Earth)] = 50;
        _effectiveness[uint8(ElementType.Water)][uint8(ElementType.Air)] = 50;
        _effectiveness[uint8(ElementType.Light)][uint8(ElementType.Dark)] = 200;
        _effectiveness[uint8(ElementType.Dark)][uint8(ElementType.Light)] = 200;
    }

    function getEffectiveness(ElementType attacker, ElementType defender) public view returns (uint256) {
        uint256 mult = _effectiveness[uint8(attacker)][uint8(defender)];
        return mult == 0 ? 100 : mult;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert NonexistentToken();
        return tokenOwner;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (to == tokenOwner) revert Unauthorized();
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) revert Unauthorized();
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (!_exists(tokenId)) revert NonexistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operatorAddr, bool approved) external {
        if (operatorAddr == msg.sender) revert Unauthorized();
        _operatorApprovals[msg.sender][operatorAddr] = approved;
        emit ApprovalForAll(msg.sender, operatorAddr, approved);
    }

    function isApprovedForAll(address account, address operatorAddr) public view returns (bool) {
        return _operatorApprovals[account][operatorAddr];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || _tokenApprovals[tokenId] == spender || isApprovedForAll(tokenOwner, spender));
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (ownerOf(tokenId) != from) revert NotMonsterOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfer(from, to, tokenId);

        delete _tokenApprovals[tokenId];

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert CallerNotOwnerNorApproved();
        _transfer(from, to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        if (_exists(tokenId)) revert NonexistentToken();

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal {
        if (from != address(0)) {
            uint256 idx = _tokenIndex[tokenId];
            uint256[] storage ownerTokens = _playerTokens[from];
            uint256 lastIdx = ownerTokens.length - 1;
            if (idx != lastIdx) {
                uint256 lastToken = ownerTokens[lastIdx];
                ownerTokens[idx] = lastToken;
                _tokenIndex[lastToken] = idx;
            }
            ownerTokens.pop();
            delete _tokenIndex[tokenId];
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal {
        if (to != address(0)) {
            _tokenIndex[tokenId] = _playerTokens[to].length;
            _playerTokens[to].push(tokenId);
        } else {
            delete monsters[tokenId];
            delete lastCombatAt[tokenId];
        }
    }

    function _baseStats(uint256 tokenId) internal view returns (uint256 attack, uint256 defense, uint256 health) {
        Monster storage m = monsters[tokenId];
        MonsterType storage t = monsterTypes[m.typeId];
        uint256 bonus = 100 + EVOLUTION_STAT_BONUS_PER_LEVEL * m.evolutionLevel;
        attack = (t.baseAttack * bonus) / 100;
        defense = (t.baseDefense * bonus) / 100;
        health = (t.baseHealth * bonus) / 100;
    }

    function getMonsterStats(uint256 tokenId)
        external
        view
        returns (uint256 attack, uint256 defense, uint256 health)
    {
        if (!_exists(tokenId)) revert MonsterNotFound();
        return _baseStats(tokenId);
    }

    function _damageFrom(uint256 attackerId, uint256 defenderId) internal view returns (uint256) {
        (uint256 aAtk, , ) = _baseStats(attackerId);
        (, uint256 dDef, ) = _baseStats(defenderId);
        uint256 mult = getEffectiveness(
            monsterTypes[monsters[attackerId].typeId].element,
            monsterTypes[monsters[defenderId].typeId].element
        );
        uint256 raw = (aAtk * mult) / 100;
        if (raw <= dDef) return 1;
        return raw - dDef;
    }

    function _healthOf(uint256 tokenId) internal view returns (uint256) {
        (, , uint256 hp) = _baseStats(tokenId);
        return hp;
    }

    function captureMonster(uint256 typeId) external payable returns (uint256 tokenId) {
        if (msg.value != CAPTURE_FEE) revert WrongFee();
        if (typeId >= monsterTypes.length || !monsterTypes[typeId].exists) revert TypeNotFound();

        tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        monsters[tokenId] = Monster({
            typeId: typeId,
            experience: 0,
            evolutionLevel: 0,
            exists: true
        });

        emit MonsterCaptured(msg.sender, tokenId, typeId);
    }

    function evolveMonster(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotMonsterOwner();
        Monster storage m = monsters[tokenId];
        if (!m.exists) revert MonsterNotFound();
        if (m.experience < EVOLUTION_THRESHOLD) revert NotEnoughExperience();

        m.experience -= EVOLUTION_THRESHOLD;
        m.evolutionLevel += 1;

        emit MonsterEvolved(tokenId, m.evolutionLevel, EVOLUTION_THRESHOLD);
    }

    function combat(uint256 attackerId, uint256 defenderId) external {
        if (!_exists(attackerId) || !monsters[attackerId].exists) revert MonsterNotFound();
        if (!_exists(defenderId) || !monsters[defenderId].exists) revert MonsterNotFound();
        address attackerOwner = ownerOf(attackerId);
        address defenderOwner = ownerOf(defenderId);
        if (attackerOwner != msg.sender) revert NotMonsterOwner();
        if (attackerOwner == defenderOwner) revert CannotCombatSelf();

        uint256 aCooldownEnd = lastCombatAt[attackerId] + COMBAT_COOLDOWN;
        if (block.timestamp < aCooldownEnd) {
            revert CombatOnCooldown(aCooldownEnd - block.timestamp);
        }
        uint256 dCooldownEnd = lastCombatAt[defenderId] + COMBAT_COOLDOWN;
        if (block.timestamp < dCooldownEnd) {
            revert CombatOnCooldown(dCooldownEnd - block.timestamp);
        }

        uint256 aDamage = _damageFrom(attackerId, defenderId);
        uint256 dDamage = _damageFrom(defenderId, attackerId);
        uint256 aHp = _healthOf(attackerId);
        uint256 dHp = _healthOf(defenderId);

        uint256 aRemaining = aHp > dDamage ? aHp - dDamage : 0;
        uint256 dRemaining = dHp > aDamage ? dHp - aDamage : 0;

        bool attackerWon = aRemaining >= dRemaining;
        if (attackerWon) {
            monsters[attackerId].experience += COMBAT_XP_REWARD;
        } else {
            monsters[defenderId].experience += COMBAT_XP_REWARD;
        }

        lastCombatAt[attackerId] = block.timestamp;
        lastCombatAt[defenderId] = block.timestamp;

        emit CombatOutcome(
            attackerId,
            defenderId,
            attackerOwner,
            defenderOwner,
            attackerWon,
            aDamage,
            dDamage,
            COMBAT_XP_REWARD
        );
    }

    function addMonsterType(
        string memory name_,
        uint256 baseAttack,
        uint256 baseDefense,
        uint256 baseHealth,
        ElementType element
    ) external onlyOperator returns (uint256 typeId) {
        if (baseAttack == 0 || baseDefense == 0 || baseHealth == 0) revert InvalidStats();
        typeId = monsterTypes.length;
        monsterTypes.push(
            MonsterType({
                name: name_,
                baseAttack: baseAttack,
                baseDefense: baseDefense,
                baseHealth: baseHealth,
                element: element,
                exists: true
            })
        );
        emit MonsterTypeAdded(typeId, name_, element, baseAttack, baseDefense, baseHealth);
    }

    function adjustTypeStats(
        uint256 typeId,
        uint256 newAttack,
        uint256 newDefense,
        uint256 newHealth
    ) external onlyOperator {
        if (typeId >= monsterTypes.length || !monsterTypes[typeId].exists) revert TypeNotFound();
        if (newAttack == 0 || newDefense == 0 || newHealth == 0) revert InvalidStats();
        MonsterType storage t = monsterTypes[typeId];
        t.baseAttack = newAttack;
        t.baseDefense = newDefense;
        t.baseHealth = newHealth;
        emit TypeStatsAdjusted(typeId, newAttack, newDefense, newHealth);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function withdrawFunds(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FundsWithdrawn(to, amount);
    }

    function getPlayerMonsters(address player) external view returns (uint256[] memory) {
        return _playerTokens[player];
    }

    function getMonster(uint256 tokenId) external view returns (Monster memory) {
        if (!_exists(tokenId)) revert MonsterNotFound();
        return monsters[tokenId];
    }

    function getMonsterType(uint256 typeId) external view returns (MonsterType memory) {
        if (typeId >= monsterTypes.length || !monsterTypes[typeId].exists) revert TypeNotFound();
        return monsterTypes[typeId];
    }

    function totalMonsterTypes() external view returns (uint256) {
        return monsterTypes.length;
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    receive() external payable {}
}
