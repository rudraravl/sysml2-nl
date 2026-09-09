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

interface IInterestBearingToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 0x20), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidAccount(address account);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidAccount(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_owner != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidAccount(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

contract RealWorldAssetVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IInterestBearingToken;

    // ============================================================
    //                          Errors
    // ============================================================
    error ZeroAmount();
    error InsufficientVaultBalance();
    error InsufficientDeposit();
    error RateChangeTooLarge();
    error Unauthorized();
    error InvalidAddress();

    // ============================================================
    //                          Events
    // ============================================================
    event Deposit(address indexed user, uint256 ibtAmount, uint256 vaultTokensMinted);
    event Withdraw(address indexed user, uint256 ibtAmount, uint256 vaultTokensBurned);
    event Redeem(
        address indexed user,
        uint256 principalReturned,
        uint256 interestPaid,
        uint256 vaultTokensBurned
    );
    event InterestRateUpdated(address indexed operator, uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event VaultTransfer(address indexed from, address indexed to, uint256 value);

    // ============================================================
    //                       Constants
    // ============================================================
    uint256 public constant INITIAL_ANNUAL_RATE = 500;
    uint256 public constant MAX_DAILY_RATE_CHANGE = 50;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RATE_WINDOW = 24 hours;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 private constant INDEX_SCALE = 1e18;

    // ============================================================
    //                  Immutable configuration
    // ============================================================
    IInterestBearingToken public immutable interestBearingToken;
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ============================================================
    //                       Access control
    // ============================================================
    address public operator;

    // ============================================================
    //                  Interest rate state
    // ============================================================
    uint256 public annualInterestRate;
    uint256 public rateWindowStart;
    uint256 public rateWindowBaseline;

    // ============================================================
    //                  Global interest index
    // ============================================================
    uint256 public accumulatedRateIndex;
    uint256 public lastRateIndexUpdate;

    // ============================================================
    //                  Vault token accounting
    // ============================================================
    uint256 public totalVaultTokenSupply;
    mapping(address => uint256) public vaultTokenBalanceOf;

    // ============================================================
    //          Per-user deposit & interest accounting
    // ============================================================
    mapping(address => uint256) public userPrincipal;
    mapping(address => uint256) public userIndexSnapshot;
    mapping(address => uint256) public userSettledInterest;

    // ============================================================
    //                        Modifiers
    // ============================================================
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ============================================================
    //                        Constructor
    // ============================================================
    constructor(
        address _interestBearingToken,
        address _operator,
        string memory _name,
        string memory _symbol
    ) Ownable(msg.sender) {
        if (_interestBearingToken == address(0)) revert InvalidAddress();
        if (_interestBearingToken.code.length == 0) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();

        interestBearingToken = IInterestBearingToken(_interestBearingToken);
        operator = _operator;
        name = _name;
        symbol = _symbol;

        annualInterestRate = INITIAL_ANNUAL_RATE;
        rateWindowStart = block.timestamp;
        rateWindowBaseline = INITIAL_ANNUAL_RATE;
        accumulatedRateIndex = INDEX_SCALE;
        lastRateIndexUpdate = block.timestamp;
    }

    // ============================================================
    //              Admin: operator management
    // ============================================================
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    // ============================================================
    //          Admin: interest rate (operator only)
    // ============================================================
    function setInterestRate(uint256 newRate) external onlyOperator {
        if (block.timestamp >= rateWindowStart + RATE_WINDOW) {
            rateWindowStart = block.timestamp;
            rateWindowBaseline = annualInterestRate;
        }

        uint256 diff = newRate > rateWindowBaseline
            ? newRate - rateWindowBaseline
            : rateWindowBaseline - newRate;
        if (diff > MAX_DAILY_RATE_CHANGE) revert RateChangeTooLarge();

        _updateIndex();

        uint256 oldRate = annualInterestRate;
        annualInterestRate = newRate;
        emit InterestRateUpdated(msg.sender, oldRate, newRate);
    }

    // ============================================================
    //       Vault token transfers (also move the principal claim)
    // ============================================================
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        if (to == msg.sender) return true;

        _settle(msg.sender);
        _settle(to);

        uint256 fromBal = vaultTokenBalanceOf[msg.sender];
        if (fromBal < amount) revert InsufficientVaultBalance();

        uint256 fromPrincipal = userPrincipal[msg.sender];
        if (fromPrincipal < amount) revert InsufficientDeposit();

        uint256 settled = userSettledInterest[msg.sender];
        uint256 interestShare = 0;
        if (fromPrincipal > 0 && settled > 0) {
            interestShare = (settled * amount) / fromPrincipal;
        }

        vaultTokenBalanceOf[msg.sender] = fromBal - amount;
        userPrincipal[msg.sender] = fromPrincipal - amount;
        userSettledInterest[msg.sender] = settled - interestShare;

        vaultTokenBalanceOf[to] += amount;
        userPrincipal[to] += amount;
        userSettledInterest[to] += interestShare;

        emit VaultTransfer(msg.sender, to, amount);
        return true;
    }

    // ============================================================
    //         Core: deposit IBT, mint vault tokens 1:1
    // ============================================================
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _settle(msg.sender);

        // Effects: update all state before the external interaction
        // to prevent cross-function reentrancy via userPrincipal reads.
        userPrincipal[msg.sender] += amount;
        vaultTokenBalanceOf[msg.sender] += amount;
        totalVaultTokenSupply += amount;

        // Interaction: pull the interest-bearing tokens from the depositor.
        interestBearingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, amount);
        emit VaultTransfer(address(0), msg.sender, amount);
    }

    // ============================================================
    //      Core: withdraw IBT principal only (interest forfeit)
    // ============================================================
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _settle(msg.sender);

        uint256 principal = userPrincipal[msg.sender];
        uint256 vBal = vaultTokenBalanceOf[msg.sender];
        if (vBal < amount) revert InsufficientVaultBalance();
        if (principal < amount) revert InsufficientDeposit();

        uint256 settled = userSettledInterest[msg.sender];
        if (principal > 0 && settled > 0) {
            uint256 forfeited = (settled * amount) / principal;
            userSettledInterest[msg.sender] = settled - forfeited;
        }

        userPrincipal[msg.sender] = principal - amount;
        vaultTokenBalanceOf[msg.sender] = vBal - amount;
        totalVaultTokenSupply -= amount;

        // Interaction after effects.
        interestBearingToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, amount);
        emit VaultTransfer(msg.sender, address(0), amount);
    }

    // ============================================================
    //  Core: redeem vault tokens for IBT principal + accrued interest
    // ============================================================
    function redeem(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _settle(msg.sender);

        uint256 principal = userPrincipal[msg.sender];
        uint256 vBal = vaultTokenBalanceOf[msg.sender];
        if (vBal < amount) revert InsufficientVaultBalance();
        if (principal < amount) revert InsufficientDeposit();

        uint256 settled = userSettledInterest[msg.sender];
        uint256 interestToPay = 0;
        if (principal > 0 && settled > 0) {
            interestToPay = (settled * amount) / principal;
            userSettledInterest[msg.sender] = settled - interestToPay;
        }

        userPrincipal[msg.sender] = principal - amount;
        vaultTokenBalanceOf[msg.sender] = vBal - amount;
        totalVaultTokenSupply -= amount;

        // Interactions after effects.
        if (interestToPay > 0) {
            interestBearingToken.mint(msg.sender, interestToPay);
        }
        interestBearingToken.safeTransfer(msg.sender, amount);

        emit Redeem(msg.sender, amount, interestToPay, amount);
        emit VaultTransfer(msg.sender, address(0), amount);
    }

    // ============================================================
    //                          Views
    // ============================================================
    function balanceOf(address user) external view returns (uint256) {
        return vaultTokenBalanceOf[user];
    }

    function pendingInterest(address user) public view returns (uint256) {
        uint256 principal = userPrincipal[user];
        if (principal == 0) return 0;
        uint256 idx = _currentIndexView();
        uint256 snap = userIndexSnapshot[user];
        if (idx <= snap) return 0;
        return (principal * (idx - snap)) / INDEX_SCALE;
    }

    function totalInterestAccrued(address user) external view returns (uint256) {
        return userSettledInterest[user] + pendingInterest(user);
    }

    // ============================================================
    //                        Internals
    // ============================================================
    function _updateIndex() internal {
        if (block.timestamp <= lastRateIndexUpdate) return;
        uint256 elapsed = block.timestamp - lastRateIndexUpdate;
        accumulatedRateIndex +=
            (accumulatedRateIndex * annualInterestRate * elapsed) /
            (BASIS_POINTS * SECONDS_PER_YEAR);
        lastRateIndexUpdate = block.timestamp;
    }

    function _currentIndexView() internal view returns (uint256) {
        if (block.timestamp <= lastRateIndexUpdate) return accumulatedRateIndex;
        uint256 elapsed = block.timestamp - lastRateIndexUpdate;
        return
            accumulatedRateIndex +
            ((accumulatedRateIndex * annualInterestRate * elapsed) /
                (BASIS_POINTS * SECONDS_PER_YEAR));
    }

    function _settle(address user) internal {
        _updateIndex();
        uint256 principal = userPrincipal[user];
        if (principal > 0) {
            uint256 snap = userIndexSnapshot[user];
            if (accumulatedRateIndex > snap) {
                uint256 pending = (principal * (accumulatedRateIndex - snap)) /
                    INDEX_SCALE;
                userSettledInterest[user] += pending;
            }
        }
        userIndexSnapshot[user] = accumulatedRateIndex;
    }
}
