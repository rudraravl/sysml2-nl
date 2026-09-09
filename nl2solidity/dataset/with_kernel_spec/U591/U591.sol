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

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

library Address {
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
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

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

contract PriceProtection is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum PolicyStatus {
        Pending,
        Active,
        Claimed,
        Withdrawn,
        Cancelled
    }

    struct Policy {
        address buyer;
        address underwriter;
        address asset;
        address collateralToken;
        uint256 strikePrice;
        uint256 expiration;
        uint256 collateralAmount;
        uint256 premiumAmount;
        PolicyStatus status;
    }

    uint256 public constant MIN_DURATION = 24 hours;
    uint256 public constant MAX_DURATION = 90 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_PREMIUM_FEE_BPS = 50; // 0.5%
    uint256 public constant CLAIM_WINDOW = 24 hours;

    IPriceOracle public immutable oracle;

    uint256 public premiumFeeBps;
    uint256 public nextPolicyId;
    uint256 public activePolicyCount;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => bool) public isActivePolicy;
    mapping(address => bool) public allowedCollateralTokens;
    mapping(address => uint256[]) public userPolicies;

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed buyer,
        address asset,
        uint256 strikePrice,
        uint256 expiration
    );
    event CollateralDeposited(
        uint256 indexed policyId,
        address indexed underwriter,
        address collateralToken,
        uint256 amount,
        uint256 premiumAmount
    );
    event ClaimProcessed(
        uint256 indexed policyId,
        address indexed buyer,
        uint256 assetPrice,
        uint256 payout
    );
    event CollateralWithdrawn(
        uint256 indexed policyId,
        address indexed underwriter,
        uint256 amount
    );
    event PremiumFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event CollateralTokenStatusUpdated(address indexed token, bool allowed);
    event PolicyCancelled(uint256 indexed policyId, address indexed buyer);

    error InvalidDuration();
    error InvalidStrikePrice();
    error InvalidAsset();
    error CollateralTokenNotAllowed();
    error PolicyNotFound();
    error PolicyNotPending();
    error PolicyNotActive();
    error PolicyNotExpired();
    error PolicyAlreadyFunded();
    error NotBuyer();
    error NotUnderwriter();
    error PriceAboveStrike();
    error ClaimWindowExpired();
    error ClaimWindowActive();
    error ZeroAmount();
    error ZeroAddress();
    error FeeTooHigh();

    constructor(address _oracle) Ownable(msg.sender) ReentrancyGuard() {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        premiumFeeBps = DEFAULT_PREMIUM_FEE_BPS;
        nextPolicyId = 1;
    }

    modifier validDuration(uint256 duration) {
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert InvalidDuration();
        _;
    }

    modifier policyExists(uint256 policyId) {
        if (policyId == 0 || policyId >= nextPolicyId) revert PolicyNotFound();
        _;
    }

    function setPremiumFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh();
        uint256 oldFee = premiumFeeBps;
        premiumFeeBps = _feeBps;
        emit PremiumFeeUpdated(oldFee, _feeBps);
    }

    function setCollateralToken(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        allowedCollateralTokens[token] = allowed;
        emit CollateralTokenStatusUpdated(token, allowed);
    }

    function createPolicy(
        address asset,
        uint256 strikePrice,
        uint256 duration
    ) external validDuration(duration) returns (uint256 policyId) {
        if (asset == address(0)) revert InvalidAsset();
        if (strikePrice == 0) revert InvalidStrikePrice();

        policyId = nextPolicyId++;
        uint256 expiration = block.timestamp + duration;

        policies[policyId] = Policy({
            buyer: msg.sender,
            underwriter: address(0),
            asset: asset,
            collateralToken: address(0),
            strikePrice: strikePrice,
            expiration: expiration,
            collateralAmount: 0,
            premiumAmount: 0,
            status: PolicyStatus.Pending
        });

        userPolicies[msg.sender].push(policyId);

        emit PolicyCreated(policyId, msg.sender, asset, strikePrice, expiration);
    }

    function depositCollateral(
        uint256 policyId,
        address collateralToken,
        uint256 amount
    ) external policyExists(policyId) nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.status != PolicyStatus.Pending) revert PolicyNotPending();
        if (!allowedCollateralTokens[collateralToken]) revert CollateralTokenNotAllowed();
        if (amount == 0) revert ZeroAmount();

        uint256 premium = (amount * premiumFeeBps) / BPS_DENOMINATOR;
        uint256 netCollateral = amount - premium;

        // Effects: update state before external interactions
        policy.underwriter = msg.sender;
        policy.collateralToken = collateralToken;
        policy.collateralAmount = netCollateral;
        policy.premiumAmount = premium;
        policy.status = PolicyStatus.Active;

        isActivePolicy[policyId] = true;
        activePolicyCount++;
        userPolicies[msg.sender].push(policyId);

        // Interactions: pull deposit and send premium to owner
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);

        if (premium > 0) {
            IERC20(collateralToken).safeTransfer(owner(), premium);
        }

        emit CollateralDeposited(policyId, msg.sender, collateralToken, netCollateral, premium);
    }

    function claim(uint256 policyId) external policyExists(policyId) nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (msg.sender != policy.buyer) revert NotBuyer();
        if (block.timestamp < policy.expiration) revert PolicyNotExpired();
        if (block.timestamp > policy.expiration + CLAIM_WINDOW) revert ClaimWindowExpired();

        uint256 assetPrice = oracle.getPrice(policy.asset);
        if (assetPrice >= policy.strikePrice) revert PriceAboveStrike();

        // Effects
        policy.status = PolicyStatus.Claimed;
        isActivePolicy[policyId] = false;
        activePolicyCount--;

        uint256 payout = policy.collateralAmount;
        policy.collateralAmount = 0;

        // Interactions
        IERC20(policy.collateralToken).safeTransfer(policy.buyer, payout);

        emit ClaimProcessed(policyId, policy.buyer, assetPrice, payout);
    }

    function withdraw(uint256 policyId) external policyExists(policyId) nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (msg.sender != policy.underwriter) revert NotUnderwriter();
        if (block.timestamp < policy.expiration + CLAIM_WINDOW) revert ClaimWindowActive();

        // Effects
        policy.status = PolicyStatus.Withdrawn;
        isActivePolicy[policyId] = false;
        activePolicyCount--;

        uint256 amount = policy.collateralAmount;
        policy.collateralAmount = 0;

        // Interactions
        IERC20(policy.collateralToken).safeTransfer(policy.underwriter, amount);

        emit CollateralWithdrawn(policyId, policy.underwriter, amount);
    }

    function cancelPolicy(uint256 policyId) external policyExists(policyId) {
        Policy storage policy = policies[policyId];
        if (policy.status != PolicyStatus.Pending) revert PolicyNotPending();
        if (msg.sender != policy.buyer) revert NotBuyer();

        policy.status = PolicyStatus.Cancelled;

        emit PolicyCancelled(policyId, msg.sender);
    }

    function getPolicy(uint256 policyId) external view policyExists(policyId) returns (Policy memory) {
        return policies[policyId];
    }

    function getUserPolicyCount(address user) external view returns (uint256) {
        return userPolicies[user].length;
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        return isActivePolicy[policyId];
    }
}
