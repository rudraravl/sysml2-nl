// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IGovernanceDistributor {
    function distribute(address user, uint256 points) external;
}

contract GovernanceLaunchStaking {
    error Unauthorized();
    error ZeroAddress();
    error InsufficientDeposit();
    error InsufficientBalance();
    error NoPointsToClaim();
    error TransferFailed();
    error InvalidRate();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardPointsClaimed(address indexed user, uint256 points);
    event RewardRateUpdated(uint256 newRate);
    event DistributorUpdated(address indexed newDistributor);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MIN_DEPOSIT = 100 * 10**18;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant TOKEN_UNITS_PER_POINT = 10 * 10**18;

    address public owner;
    address public distributor;
    IERC20 public immutable stakingToken;

    uint256 public rewardRatePerDay;

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public userAccruedPoints;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _stakingToken, address _distributor, uint256 _initialRatePerDay) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_distributor == address(0)) revert ZeroAddress();
        if (_initialRatePerDay < 1) revert InvalidRate();

        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        distributor = _distributor;
        rewardRatePerDay = _initialRatePerDay;

        emit OwnershipTransferred(address(0), msg.sender);
        emit DistributorUpdated(_distributor);
        emit RewardRateUpdated(_initialRatePerDay);
    }

    function _updateRewardPoints(address _user) internal {
        uint256 last = lastUpdateTime[_user];
        if (last < block.timestamp) {
            uint256 timeElapsed = block.timestamp - last;
            if (userDeposits[_user] > 0) {
                uint256 points = (userDeposits[_user] * timeElapsed * rewardRatePerDay) /
                    (SECONDS_PER_DAY * TOKEN_UNITS_PER_POINT);
                userAccruedPoints[_user] += points;
            }
        }
        lastUpdateTime[_user] = block.timestamp;
    }

    function deposit(uint256 amount) external {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();

        _updateRewardPoints(msg.sender);

        userDeposits[msg.sender] += amount;

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount < 1) revert InsufficientDeposit();
        if (userDeposits[msg.sender] < amount) revert InsufficientBalance();

        _updateRewardPoints(msg.sender);

        userDeposits[msg.sender] -= amount;

        bool success = stakingToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Withdraw(msg.sender, amount);
    }

    function claimRewardPoints() external {
        _updateRewardPoints(msg.sender);

        uint256 points = userAccruedPoints[msg.sender];
        if (points < 1) revert NoPointsToClaim();

        userAccruedPoints[msg.sender] = 0;

        IGovernanceDistributor(distributor).distribute(msg.sender, points);

        emit RewardPointsClaimed(msg.sender, points);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        if (newRate < 1) revert InvalidRate();
        rewardRatePerDay = newRate;
        emit RewardRateUpdated(newRate);
    }

    function setDistributor(address newDistributor) external onlyOwner {
        if (newDistributor == address(0)) revert ZeroAddress();
        distributor = newDistributor;
        emit DistributorUpdated(newDistributor);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function pendingRewardPoints(address user) external view returns (uint256) {
        uint256 last = lastUpdateTime[user];
        if (last > 0 && last < block.timestamp && userDeposits[user] > 0) {
            uint256 timeElapsed = block.timestamp - last;
            uint256 points = (userDeposits[user] * timeElapsed * rewardRatePerDay) /
                (SECONDS_PER_DAY * TOKEN_UNITS_PER_POINT);
            return userAccruedPoints[user] + points;
        }
        return userAccruedPoints[user];
    }
}
