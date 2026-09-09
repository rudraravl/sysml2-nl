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

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ReentrancyGuard {
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

contract TokenLaunch is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum LaunchState { Inactive, Active, Finalized, Cancelled }

    uint256 public constant WAD = 1e18;
    uint256 public constant MIN_DEPOSIT = 100;
    uint16 public constant FEE_BPS = 500;
    uint16 public constant BPS_DENOM = 10000;

    error Unauthorized();
    error InvalidState(LaunchState current);
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error LaunchWindowClosed(uint40 endTime);
    error LaunchNotEnded(uint40 endTime, uint40 currentTime);
    error MinRaiseNotMet(uint256 raised, uint256 minimum);
    error MinRaiseExceeded(uint256 raised, uint256 minimum);
    error InsufficientDeposit(uint256 available, uint256 requested);
    error NothingToClaim();
    error NothingToTransfer();
    error NothingToSweep();
    error InvalidParams();
    error ZeroAddress();
    error AmountZero();

    event BondingCurveUpdated(uint256 basePrice, uint256 slope);
    event Deposited(address indexed user, uint256 baseAmount, uint256 tokensAllocated);
    event Withdrawn(address indexed user, uint256 baseAmount, uint256 fee, bool launchConcluded);
    event TokensClaimed(address indexed user, uint256 tokenAmount);
    event LaunchStateChanged(LaunchState previousState, LaunchState newState);
    event LaunchInitiated(uint40 endTime, uint256 targetMinRaise);
    event LaunchFinalized(uint256 totalRaised, uint256 totalTokensAllocated);
    event LaunchCancelled(uint256 totalRaised);
    event FundsTransferred(address indexed recipient, uint256 amount);
    event FeesSwept(address indexed recipient, uint256 amount);
    event OperatorUpdated(address previousOperator, address newOperator);
    event RecipientUpdated(address previousRecipient, address newRecipient);

    IERC20 public immutable baseToken;
    address public immutable projectToken;

    address public operator;
    address public recipient;

    LaunchState public state;
    uint256 public basePrice;
    uint256 public slope;
    uint256 public targetMinRaise;
    uint40 public launchEnd;

    uint256 public totalRaised;
    uint256 public tokensSold;
    uint256 public totalAllocated;
    uint256 public totalFees;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public allocations;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier inState(LaunchState expected) {
        if (state != expected) revert InvalidState(state);
        _;
    }

    constructor(
        address _baseToken,
        address _projectToken,
        address _operator,
        address _recipient
    ) Ownable(msg.sender) ReentrancyGuard() {
        if (_baseToken == address(0) || _projectToken == address(0) || _operator == address(0) || _recipient == address(0)) {
            revert ZeroAddress();
        }

        baseToken = IERC20(_baseToken);
        projectToken = _projectToken;
        operator = _operator;
        recipient = _recipient;
        state = LaunchState.Inactive;

        emit OperatorUpdated(address(0), _operator);
        emit RecipientUpdated(address(0), _recipient);
    }

    function setBondingCurve(uint256 _basePrice, uint256 _slope) external onlyOperator inState(LaunchState.Inactive) {
        if (_basePrice == 0) revert InvalidParams();
        basePrice = _basePrice;
        slope = _slope;
        emit BondingCurveUpdated(_basePrice, _slope);
    }

    function initiateLaunch(uint256 _targetMinRaise, uint40 _duration) external onlyOperator inState(LaunchState.Inactive) {
        if (_duration == 0) revert InvalidParams();
        if (basePrice == 0) revert InvalidParams();
        targetMinRaise = _targetMinRaise;
        launchEnd = uint40(block.timestamp) + _duration;

        LaunchState prev = state;
        state = LaunchState.Active;

        emit LaunchInitiated(launchEnd, _targetMinRaise);
        emit LaunchStateChanged(prev, LaunchState.Active);
    }

    function finalizeLaunch() external nonReentrant inState(LaunchState.Active) {
        if (block.timestamp < launchEnd) {
            if (msg.sender != operator) revert Unauthorized();
        }

        LaunchState prev = state;

        if (totalRaised >= targetMinRaise) {
            state = LaunchState.Finalized;

            uint256 tokensToMint = totalAllocated;
            if (tokensToMint > 0) {
                IMintableERC20(projectToken).mint(address(this), tokensToMint);
            }

            emit LaunchFinalized(totalRaised, tokensToMint);
            emit LaunchStateChanged(prev, LaunchState.Finalized);
        } else {
            state = LaunchState.Cancelled;

            emit LaunchCancelled(totalRaised);
            emit LaunchStateChanged(prev, LaunchState.Cancelled);
        }
    }

    function transferRaised() external onlyOperator nonReentrant inState(LaunchState.Finalized) {
        uint256 amount = totalRaised;
        if (amount == 0) revert NothingToTransfer();

        totalRaised = 0;
        baseToken.safeTransfer(recipient, amount);

        emit FundsTransferred(recipient, amount);
    }

    function sweepFees() external onlyOperator nonReentrant {
        uint256 amount = totalFees;
        if (amount == 0) revert NothingToSweep();

        totalFees = 0;
        baseToken.safeTransfer(recipient, amount);

        emit FeesSwept(recipient, amount);
    }

    function currentPrice() public view returns (uint256) {
        return basePrice + (slope * tokensSold) / WAD;
    }

    function quote(uint256 amount) public view returns (uint256) {
        if (amount == 0) return 0;
        return (amount * WAD) / currentPrice();
    }

    function deposit(uint256 amount) external nonReentrant inState(LaunchState.Active) {
        if (block.timestamp >= launchEnd) revert LaunchWindowClosed(launchEnd);
        if (amount == 0) revert AmountZero();
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        uint256 price = currentPrice();
        if (price == 0) revert InvalidParams();
        uint256 tokensToMint = (amount * WAD) / price;
        if (tokensToMint == 0) revert InvalidParams();

        deposits[msg.sender] += amount;
        totalRaised += amount;
        tokensSold += tokensToMint;
        totalAllocated += tokensToMint;
        allocations[msg.sender] += tokensToMint;

        baseToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount, tokensToMint);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        uint256 available = deposits[msg.sender];
        if (available < amount) revert InsufficientDeposit(available, amount);

        LaunchState st = state;

        if (st == LaunchState.Active) {
            uint256 fee = (amount * FEE_BPS) / BPS_DENOM;
            uint256 payout = amount - fee;

            uint256 tokensToRemove = (allocations[msg.sender] * amount) / available;

            deposits[msg.sender] = available - amount;
            totalRaised -= amount;
            totalFees += fee;
            allocations[msg.sender] -= tokensToRemove;
            totalAllocated -= tokensToRemove;

            baseToken.safeTransfer(msg.sender, payout);
            emit Withdrawn(msg.sender, payout, fee, false);
        } else if (st == LaunchState.Cancelled) {
            deposits[msg.sender] = available - amount;
            totalRaised -= amount;

            baseToken.safeTransfer(msg.sender, amount);
            emit Withdrawn(msg.sender, amount, 0, true);
        } else {
            revert InvalidState(st);
        }
    }

    function claimTokens() external nonReentrant inState(LaunchState.Finalized) {
        uint256 alloc = allocations[msg.sender];
        if (alloc == 0) revert NothingToClaim();

        allocations[msg.sender] = 0;
        IERC20(projectToken).safeTransfer(msg.sender, alloc);

        emit TokensClaimed(msg.sender, alloc);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit RecipientUpdated(recipient, newRecipient);
        recipient = newRecipient;
    }

    function userAllocation(address user) external view returns (uint256) {
        return allocations[user];
    }

    function userDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }
}
