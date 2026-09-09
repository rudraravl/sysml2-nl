// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

library SafeTransfer {
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeTransfer: transfer failed"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeTransfer: transferFrom failed"
        );
    }
}

contract TokenSaleAllocation {
    uint256 public constant MAX_CONTRIBUTION_PER_PARTICIPANT = 1000 ether;

    address public operator;
    address public pendingOperator;

    struct Sale {
        address project;
        address contributionToken;
        address saleToken;
        uint256 totalTokensOffered;
        uint256 minimumReputationScore;
        uint256 startTime;
        uint256 endTime;
        uint256 totalContributed;
        uint256 totalAllocatedTokens;
        bool concluded;
        bool exists;
    }

    struct ParticipantInfo {
        uint256 contributed;
        uint256 allocated;
        bool claimed;
        bool excessWithdrawn;
    }

    mapping(uint256 => Sale) public sales;
    mapping(uint256 => mapping(address => ParticipantInfo)) public participants;
    uint256 public nextSaleId = 1;

    event SaleCreated(
        uint256 indexed saleId,
        address indexed project,
        address contributionToken,
        address saleToken,
        uint256 totalTokensOffered,
        uint256 minimumReputationScore,
        uint256 startTime,
        uint256 endTime
    );
    event ContributionMade(uint256 indexed saleId, address indexed participant, uint256 amount);
    event AllocationSet(uint256 indexed saleId, address indexed participant, uint256 amount);
    event SaleConcluded(uint256 indexed saleId, uint256 endTime);
    event TokensClaimed(uint256 indexed saleId, address indexed participant, uint256 amount);
    event ExcessWithdrawn(uint256 indexed saleId, address indexed participant, uint256 amount);
    event FundsWithdrawn(uint256 indexed saleId, address indexed project, uint256 amount);
    event OperatorProposed(address indexed previousOperator, address indexed newOperator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error NotPendingOperator();
    error SaleDoesNotExist();
    error SaleNotActive();
    error SaleAlreadyConcluded();
    error SaleNotConcluded();
    error ZeroAddress();
    error InvalidParameters();
    error ContributionExceedsMax();
    error AllocationExceedsOffered();
    error NoAllocation();
    error AlreadyClaimed();
    error AlreadyExcessWithdrawn();
    error NoExcess();
    error NothingToWithdraw();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier saleExists(uint256 saleId) {
        if (!sales[saleId].exists) revert SaleDoesNotExist();
        _;
    }

    constructor() {
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    function proposeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorProposed(operator, newOperator);
        pendingOperator = newOperator;
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();
        emit OperatorChanged(operator, msg.sender);
        operator = msg.sender;
        pendingOperator = address(0);
    }

    function startSale(
        address project,
        address contributionToken,
        address saleToken,
        uint256 totalTokensOffered,
        uint256 minimumReputationScore,
        uint256 startTime,
        uint256 endTime
    ) external onlyOperator returns (uint256 saleId) {
        if (project == address(0) || contributionToken == address(0) || saleToken == address(0)) revert ZeroAddress();
        if (totalTokensOffered == 0) revert InvalidParameters();
        if (startTime >= endTime) revert InvalidParameters();
        if (block.timestamp > startTime) revert InvalidParameters();

        saleId = nextSaleId++;
        Sale storage sale = sales[saleId];
        sale.project = project;
        sale.contributionToken = contributionToken;
        sale.saleToken = saleToken;
        sale.totalTokensOffered = totalTokensOffered;
        sale.minimumReputationScore = minimumReputationScore;
        sale.startTime = startTime;
        sale.endTime = endTime;
        sale.exists = true;

        emit SaleCreated(
            saleId,
            project,
            contributionToken,
            saleToken,
            totalTokensOffered,
            minimumReputationScore,
            startTime,
            endTime
        );
    }

    function endSale(uint256 saleId) external onlyOperator saleExists(saleId) {
        Sale storage sale = sales[saleId];
        if (sale.concluded) revert SaleAlreadyConcluded();
        sale.concluded = true;
        sale.endTime = block.timestamp;
        emit SaleConcluded(saleId, block.timestamp);
    }

    function setAllocation(
        uint256 saleId,
        address participant,
        uint256 amount
    ) external onlyOperator saleExists(saleId) {
        if (participant == address(0)) revert ZeroAddress();
        Sale storage sale = sales[saleId];
        if (sale.concluded) revert SaleNotActive();

        ParticipantInfo storage info = participants[saleId][participant];
        uint256 oldAllocated = info.allocated;
        uint256 newTotalAllocated = sale.totalAllocatedTokens - oldAllocated + amount;
        if (newTotalAllocated > sale.totalTokensOffered) revert AllocationExceedsOffered();

        sale.totalAllocatedTokens = newTotalAllocated;
        info.allocated = amount;
        emit AllocationSet(saleId, participant, amount);
    }

    function contribute(uint256 saleId, uint256 amount) external saleExists(saleId) {
        Sale storage sale = sales[saleId];
        if (sale.concluded) revert SaleNotActive();
        if (block.timestamp < sale.startTime || block.timestamp >= sale.endTime) revert SaleNotActive();
        if (amount == 0) revert InvalidParameters();

        ParticipantInfo storage info = participants[saleId][msg.sender];
        uint256 newContributed = info.contributed + amount;
        if (newContributed > MAX_CONTRIBUTION_PER_PARTICIPANT) revert ContributionExceedsMax();

        info.contributed = newContributed;
        sale.totalContributed += amount;

        SafeTransfer.safeTransferFrom(sale.contributionToken, msg.sender, address(this), amount);
        emit ContributionMade(saleId, msg.sender, amount);
    }

    function claimTokens(uint256 saleId) external saleExists(saleId) {
        Sale storage sale = sales[saleId];
        if (!sale.concluded) revert SaleNotConcluded();

        ParticipantInfo storage info = participants[saleId][msg.sender];
        if (info.allocated == 0) revert NoAllocation();
        if (info.claimed) revert AlreadyClaimed();

        uint256 allocation = info.allocated;
        info.claimed = true;

        SafeTransfer.safeTransfer(sale.saleToken, msg.sender, allocation);
        emit TokensClaimed(saleId, msg.sender, allocation);
    }

    function withdrawExcess(uint256 saleId) external saleExists(saleId) {
        Sale storage sale = sales[saleId];
        if (!sale.concluded) revert SaleNotConcluded();

        ParticipantInfo storage info = participants[saleId][msg.sender];
        if (info.excessWithdrawn) revert AlreadyExcessWithdrawn();

        uint256 excess = info.contributed > info.allocated
            ? info.contributed - info.allocated
            : 0;
        if (excess == 0) revert NoExcess();

        info.excessWithdrawn = true;
        sale.totalContributed -= excess;

        SafeTransfer.safeTransfer(sale.contributionToken, msg.sender, excess);
        emit ExcessWithdrawn(saleId, msg.sender, excess);
    }

    function withdrawFunds(uint256 saleId) external onlyOperator saleExists(saleId) {
        Sale storage sale = sales[saleId];
        if (!sale.concluded) revert SaleNotConcluded();

        uint256 amount = sale.totalContributed;
        if (amount == 0) revert NothingToWithdraw();

        sale.totalContributed = 0;

        SafeTransfer.safeTransfer(sale.contributionToken, sale.project, amount);
        emit FundsWithdrawn(saleId, sale.project, amount);
    }

    function getSale(uint256 saleId)
        external
        view
        saleExists(saleId)
        returns (
            address project,
            address contributionToken,
            address saleToken,
            uint256 totalTokensOffered,
            uint256 minimumReputationScore,
            uint256 startTime,
            uint256 endTime,
            uint256 totalContributed,
            uint256 totalAllocatedTokens,
            bool concluded
        )
    {
        Sale storage sale = sales[saleId];
        return (
            sale.project,
            sale.contributionToken,
            sale.saleToken,
            sale.totalTokensOffered,
            sale.minimumReputationScore,
            sale.startTime,
            sale.endTime,
            sale.totalContributed,
            sale.totalAllocatedTokens,
            sale.concluded
        );
    }

    function getParticipant(uint256 saleId, address account)
        external
        view
        saleExists(saleId)
        returns (
            uint256 contributed,
            uint256 allocated,
            bool claimed,
            bool excessWithdrawn
        )
    {
        ParticipantInfo storage info = participants[saleId][account];
        return (info.contributed, info.allocated, info.claimed, info.excessWithdrawn);
    }

    function saleContributionTokenBalance(uint256 saleId)
        external
        view
        saleExists(saleId)
        returns (uint256)
    {
        return IERC20(sales[saleId].contributionToken).balanceOf(address(this));
    }

    function saleTokenBalance(uint256 saleId)
        external
        view
        saleExists(saleId)
        returns (uint256)
    {
        return IERC20(sales[saleId].saleToken).balanceOf(address(this));
    }
}
