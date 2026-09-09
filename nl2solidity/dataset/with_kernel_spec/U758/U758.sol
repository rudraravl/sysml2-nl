// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PresaleManager {
    uint256 public constant MIN_SOFT_CAP = 100;
    uint256 public constant MAX_HARD_CAP = 10_000;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public owner;
    uint256 public feeRateBps;
    uint256 public accumulatedFees;
    uint256 public presaleCount;

    struct Presale {
        address creator;
        address token;
        uint256 softCap;
        uint256 hardCap;
        uint256 minContribution;
        uint256 maxContribution;
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 tokensForSale;
        uint256 totalContributed;
        uint256 feeAmount;
        bool finalized;
        bool cancelled;
    }

    struct CreatePresaleParams {
        address token;
        uint256 softCap;
        uint256 hardCap;
        uint256 minContribution;
        uint256 maxContribution;
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 tokensForSale;
    }

    mapping(uint256 => Presale) private s_presales;
    mapping(uint256 => mapping(address => uint256)) private s_contributions;
    mapping(uint256 => mapping(address => uint256)) private s_allocations;

    event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event PresaleCreated(
        uint256 indexed presaleId,
        address indexed creator,
        address indexed token,
        uint256 softCap,
        uint256 hardCap,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenPrice,
        uint256 tokensForSale,
        uint256 feeAmount
    );
    event ContributionMade(uint256 indexed presaleId, address indexed contributor, uint256 amount, uint256 allocation);
    event PresaleFinalized(uint256 indexed presaleId, uint256 totalContributed, uint256 feeAmount);
    event PresaleCancelled(uint256 indexed presaleId, uint256 totalContributed);
    event TokensClaimed(uint256 indexed presaleId, address indexed claimer, uint256 amount);
    event ContributionWithdrawn(uint256 indexed presaleId, address indexed contributor, uint256 amount);

    error NotOwner();
    error NotPresaleCreator();
    error InvalidCaps();
    error InvalidContributionLimits();
    error InvalidTimeWindow();
    error PresaleNotFound();
    error PresaleNotActive();
    error PresaleAlreadyFinalized();
    error PresaleAlreadyCancelled();
    error PresaleNotFinalized();
    error PresaleNotCancelled();
    error HardCapExceeded();
    error ContributionBelowMinimum();
    error ContributionAboveMaximum();
    error NothingToClaim();
    error NothingToWithdraw();
    error InsufficientFee();
    error TokenTransferFailed();
    error EthTransferFailed();
    error PresaleStillActive();
    error SoftCapNotReached();
    error SoftCapReached();
    error ZeroAddress();
    error InvalidTokenPrice();
    error InvalidTokensForSale();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        feeRateBps = 50;
        emit OwnerUpdated(address(0), msg.sender);
        emit FeeRateUpdated(0, 50);
    }

    function setFeeRate(uint256 newRateBps) external onlyOwner {
        uint256 old = feeRateBps;
        feeRateBps = newRateBps;
        emit FeeRateUpdated(old, newRateBps);
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    function createPresale(CreatePresaleParams calldata params) external payable returns (uint256 presaleId) {
        if (params.token == address(0)) revert ZeroAddress();
        if (params.softCap < MIN_SOFT_CAP || params.softCap > params.hardCap) revert InvalidCaps();
        if (params.hardCap > MAX_HARD_CAP) revert InvalidCaps();
        if (params.minContribution == 0 || params.minContribution > params.maxContribution) revert InvalidContributionLimits();
        if (params.maxContribution > params.hardCap) revert InvalidContributionLimits();
        if (params.startTime < block.timestamp || params.endTime <= params.startTime) revert InvalidTimeWindow();
        if (params.tokenPrice == 0) revert InvalidTokenPrice();
        if (params.tokensForSale == 0) revert InvalidTokensForSale();

        uint256 feeAmount = (params.hardCap * feeRateBps) / BPS_DENOMINATOR;
        if (msg.value < feeAmount) revert InsufficientFee();

        presaleId = presaleCount++;

        Presale storage p = s_presales[presaleId];
        p.creator = msg.sender;
        p.token = params.token;
        p.softCap = params.softCap;
        p.hardCap = params.hardCap;
        p.minContribution = params.minContribution;
        p.maxContribution = params.maxContribution;
        p.startTime = params.startTime;
        p.endTime = params.endTime;
        p.tokenPrice = params.tokenPrice;
        p.tokensForSale = params.tokensForSale;
        p.feeAmount = feeAmount;

        accumulatedFees += feeAmount;

        uint256 refund = msg.value - feeAmount;
        if (refund > 0) {
            (bool ok,) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert EthTransferFailed();
        }

        bool ok = IERC20(params.token).transferFrom(msg.sender, address(this), params.tokensForSale);
        if (!ok) revert TokenTransferFailed();

        emit PresaleCreated(
            presaleId,
            msg.sender,
            params.token,
            params.softCap,
            params.hardCap,
            params.startTime,
            params.endTime,
            params.tokenPrice,
            params.tokensForSale,
            feeAmount
        );
    }

    function contribute(uint256 presaleId) external payable {
        Presale storage p = s_presales[presaleId];
        if (p.creator == address(0)) revert PresaleNotFound();
        if (p.finalized) revert PresaleAlreadyFinalized();
        if (p.cancelled) revert PresaleAlreadyCancelled();
        if (block.timestamp < p.startTime || block.timestamp > p.endTime) revert PresaleNotActive();
        if (msg.value == 0) revert ContributionBelowMinimum();

        uint256 newTotal = p.totalContributed + msg.value;
        if (newTotal > p.hardCap) revert HardCapExceeded();

        uint256 currentContribution = s_contributions[presaleId][msg.sender];
        uint256 updatedContribution = currentContribution + msg.value;
        if (updatedContribution < p.minContribution) revert ContributionBelowMinimum();
        if (updatedContribution > p.maxContribution) revert ContributionAboveMaximum();

        uint256 allocation = (updatedContribution * 1e18) / p.tokenPrice;
        if (allocation > p.tokensForSale) revert HardCapExceeded();

        s_contributions[presaleId][msg.sender] = updatedContribution;
        s_allocations[presaleId][msg.sender] = allocation;
        p.totalContributed = newTotal;

        emit ContributionMade(presaleId, msg.sender, msg.value, allocation);
    }

    function finalizePresale(uint256 presaleId) external {
        Presale storage p = s_presales[presaleId];
        if (p.creator == address(0)) revert PresaleNotFound();
        if (msg.sender != p.creator) revert NotPresaleCreator();
        if (p.finalized) revert PresaleAlreadyFinalized();
        if (p.cancelled) revert PresaleAlreadyCancelled();
        if (block.timestamp <= p.endTime) revert PresaleStillActive();
        if (p.totalContributed < p.softCap) revert SoftCapNotReached();

        p.finalized = true;

        uint256 total = p.totalContributed;
        uint256 fee = p.feeAmount;
        if (fee > total) fee = total;
        uint256 creatorProceeds = total - fee;

        if (creatorProceeds > 0) {
            (bool ok,) = payable(p.creator).call{value: creatorProceeds}("");
            if (!ok) revert EthTransferFailed();
        }

        emit PresaleFinalized(presaleId, total, fee);
    }

    function cancelPresale(uint256 presaleId) external {
        Presale storage p = s_presales[presaleId];
        if (p.creator == address(0)) revert PresaleNotFound();
        if (msg.sender != p.creator) revert NotPresaleCreator();
        if (p.finalized) revert PresaleAlreadyFinalized();
        if (p.cancelled) revert PresaleAlreadyCancelled();
        if (block.timestamp <= p.endTime) revert PresaleStillActive();
        if (p.totalContributed >= p.softCap) revert SoftCapReached();

        p.cancelled = true;

        uint256 tokenBalance = IERC20(p.token).balanceOf(address(this));
        uint256 alreadyAllocated = _totalAllocated(presaleId);
        uint256 unsold = tokenBalance > alreadyAllocated ? tokenBalance - alreadyAllocated : 0;
        if (unsold > 0) {
            bool ok = IERC20(p.token).transfer(p.creator, unsold);
            if (!ok) revert TokenTransferFailed();
        }

        emit PresaleCancelled(presaleId, p.totalContributed);
    }

    function claimTokens(uint256 presaleId) external {
        Presale storage p = s_presales[presaleId];
        if (p.creator == address(0)) revert PresaleNotFound();
        if (!p.finalized) revert PresaleNotFinalized();

        uint256 allocation = s_allocations[presaleId][msg.sender];
        if (allocation == 0) revert NothingToClaim();

        s_allocations[presaleId][msg.sender] = 0;

        bool ok = IERC20(p.token).transfer(msg.sender, allocation);
        if (!ok) revert TokenTransferFailed();

        emit TokensClaimed(presaleId, msg.sender, allocation);
    }

    function withdrawContribution(uint256 presaleId) external {
        Presale storage p = s_presales[presaleId];
        if (p.creator == address(0)) revert PresaleNotFound();
        if (!p.cancelled) revert PresaleNotCancelled();

        uint256 contributed = s_contributions[presaleId][msg.sender];
        if (contributed == 0) revert NothingToWithdraw();

        s_contributions[presaleId][msg.sender] = 0;
        s_allocations[presaleId][msg.sender] = 0;

        (bool ok,) = payable(msg.sender).call{value: contributed}("");
        if (!ok) revert EthTransferFailed();

        emit ContributionWithdrawn(presaleId, msg.sender, contributed);
    }

    function _totalAllocated(uint256 presaleId) internal view returns (uint256) {
        Presale storage p = s_presales[presaleId];
        return (p.totalContributed * 1e18) / p.tokenPrice;
    }

    function getPresale(uint256 presaleId) external view returns (Presale memory) {
        return s_presales[presaleId];
    }

    function getContribution(uint256 presaleId, address user) external view returns (uint256) {
        return s_contributions[presaleId][user];
    }

    function getAllocation(uint256 presaleId, address user) external view returns (uint256) {
        return s_allocations[presaleId][user];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerUpdated(old, newOwner);
    }
}
