// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PlayerTrainingManager
 * @notice Manages player NFT assets and their associated training progress
 *         within a strategic gaming ecosystem. Only a designated operator may
 *         mint new players and adjust the global training cost; players may
 *         train their owned tokens and transfer them to other accounts.
 */
contract PlayerTrainingManager {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOperator();
    error NotOwnerOrApproved();
    error InvalidTokenId();
    error ZeroAddress();
    error InvalidStats();
    error TransferToSelf();
    error InsufficientTrainingPoints();
    error InsufficientPayment();
    error TrainingCostExceedsCap();
    error InvalidThreshold();
    error RefundFailed();
    error WithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event PlayerMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 speed,
        uint256 strength
    );

    event PlayerTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );

    event TrainingCompleted(
        uint256 indexed tokenId,
        address indexed trainer,
        uint256 pointsConsumed,
        uint256 speedGained,
        uint256 strengthGained,
        uint256 newSpeed,
        uint256 newStrength
    );

    event TrainingPointsAwarded(uint256 indexed tokenId, uint256 amount);

    event TrainingCostUpdated(uint256 oldCost, uint256 newCost);

    event ExperienceThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Maximum training cost per session: 0.05 native token.
    uint256 public constant MAX_TRAINING_COST = 0.05 ether;

    /// @dev Minimum training points required to be consumed per training session.
    uint256 public constant MIN_TRAINING_POINTS = 10;

    /// @dev Scaling divisor used when converting points to stat gains.
    uint256 public constant STAT_GAIN_DIVISOR = 100;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Player {
        uint256 id;
        uint256 speed;
        uint256 strength;
        uint256 trainingPoints;
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Address authorized to mint players and adjust configuration.
    address public operator;

    /// @notice Cost in native token to initiate a single training session.
    uint256 public trainingCost;

    /// @notice Experience threshold that scales stat gains per training point.
    uint256 public experienceThreshold;

    uint256 private _nextTokenId;

    mapping(uint256 => Player) private _players;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier validToken(uint256 tokenId) {
        if (_owners[tokenId] == address(0)) revert InvalidTokenId();
        _;
    }

    modifier onlyOwnerOrApproved(uint256 tokenId) {
        if (!_isOwnerOrApproved(msg.sender, tokenId)) revert NotOwnerOrApproved();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _operator        Address of the designated operator.
     * @param _trainingCost    Initial cost per training session (wei).
     * @param _experienceThreshold Initial threshold used to scale stat gains.
     */
    constructor(
        address _operator,
        uint256 _trainingCost,
        uint256 _experienceThreshold
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_trainingCost > MAX_TRAINING_COST) revert TrainingCostExceedsCap();
        if (_experienceThreshold == 0) revert InvalidThreshold();

        operator = _operator;
        trainingCost = _trainingCost;
        experienceThreshold = _experienceThreshold;

        emit OperatorUpdated(address(0), _operator);
        emit TrainingCostUpdated(0, _trainingCost);
        emit ExperienceThresholdUpdated(0, _experienceThreshold);
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL / PUBLIC LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a new player NFT. Only callable by the operator.
     * @param to       The recipient of the newly minted player.
     * @param speed    Initial speed stat (must be > 0).
     * @param strength Initial strength stat (must be > 0).
     * @return tokenId The identifier of the newly minted player.
     */
    function mintPlayer(
        address to,
        uint256 speed,
        uint256 strength
    ) external onlyOperator returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (speed == 0 || strength == 0) revert InvalidStats();

        tokenId = _nextTokenId++;
        _players[tokenId] = Player({
            id: tokenId,
            speed: speed,
            strength: strength,
            trainingPoints: 0
        });

        _owners[tokenId] = to;
        unchecked {
            _balances[to] += 1;
        }

        emit PlayerMinted(tokenId, to, speed, strength);
        emit PlayerTransferred(tokenId, address(0), to);
    }

    /**
     * @notice Awards training points to a player. Only callable by the operator.
     * @param tokenId The player NFT to award points to.
     * @param amount  The number of training points to add.
     */
    function awardTrainingPoints(
        uint256 tokenId,
        uint256 amount
    ) external onlyOperator validToken(tokenId) {
        _players[tokenId].trainingPoints += amount;
        emit TrainingPointsAwarded(tokenId, amount);
    }

    /**
     * @notice Initiates a training session for a player, consuming training
     *         points and improving statistics. Caller must pay the training cost.
     * @param tokenId        The player NFT to train.
     * @param pointsToConsume The number of training points to consume (>= 10).
     */
    function trainPlayer(
        uint256 tokenId,
        uint256 pointsToConsume
    )
        external
        payable
        validToken(tokenId)
        onlyOwnerOrApproved(tokenId)
    {
        if (pointsToConsume < MIN_TRAINING_POINTS) revert InsufficientTrainingPoints();
        if (msg.value < trainingCost) revert InsufficientPayment();

        Player storage player = _players[tokenId];
        if (player.trainingPoints < pointsToConsume) revert InsufficientTrainingPoints();

        // Stat gains scale with the experience threshold (default: 1:1).
        uint256 speedGained = (pointsToConsume * experienceThreshold) / STAT_GAIN_DIVISOR;
        uint256 strengthGained = (pointsToConsume * experienceThreshold) / STAT_GAIN_DIVISOR;
        if (speedGained == 0) speedGained = 1;
        if (strengthGained == 0) strengthGained = 1;

        // Effects.
        player.trainingPoints -= pointsToConsume;
        player.speed += speedGained;
        player.strength += strengthGained;

        // Refund excess payment.
        if (msg.value > trainingCost) {
            uint256 excess = msg.value - trainingCost;
            (bool ok, ) = msg.sender.call{value: excess}("");
            if (!ok) revert RefundFailed();
        }

        emit TrainingCompleted(
            tokenId,
            msg.sender,
            pointsToConsume,
            speedGained,
            strengthGained,
            player.speed,
            player.strength
        );
    }

    /**
     * @notice Transfers a player NFT from one account to another.
     * @param from    Current owner of the token.
     * @param to      Recipient address.
     * @param tokenId The player NFT to transfer.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external validToken(tokenId) {
        if (from == to) revert TransferToSelf();
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != from) revert NotOwnerOrApproved();
        if (!_isOwnerOrApproved(msg.sender, tokenId)) revert NotOwnerOrApproved();

        // Effects.
        _tokenApprovals[tokenId] = address(0);
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit PlayerTransferred(tokenId, from, to);
    }

    /**
     * @notice Approves an account to manage a specific player NFT.
     * @param to      The address to approve.
     * @param tokenId The player NFT to approve.
     */
    function approve(
        address to,
        uint256 tokenId
    ) external validToken(tokenId) {
        address tokenOwner = _owners[tokenId];
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) {
            revert NotOwnerOrApproved();
        }
        _tokenApprovals[tokenId] = to;
    }

    /**
     * @notice Sets or revokes operator approval for the caller's entire collection.
     * @param operator_ The address to grant or revoke approval to.
     * @param approved  Whether approval is granted.
     */
    function setApprovalForAll(address operator_, bool approved) external {
        if (operator_ == msg.sender) revert TransferToSelf();
        _operatorApprovals[msg.sender][operator_] = approved;
    }

    /**
     * @notice Updates the global training cost. Only callable by the operator.
     * @param newCost The new cost per training session, capped at MAX_TRAINING_COST.
     */
    function setTrainingCost(uint256 newCost) external onlyOperator {
        if (newCost > MAX_TRAINING_COST) revert TrainingCostExceedsCap();
        uint256 oldCost = trainingCost;
        trainingCost = newCost;
        emit TrainingCostUpdated(oldCost, newCost);
    }

    /**
     * @notice Updates the experience threshold used to scale stat gains.
     * @param newThreshold The new threshold (must be > 0).
     */
    function setExperienceThreshold(uint256 newThreshold) external onlyOperator {
        if (newThreshold == 0) revert InvalidThreshold();
        uint256 oldThreshold = experienceThreshold;
        experienceThreshold = newThreshold;
        emit ExperienceThresholdUpdated(oldThreshold, newThreshold);
    }

    /**
     * @notice Transfers operator role to a new address.
     * @param newOperator The new operator address (must not be zero).
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Allows the operator to withdraw accumulated training fees.
     * @param recipient The address to receive the native token balance.
     */
    function withdrawFees(address recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok, ) = recipient.call{value: balance}("");
            if (!ok) revert WithdrawFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function ownerOf(uint256 tokenId) external view validToken(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function getApproved(uint256 tokenId) external view validToken(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator_
    ) external view returns (bool) {
        return _operatorApprovals[owner][operator_];
    }

    function getPlayer(
        uint256 tokenId
    )
        external
        view
        validToken(tokenId)
        returns (
            uint256 id,
            uint256 speed,
            uint256 strength,
            uint256 trainingPoints
        )
    {
        Player storage p = _players[tokenId];
        return (p.id, p.speed, p.strength, p.trainingPoints);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _isOwnerOrApproved(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        address tokenOwner = _owners[tokenId];
        return spender == tokenOwner
            || _tokenApprovals[tokenId] == spender
            || _operatorApprovals[tokenOwner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/
    /// @dev Accepts native token deposits used to pay training fees.
    receive() external payable {}
}
