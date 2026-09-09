// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
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

/**
 * @dev Wrappers over ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and thus have a
 * non-standard interface) are supported through the use of revert reasons.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title PvPBattleArena
 * @notice A player-versus-player gaming system that custodies WETH for battle rewards.
 *         Players deposit WETH, initiate attacks against other players, defend battles,
 *         and claim rewards from resolved battles. A designated operator manages game
 *         parameters and may pause the system.
 */
contract PvPBattleArena is Ownable {
    using SafeERC20 for IERC20;

    // ============ Custom Errors ============
    error SystemPaused();
    error NotPaused();
    error Unauthorized();
    error ZeroAddress();
    error SelfAttack();
    error InsufficientBalance(uint256 available, uint256 required);
    error AttackCooldownNotElapsed(uint256 nextAvailableAt);
    error BattleNotFound();
    error BattleNotPending();
    error BattleAlreadyResolved();
    error NotDefender();
    error DefendWindowClosed();
    error DefendWindowOpen();
    error NotBattleWinner();
    error NothingToClaim();
    error InvalidAmount();
    error InvalidBattleWinner();

    // ============ Enums ============
    enum BattleStatus {
        Pending,
        Defended,
        AttackerWon,
        DefenderWon
    }

    // ============ Structs ============
    struct Battle {
        address attacker;
        address defender;
        uint256 pot;
        uint256 startTime;
        uint256 defendDeadline;
        bool defended;
        bool resolved;
        bool claimed;
        BattleStatus status;
        address winner;
    }

    struct GameConfig {
        uint256 attackCost;
        uint256 battleWindow;
        uint256 attackCooldown;
    }

    // ============ State Variables ============
    IERC20 public immutable weth;
    address public operator;
    bool public paused;

    GameConfig public config;

    uint256 public battleCount;
    mapping(uint256 => Battle) public battles;
    mapping(address => uint256) public playerBalances;
    mapping(address => uint256) public lastAttackTime;

    // ============ Events ============
    event Deposited(address indexed player, uint256 amount);
    event Withdrawn(address indexed player, uint256 amount);
    event BattleInitiated(uint256 indexed battleId, address indexed attacker, address indexed defender, uint256 pot);
    event BattleDefended(uint256 indexed battleId, address indexed defender, uint256 pot);
    event BattleConcluded(uint256 indexed battleId, address indexed winner, BattleStatus status);
    event RewardsClaimed(uint256 indexed battleId, address indexed winner, uint256 amount);
    event AttackCostUpdated(uint256 previousCost, uint256 newCost);
    event BattleWindowUpdated(uint256 previousWindow, uint256 newWindow);
    event AttackCooldownUpdated(uint256 previousCooldown, uint256 newCooldown);
    event PausedStateChanged(bool paused);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert SystemPaused();
        _;
    }

    // ============ Constructor ============
    constructor(address _weth, address _operator) Ownable(msg.sender) {
        if (_weth == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        weth = IERC20(_weth);
        operator = _operator;
        config = GameConfig({
            attackCost: 0.001 ether,
            battleWindow: 1 hours,
            attackCooldown: 5 minutes
        });
    }

    // ============ Operator Functions ============

    function setAttackCost(uint256 _newCost) external onlyOperator {
        if (_newCost == 0) revert InvalidAmount();
        emit AttackCostUpdated(config.attackCost, _newCost);
        config.attackCost = _newCost;
    }

    function setBattleWindow(uint256 _newWindow) external onlyOperator {
        if (_newWindow == 0) revert InvalidAmount();
        emit BattleWindowUpdated(config.battleWindow, _newWindow);
        config.battleWindow = _newWindow;
    }

    function setAttackCooldown(uint256 _newCooldown) external onlyOperator {
        if (_newCooldown == 0) revert InvalidAmount();
        emit AttackCooldownUpdated(config.attackCooldown, _newCooldown);
        config.attackCooldown = _newCooldown;
    }

    function setPaused(bool _paused) external onlyOperator {
        if (paused == _paused) {
            if (_paused) revert SystemPaused();
            else revert NotPaused();
        }
        paused = _paused;
        emit PausedStateChanged(paused);
    }

    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance(balance, amount);
        IERC20(token).safeTransfer(owner(), amount);
        emit Recovered(token, owner(), amount);
    }

    // ============ User Functions ============

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        playerBalances[msg.sender] += amount;
        weth.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        uint256 balance = playerBalances[msg.sender];
        if (balance < amount) revert InsufficientBalance(balance, amount);
        playerBalances[msg.sender] = balance - amount;
        weth.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function initiateAttack(address defender) external whenNotPaused returns (uint256 battleId) {
        if (defender == address(0)) revert ZeroAddress();
        if (defender == msg.sender) revert SelfAttack();

        uint256 cost = config.attackCost;
        uint256 balance = playerBalances[msg.sender];
        if (balance < cost) revert InsufficientBalance(balance, cost);

        uint256 nextAvailable = lastAttackTime[msg.sender] + config.attackCooldown;
        if (block.timestamp < nextAvailable) revert AttackCooldownNotElapsed(nextAvailable);

        playerBalances[msg.sender] = balance - cost;
        lastAttackTime[msg.sender] = block.timestamp;

        battleId = battleCount++;
        battles[battleId] = Battle({
            attacker: msg.sender,
            defender: defender,
            pot: cost,
            startTime: block.timestamp,
            defendDeadline: block.timestamp + config.battleWindow,
            defended: false,
            resolved: false,
            claimed: false,
            status: BattleStatus.Pending,
            winner: address(0)
        });

        emit BattleInitiated(battleId, msg.sender, defender, cost);
    }

    function defendBattle(uint256 battleId) external whenNotPaused {
        Battle storage battle = battles[battleId];
        if (battle.attacker == address(0)) revert BattleNotFound();
        if (battle.status != BattleStatus.Pending) revert BattleNotPending();
        if (msg.sender != battle.defender) revert NotDefender();
        if (block.timestamp > battle.defendDeadline) revert DefendWindowClosed();

        uint256 cost = config.attackCost;
        uint256 balance = playerBalances[msg.sender];
        if (balance < cost) revert InsufficientBalance(balance, cost);

        playerBalances[msg.sender] = balance - cost;
        battle.pot += cost;
        battle.defended = true;
        battle.status = BattleStatus.Defended;

        emit BattleDefended(battleId, msg.sender, battle.pot);
    }

    function concludeBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        if (battle.attacker == address(0)) revert BattleNotFound();
        if (battle.resolved) revert BattleAlreadyResolved();
        if (battle.defended) revert BattleNotPending();
        if (block.timestamp <= battle.defendDeadline) revert DefendWindowOpen();

        battle.status = BattleStatus.AttackerWon;
        battle.winner = battle.attacker;
        battle.resolved = true;

        emit BattleConcluded(battleId, battle.winner, battle.status);
    }

    function resolveBattle(uint256 battleId, address winner) external onlyOperator {
        Battle storage battle = battles[battleId];
        if (battle.attacker == address(0)) revert BattleNotFound();
        if (battle.resolved) revert BattleAlreadyResolved();
        if (!battle.defended) revert BattleNotPending();
        if (winner != battle.attacker && winner != battle.defender) revert InvalidBattleWinner();

        battle.status = winner == battle.attacker ? BattleStatus.AttackerWon : BattleStatus.DefenderWon;
        battle.winner = winner;
        battle.resolved = true;

        emit BattleConcluded(battleId, battle.winner, battle.status);
    }

    function claimRewards(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        if (battle.attacker == address(0)) revert BattleNotFound();
        if (!battle.resolved) revert BattleNotPending();
        if (battle.claimed) revert NothingToClaim();
        if (battle.winner != msg.sender) revert NotBattleWinner();
        if (battle.pot == 0) revert NothingToClaim();

        uint256 reward = battle.pot;
        battle.claimed = true;
        battle.pot = 0;
        playerBalances[msg.sender] += reward;

        emit RewardsClaimed(battleId, msg.sender, reward);
    }

    // ============ View Functions ============

    function getBattle(uint256 battleId) external view returns (Battle memory) {
        return battles[battleId];
    }

    function canAttack(address player) external view returns (bool) {
        return block.timestamp >= lastAttackTime[player] + config.attackCooldown;
    }

    function nextAttackAvailableAt(address player) external view returns (uint256) {
        return lastAttackTime[player] + config.attackCooldown;
    }

    function getBattleStatus(uint256 battleId) external view returns (BattleStatus) {
        return battles[battleId].status;
    }
}
