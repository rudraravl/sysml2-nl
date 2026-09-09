// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreatureVerse {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorized();
    error TokenDoesNotExist();
    error NotTokenOwner();
    error NotApprovedOrOwner();
    error ZeroAddressRecipient();
    error PoolEmpty();
    error NotEnoughBreedingSlots();
    error SameParent();
    error BattleInvalid();
    error InsufficientFee();
    error InvalidFee();
    error UnsafeRecipient();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CreatureCreated(uint256 indexed tokenId, uint256 genes, uint16 attack, uint16 defense, uint16 speed);
    event BattleOutcome(
        uint256 indexed attackerId,
        uint256 indexed defenderId,
        uint256 indexed winnerId,
        uint256 attackerRoll,
        uint256 defenderRoll
    );
    event BreedingFeeUpdated(uint256 oldFee, uint256 newFee);
    event PoolMinted(uint256 indexed tokenId);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                            TYPE DEFINITIONS
    //////////////////////////////////////////////////////////////*/

    struct Creature {
        uint256 genes;       // packed genetic traits
        uint16 attack;
        uint16 defense;
        uint16 speed;
        uint8 breedings;     // number of times this creature has bred
        uint64 birthTime;
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    uint256 public breedingFee = 0.005 ether;
    uint8 public constant MAX_BREEDINGS = 7;

    uint256 private _nextTokenId = 1;
    uint256[] private _pool;

    mapping(uint256 => Creature) private _creatures;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddressRecipient();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBreedingFee(uint256 newFee) external onlyOperator {
        if (newFee == 0) revert InvalidFee();
        emit BreedingFeeUpdated(breedingFee, newFee);
        breedingFee = newFee;
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddressRecipient();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Mints a new creature into the acquisition pool.
    function mintToPool(
        uint256 genes,
        uint16 attack,
        uint16 defense,
        uint16 speed
    ) external onlyOperator returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _creatures[tokenId] = Creature({
            genes: genes,
            attack: attack,
            defense: defense,
            speed: speed,
            breedings: 0,
            birthTime: uint64(block.timestamp)
        });
        _pool.push(tokenId);
        emit CreatureCreated(tokenId, genes, attack, defense, speed);
        emit PoolMinted(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                       ACQUISITION FROM POOL
    //////////////////////////////////////////////////////////////*/

    /// @notice Acquires a creature from the pool.
    function acquireFromPool() external returns (uint256 tokenId) {
        uint256 poolLength = _pool.length;
        if (poolLength == 0) revert PoolEmpty();

        tokenId = _pool[poolLength - 1];
        _pool.pop();

        _balances[msg.sender] += 1;
        _owners[tokenId] = msg.sender;

        emit Transfer(address(0), msg.sender, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC721-LIKE LOGIC
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddressRecipient();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    function getCreature(uint256 tokenId) external view returns (Creature memory) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return _creatures[tokenId];
    }

    function poolSize() external view returns (uint256) {
        return _pool.length;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (to == owner) revert NotAuthorized();
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) revert NotAuthorized();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address to, bool approved) external {
        if (to == msg.sender) revert NotAuthorized();
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        ownerOf(tokenId);
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address account, address operatorAddr) external view returns (bool) {
        return _operatorApprovals[account][operatorAddr];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        address owner = ownerOf(tokenId);
        if (from != owner) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddressRecipient();

        bool isApproved = msg.sender == owner
            || _tokenApprovals[tokenId] == msg.sender
            || _operatorApprovals[owner][msg.sender];
        if (!isApproved) revert NotApprovedOrOwner();

        _tokenApprovals[tokenId] = address(0);
        emit Approval(owner, address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
            } catch {
                revert UnsafeRecipient();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             BREEDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Breeds two creatures owned by the caller. Costs the breeding fee.
    function breed(uint256 parentAId, uint256 parentBId) external payable returns (uint256 childId) {
        if (msg.value < breedingFee) revert InsufficientFee();
        if (parentAId == parentBId) revert SameParent();

        address ownerA = ownerOf(parentAId);
        address ownerB = ownerOf(parentBId);
        if (ownerA != msg.sender || ownerB != msg.sender) revert NotTokenOwner();

        Creature storage a = _creatures[parentAId];
        Creature storage b = _creatures[parentBId];
        if (a.breedings >= MAX_BREEDINGS || b.breedings >= MAX_BREEDINGS) revert NotEnoughBreedingSlots();

        a.breedings += 1;
        b.breedings += 1;

        uint256 childGenes = (a.genes ^ b.genes) ^ (uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            parentAId,
            parentBId,
            _nextTokenId
        ))) & 0xFFFFFFFFFFFFFFFF);

        uint16 variance = uint16(uint256(keccak256(abi.encodePacked(block.timestamp, _nextTokenId))) % 20);
        uint16 childAttack = (a.attack + b.attack) / 2 + variance;
        uint16 childDefense = (a.defense + b.defense) / 2 + variance;
        uint16 childSpeed = (a.speed + b.speed) / 2 + variance;

        childId = _nextTokenId++;
        _creatures[childId] = Creature({
            genes: childGenes,
            attack: childAttack,
            defense: childDefense,
            speed: childSpeed,
            breedings: 0,
            birthTime: uint64(block.timestamp)
        });

        _balances[msg.sender] += 1;
        _owners[childId] = msg.sender;

        emit CreatureCreated(childId, childGenes, childAttack, childDefense, childSpeed);
        emit Transfer(address(0), msg.sender, childId);

        if (msg.value > breedingFee) {
            (bool sent, ) = payable(msg.sender).call{value: msg.value - breedingFee}("");
            require(sent, "Refund failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                              BATTLING
    //////////////////////////////////////////////////////////////*/

    /// @notice Simulates a battle between two creatures. Caller must own the attacker.
    function battle(uint256 attackerId, uint256 defenderId) external returns (uint256 winnerId) {
        if (attackerId == defenderId) revert BattleInvalid();
        address attackerOwner = ownerOf(attackerId);
        if (attackerOwner != msg.sender) revert NotTokenOwner();
        ownerOf(defenderId);

        Creature storage attacker = _creatures[attackerId];
        Creature storage defender = _creatures[defenderId];

        uint256 attackerRoll = _roll(attacker, attackerId, defenderId, true);
        uint256 defenderRoll = _roll(defender, defenderId, attackerId, false);

        if (attackerRoll >= defenderRoll) {
            winnerId = attackerId;
        } else {
            winnerId = defenderId;
        }

        emit BattleOutcome(attackerId, defenderId, winnerId, attackerRoll, defenderRoll);
    }

    function _roll(
        Creature storage c,
        uint256 selfId,
        uint256 opponentId,
        bool isAttacker
    ) internal view returns (uint256) {
        uint256 base = uint256(c.attack) + uint256(c.defense) + uint256(c.speed);
        uint256 salt = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            selfId,
            opponentId,
            isAttacker
        )));
        return base + (salt % 1000);
    }

    /*//////////////////////////////////////////////////////////////
                          FEE WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function withdrawFees(address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddressRecipient();
        uint256 balance = address(this).balance;
        (bool success, ) = to.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}
    fallback() external payable {}
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
