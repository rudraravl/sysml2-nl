// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// Inlined minimal OpenZeppelin contracts for standalone compilation
// ============================================================================

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

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 0x20), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
        return returndata;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address account);

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ============================================================================
// Main contract
// ============================================================================

/// @title OpenSourceDonations
/// @notice Custodies donated ERC-20 tokens and splits each donation between a project
///         and its registered dependencies according to configurable basis-point ratios.
contract OpenSourceDonations is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Basis points denominator (1e4). 100 bps = 1%.
    uint256 public constant BPS = 10_000;

    /// @dev Minimum ratio assignable to a single dependency (1%).
    uint16 public constant MIN_RATIO = 100;

    /// @dev Maximum ratio assignable to a single dependency (50%).
    uint16 public constant MAX_RATIO = 5_000;

    /// @dev Maximum aggregate ratio across all dependencies of a project (80%).
    uint16 public constant MAX_TOTAL_RATIO = 8_000;

    struct Project {
        address wallet;
        bool exists;
        uint16 totalRatio;
        address[] deps;
        mapping(address => bool) isDep;
        mapping(address => uint16) ratio;
        mapping(address => uint256) depIndex;
    }

    /// @dev Canonical donation token custodied by this contract.
    IERC20 public immutable donationToken;

    mapping(address => Project) private _projects;
    address[] private _projectList;
    mapping(address => uint256) private _projectIndex;

    event ProjectRegistered(address indexed projectId, address wallet);
    event ProjectWalletUpdated(address indexed projectId, address oldWallet, address newWallet);
    event DependencyAdded(address indexed projectId, address dependency, uint16 ratio);
    event DependencyRemoved(address indexed projectId, address dependency);
    event DependencyRatioUpdated(address indexed projectId, address dependency, uint16 oldRatio, uint16 newRatio);
    event DonationReceived(address indexed projectId, address donor, uint256 amount);
    event Distributed(address indexed projectId, address recipient, uint256 amount);

    error ProjectAlreadyExists(address projectId);
    error ProjectNotFound(address projectId);
    error InvalidWallet(address wallet);
    error DependencyAlreadyExists(address projectId, address dependency);
    error DependencyNotFound(address projectId, address dependency);
    error InvalidSelfDependency(address projectId);
    error RatioOutOfRange(uint16 ratio);
    error TotalRatioExceeded(uint16 currentTotal, uint16 attemptedTotal);
    error ZeroAmount();

    /// @param token_ The ERC-20 token accepted for donations.
    /// @param initialOwner Address authorized to manage the project registry.
    constructor(address token_, address initialOwner) Ownable(initialOwner) {
        if (token_ == address(0)) revert InvalidWallet(address(0));
        donationToken = IERC20(token_);
    }

    // --------------------------------------------------------------------------------------------
    // View functions
    // --------------------------------------------------------------------------------------------

    function projectExists(address projectId) external view returns (bool) {
        return _projects[projectId].exists;
    }

    function projectWallet(address projectId) external view returns (address) {
        if (!_projects[projectId].exists) revert ProjectNotFound(projectId);
        return _projects[projectId].wallet;
    }

    function projectTotalRatio(address projectId) external view returns (uint16) {
        if (!_projects[projectId].exists) revert ProjectNotFound(projectId);
        return _projects[projectId].totalRatio;
    }

    function projectDependencyRatio(address projectId, address dependency) external view returns (uint16) {
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);
        if (!p.isDep[dependency]) revert DependencyNotFound(projectId, dependency);
        return p.ratio[dependency];
    }

    function projectDependencies(address projectId) external view returns (address[] memory) {
        if (!_projects[projectId].exists) revert ProjectNotFound(projectId);
        return _projects[projectId].deps;
    }

    function projectsList() external view returns (address[] memory) {
        return _projectList;
    }

    function projectCount() external view returns (uint256) {
        return _projectList.length;
    }

    // --------------------------------------------------------------------------------------------
    // Admin functions
    // --------------------------------------------------------------------------------------------

    /// @notice Registers a new project.
    /// @param projectId Unique identifier for the project (any non-zero address).
    /// @param wallet Wallet that receives the project's share of donations.
    function registerProject(address projectId, address wallet) external onlyOwner {
        if (projectId == address(0)) revert InvalidWallet(projectId);
        if (wallet == address(0)) revert InvalidWallet(wallet);
        if (_projects[projectId].exists) revert ProjectAlreadyExists(projectId);

        Project storage p = _projects[projectId];
        p.wallet = wallet;
        p.exists = true;

        _projectIndex[projectId] = _projectList.length;
        _projectList.push(projectId);

        emit ProjectRegistered(projectId, wallet);
    }

    /// @notice Updates the wallet address that receives a project's share of donations.
    /// @param projectId Project whose wallet is being updated.
    /// @param newWallet New wallet address (must be non-zero).
    function updateProjectWallet(address projectId, address newWallet) external onlyOwner {
        if (newWallet == address(0)) revert InvalidWallet(newWallet);
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);

        address oldWallet = p.wallet;
        p.wallet = newWallet;

        emit ProjectWalletUpdated(projectId, oldWallet, newWallet);
    }

    /// @notice Adds a dependency to a project with a given distribution ratio.
    /// @dev The dependency must itself be a registered project. The ratio must be within
    ///      [MIN_RATIO, MAX_RATIO] and the project's aggregate ratio must remain <= MAX_TOTAL_RATIO.
    /// @param projectId Project that receives donations.
    /// @param dependency Dependent project that receives a portion of donations.
    /// @param ratio Share of donations routed to `dependency`, in basis points.
    function addDependency(address projectId, address dependency, uint16 ratio) external onlyOwner {
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);
        if (!_projects[dependency].exists) revert ProjectNotFound(dependency);
        if (dependency == projectId) revert InvalidSelfDependency(projectId);
        if (p.isDep[dependency]) revert DependencyAlreadyExists(projectId, dependency);
        if (ratio < MIN_RATIO || ratio > MAX_RATIO) revert RatioOutOfRange(ratio);

        uint16 newTotal = p.totalRatio + ratio;
        if (newTotal > MAX_TOTAL_RATIO) revert TotalRatioExceeded(p.totalRatio, newTotal);

        p.isDep[dependency] = true;
        p.ratio[dependency] = ratio;
        p.depIndex[dependency] = p.deps.length;
        p.deps.push(dependency);
        p.totalRatio = newTotal;

        emit DependencyAdded(projectId, dependency, ratio);
    }

    /// @notice Removes a dependency from a project.
    /// @param projectId Project whose dependency is being removed.
    /// @param dependency Dependent project to remove.
    function removeDependency(address projectId, address dependency) external onlyOwner {
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);
        if (!p.isDep[dependency]) revert DependencyNotFound(projectId, dependency);

        uint16 ratio = p.ratio[dependency];
        p.totalRatio = p.totalRatio - ratio;

        uint256 idx = p.depIndex[dependency];
        uint256 lastIdx = p.deps.length - 1;
        if (idx != lastIdx) {
            address last = p.deps[lastIdx];
            p.deps[idx] = last;
            p.depIndex[last] = idx;
        }
        p.deps.pop();

        delete p.isDep[dependency];
        delete p.ratio[dependency];
        delete p.depIndex[dependency];

        emit DependencyRemoved(projectId, dependency);
    }

    /// @notice Adjusts the distribution ratio for an existing dependency.
    /// @param projectId Project that owns the dependency.
    /// @param dependency Dependent project whose ratio is being updated.
    /// @param newRatio New ratio in basis points, within [MIN_RATIO, MAX_RATIO].
    function setDependencyRatio(address projectId, address dependency, uint16 newRatio) external onlyOwner {
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);
        if (!p.isDep[dependency]) revert DependencyNotFound(projectId, dependency);
        if (newRatio < MIN_RATIO || newRatio > MAX_RATIO) revert RatioOutOfRange(newRatio);

        uint16 oldRatio = p.ratio[dependency];
        uint16 newTotal = p.totalRatio - oldRatio + newRatio;
        if (newTotal > MAX_TOTAL_RATIO) revert TotalRatioExceeded(p.totalRatio - oldRatio, newTotal);

        p.ratio[dependency] = newRatio;
        p.totalRatio = newTotal;

        emit DependencyRatioUpdated(projectId, dependency, oldRatio, newRatio);
    }

    // --------------------------------------------------------------------------------------------
    // Donation flow
    // --------------------------------------------------------------------------------------------

    /// @notice Donates `amount` of the donation token to `projectId`, routing the configured
    ///         fraction to each registered dependency and the remainder to the project wallet.
    /// @dev The caller must have approved this contract to spend `amount` of `donationToken`.
    ///      The aggregate ratio is bounded by MAX_TOTAL_RATIO, so at least 20% reaches the project.
    /// @param projectId Registered project receiving the donation.
    /// @param amount Donation amount in the smallest unit of `donationToken`.
    function donate(address projectId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Project storage p = _projects[projectId];
        if (!p.exists) revert ProjectNotFound(projectId);

        donationToken.safeTransferFrom(msg.sender, address(this), amount);
        emit DonationReceived(projectId, msg.sender, amount);

        uint256 remaining = amount;
        address[] storage deps = p.deps;
        uint256 len = deps.length;
        for (uint256 i = 0; i < len; ) {
            address dep = deps[i];
            uint16 r = p.ratio[dep];
            uint256 share = (amount * uint256(r)) / BPS;
            if (share > 0) {
                address depWallet = _projects[dep].wallet;
                donationToken.safeTransfer(depWallet, share);
                emit Distributed(projectId, depWallet, share);
                remaining -= share;
            }
            unchecked {
                ++i;
            }
        }

        if (remaining > 0) {
            donationToken.safeTransfer(p.wallet, remaining);
            emit Distributed(projectId, p.wallet, remaining);
        }
    }
}
