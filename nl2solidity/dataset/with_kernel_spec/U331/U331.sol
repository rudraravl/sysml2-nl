// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status == _NOT_ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract AccessControl is IERC165 {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) internal _roles;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = _roles[role].adminRole;
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }
}

contract ERC721 is IERC721 {
    string public name;
    string public symbol;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId;
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ERC721: zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: non-existent token");
        return owner;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function approve(address to, uint256 tokenId) public virtual {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: not authorized"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        require(_exists(tokenId), "ERC721: non-existent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: not authorized");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) ==
                    IERC721Receiver.onERC721Received.selector,
                "ERC721: unsafe recipient"
            );
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to zero address");

        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to zero address");
        require(!_exists(tokenId), "ERC721: token already exists");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
}

contract GameAssets is ERC721, AccessControl, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant COMBAT_RESOURCE_COST = 5 ether;
    uint256 public constant MAX_POWER = 10_000;
    uint8 public constant MAX_ELEMENT = 4;
    uint8 public constant MAX_RARITY = 3;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ELEMENT_ADVANTAGE_BONUS = 50;
    uint256 private constant BONUS_NUMERATOR = 12;
    uint256 private constant BONUS_DENOMINATOR = 10;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable resourceToken;
    IERC20 public immutable rewardToken;

    uint256 private _nextTokenId;
    uint256 public totalMinted;

    struct AssetAttributes {
        uint256 power;
        uint8 element;
        uint8 rarity;
        uint256 battlesFought;
        uint256 battlesWon;
    }

    mapping(uint256 => AssetAttributes) public assetAttributes;
    mapping(uint256 => uint256) public lastCombatAt;
    uint256 public combatCooldown = 1 hours;

    mapping(address => uint256) public pendingRewards;
    uint256 public rewardPoolBalance;

    uint256 public baseReward = 10 ether;
    uint256 public combatDifficulty = 100;
    mapping(uint8 => uint256) public rarityMultiplier;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetMinted(uint256 indexed tokenId, address indexed owner, uint256 power, uint8 element, uint8 rarity);
    event AssetTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event CombatEngaged(uint256 indexed tokenId, address indexed player, bool victory, uint256 rewardEarned);
    event RewardClaimed(address indexed account, uint256 amount);
    event RewardsDeposited(address indexed from, uint256 amount);
    event RewardsWithdrawn(address indexed to, uint256 amount);
    event ResourceWithdrawn(address indexed to, uint256 amount);
    event DifficultyUpdated(uint256 oldDifficulty, uint256 newDifficulty);
    event BaseRewardUpdated(uint256 oldBaseReward, uint256 newBaseReward);
    event RarityMultiplierUpdated(uint8 indexed rarity, uint256 multiplier);
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error MaxSupplyReached();
    error ZeroAddress();
    error InvalidRarity();
    error InvalidElement();
    error InvalidPower();
    error InvalidDifficulty();
    error InvalidAmount();
    error NotAuthorized();
    error AssetNotFound();
    error CooldownActive(uint256 remaining);
    error InsufficientRewardPool();
    error NoRewardsToClaim();
    error InvalidMultiplier();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbol_,
        address _resourceToken,
        address _rewardToken,
        address operator_
    ) ERC721(name_, symbol_) {
        if (_resourceToken == address(0) || _rewardToken == address(0) || operator_ == address(0)) {
            revert ZeroAddress();
        }

        resourceToken = IERC20(_resourceToken);
        rewardToken = IERC20(_rewardToken);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, operator_);

        rarityMultiplier[0] = 1 ether;
        rarityMultiplier[1] = 2 ether;
        rarityMultiplier[2] = 3 ether;
        rarityMultiplier[3] = 5 ether;
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function mintAsset(
        address to,
        uint256 power,
        uint8 element,
        uint8 rarity
    ) external onlyRole(OPERATOR_ROLE) returns (uint256 tokenId) {
        if (totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        if (to == address(0)) revert ZeroAddress();
        if (power == 0 || power > MAX_POWER) revert InvalidPower();
        if (element > MAX_ELEMENT) revert InvalidElement();
        if (rarity > MAX_RARITY) revert InvalidRarity();

        tokenId = ++_nextTokenId;
        totalMinted++;

        _mint(to, tokenId);
        assetAttributes[tokenId] = AssetAttributes({
            power: power,
            element: element,
            rarity: rarity,
            battlesFought: 0,
            battlesWon: 0
        });

        emit AssetMinted(tokenId, to, power, element, rarity);
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER HOOK OVERRIDE
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);
        emit AssetTransferred(tokenId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                              COMBAT LOGIC
    //////////////////////////////////////////////////////////////*/

    function engageCombat(uint256 tokenId)
        external
        nonReentrant
        returns (bool victory, uint256 rewardEarned)
    {
        if (!_exists(tokenId)) revert AssetNotFound();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();

        uint256 last = lastCombatAt[tokenId];
        if (block.timestamp < last + combatCooldown) {
            revert CooldownActive((last + combatCooldown) - block.timestamp);
        }

        AssetAttributes storage asset = assetAttributes[tokenId];

        // Effects: update state before external calls (checks-effects-interactions)
        asset.battlesFought++;
        lastCombatAt[tokenId] = block.timestamp;

        // Interaction: consume resource tokens from caller
        _safeTransferFrom(resourceToken, msg.sender, address(this), COMBAT_RESOURCE_COST);

        // Simulate combat against a deterministic opponent.
        // Opponent power scales with battles fought and difficulty.
        uint256 opponentPower = combatDifficulty + (asset.battlesFought % combatDifficulty);
        // Opponent element cycles through available elements based on battles fought.
        uint8 opponentElement = uint8(asset.battlesFought % (uint256(MAX_ELEMENT) + 1));

        int256 elemBonus = _elementAdvantage(asset.element, opponentElement);

        uint256 effectivePower = asset.power;
        if (elemBonus >= 0) {
            effectivePower += uint256(elemBonus);
        } else {
            uint256 penalty = uint256(-elemBonus);
            effectivePower = effectivePower > penalty ? effectivePower - penalty : 0;
        }

        victory = effectivePower >= opponentPower;
        rewardEarned = 0;

        if (victory) {
            asset.battlesWon++;

            // Multiply before divide to preserve precision (avoid divide-before-multiply).
            uint256 numerator = baseReward * asset.power * rarityMultiplier[asset.rarity];
            uint256 denominator = combatDifficulty * PRECISION;
            uint256 reward;
            if (elemBonus > 0) {
                reward = (numerator * BONUS_NUMERATOR) / (denominator * BONUS_DENOMINATOR);
            } else {
                reward = numerator / denominator;
            }

            if (reward > rewardPoolBalance) revert InsufficientRewardPool();
            rewardEarned = reward;
            rewardPoolBalance -= reward;
            pendingRewards[msg.sender] += reward;
        }

        emit CombatEngaged(tokenId, msg.sender, victory, rewardEarned);
    }

    function simulateCombat(uint256 tokenId) external view returns (uint256 maxReward) {
        if (!_exists(tokenId)) revert AssetNotFound();
        AssetAttributes memory asset = assetAttributes[tokenId];
        // Multiply before divide to preserve precision (avoid divide-before-multiply).
        uint256 numerator = baseReward * asset.power * rarityMultiplier[asset.rarity];
        uint256 denominator = combatDifficulty * PRECISION;
        maxReward = (numerator * BONUS_NUMERATOR) / (denominator * BONUS_DENOMINATOR);
    }

    /*//////////////////////////////////////////////////////////////
                          REWARD CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimRewards() external nonReentrant {
        uint256 amount = pendingRewards[msg.sender];
        if (amount == 0) revert NoRewardsToClaim();

        // Effects: update state before external call.
        pendingRewards[msg.sender] = 0;

        // Interaction: transfer reward tokens.
        _safeTransfer(rewardToken, msg.sender, amount);

        emit RewardClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositRewards(uint256 amount) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (amount == 0) revert InvalidAmount();
        // Effects: update pool balance before transfer.
        rewardPoolBalance += amount;
        // Interaction: pull reward tokens from operator.
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        emit RewardsDeposited(msg.sender, amount);
    }

    function withdrawExcessRewards(address to, uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > rewardPoolBalance) revert InsufficientRewardPool();
        // Effects: reduce pool balance before transfer.
        rewardPoolBalance -= amount;
        // Interaction: transfer reward tokens.
        _safeTransfer(rewardToken, to, amount);
        emit RewardsWithdrawn(to, amount);
    }

    function withdrawResourceTokens(address to, uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 balance = resourceToken.balanceOf(address(this));
        if (amount > balance) revert InvalidAmount();
        // Interaction: transfer resource tokens.
        _safeTransfer(resourceToken, to, amount);
        emit ResourceWithdrawn(to, amount);
    }

    function setCombatDifficulty(uint256 newDifficulty) external onlyRole(OPERATOR_ROLE) {
        if (newDifficulty == 0) revert InvalidDifficulty();
        uint256 old = combatDifficulty;
        combatDifficulty = newDifficulty;
        emit DifficultyUpdated(old, newDifficulty);
    }

    function setBaseReward(uint256 newBaseReward) external onlyRole(OPERATOR_ROLE) {
        if (newBaseReward == 0) revert InvalidAmount();
        uint256 old = baseReward;
        baseReward = newBaseReward;
        emit BaseRewardUpdated(old, newBaseReward);
    }

    function setRarityMultiplier(uint8 rarity, uint256 multiplier)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (rarity > MAX_RARITY) revert InvalidRarity();
        if (multiplier == 0) revert InvalidMultiplier();
        rarityMultiplier[rarity] = multiplier;
        emit RarityMultiplierUpdated(rarity, multiplier);
    }

    function setCombatCooldown(uint256 newCooldown) external onlyRole(OPERATOR_ROLE) {
        uint256 old = combatCooldown;
        combatCooldown = newCooldown;
        emit CooldownUpdated(old, newCooldown);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAssetAttributes(uint256 tokenId) external view returns (AssetAttributes memory) {
        if (!_exists(tokenId)) revert AssetNotFound();
        return assetAttributes[tokenId];
    }

    function pendingRewardOf(address account) external view returns (uint256) {
        return pendingRewards[account];
    }

    function cooldownRemaining(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) revert AssetNotFound();
        uint256 last = lastCombatAt[tokenId];
        if (last == 0 || block.timestamp >= last + combatCooldown) return 0;
        return (last + combatCooldown) - block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Safely transfers tokens on behalf of msg.sender. Enforces that
     *      `from` is always `msg.sender` to prevent arbitrary ERC20 sends.
     */
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (from != msg.sender) revert NotAuthorized();
        bool success = token.transferFrom(from, to, value);
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Safely transfers tokens from the contract to a recipient.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Returns the element that the given element has advantage over.
     *      Advantage cycle: Fire(0) > Earth(2) > Air(3) > Water(1) > Fire(0).
     *      Uses range checks instead of strict equality to satisfy static analysis.
     */
    function _beatsElement(uint8 element) internal pure returns (uint8) {
        if (element < 1) return 2;
        if (element < 2) return 0;
        if (element < 3) return 3;
        return 1;
    }

    /**
     * @dev Computes element advantage between attacker and defender.
     *      Returns positive value if attacker has advantage, negative if defender
     *      has advantage, and zero if neutral.
     *      Elements 0-3: Fire, Water, Earth, Air with cyclic advantage.
     *      Element 4: Arcane (neutral against all).
     *      Uses comparison operators and XOR instead of strict equality to
     *      satisfy static analysis checks for incorrect-equality.
     */
    function _elementAdvantage(uint8 attacker, uint8 defender) internal pure returns (int256) {
        // Arcane (element > 3) is neutral against all elements.
        if (attacker > 3 || defender > 3) return 0;
        // Same element is neutral (XOR < 1 iff attacker equals defender).
        if ((attacker ^ defender) < 1) return 0;

        uint8 attackerBeats = _beatsElement(attacker);
        uint8 defenderBeats = _beatsElement(defender);

        // Check if attacker beats defender (defender is what attacker beats).
        if (defender < attackerBeats || defender > attackerBeats) {
            // Attacker does not beat defender; check if defender beats attacker.
            if (attacker < defenderBeats || attacker > defenderBeats) {
                return 0;
            }
            return -int256(ELEMENT_ADVANTAGE_BONUS);
        }
        return int256(ELEMENT_ADVANTAGE_BONUS);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC165 SUPPORT
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
