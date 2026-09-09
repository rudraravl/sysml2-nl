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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, address indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        if (contains(set, value)) return false;
        set._values.push(value);
        set._indexes[value] = set._values.length;
        return true;
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) return false;
        uint256 lastIndex = set._values.length;
        if (valueIndex != lastIndex) {
            address lastValue = set._values[lastIndex - 1];
            set._values[valueIndex - 1] = lastValue;
            set._indexes[lastValue] = valueIndex;
        }
        set._values.pop();
        delete set._indexes[value];
        return true;
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address to, uint256 value) internal {
        bool success = token.transferFrom(msg.sender, to, value);
        require(success, "SafeERC20: transferFrom failed");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract AccessControl is Context {
    struct RoleData {
        mapping(address => bool) members;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "AccessControl: account is missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role].members[account]) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role].members[account]) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

abstract contract Pausable is Context {
    bool internal _paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract ERC721Holder is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract NFTLending is AccessControl, Pausable, ReentrancyGuard, ERC721Holder {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MAX_LOAN_DURATION = 30 days;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BPS = 10_000;
    uint256 public constant PROTOCOL_FEE_BPS = 50;

    enum LoanStatus {
        None,
        Offered,
        Active,
        Repaid,
        Defaulted,
        Cancelled
    }

    struct Offer {
        address borrower;
        address collection;
        uint256 tokenId;
        uint256 principal;
        uint256 interestRateAPR;
        uint256 duration;
        uint256 created;
        bool active;
    }

    struct Loan {
        address borrower;
        address lender;
        address collection;
        uint256 tokenId;
        uint256 principal;
        uint256 interestRateAPR;
        uint256 startDate;
        uint256 dueDate;
        LoanStatus status;
    }

    struct DefaultTerms {
        uint256 principal;
        uint256 interestRateAPR;
        uint256 duration;
    }

    IERC20 public immutable principalToken;
    address public feeRecipient;
    DefaultTerms public defaultTerms;
    EnumerableSet.AddressSet internal supportedCollections;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => Loan) public loans;
    mapping(address => mapping(uint256 => uint256)) internal collateralOffer;
    uint256 public nextOfferId = 1;
    uint256 public nextLoanId = 1;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed borrower,
        address indexed collection,
        uint256 tokenId,
        uint256 principal,
        uint256 interestRateAPR,
        uint256 duration
    );
    event OfferCancelled(uint256 indexed offerId, address indexed borrower);
    event LoanOriginated(
        uint256 indexed loanId,
        uint256 indexed offerId,
        address indexed borrower,
        address lender,
        address collection,
        uint256 tokenId,
        uint256 principal,
        uint256 interestRateAPR,
        uint256 startDate,
        uint256 dueDate
    );
    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 principalPaid,
        uint256 interestPaid,
        uint256 protocolFee
    );
    event CollateralReclaimed(
        uint256 indexed loanId,
        address indexed by,
        address indexed collection,
        uint256 tokenId,
        bool seized
    );
    event CollectionSupported(address indexed collection);
    event CollectionRemoved(address indexed collection);
    event DefaultTermsUpdated(uint256 principal, uint256 interestRateAPR, uint256 duration);
    event FeeRecipientUpdated(address indexed feeRecipient);

    error ZeroAddress();
    error ZeroAmount();
    error CollectionNotSupported();
    error LoanDurationExceeded();
    error DurationTooShort();
    error NotOfferOwner();
    error OfferNotActive();
    error BorrowerCannotBeLender();
    error LoanNotActive();
    error NotBorrower();
    error NotLender();
    error NotInDefault();
    error CollateralLocked();

    constructor(address _principalToken, address _feeRecipient, address _operator) {
        if (_principalToken == address(0) || _feeRecipient == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        principalToken = IERC20(_principalToken);
        feeRecipient = _feeRecipient;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
        defaultTerms = DefaultTerms({principal: 1 ether, interestRateAPR: 500, duration: 14 days});
    }

    modifier onlySupportedCollection(address collection) {
        if (!supportedCollections.contains(collection)) revert CollectionNotSupported();
        _;
    }

    function isCollectionSupported(address collection) external view returns (bool) {
        return supportedCollections.contains(collection);
    }

    function supportedCollectionsList() external view returns (address[] memory) {
        return supportedCollections.values();
    }

    function totalSupportedCollections() external view returns (uint256) {
        return supportedCollections.length();
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getAmountDue(uint256 loanId)
        public
        view
        returns (uint256 principal, uint256 interest, uint256 total)
    {
        Loan storage l = loans[loanId];
        if (l.status != LoanStatus.Active) return (0, 0, 0);
        uint256 elapsed = block.timestamp - l.startDate;
        interest = (l.principal * l.interestRateAPR * elapsed) / (SECONDS_PER_YEAR * BPS);
        principal = l.principal;
        total = principal + interest;
    }

    function offerNFT(
        address collection,
        uint256 tokenId,
        uint256 principal,
        uint256 interestRateAPR,
        uint256 duration
    ) public onlySupportedCollection(collection) whenNotPaused nonReentrant returns (uint256 offerId) {
        if (principal == 0) revert ZeroAmount();
        if (duration == 0) revert DurationTooShort();
        if (duration > MAX_LOAN_DURATION) revert LoanDurationExceeded();
        if (collateralOffer[collection][tokenId] != 0) revert CollateralLocked();

        offerId = nextOfferId++;
        offers[offerId] = Offer({
            borrower: msg.sender,
            collection: collection,
            tokenId: tokenId,
            principal: principal,
            interestRateAPR: interestRateAPR,
            duration: duration,
            created: block.timestamp,
            active: true
        });
        collateralOffer[collection][tokenId] = offerId;

        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        emit OfferCreated(offerId, msg.sender, collection, tokenId, principal, interestRateAPR, duration);
    }

    function offerNFTWithDefaultTerms(address collection, uint256 tokenId)
        external
        returns (uint256 offerId)
    {
        offerId = offerNFT(
            collection,
            tokenId,
            defaultTerms.principal,
            defaultTerms.interestRateAPR,
            defaultTerms.duration
        );
    }

    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        if (!o.active) revert OfferNotActive();
        if (o.borrower != msg.sender) revert NotOfferOwner();

        o.active = false;
        delete collateralOffer[o.collection][o.tokenId];

        IERC721(o.collection).safeTransferFrom(address(this), o.borrower, o.tokenId);

        emit OfferCancelled(offerId, o.borrower);
    }

    function takeLoan(uint256 offerId) external whenNotPaused nonReentrant returns (uint256 loanId) {
        Offer storage o = offers[offerId];
        if (!o.active) revert OfferNotActive();
        if (o.borrower == msg.sender) revert BorrowerCannotBeLender();

        o.active = false;

        loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: o.borrower,
            lender: msg.sender,
            collection: o.collection,
            tokenId: o.tokenId,
            principal: o.principal,
            interestRateAPR: o.interestRateAPR,
            startDate: block.timestamp,
            dueDate: block.timestamp + o.duration,
            status: LoanStatus.Active
        });

        principalToken.safeTransferFrom(o.borrower, o.principal);

        emit LoanOriginated(
            loanId,
            offerId,
            o.borrower,
            msg.sender,
            o.collection,
            o.tokenId,
            o.principal,
            o.interestRateAPR,
            block.timestamp,
            block.timestamp + o.duration
        );
    }

    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage l = loans[loanId];
        if (l.status != LoanStatus.Active) revert LoanNotActive();
        if (l.borrower != msg.sender) revert NotBorrower();

        (uint256 principal, uint256 interest, uint256 totalDue) = getAmountDue(loanId);

        uint256 fee = (interest * PROTOCOL_FEE_BPS) / BPS;
        uint256 lenderPayout = totalDue - fee;

        l.status = LoanStatus.Repaid;
        delete collateralOffer[l.collection][l.tokenId];

        principalToken.safeTransferFrom(address(this), totalDue);
        principalToken.safeTransfer(l.lender, lenderPayout);
        if (fee > 0) {
            principalToken.safeTransfer(feeRecipient, fee);
        }

        IERC721(l.collection).safeTransferFrom(address(this), l.borrower, l.tokenId);

        emit LoanRepaid(loanId, l.borrower, l.lender, principal, interest, fee);
        emit CollateralReclaimed(loanId, l.borrower, l.collection, l.tokenId, false);
    }

    function reclaimCollateral(uint256 loanId) external nonReentrant {
        Loan storage l = loans[loanId];
        if (l.status != LoanStatus.Active) revert LoanNotActive();
        if (block.timestamp <= l.dueDate) revert NotInDefault();
        if (l.lender != msg.sender) revert NotLender();

        l.status = LoanStatus.Defaulted;
        delete collateralOffer[l.collection][l.tokenId];

        IERC721(l.collection).safeTransferFrom(address(this), l.lender, l.tokenId);

        emit CollateralReclaimed(loanId, l.lender, l.collection, l.tokenId, true);
    }

    function setSupportedCollection(address collection) external onlyRole(OPERATOR_ROLE) {
        if (collection == address(0)) revert ZeroAddress();
        if (supportedCollections.add(collection)) {
            emit CollectionSupported(collection);
        }
    }

    function removeSupportedCollection(address collection) external onlyRole(OPERATOR_ROLE) {
        if (supportedCollections.remove(collection)) {
            emit CollectionRemoved(collection);
        }
    }

    function setDefaultTerms(uint256 principal, uint256 interestRateAPR, uint256 duration)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (duration == 0) revert DurationTooShort();
        if (duration > MAX_LOAN_DURATION) revert LoanDurationExceeded();
        defaultTerms = DefaultTerms({
            principal: principal,
            interestRateAPR: interestRateAPR,
            duration: duration
        });
        emit DefaultTermsUpdated(principal, interestRateAPR, duration);
    }

    function setFeeRecipient(address recipient) external onlyRole(OPERATOR_ROLE) {
        if (recipient == address(0)) revert ZeroAddress();
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}
