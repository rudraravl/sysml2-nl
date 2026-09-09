// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SocialImpactFund {
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error DepositsPaused();
    error MinimumDepositRequired(uint256 minimum);
    error ProjectAlreadyApproved();
    error ProjectNotApproved();
    error InvalidFundingCap();
    error FundingCapExceeded();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();

    event ProjectProposed(address indexed proposer, address indexed project);
    event ProjectApproved(address indexed project, uint256 fundingCap);
    event FundingCapUpdated(address indexed project, uint256 oldCap, uint256 newCap);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event FundsClaimed(address indexed project, address indexed treasury, uint256 amount, uint256 fee);
    event DepositsPausedStateChanged(bool paused);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    uint256 public constant MINIMUM_DEPOSIT = 10 ether;
    uint256 public constant FEE_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable baseToken;
    address public owner;
    address public treasury;
    uint256 public totalDeposits;
    uint256 public fundBalance;
    bool public depositsPaused;
    uint256 private _locked = 1;

    struct Project {
        bool approved;
        uint256 fundingCap;
        uint256 totalClaimed;
    }

    mapping(address => uint256) public userDeposits;
    mapping(address => Project) internal _projects;
    address[] internal _proposedProjects;
    mapping(address => bool) internal _isProposed;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _baseToken, address _treasury)
        notZeroAddress(_baseToken)
        notZeroAddress(_treasury)
    {
        baseToken = IERC20(_baseToken);
        treasury = _treasury;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (depositsPaused) revert DepositsPaused();
        if (amount < MINIMUM_DEPOSIT) revert MinimumDepositRequired(MINIMUM_DEPOSIT);

        userDeposits[msg.sender] += amount;
        totalDeposits += amount;
        fundBalance += amount;

        bool success = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit FundsDeposited(msg.sender, amount);
    }

    function proposeProject(address project)
        external
        notZeroAddress(project)
    {
        if (_projects[project].approved) revert ProjectAlreadyApproved();
        if (!_isProposed[project]) {
            _isProposed[project] = true;
            _proposedProjects.push(project);
        }
        emit ProjectProposed(msg.sender, project);
    }

    function approveProject(address project, uint256 fundingCap)
        external
        onlyOwner
        notZeroAddress(project)
    {
        if (fundingCap == 0) revert InvalidFundingCap();
        if (_projects[project].approved) revert ProjectAlreadyApproved();

        _projects[project] = Project({
            approved: true,
            fundingCap: fundingCap,
            totalClaimed: 0
        });

        emit ProjectApproved(project, fundingCap);
    }

    function setFundingCap(address project, uint256 newCap)
        external
        onlyOwner
        notZeroAddress(project)
    {
        Project storage p = _projects[project];
        if (!p.approved) revert ProjectNotApproved();
        if (newCap < p.totalClaimed) revert InvalidFundingCap();

        uint256 oldCap = p.fundingCap;
        p.fundingCap = newCap;

        emit FundingCapUpdated(project, oldCap, newCap);
    }

    function claimFunds(uint256 amount) external nonReentrant {
        Project storage p = _projects[msg.sender];
        if (!p.approved) revert ProjectNotApproved();
        if (amount == 0) revert ZeroAmount();

        uint256 remainingCap = p.fundingCap - p.totalClaimed;
        if (amount > remainingCap) revert FundingCapExceeded();
        if (amount > fundBalance) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        p.totalClaimed += amount;
        fundBalance -= amount;

        bool success = baseToken.transfer(msg.sender, payout);
        if (!success) revert TransferFailed();

        if (fee > 0) {
            bool feeSuccess = baseToken.transfer(treasury, fee);
            if (!feeSuccess) revert TransferFailed();
        }

        emit FundsClaimed(msg.sender, treasury, amount, fee);
    }

    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPausedStateChanged(paused);
    }

    function setTreasury(address newTreasury)
        external
        onlyOwner
        notZeroAddress(newTreasury)
    {
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
        notZeroAddress(newOwner)
    {
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function getProject(address project)
        external
        view
        returns (
            bool approved,
            uint256 fundingCap,
            uint256 totalClaimed,
            uint256 remainingCap
        )
    {
        Project storage p = _projects[project];
        approved = p.approved;
        fundingCap = p.fundingCap;
        totalClaimed = p.totalClaimed;
        remainingCap = p.approved ? p.fundingCap - p.totalClaimed : 0;
    }

    function isProjectApproved(address project) external view returns (bool) {
        return _projects[project].approved;
    }

    function isProjectProposed(address project) external view returns (bool) {
        return _isProposed[project];
    }

    function proposedProjectsCount() external view returns (uint256) {
        return _proposedProjects.length;
    }

    function proposedProjectAt(uint256 index) external view returns (address) {
        return _proposedProjects[index];
    }
}
