// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract TokenLaunchpad {
    address public operator;

    uint256 public constant FEE_RATE = 200;          // 2% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_COMMIT = 1000;       // max base units per participant per project

    struct Project {
        address token;            // project token being distributed
        address depositToken;     // token participants deposit to commit
        uint256 pricePerToken;    // depositToken units required per project token base unit
        uint256 totalAllocation;  // total project tokens available
        uint256 committedTotal;   // total project tokens committed
        bool finalized;           // whether the launch has been finalized
        bool active;              // whether the project accepts deposits/commits
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    // participant deposits (depositToken) per project
    mapping(uint256 => mapping(address => uint256)) public deposits;
    // deposits locked by commitments per project per participant
    mapping(uint256 => mapping(address => uint256)) public lockedDeposits;
    // participant commitments (project token base units) per project
    mapping(uint256 => mapping(address => uint256)) public commitments;
    // whether a participant has claimed for a project
    mapping(uint256 => mapping(address => bool)) public claimed;
    // total locked deposits per project (depositToken)
    mapping(uint256 => uint256) public totalLockedDeposits;
    // total fees collected per project (project token)
    mapping(uint256 => uint256) public totalFeesCollected;

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed token,
        address indexed depositToken,
        uint256 totalAllocation,
        uint256 pricePerToken
    );
    event ProjectParamsSet(uint256 indexed projectId, uint256 pricePerToken, uint256 totalAllocation);
    event ProjectFinalized(uint256 indexed projectId);
    event ProjectDeactivated(uint256 indexed projectId);
    event Deposited(uint256 indexed projectId, address indexed participant, uint256 amount);
    event Committed(uint256 indexed projectId, address indexed participant, uint256 amount);
    event Claimed(uint256 indexed projectId, address indexed participant, uint256 tokenAmount, uint256 feeAmount);
    event Withdrawn(uint256 indexed projectId, address indexed participant, uint256 amount);
    event LockedDepositsSwept(uint256 indexed projectId, address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error ProjectNotFound();
    error ProjectNotActive();
    error ProjectAlreadyFinalized();
    error ProjectNotFinalized();
    error AlreadyClaimed();
    error ExceedsMaxCommit();
    error InsufficientDeposit();
    error InsufficientAllocation();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error NothingToSweep();
    error AmountExceedsAvailable();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier projectExists(uint256 projectId) {
        if (projects[projectId].token == address(0)) revert ProjectNotFound();
        _;
    }

    constructor() {
        operator = msg.sender;
    }

    function createProject(
        address token,
        address depositToken,
        uint256 totalAllocation,
        uint256 pricePerToken
    ) external onlyOperator returns (uint256 projectId) {
        if (token == address(0) || depositToken == address(0)) revert ZeroAddress();
        if (totalAllocation == 0) revert ZeroAmount();

        projectId = projectCount++;
        projects[projectId] = Project({
            token: token,
            depositToken: depositToken,
            pricePerToken: pricePerToken,
            totalAllocation: totalAllocation,
            committedTotal: 0,
            finalized: false,
            active: true
        });

        _safeTransferFrom(token, msg.sender, address(this), totalAllocation);

        emit ProjectCreated(projectId, token, depositToken, totalAllocation, pricePerToken);
    }

    function setProjectParams(
        uint256 projectId,
        uint256 pricePerToken,
        uint256 totalAllocation
    ) external onlyOperator projectExists(projectId) {
        Project storage p = projects[projectId];
        if (p.finalized) revert ProjectAlreadyFinalized();

        p.pricePerToken = pricePerToken;

        if (totalAllocation > p.totalAllocation) {
            uint256 diff = totalAllocation - p.totalAllocation;
            p.totalAllocation = totalAllocation;
            _safeTransferFrom(p.token, msg.sender, address(this), diff);
        } else {
            p.totalAllocation = totalAllocation;
        }

        emit ProjectParamsSet(projectId, pricePerToken, p.totalAllocation);
    }

    function deactivateProject(uint256 projectId) external onlyOperator projectExists(projectId) {
        Project storage p = projects[projectId];
        if (p.finalized) revert ProjectAlreadyFinalized();
        if (!p.active) revert ProjectNotActive();
        p.active = false;
        emit ProjectDeactivated(projectId);
    }

    function finalizeProject(uint256 projectId) external onlyOperator projectExists(projectId) {
        Project storage p = projects[projectId];
        if (p.finalized) revert ProjectAlreadyFinalized();
        if (!p.active) revert ProjectNotActive();
        p.finalized = true;
        p.active = false;
        emit ProjectFinalized(projectId);
    }

    function deposit(uint256 projectId, uint256 amount) external projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.active) revert ProjectNotActive();
        if (p.finalized) revert ProjectAlreadyFinalized();
        if (amount == 0) revert ZeroAmount();

        deposits[projectId][msg.sender] += amount;
        _safeTransferFrom(p.depositToken, msg.sender, address(this), amount);

        emit Deposited(projectId, msg.sender, amount);
    }

    function commit(uint256 projectId, uint256 amount) external projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.active) revert ProjectNotActive();
        if (p.finalized) revert ProjectAlreadyFinalized();
        if (amount == 0) revert ZeroAmount();

        uint256 newCommit = commitments[projectId][msg.sender] + amount;
        if (newCommit > MAX_COMMIT) revert ExceedsMaxCommit();
        if (p.committedTotal + amount > p.totalAllocation) revert InsufficientAllocation();

        uint256 depositNeeded = amount * p.pricePerToken;
        uint256 available = deposits[projectId][msg.sender] - lockedDeposits[projectId][msg.sender];
        if (available < depositNeeded) revert InsufficientDeposit();

        lockedDeposits[projectId][msg.sender] += depositNeeded;
        totalLockedDeposits[projectId] += depositNeeded;
        commitments[projectId][msg.sender] = newCommit;
        p.committedTotal += amount;

        emit Committed(projectId, msg.sender, amount);
    }

    function claim(uint256 projectId) external projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.finalized) revert ProjectNotFinalized();
        if (claimed[projectId][msg.sender]) revert AlreadyClaimed();

        uint256 commitAmt = commitments[projectId][msg.sender];
        if (commitAmt == 0) revert ZeroAmount();

        claimed[projectId][msg.sender] = true;

        uint256 fee = (commitAmt * FEE_RATE) / BASIS_POINTS;
        uint256 payout = commitAmt - fee;

        if (fee > 0) {
            totalFeesCollected[projectId] += fee;
            _safeTransfer(p.token, operator, fee);
        }
        if (payout > 0) {
            _safeTransfer(p.token, msg.sender, payout);
        }

        emit Claimed(projectId, msg.sender, payout, fee);
    }

    function withdraw(uint256 projectId, uint256 amount) external projectExists(projectId) {
        if (amount == 0) revert ZeroAmount();

        uint256 available = deposits[projectId][msg.sender] - lockedDeposits[projectId][msg.sender];
        if (available < amount) revert AmountExceedsAvailable();

        deposits[projectId][msg.sender] -= amount;

        Project storage p = projects[projectId];
        _safeTransfer(p.depositToken, msg.sender, amount);

        emit Withdrawn(projectId, msg.sender, amount);
    }

    function sweepLockedDeposits(uint256 projectId, address recipient)
        external
        onlyOperator
        projectExists(projectId)
    {
        Project storage p = projects[projectId];
        if (!p.finalized) revert ProjectNotFinalized();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 amount = totalLockedDeposits[projectId];
        if (amount == 0) revert NothingToSweep();

        totalLockedDeposits[projectId] = 0;
        _safeTransfer(p.depositToken, recipient, amount);

        emit LockedDepositsSwept(projectId, recipient, amount);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function getProject(uint256 projectId)
        external
        view
        projectExists(projectId)
        returns (
            address token,
            address depositToken,
            uint256 pricePerToken,
            uint256 totalAllocation,
            uint256 committedTotal,
            bool finalized,
            bool active
        )
    {
        Project storage p = projects[projectId];
        return (
            p.token,
            p.depositToken,
            p.pricePerToken,
            p.totalAllocation,
            p.committedTotal,
            p.finalized,
            p.active
        );
    }

    function availableDeposit(uint256 projectId, address participant)
        external
        view
        projectExists(projectId)
        returns (uint256)
    {
        return deposits[projectId][participant] - lockedDeposits[projectId][participant];
    }

    function pendingClaim(uint256 projectId, address participant)
        external
        view
        projectExists(projectId)
        returns (uint256 payout, uint256 fee)
    {
        uint256 commitAmt = commitments[projectId][participant];
        fee = (commitAmt * FEE_RATE) / BASIS_POINTS;
        payout = commitAmt - fee;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
