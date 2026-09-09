// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StrategicGame {
    IERC20 public immutable token;
    address public operator;
    address public treasury;
    uint256 public currentEpoch;

    uint256 public constant MIN_STAKE = 100;
    uint256 public constant WITHDRAW_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    mapping(uint256 => mapping(address => uint256)) public playerStake;
    mapping(uint256 => uint256) public countryVault;
    mapping(uint256 => bool) public countryActive;
    mapping(uint256 => bool) public countryEliminated;
    mapping(uint256 => mapping(uint256 => bool)) public alliances;

    event Staked(address indexed player, uint256 indexed countryId, uint256 amount);
    event StakeTransferred(address indexed player, uint256 indexed fromCountry, uint256 indexed toCountry, uint256 amount);
    event Withdrawn(address indexed player, uint256 indexed countryId, uint256 amount, uint256 fee);
    event CountryEliminated(uint256 indexed countryId, uint256 indexed epoch, uint256[] conquerors, uint256[] shares);
    event EpochStarted(uint256 epoch);
    event CountryAdded(uint256 countryId);
    event AllianceUpdated(uint256 countryA, uint256 countryB, bool allied);
    event OperatorUpdated(address previousOperator, address newOperator);
    event TreasuryUpdated(address previousTreasury, address newTreasury);

    error NotOperator();
    error ZeroAddress();
    error CountryNotActive();
    error CountryEliminatedError();
    error InsufficientStake();
    error NotAllied();
    error InsufficientBalance();
    error InvalidShares();
    error InvalidConqueror();
    error TransferFailed();
    error SameCountry();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _token, address _treasury) {
        if (_token == address(0) || _treasury == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        treasury = _treasury;
        operator = msg.sender;
        currentEpoch = 1;
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function addCountry(uint256 countryId) external onlyOperator {
        if (countryActive[countryId]) revert CountryNotActive();
        countryActive[countryId] = true;
        emit CountryAdded(countryId);
    }

    function setAlliance(uint256 countryA, uint256 countryB, bool allied) external onlyOperator {
        if (countryA == countryB) revert SameCountry();
        if (!countryActive[countryA] || !countryActive[countryB]) revert CountryNotActive();
        alliances[countryA][countryB] = allied;
        alliances[countryB][countryA] = allied;
        emit AllianceUpdated(countryA, countryB, allied);
    }

    function stake(uint256 countryId, uint256 amount) external {
        if (!countryActive[countryId] || countryEliminated[countryId]) revert CountryNotActive();
        if (amount < MIN_STAKE) revert InsufficientStake();

        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        playerStake[countryId][msg.sender] += amount;
        countryVault[countryId] += amount;

        emit Staked(msg.sender, countryId, amount);
    }

    function transferStake(uint256 fromCountry, uint256 toCountry, uint256 amount) external {
        if (!countryActive[fromCountry] || !countryActive[toCountry] || countryEliminated[fromCountry] || countryEliminated[toCountry]) revert CountryNotActive();
        if (fromCountry == toCountry) revert SameCountry();
        if (!alliances[fromCountry][toCountry]) revert NotAllied();
        if (amount == 0 || playerStake[fromCountry][msg.sender] < amount) revert InsufficientBalance();

        playerStake[fromCountry][msg.sender] -= amount;
        playerStake[toCountry][msg.sender] += amount;
        countryVault[fromCountry] -= amount;
        countryVault[toCountry] += amount;

        emit StakeTransferred(msg.sender, fromCountry, toCountry, amount);
    }

    function withdraw(uint256 countryId, uint256 amount) external {
        if (!countryActive[countryId] || countryEliminated[countryId]) revert CountryNotActive();
        if (amount == 0 || playerStake[countryId][msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        playerStake[countryId][msg.sender] -= amount;
        countryVault[countryId] -= amount;

        if (!token.transfer(msg.sender, netAmount)) revert TransferFailed();
        if (fee > 0) {
            if (!token.transfer(treasury, fee)) revert TransferFailed();
        }

        emit Withdrawn(msg.sender, countryId, amount, fee);
    }

    function startNewEpoch() external onlyOperator {
        currentEpoch++;
        emit EpochStarted(currentEpoch);
    }

    function eliminateCountry(uint256 countryId, uint256[] calldata conquerors, uint256[] calldata shares) external onlyOperator {
        if (!countryActive[countryId] || countryEliminated[countryId]) revert CountryNotActive();
        if (conquerors.length != shares.length) revert InvalidShares();

        uint256 vaultBalance = countryVault[countryId];
        uint256 totalShares = 0;
        for (uint256 i = 0; i < conquerors.length; i++) {
            if (!countryActive[conquerors[i]] || countryEliminated[conquerors[i]]) revert InvalidConqueror();
            totalShares += shares[i];
        }
        if (totalShares > vaultBalance) revert InvalidShares();

        countryEliminated[countryId] = true;
        countryActive[countryId] = false;
        countryVault[countryId] = 0;

        for (uint256 i = 0; i < conquerors.length; i++) {
            countryVault[conquerors[i]] += shares[i];
        }

        uint256 treasuryShare = vaultBalance - totalShares;
        if (treasuryShare > 0) {
            if (!token.transfer(treasury, treasuryShare)) revert TransferFailed();
        }

        emit CountryEliminated(countryId, currentEpoch, conquerors, shares);
    }
}
