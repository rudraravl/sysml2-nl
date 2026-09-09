// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Initializable {
    uint8 private _initialized;
    bool private _initializing;

    event Initialized(uint8 version);

    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) ||
                (!_isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    function _isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }
}

abstract contract ContextUpgradeable {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function __Ownable_init(address initialOwner) internal onlyInitializing {
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    bool private _paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    function __Pausable_init() internal onlyInitializing {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    function _pause() internal virtual {
        require(!_paused, "Pausable: not paused");
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual {
        require(_paused, "Pausable: not paused");
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

abstract contract ReentrancyGuardUpgradeable is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract UUPSUpgradeable is Initializable {
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    event Upgraded(address indexed implementation);

    function _authorizeUpgrade(address newImplementation) internal virtual;

    function upgradeTo(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, "");
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) internal {
        require(newImplementation.code.length > 0, "UUPS: new implementation is not a contract");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        if (data.length > 0) {
            (bool success, bytes memory ret) = newImplementation.delegatecall(data);
            if (!success) {
                if (ret.length > 0) {
                    assembly {
                        revert(add(ret, 0x20), mload(ret))
                    }
                }
                revert("UUPS: delegatecall failed");
            }
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
}

contract TokenLaunchpad is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    struct Project {
        address creator;
        address baseToken;
        address projectToken;
        uint256 saleStart;
        uint256 saleEnd;
        uint256 projectTokensPerBase;
        uint256 softCap;
        uint256 hardCap;
        uint256 tokensForSale;
        uint256 totalContributed;
        uint256 totalProjectTokensClaimable;
        uint256 totalProjectTokensClaimed;
        uint256 totalBaseRefunded;
        bool finalized;
        bool successful;
        bool cancelled;
    }

    uint256 public nextProjectId;
    address public treasury;
    uint256 public feeBps;

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => uint256)) public claimedProjectTokens;

    event ProjectLaunchCreated(
        uint256 indexed projectId,
        address indexed creator,
        address indexed baseToken,
        address projectToken,
        uint256 saleStart,
        uint256 saleEnd,
        uint256 projectTokensPerBase,
        uint256 softCap,
        uint256 hardCap,
        uint256 tokensForSale
    );
    event Contributed(uint256 indexed projectId, address indexed contributor, uint256 amount);
    event ProjectTokensClaimed(uint256 indexed projectId, address indexed contributor, uint256 projectTokenAmount);
    event BaseTokensWithdrawn(uint256 indexed projectId, address indexed contributor, uint256 baseTokenAmount);
    event ProjectFinalized(uint256 indexed projectId, bool successful, uint256 feeAmount);
    event ProjectCancelledEvt(uint256 indexed projectId);
    event UnsoldProjectTokensReclaimed(uint256 indexed projectId, address indexed creator, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    error ZeroAddress();
    error InvalidSaleWindow();
    error InvalidCaps();
    error InvalidAmount();
    error SaleNotActive();
    error SaleNotEnded();
    error AlreadyFinalized();
    error NotFinalized();
    error NotSuccessful();
    error NotFailed();
    error ExceedsHardCap();
    error ExceedsParticipantCap();
    error NothingToClaim();
    error NothingToWithdraw();
    error AlreadyClaimed();
    error NotAuthorized();
    error TransferFailed();
    error InvalidFee();
    error ProjectNotFound();
    error ProjectCancelledErr();
    error SameTokens();

    uint256 private constant MAX_PARTICIPANT_BASE_TOKENS = 1000;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant RECLAIM_DELAY = 90 days;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _treasury,
        uint256 _feeBps,
        address _owner
    ) public initializer {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        if (_feeBps > BPS_DENOMINATOR) revert InvalidFee();

        treasury = _treasury;
        feeBps = _feeBps;
        nextProjectId = 1;

        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    modifier projectExists(uint256 projectId) {
        if (projects[projectId].creator == address(0)) revert ProjectNotFound();
        _;
    }

    function createProjectLaunch(
        address baseToken,
        address projectToken,
        uint256 saleStart,
        uint256 saleEnd,
        uint256 projectTokensPerBase,
        uint256 softCap,
        uint256 hardCap
    ) external whenNotPaused nonReentrant returns (uint256 projectId) {
        if (baseToken == address(0) || projectToken == address(0)) revert ZeroAddress();
        if (baseToken == projectToken) revert SameTokens();
        if (saleEnd <= block.timestamp) revert InvalidSaleWindow();
        if (saleStart >= saleEnd) revert InvalidSaleWindow();
        if (softCap == 0 || hardCap == 0 || softCap > hardCap) revert InvalidCaps();
        if (projectTokensPerBase == 0) revert InvalidCaps();

        uint256 tokensForSale = (hardCap * projectTokensPerBase) / PRECISION;
        if (tokensForSale == 0) revert InvalidCaps();

        projectId = nextProjectId++;
        Project storage p = projects[projectId];
        p.creator = msg.sender;
        p.baseToken = baseToken;
        p.projectToken = projectToken;
        p.saleStart = saleStart;
        p.saleEnd = saleEnd;
        p.projectTokensPerBase = projectTokensPerBase;
        p.softCap = softCap;
        p.hardCap = hardCap;
        p.tokensForSale = tokensForSale;
        p.totalContributed = 0;
        p.totalProjectTokensClaimable = 0;
        p.totalProjectTokensClaimed = 0;
        p.totalBaseRefunded = 0;
        p.finalized = false;
        p.successful = false;
        p.cancelled = false;

        _safeTransferFrom(projectToken, msg.sender, address(this), tokensForSale);

        emit ProjectLaunchCreated(
            projectId,
            msg.sender,
            baseToken,
            projectToken,
            saleStart,
            saleEnd,
            projectTokensPerBase,
            softCap,
            hardCap,
            tokensForSale
        );
    }

    function contribute(uint256 projectId, uint256 amount)
        external
        projectExists(projectId)
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert InvalidAmount();

        Project storage p = projects[projectId];
        if (p.cancelled) revert ProjectCancelledErr();
        if (p.finalized) revert AlreadyFinalized();
        if (block.timestamp < p.saleStart || block.timestamp >= p.saleEnd) revert SaleNotActive();

        uint256 newTotal = p.totalContributed + amount;
        if (newTotal > p.hardCap) revert ExceedsHardCap();

        uint256 newContribution = contributions[projectId][msg.sender] + amount;
        uint256 maxCap = _maxParticipantCap(p.baseToken);
        if (newContribution > maxCap) revert ExceedsParticipantCap();

        contributions[projectId][msg.sender] = newContribution;
        p.totalContributed = newTotal;

        _safeTransferFrom(p.baseToken, msg.sender, address(this), amount);

        emit Contributed(projectId, msg.sender, amount);
    }

    function finalize(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (p.cancelled) revert ProjectCancelledErr();
        if (p.finalized) revert AlreadyFinalized();
        if (block.timestamp < p.saleEnd && p.totalContributed < p.hardCap) revert SaleNotEnded();

        p.finalized = true;
        if (p.totalContributed >= p.softCap) {
            _finalizeSuccess(projectId, p);
        } else {
            _finalizeFailure(projectId, p);
        }
    }

    function _finalizeSuccess(uint256 projectId, Project storage p) internal {
        p.successful = true;

        uint256 claimable = (p.totalContributed * p.projectTokensPerBase) / PRECISION;
        if (claimable > p.tokensForSale) {
            claimable = p.tokensForSale;
        }
        p.totalProjectTokensClaimable = claimable;

        uint256 fee = (p.totalContributed * feeBps) / BPS_DENOMINATOR;
        uint256 creatorShare = p.totalContributed - fee;

        if (fee > 0) {
            _safeTransfer(p.baseToken, treasury, fee);
        }
        if (creatorShare > 0) {
            _safeTransfer(p.baseToken, p.creator, creatorShare);
        }

        if (p.tokensForSale > claimable) {
            uint256 unsold = p.tokensForSale - claimable;
            p.tokensForSale = claimable;
            _safeTransfer(p.projectToken, p.creator, unsold);
            emit UnsoldProjectTokensReclaimed(projectId, p.creator, unsold);
        }

        emit ProjectFinalized(projectId, true, fee);
    }

    function _finalizeFailure(uint256 projectId, Project storage p) internal {
        uint256 bal = IERC20(p.projectToken).balanceOf(address(this));
        if (bal > 0) {
            p.tokensForSale = 0;
            _safeTransfer(p.projectToken, p.creator, bal);
        }
        emit ProjectFinalized(projectId, false, 0);
    }

    function claim(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (!p.finalized) revert NotFinalized();
        if (!p.successful) revert NotSuccessful();

        uint256 contribution = contributions[projectId][msg.sender];
        if (contribution == 0) revert NothingToClaim();
        if (claimedProjectTokens[projectId][msg.sender] != 0) revert AlreadyClaimed();

        uint256 projectTokenAmount = (contribution * p.projectTokensPerBase) / PRECISION;
        if (projectTokenAmount == 0) revert NothingToClaim();

        claimedProjectTokens[projectId][msg.sender] = projectTokenAmount;
        p.totalProjectTokensClaimed += projectTokenAmount;

        _safeTransfer(p.projectToken, msg.sender, projectTokenAmount);

        emit ProjectTokensClaimed(projectId, msg.sender, projectTokenAmount);
    }

    function withdraw(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        bool canWithdraw = p.cancelled || (p.finalized && !p.successful);
        if (!canWithdraw) revert NotFailed();

        uint256 contribution = contributions[projectId][msg.sender];
        if (contribution == 0) revert NothingToWithdraw();

        contributions[projectId][msg.sender] = 0;
        p.totalBaseRefunded += contribution;

        _safeTransfer(p.baseToken, msg.sender, contribution);

        emit BaseTokensWithdrawn(projectId, msg.sender, contribution);
    }

    function cancelProject(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (msg.sender != p.creator && msg.sender != owner()) revert NotAuthorized();
        if (p.cancelled) revert ProjectCancelledErr();
        if (p.finalized) revert AlreadyFinalized();
        if (p.totalContributed >= p.softCap) revert NotAuthorized();

        p.cancelled = true;

        uint256 bal = IERC20(p.projectToken).balanceOf(address(this));
        if (bal > 0) {
            p.tokensForSale = 0;
            _safeTransfer(p.projectToken, p.creator, bal);
        }

        emit ProjectCancelledEvt(projectId);
    }

    function reclaimUnclaimedProjectTokens(uint256 projectId)
        external
        projectExists(projectId)
        nonReentrant
    {
        Project storage p = projects[projectId];
        if (msg.sender != p.creator) revert NotAuthorized();
        if (!p.finalized || !p.successful) revert NotSuccessful();
        if (block.timestamp < p.saleEnd + RECLAIM_DELAY) revert SaleNotEnded();

        uint256 remaining = p.totalProjectTokensClaimable - p.totalProjectTokensClaimed;
        if (remaining == 0) revert NothingToClaim();

        p.totalProjectTokensClaimed = p.totalProjectTokensClaimable;
        _safeTransfer(p.projectToken, p.creator, remaining);

        emit UnsoldProjectTokensReclaimed(projectId, p.creator, remaining);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert InvalidFee();
        uint256 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getProject(uint256 projectId)
        external
        view
        projectExists(projectId)
        returns (Project memory)
    {
        return projects[projectId];
    }

    function getContribution(uint256 projectId, address user)
        external
        view
        projectExists(projectId)
        returns (uint256)
    {
        return contributions[projectId][user];
    }

    function getClaimedProjectTokens(uint256 projectId, address user)
        external
        view
        projectExists(projectId)
        returns (uint256)
    {
        return claimedProjectTokens[projectId][user];
    }

    function maxParticipantCap(address baseToken) external view returns (uint256) {
        return _maxParticipantCap(baseToken);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _maxParticipantCap(address baseToken) internal view returns (uint256) {
        try IERC20Metadata(baseToken).decimals() returns (uint8 d) {
            if (d > 18) d = 18;
            return MAX_PARTICIPANT_BASE_TOKENS * (10 ** uint256(d));
        } catch {
            return MAX_PARTICIPANT_BASE_TOKENS * PRECISION;
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
