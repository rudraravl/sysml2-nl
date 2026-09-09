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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            } else {
                revert("SafeERC20: call failed");
            }
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: operation did not succeed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            } else {
                revert("SafeERC20: call failed");
            }
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address oldOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
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
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum SaleStatus {
        Active,
        Success,
        Failed
    }

    struct Sale {
        address saleToken;
        address paymentToken;
        uint256 tokensPerUnit; // sale tokens per 1 payment token, scaled by 1e18
        uint64 startTime;
        uint64 endTime;
        uint256 minTarget; // minimum total raised for sale to succeed
        uint256 maxTarget; // hard cap on total raised
        uint256 totalRaised; // total payment tokens raised so far
        uint256 tokensAllocated; // sale tokens reserved for this sale
        SaleStatus status;
        bool ownerFundsWithdrawn;
    }

    struct UserAllocation {
        uint256 amount; // payment tokens contributed by the user
        bool settled; // whether the user has claimed or refunded
    }

    uint256 public constant MIN_PURCHASE = 100e18;
    uint256 public constant MAX_ALLOCATION = 10_000e18;
    uint256 private constant SCALE = 1e18;

    uint256 public nextSaleId = 1;
    uint256[] public activeSaleIds;
    mapping(uint256 => Sale) public sales;
    mapping(uint256 => mapping(address => UserAllocation)) public userAllocations;
    mapping(uint256 => uint256) private _activeIndex;

    event SaleCreated(
        uint256 indexed saleId,
        address indexed saleToken,
        address indexed paymentToken,
        uint64 startTime,
        uint64 endTime,
        uint256 minTarget,
        uint256 maxTarget,
        uint256 tokensPerUnit,
        uint256 tokensAllocated
    );
    event SaleParametersUpdated(
        uint256 indexed saleId,
        uint64 startTime,
        uint64 endTime,
        uint256 minTarget,
        uint256 maxTarget,
        uint256 tokensPerUnit
    );
    event Participated(uint256 indexed saleId, address indexed user, uint256 amount);
    event Claimed(uint256 indexed saleId, address indexed user, uint256 saleTokenAmount);
    event Refunded(uint256 indexed saleId, address indexed user, uint256 paymentTokenAmount);
    event SaleFinalized(uint256 indexed saleId, bool success, uint256 totalRaised);
    event OwnerFundsWithdrawn(
        uint256 indexed saleId,
        address indexed owner,
        uint256 paymentAmount,
        uint256 unsoldTokenAmount
    );

    error ZeroAddress();
    error InvalidTimeRange();
    error InvalidTargets();
    error InvalidTokensPerUnit();
    error SaleNotFound(uint256 saleId);
    error SaleNotActive(uint256 saleId);
    error SaleAlreadyFinalized(uint256 saleId);
    error SaleAlreadyStarted(uint256 saleId);
    error SaleNotStarted(uint256 saleId);
    error SaleNotEnded(uint256 saleId);
    error SaleNotFailed(uint256 saleId);
    error SaleNotSuccessful(uint256 saleId);
    error BelowMinPurchase();
    error ExceedsMaxAllocation();
    error ExceedsMaxTarget();
    error AlreadySettled(uint256 saleId, address user);
    error OwnerFundsAlreadyWithdrawn(uint256 saleId);
    error NothingToClaim();
    error NothingToRefund();

    constructor() Ownable(msg.sender) {}

    function createSale(
        address saleToken,
        address paymentToken,
        uint256 tokensPerUnit,
        uint64 startTime,
        uint64 endTime,
        uint256 minTarget,
        uint256 maxTarget
    ) external onlyOwner returns (uint256 saleId) {
        if (saleToken == address(0) || paymentToken == address(0)) revert ZeroAddress();
        if (startTime <= block.timestamp) revert InvalidTimeRange();
        if (endTime <= startTime) revert InvalidTimeRange();
        if (minTarget == 0 || maxTarget < minTarget) revert InvalidTargets();
        if (maxTarget < MIN_PURCHASE) revert InvalidTargets();
        if (tokensPerUnit == 0) revert InvalidTokensPerUnit();

        saleId = nextSaleId++;
        uint256 tokensNeeded = (maxTarget * tokensPerUnit) / SCALE;
        if ((maxTarget * tokensPerUnit) % SCALE != 0) {
            tokensNeeded += 1;
        }

        sales[saleId] = Sale({
            saleToken: saleToken,
            paymentToken: paymentToken,
            tokensPerUnit: tokensPerUnit,
            startTime: startTime,
            endTime: endTime,
            minTarget: minTarget,
            maxTarget: maxTarget,
            totalRaised: 0,
            tokensAllocated: tokensNeeded,
            status: SaleStatus.Active,
            ownerFundsWithdrawn: false
        });

        activeSaleIds.push(saleId);
        _activeIndex[saleId] = activeSaleIds.length - 1;

        IERC20(saleToken).safeTransferFrom(msg.sender, address(this), tokensNeeded);

        emit SaleCreated(
            saleId,
            saleToken,
            paymentToken,
            startTime,
            endTime,
            minTarget,
            maxTarget,
            tokensPerUnit,
            tokensNeeded
        );
    }

    function updateSaleParameters(
        uint256 saleId,
        uint64 startTime,
        uint64 endTime,
        uint256 minTarget,
        uint256 maxTarget,
        uint256 tokensPerUnit
    ) external onlyOwner nonReentrant {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status != SaleStatus.Active) revert SaleNotActive(saleId);
        if (block.timestamp >= sale.startTime) revert SaleAlreadyStarted(saleId);
        if (startTime <= block.timestamp) revert InvalidTimeRange();
        if (endTime <= startTime) revert InvalidTimeRange();
        if (minTarget == 0 || maxTarget < minTarget) revert InvalidTargets();
        if (maxTarget < MIN_PURCHASE) revert InvalidTargets();
        if (tokensPerUnit == 0) revert InvalidTokensPerUnit();

        uint256 newTokensNeeded = (maxTarget * tokensPerUnit) / SCALE;
        if ((maxTarget * tokensPerUnit) % SCALE != 0) {
            newTokensNeeded += 1;
        }

        uint256 currentAllocated = sale.tokensAllocated;
        uint256 transferIn = 0;
        uint256 transferOut = 0;
        if (newTokensNeeded > currentAllocated) {
            transferIn = newTokensNeeded - currentAllocated;
        } else if (newTokensNeeded < currentAllocated) {
            transferOut = currentAllocated - newTokensNeeded;
        }

        // Effects: update all state before any external calls
        sale.startTime = startTime;
        sale.endTime = endTime;
        sale.minTarget = minTarget;
        sale.maxTarget = maxTarget;
        sale.tokensPerUnit = tokensPerUnit;
        sale.tokensAllocated = newTokensNeeded;

        // Interactions: perform token movements after state is consistent
        if (transferIn > 0) {
            IERC20(sale.saleToken).safeTransferFrom(msg.sender, address(this), transferIn);
        } else if (transferOut > 0) {
            IERC20(sale.saleToken).safeTransfer(msg.sender, transferOut);
        }

        emit SaleParametersUpdated(saleId, startTime, endTime, minTarget, maxTarget, tokensPerUnit);
    }

    function participate(uint256 saleId, uint256 amount) external nonReentrant {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status != SaleStatus.Active) revert SaleNotActive(saleId);
        if (block.timestamp < sale.startTime) revert SaleNotStarted(saleId);
        if (block.timestamp >= sale.endTime) revert SaleNotEnded(saleId);
        if (amount < MIN_PURCHASE) revert BelowMinPurchase();

        UserAllocation storage userAlloc = userAllocations[saleId][msg.sender];
        if (userAlloc.amount + amount > MAX_ALLOCATION) revert ExceedsMaxAllocation();
        if (sale.totalRaised + amount > sale.maxTarget) revert ExceedsMaxTarget();

        userAlloc.amount += amount;
        sale.totalRaised += amount;

        IERC20(sale.paymentToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Participated(saleId, msg.sender, amount);
    }

    function finalize(uint256 saleId) external {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status != SaleStatus.Active) revert SaleAlreadyFinalized(saleId);
        if (block.timestamp < sale.endTime) revert SaleNotEnded(saleId);
        _finalize(saleId);
    }

    function _finalize(uint256 saleId) internal {
        Sale storage sale = sales[saleId];
        if (sale.status != SaleStatus.Active) return;
        if (block.timestamp < sale.endTime) return;

        bool success = sale.totalRaised >= sale.minTarget;
        sale.status = success ? SaleStatus.Success : SaleStatus.Failed;

        uint256 idx = _activeIndex[saleId];
        uint256 lastIdx = activeSaleIds.length - 1;
        if (idx != lastIdx) {
            uint256 lastId = activeSaleIds[lastIdx];
            activeSaleIds[idx] = lastId;
            _activeIndex[lastId] = idx;
        }
        activeSaleIds.pop();
        delete _activeIndex[saleId];

        emit SaleFinalized(saleId, success, sale.totalRaised);
    }

    function claim(uint256 saleId) external nonReentrant {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status == SaleStatus.Active) {
            if (block.timestamp < sale.endTime) revert SaleNotEnded(saleId);
            _finalize(saleId);
        }
        if (sale.status != SaleStatus.Success) revert SaleNotSuccessful(saleId);

        UserAllocation storage userAlloc = userAllocations[saleId][msg.sender];
        if (userAlloc.amount == 0) revert NothingToClaim();
        if (userAlloc.settled) revert AlreadySettled(saleId, msg.sender);

        uint256 saleTokenAmount = (userAlloc.amount * sale.tokensPerUnit) / SCALE;
        userAlloc.settled = true;

        IERC20(sale.saleToken).safeTransfer(msg.sender, saleTokenAmount);

        emit Claimed(saleId, msg.sender, saleTokenAmount);
    }

    function withdrawFailed(uint256 saleId) external nonReentrant {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status == SaleStatus.Active) {
            if (block.timestamp < sale.endTime) revert SaleNotEnded(saleId);
            _finalize(saleId);
        }
        if (sale.status != SaleStatus.Failed) revert SaleNotFailed(saleId);

        UserAllocation storage userAlloc = userAllocations[saleId][msg.sender];
        if (userAlloc.amount == 0) revert NothingToRefund();
        if (userAlloc.settled) revert AlreadySettled(saleId, msg.sender);

        uint256 refundAmount = userAlloc.amount;
        userAlloc.settled = true;

        IERC20(sale.paymentToken).safeTransfer(msg.sender, refundAmount);

        emit Refunded(saleId, msg.sender, refundAmount);
    }

    function withdrawFunds(uint256 saleId) external onlyOwner nonReentrant {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        if (sale.status == SaleStatus.Active) {
            if (block.timestamp < sale.endTime) revert SaleNotEnded(saleId);
            _finalize(saleId);
        }
        if (sale.status != SaleStatus.Success) revert SaleNotSuccessful(saleId);
        if (sale.ownerFundsWithdrawn) revert OwnerFundsAlreadyWithdrawn(saleId);

        sale.ownerFundsWithdrawn = true;

        uint256 paymentAmount = sale.totalRaised;
        uint256 soldTokens = (sale.totalRaised * sale.tokensPerUnit) / SCALE;
        uint256 unsoldTokens = sale.tokensAllocated - soldTokens;

        if (paymentAmount > 0) {
            IERC20(sale.paymentToken).safeTransfer(msg.sender, paymentAmount);
        }
        if (unsoldTokens > 0) {
            IERC20(sale.saleToken).safeTransfer(msg.sender, unsoldTokens);
        }

        emit OwnerFundsWithdrawn(saleId, msg.sender, paymentAmount, unsoldTokens);
    }

    function getActiveSaleIds() external view returns (uint256[] memory) {
        return activeSaleIds;
    }

    function getActiveSaleCount() external view returns (uint256) {
        return activeSaleIds.length;
    }

    function getSale(uint256 saleId) external view returns (Sale memory) {
        if (sales[saleId].saleToken == address(0)) revert SaleNotFound(saleId);
        return sales[saleId];
    }

    function getUserAllocation(
        uint256 saleId,
        address user
    ) external view returns (uint256 amount, bool settled) {
        UserAllocation storage ua = userAllocations[saleId][user];
        return (ua.amount, ua.settled);
    }

    function pendingSaleTokens(uint256 saleId, address user) external view returns (uint256) {
        Sale storage sale = sales[saleId];
        if (sale.saleToken == address(0)) revert SaleNotFound(saleId);
        UserAllocation storage ua = userAllocations[saleId][user];
        if (ua.amount == 0) return 0;
        if (sale.status != SaleStatus.Success) return 0;
        return (ua.amount * sale.tokensPerUnit) / SCALE;
    }
}
