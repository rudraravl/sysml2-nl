// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
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
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, address indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(from == msg.sender, "SafeERC20: from != msg.sender");
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool success = token.approve(spender, amount);
        require(success, "SafeERC20: approve failed");
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

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPriceOracle {
    function getPrice(address collection, uint256 tokenId) external view returns (uint256);
}

contract CollectibleVault is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    error NotApprovedCollateral();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInterestRate();
    error InsufficientCollateral();
    error OutstandingDebt();
    error NotPositionOwner();
    error NothingToRepay();
    error NotTokenOwner();
    error CollateralAlreadyApproved();
    error TokenAlreadyDeposited();
    error InvalidTokenId();

    event CollateralDeposited(address indexed user, address indexed collection, uint256 indexed tokenId);
    event CollateralWithdrawn(address indexed user, address indexed collection, uint256 indexed tokenId);
    event LoanIssued(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount, bool fullyRepaid);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event CollateralTypeAdded(address indexed collection);
    event CollateralTypeRemoved(address indexed collection);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    uint256 public constant MAX_LTV = 50;
    uint256 public constant MAX_INTEREST_RATE = 1000;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    address public operator;
    IPriceOracle public oracle;
    IERC20 public immutable stablecoin;

    uint256 public interestRateBps;
    uint256 public totalDebt;

    struct CollateralItem {
        address collection;
        uint256 tokenId;
    }

    struct Position {
        uint256 principalDebt;
        uint256 accruedInterest;
        uint256 lastAccrualTime;
        uint256 interestRateAtBorrow;
        CollateralItem[] collateral;
        mapping(address => mapping(uint256 => bool)) deposited;
    }

    mapping(address => Position) public positions;

    mapping(address => bool) public approvedCollateral;
    address[] public approvedCollateralList;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address _stablecoin,
        address _oracle,
        address _operator,
        uint256 _initialInterestRateBps
    ) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialInterestRateBps > MAX_INTEREST_RATE) revert InvalidInterestRate();

        stablecoin = IERC20(_stablecoin);
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        interestRateBps = _initialInterestRateBps;

        emit InterestRateUpdated(0, _initialInterestRateBps);
        emit OperatorUpdated(address(0), _operator);
        emit OracleUpdated(address(0), _oracle);
    }

    function depositCollateral(address collection, uint256 tokenId) external nonReentrant {
        if (!approvedCollateral[collection]) revert NotApprovedCollateral();
        if (tokenId == 0) revert InvalidTokenId();

        Position storage pos = positions[msg.sender];
        if (pos.deposited[collection][tokenId]) revert TokenAlreadyDeposited();

        pos.deposited[collection][tokenId] = true;
        pos.collateral.push(CollateralItem({collection: collection, tokenId: tokenId}));

        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        emit CollateralDeposited(msg.sender, collection, tokenId);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        uint256 collateralValue = _getCollateralValue(msg.sender);
        uint256 maxBorrow = (collateralValue * MAX_LTV) / BASIS_POINTS;

        uint256 newDebt = pos.principalDebt + pos.accruedInterest + amount;
        if (newDebt > maxBorrow) revert InsufficientCollateral();

        if (pos.accruedInterest > 0) {
            pos.principalDebt += pos.accruedInterest;
            pos.accruedInterest = 0;
        }

        pos.principalDebt += amount;
        pos.lastAccrualTime = block.timestamp;
        pos.interestRateAtBorrow = interestRateBps;

        totalDebt += amount;

        stablecoin.safeTransfer(msg.sender, amount);

        emit LoanIssued(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        uint256 totalOwed = pos.principalDebt + pos.accruedInterest;
        if (totalOwed == 0) revert NothingToRepay();

        uint256 repayAmount = amount > totalOwed ? totalOwed : amount;

        if (repayAmount <= pos.accruedInterest) {
            pos.accruedInterest -= repayAmount;
        } else {
            uint256 remaining = repayAmount - pos.accruedInterest;
            pos.accruedInterest = 0;
            pos.principalDebt -= remaining;
        }

        totalDebt -= repayAmount;

        bool fullyRepaid = (pos.principalDebt == 0 && pos.accruedInterest == 0);
        if (fullyRepaid) {
            pos.lastAccrualTime = 0;
            pos.interestRateAtBorrow = 0;
        }

        stablecoin.safeTransferFrom(msg.sender, address(this), repayAmount);

        if (amount > repayAmount) {
            stablecoin.safeTransfer(msg.sender, amount - repayAmount);
        }

        emit LoanRepaid(msg.sender, repayAmount, fullyRepaid);
    }

    function withdrawCollateral(address collection, uint256 tokenId) external nonReentrant {
        Position storage pos = positions[msg.sender];
        if (!pos.deposited[collection][tokenId]) revert NotTokenOwner();

        _accrueInterest(pos);
        uint256 totalOwed = pos.principalDebt + pos.accruedInterest;
        if (totalOwed > 0) revert OutstandingDebt();

        pos.deposited[collection][tokenId] = false;

        uint256 len = pos.collateral.length;
        for (uint256 i = 0; i < len; i++) {
            if (pos.collateral[i].collection == collection && pos.collateral[i].tokenId == tokenId) {
                pos.collateral[i] = pos.collateral[len - 1];
                pos.collateral.pop();
                break;
            }
        }

        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);

        emit CollateralWithdrawn(msg.sender, collection, tokenId);
    }

    function setInterestRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps > MAX_INTEREST_RATE) revert InvalidInterestRate();
        uint256 oldRate = interestRateBps;
        interestRateBps = newRateBps;
        emit InterestRateUpdated(oldRate, newRateBps);
    }

    function addCollateralType(address collection) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (approvedCollateral[collection]) revert CollateralAlreadyApproved();

        approvedCollateral[collection] = true;
        approvedCollateralList.push(collection);

        emit CollateralTypeAdded(collection);
    }

    function removeCollateralType(address collection) external onlyOperator {
        if (!approvedCollateral[collection]) revert NotApprovedCollateral();

        approvedCollateral[collection] = false;

        uint256 len = approvedCollateralList.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedCollateralList[i] == collection) {
                approvedCollateralList[i] = approvedCollateralList[len - 1];
                approvedCollateralList.pop();
                break;
            }
        }

        emit CollateralTypeRemoved(collection);
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }

    function getDebt(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        uint256 interest = _calculateInterest(pos);
        return pos.principalDebt + pos.accruedInterest + interest;
    }

    function getPrincipalDebt(address user) external view returns (uint256) {
        return positions[user].principalDebt;
    }

    function getAccruedInterest(address user) external view returns (uint256) {
        return positions[user].accruedInterest + _calculateInterest(positions[user]);
    }

    function getCollateralValue(address user) external view returns (uint256) {
        return _getCollateralValue(user);
    }

    function getMaxBorrow(address user) external view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        uint256 currentDebt = positions[user].principalDebt +
            positions[user].accruedInterest +
            _calculateInterest(positions[user]);
        uint256 maxTotal = (collateralValue * MAX_LTV) / BASIS_POINTS;
        if (currentDebt >= maxTotal) return 0;
        return maxTotal - currentDebt;
    }

    function getCollateral(address user) external view returns (CollateralItem[] memory) {
        return positions[user].collateral;
    }

    function getApprovedCollateralTypes() external view returns (address[] memory) {
        return approvedCollateralList;
    }

    function isApprovedCollateral(address collection) external view returns (bool) {
        return approvedCollateral[collection];
    }

    function isDeposited(address user, address collection, uint256 tokenId) external view returns (bool) {
        return positions[user].deposited[collection][tokenId];
    }

    function _accrueInterest(Position storage pos) internal {
        if (pos.lastAccrualTime == 0 || pos.principalDebt == 0) {
            return;
        }
        if (block.timestamp > pos.lastAccrualTime) {
            uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
            uint256 rate = pos.interestRateAtBorrow;
            if (rate == 0) rate = interestRateBps;

            uint256 interest = (pos.principalDebt * rate * timeElapsed) /
                (SECONDS_PER_YEAR * BASIS_POINTS);

            pos.accruedInterest += interest;
            pos.lastAccrualTime = block.timestamp;
        }
    }

    function _calculateInterest(Position storage pos) internal view returns (uint256) {
        if (pos.lastAccrualTime == 0 || pos.principalDebt == 0) {
            return 0;
        }
        if (block.timestamp > pos.lastAccrualTime) {
            uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
            uint256 rate = pos.interestRateAtBorrow;
            if (rate == 0) rate = interestRateBps;

            return (pos.principalDebt * rate * timeElapsed) /
                (SECONDS_PER_YEAR * BASIS_POINTS);
        }
        return 0;
    }

    function _getCollateralValue(address user) internal view returns (uint256 totalValue) {
        Position storage pos = positions[user];
        uint256 len = pos.collateral.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 price = oracle.getPrice(pos.collateral[i].collection, pos.collateral[i].tokenId);
            totalValue += price;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
