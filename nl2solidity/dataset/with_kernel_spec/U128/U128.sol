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

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(token.approve(spender, value), "SafeERC20: approve failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;
    constructor() {
        _status = NOT_ENTERED;
    }
    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce for self");
        _revokeRole(role, account);
    }
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        if (role == DEFAULT_ADMIN_ROLE) {
            return DEFAULT_ADMIN_ROLE;
        }
        return DEFAULT_ADMIN_ROLE;
    }
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }
}

interface INFTPriceOracle {
    function getAppraisedValue(address collection, uint256 tokenId) external view returns (uint256);
}

contract NFTVault is AccessControl, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant PERCENT_DENOMINATOR = 100;

    IERC20 public immutable loanToken;

    INFTPriceOracle public oracle;
    uint256 public maxLTV;
    uint256 public interestRate;

    struct LoanPosition {
        address owner;
        uint256 principal;
        uint256 accruedInterest;
        uint256 lastInterestTimestamp;
        bool active;
    }

    mapping(address => mapping(uint256 => LoanPosition)) public loans;
    mapping(address => mapping(uint256 => bool)) public isDeposited;
    mapping(address => uint256) public depositCount;
    uint256 public totalOutstandingDebt;

    event NFTDeposited(address indexed collection, uint256 indexed tokenId, address indexed depositor, uint256 appraisedValue);
    event LoanBorrowed(address indexed collection, uint256 indexed tokenId, address indexed borrower, uint256 amount, uint256 totalPrincipal);
    event LoanRepaid(address indexed collection, uint256 indexed tokenId, address indexed repayer, uint256 principalRepaid, uint256 interestRepaid);
    event NFTWithdrawn(address indexed collection, uint256 indexed tokenId, address indexed owner);
    event NFTLiquidated(address indexed collection, uint256 indexed tokenId, address indexed borrower, address liquidator, uint256 debtRepaid);
    event ParametersUpdated(uint256 oldMaxLTV, uint256 newMaxLTV, uint256 oldInterestRate, uint256 newInterestRate);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event PoolFunded(address indexed funder, uint256 amount);
    event PoolWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error NotNFTOwner();
    error NFTAlreadyDeposited();
    error NFTNotDeposited();
    error LoanNotFullyRepaid();
    error ExceedsMaxBorrow(uint256 totalDebtAfter, uint256 maxBorrow);
    error InsufficientPoolLiquidity();
    error NothingToRepay();
    error NotAuthorized();
    error LiquidationNotEligible();
    error InvalidParameter();
    error RepayExceedsDebt();

    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAuthorized();
        _;
    }

    constructor(
        address loanToken_,
        address oracle_,
        uint256 maxLTV_,
        uint256 interestRate_
    ) {
        if (loanToken_ == address(0) || oracle_ == address(0)) revert ZeroAddress();
        if (maxLTV_ == 0 || maxLTV_ > 100) revert InvalidParameter();
        if (interestRate_ == 0) revert InvalidParameter();

        loanToken = IERC20(loanToken_);
        oracle = INFTPriceOracle(oracle_);
        maxLTV = maxLTV_;
        interestRate = interestRate_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function depositNFT(address collection, uint256 tokenId) external nonReentrant {
        if (collection == address(0)) revert ZeroAddress();
        if (IERC721(collection).ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
        if (isDeposited[collection][tokenId]) revert NFTAlreadyDeposited();

        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        if (appraisedValue == 0) revert InvalidParameter();

        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        isDeposited[collection][tokenId] = true;
        depositCount[collection] += 1;
        loans[collection][tokenId] = LoanPosition({
            owner: msg.sender,
            principal: 0,
            accruedInterest: 0,
            lastInterestTimestamp: block.timestamp,
            active: true
        });

        emit NFTDeposited(collection, tokenId, msg.sender, appraisedValue);
    }

    function borrow(address collection, uint256 tokenId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        LoanPosition storage loan = loans[collection][tokenId];
        if (!loan.active) revert NFTNotDeposited();
        if (loan.owner != msg.sender) revert NotNFTOwner();

        _accrueInterest(loan);

        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        if (appraisedValue == 0) revert InvalidParameter();
        uint256 maxBorrow = (appraisedValue * maxLTV) / PERCENT_DENOMINATOR;
        uint256 totalDebtAfter = loan.principal + loan.accruedInterest + amount;
        if (totalDebtAfter > maxBorrow) revert ExceedsMaxBorrow(totalDebtAfter, maxBorrow);

        if (loanToken.balanceOf(address(this)) < amount) revert InsufficientPoolLiquidity();

        loan.principal += amount;
        totalOutstandingDebt += amount;

        loanToken.safeTransfer(msg.sender, amount);

        emit LoanBorrowed(collection, tokenId, msg.sender, amount, loan.principal);
    }

    function repay(address collection, uint256 tokenId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        LoanPosition storage loan = loans[collection][tokenId];
        if (!loan.active) revert NFTNotDeposited();

        _accrueInterest(loan);

        uint256 totalDebt = loan.principal + loan.accruedInterest;
        if (totalDebt == 0) revert NothingToRepay();
        if (amount > totalDebt) revert RepayExceedsDebt();

        uint256 repayAmount = amount;
        uint256 interestPart = repayAmount > loan.accruedInterest ? loan.accruedInterest : repayAmount;
        uint256 principalPart = repayAmount - interestPart;

        loanToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        loan.accruedInterest -= interestPart;
        loan.principal -= principalPart;
        totalOutstandingDebt -= principalPart;

        emit LoanRepaid(collection, tokenId, msg.sender, principalPart, interestPart);
    }

    function withdrawNFT(address collection, uint256 tokenId) external nonReentrant {
        LoanPosition storage loan = loans[collection][tokenId];
        if (!loan.active) revert NFTNotDeposited();
        if (loan.owner != msg.sender) revert NotNFTOwner();

        _accrueInterest(loan);

        if (loan.principal > 0 || loan.accruedInterest > 0) revert LoanNotFullyRepaid();

        isDeposited[collection][tokenId] = false;
        depositCount[collection] -= 1;
        loan.active = false;
        loan.owner = address(0);

        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTWithdrawn(collection, tokenId, msg.sender);
    }

    function liquidate(address collection, uint256 tokenId) external onlyAdmin nonReentrant {
        LoanPosition storage loan = loans[collection][tokenId];
        if (!loan.active) revert NFTNotDeposited();

        _accrueInterest(loan);

        uint256 totalDebt = loan.principal + loan.accruedInterest;
        if (totalDebt == 0) revert LiquidationNotEligible();

        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        if (appraisedValue == 0) revert InvalidParameter();
        uint256 maxBorrow = (appraisedValue * maxLTV) / PERCENT_DENOMINATOR;
        if (totalDebt <= maxBorrow) revert LiquidationNotEligible();

        address borrower = loan.owner;

        loanToken.safeTransferFrom(msg.sender, address(this), totalDebt);

        totalOutstandingDebt -= loan.principal;
        isDeposited[collection][tokenId] = false;
        depositCount[collection] -= 1;
        loan.active = false;
        loan.principal = 0;
        loan.accruedInterest = 0;
        loan.lastInterestTimestamp = block.timestamp;
        loan.owner = address(0);

        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTLiquidated(collection, tokenId, borrower, msg.sender, totalDebt);
    }

    function setParameters(uint256 newMaxLTV, uint256 newInterestRate) external onlyAdmin {
        if (newMaxLTV == 0 || newMaxLTV > 100) revert InvalidParameter();
        if (newInterestRate == 0) revert InvalidParameter();

        uint256 oldMaxLTV = maxLTV;
        uint256 oldInterestRate = interestRate;
        maxLTV = newMaxLTV;
        interestRate = newInterestRate;

        emit ParametersUpdated(oldMaxLTV, newMaxLTV, oldInterestRate, newInterestRate);
    }

    function setOracle(address newOracle) external onlyAdmin {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = INFTPriceOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    function fundPool(uint256 amount) external onlyAdmin {
        if (amount == 0) revert ZeroAmount();
        loanToken.safeTransferFrom(msg.sender, address(this), amount);
        emit PoolFunded(msg.sender, amount);
    }

    function withdrawExcess(uint256 amount) external onlyAdmin {
        if (amount == 0) revert ZeroAmount();
        if (loanToken.balanceOf(address(this)) < totalOutstandingDebt + amount) revert InsufficientPoolLiquidity();
        loanToken.safeTransfer(msg.sender, amount);
        emit PoolWithdrawn(msg.sender, amount);
    }

    function getDebt(address collection, uint256 tokenId) public view returns (uint256) {
        LoanPosition storage loan = loans[collection][tokenId];
        if (!loan.active) return 0;
        if (loan.principal == 0) return loan.accruedInterest;
        uint256 elapsed = block.timestamp - loan.lastInterestTimestamp;
        uint256 pendingInterest = (loan.principal * interestRate * elapsed) / (PERCENT_DENOMINATOR * SECONDS_PER_YEAR);
        return loan.principal + loan.accruedInterest + pendingInterest;
    }

    function getMaxBorrow(address collection, uint256 tokenId) public view returns (uint256) {
        if (!isDeposited[collection][tokenId]) return 0;
        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        return (appraisedValue * maxLTV) / PERCENT_DENOMINATOR;
    }

    function getAppraisedValue(address collection, uint256 tokenId) external view returns (uint256) {
        return oracle.getAppraisedValue(collection, tokenId);
    }

    function getLTV(address collection, uint256 tokenId) external view returns (uint256) {
        if (!isDeposited[collection][tokenId]) return 0;
        uint256 debt = getDebt(collection, tokenId);
        if (debt == 0) return 0;
        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        if (appraisedValue == 0) return 0;
        return (debt * PERCENT_DENOMINATOR) / appraisedValue;
    }

    function isLiquidatable(address collection, uint256 tokenId) external view returns (bool) {
        if (!isDeposited[collection][tokenId]) return false;
        uint256 debt = getDebt(collection, tokenId);
        if (debt == 0) return false;
        uint256 appraisedValue = oracle.getAppraisedValue(collection, tokenId);
        if (appraisedValue == 0) return false;
        uint256 maxBorrow = (appraisedValue * maxLTV) / PERCENT_DENOMINATOR;
        return debt > maxBorrow;
    }

    function getLoanPosition(address collection, uint256 tokenId)
        external
        view
        returns (address owner, uint256 principal, uint256 accruedInterest, uint256 lastInterestTimestamp, bool active)
    {
        LoanPosition storage loan = loans[collection][tokenId];
        return (loan.owner, loan.principal, loan.accruedInterest, loan.lastInterestTimestamp, loan.active);
    }

    function _accrueInterest(LoanPosition storage loan) internal {
        if (loan.principal == 0) {
            loan.lastInterestTimestamp = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - loan.lastInterestTimestamp;
        if (elapsed == 0) return;
        uint256 interest = (loan.principal * interestRate * elapsed) / (PERCENT_DENOMINATOR * SECONDS_PER_YEAR);
        loan.accruedInterest += interest;
        loan.lastInterestTimestamp = block.timestamp;
    }
}
