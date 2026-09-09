// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RiskCoverageProvider is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant UNIT = 1e18;
    uint256 public constant REVIEW_PERIOD = 7 days;

    error ZeroAmount();
    error NotOwner();
    error CoveragePaused();
    error ProtocolNotSupported();
    error ProtocolAlreadySupported();
    error CoverageTooSmall();
    error InvalidDuration();
    error PremiumTooLow();
    error InsufficientBacking();
    error InsufficientShares();
    error InsufficientFreeBalance();
    error PolicyNotFound();
    error NotPolicyHolder();
    error PolicyNotActive();
    error PolicyExpired();
    error PolicyStillActive();
    error ClaimAlreadyFiled();
    error NoClaimFiled();
    error ReviewPeriodNotOver();
    error AlreadyPaid();
    error InvalidAddress();

    event CollateralDeposited(address indexed user, uint256 amount, uint256 sharesMinted);
    event CollateralUnstaked(address indexed user, uint256 sharesBurned, uint256 tokenAmount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CoveragePurchased(
        uint256 indexed policyId,
        address indexed holder,
        address indexed protocol,
        uint256 coverageAmount,
        uint256 expiryTime,
        uint256 premium
    );
    event PolicyExtended(uint256 indexed policyId, uint256 newExpiryTime, uint256 premium);
    event PolicyExpired(uint256 indexed policyId);
    event ClaimFiled(uint256 indexed policyId, uint256 filedAt, uint256 reviewEnd);
    event ClaimPayout(uint256 indexed policyId, address indexed holder, uint256 amount);
    event ProtocolAdded(address indexed protocol);
    event ProtocolRemoved(address indexed protocol);
    event PricingUpdated(uint256 oldPrice, uint256 newPrice);
    event MinCoverageUpdated(uint256 oldMin, uint256 newMin);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct Policy {
        address holder;
        address protocol;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 expiryTime;
        uint256 claimFiledTime;
        bool paid;
        bool expired;
    }

    IERC20 public immutable collateralToken;
    uint8 public immutable collateralDecimals;
    address public owner;
    bool public paused;

    uint256 public pricePerUnitPerSecond;
    uint256 public minCoverage;

    uint256 public totalShares;
    uint256 public totalCollateral;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public freeCollateral;

    mapping(address => bool) public supportedProtocols;

    Policy[] public policies;
    mapping(address => uint256[]) public userPolicyIds;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _collateralToken, uint256 _pricePerUnitPerSecond) {
        if (_collateralToken == address(0)) revert InvalidAddress();
        collateralToken = IERC20(_collateralToken);
        collateralDecimals = IERC20Metadata(_collateralToken).decimals();
        owner = msg.sender;
        pricePerUnitPerSecond = _pricePerUnitPerSecond;
        minCoverage = 100 * (10 ** uint256(collateralDecimals));
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 sharesMinted;
        if (totalCollateral == 0) {
            totalShares = 0;
            sharesMinted = amount;
        } else {
            sharesMinted = (amount * totalShares) / totalCollateral;
        }

        shares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;
        totalCollateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount, sharesMinted);
    }

    function unstake(uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert ZeroAmount();
        if (shareAmount > shares[msg.sender]) revert InsufficientShares();
        if (totalShares == 0) revert InsufficientShares();

        uint256 tokenAmount = (shareAmount * totalCollateral) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalCollateral -= tokenAmount;
        freeCollateral[msg.sender] += tokenAmount;

        emit CollateralUnstaked(msg.sender, shareAmount, tokenAmount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > freeCollateral[msg.sender]) revert InsufficientFreeBalance();

        freeCollateral[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function shareValue(uint256 shareAmount) public view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shareAmount * totalCollateral) / totalShares;
    }

    function purchaseCoverage(
        address protocol,
        uint256 coverageAmount,
        uint256 duration
    ) external nonReentrant {
        if (paused) revert CoveragePaused();
        if (!supportedProtocols[protocol]) revert ProtocolNotSupported();
        if (coverageAmount < minCoverage) revert CoverageTooSmall();
        if (duration == 0) revert InvalidDuration();
        if (coverageAmount > totalCollateral) revert InsufficientBacking();

        uint256 premium = (coverageAmount * pricePerUnitPerSecond * duration) / UNIT;
        if (premium == 0) revert PremiumTooLow();

        uint256 policyId = policies.length;
        policies.push(
            Policy({
                holder: msg.sender,
                protocol: protocol,
                coverageAmount: coverageAmount,
                startTime: block.timestamp,
                expiryTime: block.timestamp + duration,
                claimFiledTime: 0,
                paid: false,
                expired: false
            })
        );
        userPolicyIds[msg.sender].push(policyId);

        collateralToken.safeTransferFrom(msg.sender, address(this), premium);
        totalCollateral += premium;

        emit CoveragePurchased(
            policyId,
            msg.sender,
            protocol,
            coverageAmount,
            block.timestamp + duration,
            premium
        );
    }

    function extendPolicy(uint256 policyId, uint256 extension) external nonReentrant {
        if (policyId >= policies.length) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (p.expired || p.paid) revert PolicyNotActive();
        if (p.claimFiledTime != 0) revert ClaimAlreadyFiled();
        if (block.timestamp > p.expiryTime) revert PolicyExpired();
        if (extension == 0) revert InvalidDuration();

        uint256 premium = (p.coverageAmount * pricePerUnitPerSecond * extension) / UNIT;
        if (premium == 0) revert PremiumTooLow();

        p.expiryTime += extension;
        collateralToken.safeTransferFrom(msg.sender, address(this), premium);
        totalCollateral += premium;

        emit PolicyExtended(policyId, p.expiryTime, premium);
    }

    function claim(uint256 policyId) external nonReentrant {
        if (policyId >= policies.length) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (p.expired || p.paid) revert PolicyNotActive();
        if (p.claimFiledTime != 0) revert ClaimAlreadyFiled();
        if (block.timestamp > p.expiryTime) revert PolicyExpired();

        p.claimFiledTime = block.timestamp;
        emit ClaimFiled(policyId, block.timestamp, block.timestamp + REVIEW_PERIOD);
    }

    function payoutClaim(uint256 policyId) external nonReentrant {
        if (policyId >= policies.length) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (p.claimFiledTime == 0) revert NoClaimFiled();
        if (p.paid) revert AlreadyPaid();
        if (block.timestamp < p.claimFiledTime + REVIEW_PERIOD) revert ReviewPeriodNotOver();

        p.paid = true;

        uint256 payoutAmount = p.coverageAmount;
        if (payoutAmount > totalCollateral) {
            payoutAmount = totalCollateral;
        }
        totalCollateral -= payoutAmount;

        collateralToken.safeTransfer(p.holder, payoutAmount);
        emit ClaimPayout(policyId, p.holder, payoutAmount);
    }

    function expirePolicy(uint256 policyId) external {
        if (policyId >= policies.length) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (p.expired || p.paid) revert PolicyNotActive();
        if (p.claimFiledTime != 0) revert ClaimAlreadyFiled();
        if (block.timestamp <= p.expiryTime) revert PolicyStillActive();

        p.expired = true;
        emit PolicyExpired(policyId);
    }

    function setPricing(uint256 newPrice) external onlyOwner {
        emit PricingUpdated(pricePerUnitPerSecond, newPrice);
        pricePerUnitPerSecond = newPrice;
    }

    function setMinCoverage(uint256 newMin) external onlyOwner {
        emit MinCoverageUpdated(minCoverage, newMin);
        minCoverage = newMin;
    }

    function addProtocol(address protocol) external onlyOwner {
        if (protocol == address(0)) revert InvalidAddress();
        if (supportedProtocols[protocol]) revert ProtocolAlreadySupported();
        supportedProtocols[protocol] = true;
        emit ProtocolAdded(protocol);
    }

    function removeProtocol(address protocol) external onlyOwner {
        if (!supportedProtocols[protocol]) revert ProtocolNotSupported();
        supportedProtocols[protocol] = false;
        emit ProtocolRemoved(protocol);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function policyCount() external view returns (uint256) {
        return policies.length;
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        if (policyId >= policies.length) revert PolicyNotFound();
        return policies[policyId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicyIds[user];
    }

    function isProtocolSupported(address protocol) external view returns (bool) {
        return supportedProtocols[protocol];
    }
}
