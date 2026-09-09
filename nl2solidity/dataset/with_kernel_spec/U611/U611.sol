// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AssetManagerRegistry
 * @notice Registry of digital asset managers and their performance scores.
 * @dev This contract does not custody any digital assets. It only stores metadata.
 */
contract AssetManagerRegistry {
    struct ManagerRecord {
        uint256 id;
        address managerAddress;
        uint256 score;
        uint256 lastScoreUpdate;
        bool registered;
    }

    address public operator;
    uint256 private nextManagerId;

    mapping(uint256 => ManagerRecord) private managersById;
    mapping(address => uint256) private managerIdByAddress;

    uint256 public constant MIN_SCORE = 1;
    uint256 public constant MAX_SCORE = 100;
    uint256 public constant UPDATE_COOLDOWN = 24 hours;

    error Unauthorized();
    error InvalidScore();
    error ManagerAlreadyRegistered();
    error ManagerNotRegistered();
    error ScoreUpdateTooSoon();
    error ZeroAddress();

    event ManagerRegistered(uint256 indexed managerId, address indexed managerAddress, uint256 score, uint256 timestamp);
    event ManagerScoreUpdated(uint256 indexed managerId, address indexed managerAddress, uint256 oldScore, uint256 newScore, uint256 timestamp);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;
        nextManagerId = 1;
        emit OperatorChanged(address(0), _operator);
    }

    function registerManager(address managerAddress, uint256 score) external onlyOperator returns (uint256 managerId) {
        if (managerAddress == address(0)) {
            revert ZeroAddress();
        }
        if (managerIdByAddress[managerAddress] != 0) {
            revert ManagerAlreadyRegistered();
        }
        if (score < MIN_SCORE || score > MAX_SCORE) {
            revert InvalidScore();
        }

        managerId = nextManagerId++;
        uint256 currentTime = block.timestamp;

        managersById[managerId] = ManagerRecord({
            id: managerId,
            managerAddress: managerAddress,
            score: score,
            lastScoreUpdate: currentTime,
            registered: true
        });
        managerIdByAddress[managerAddress] = managerId;

        emit ManagerRegistered(managerId, managerAddress, score, currentTime);
    }

    function updateManagerScore(uint256 managerId, uint256 newScore) external onlyOperator {
        ManagerRecord storage record = managersById[managerId];
        if (!record.registered) {
            revert ManagerNotRegistered();
        }
        if (newScore < MIN_SCORE || newScore > MAX_SCORE) {
            revert InvalidScore();
        }
        if (block.timestamp < record.lastScoreUpdate + UPDATE_COOLDOWN) {
            revert ScoreUpdateTooSoon();
        }

        uint256 oldScore = record.score;
        record.score = newScore;
        record.lastScoreUpdate = block.timestamp;

        emit ManagerScoreUpdated(managerId, record.managerAddress, oldScore, newScore, block.timestamp);
    }

    function getManagerScore(uint256 managerId) external view returns (uint256 score, uint256 lastScoreUpdate) {
        ManagerRecord storage record = managersById[managerId];
        if (!record.registered) {
            revert ManagerNotRegistered();
        }
        return (record.score, record.lastScoreUpdate);
    }

    function getManagerDetails(uint256 managerId)
        external
        view
        returns (
            address managerAddress,
            uint256 score,
            uint256 lastScoreUpdate,
            bool registered
        )
    {
        ManagerRecord storage record = managersById[managerId];
        if (!record.registered) {
            revert ManagerNotRegistered();
        }
        return (record.managerAddress, record.score, record.lastScoreUpdate, record.registered);
    }

    function getManagerIdByAddress(address managerAddress) external view returns (uint256 managerId) {
        managerId = managerIdByAddress[managerAddress];
        if (managerId == 0) {
            revert ManagerNotRegistered();
        }
    }

    function isManagerRegistered(uint256 managerId) external view returns (bool) {
        return managersById[managerId].registered;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) {
            revert ZeroAddress();
        }
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }
}
