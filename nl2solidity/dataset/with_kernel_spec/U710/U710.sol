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

library Address {
    error AddressInsufficientBalance(address account);
    error FailedInnerCall();

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

    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if ((uint256(int256(value))) != value) {
            revert SafeERC20FailedOperation(address(token));
        }
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert SafeERC20FailedOperation(address(token));
            }
        }
    }
}

/**
 * @title NoLossPrizePool
 * @notice Users deposit a base ERC20 asset into a shared pool. Yield accrued on the
 *         pooled assets is periodically collected by an operator and awarded to a
 *         randomly selected eligible depositor. Depositors never lose their principal.
 */
contract NoLossPrizePool {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error DepositTooSmall();
    error InsufficientBalance();
    error RoundStillActive();
    error NotWinner();
    error PrizeAlreadyClaimed();
    error NoEligibleDepositors();
    error InvalidPrizePeriod();
    error ZeroAddress();
    error ZeroAmount();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event YieldAdded(address indexed source, uint256 amount);
    event PrizeRoundStarted(uint256 indexed roundId, uint256 startTime, uint256 yieldCollected);
    event WinnerAnnounced(uint256 indexed roundId, address indexed winner, uint256 prizeAmount);
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event PrizePeriodDurationUpdated(uint256 previousDuration, uint256 newDuration);

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant MAX_PRIZE_PERIOD = 7 days;

    IERC20 public immutable baseAsset;
    address public operator;
    uint256 public prizePeriodDuration;

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    uint256 public totalYield;

    address[] internal _depositors;
    mapping(address => uint256) internal _depositorIndex; // 1-indexed; 0 means not present

    struct Round {
        uint256 startTime;
        uint256 yieldAmount;
        address winner;
        bool claimed;
        bool concluded;
    }

    mapping(uint256 => Round) public rounds;
    uint256 public currentRoundId;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address baseAsset_, uint256 prizePeriodDuration_) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (prizePeriodDuration_ == 0 || prizePeriodDuration_ > MAX_PRIZE_PERIOD) revert InvalidPrizePeriod();
        baseAsset = IERC20(baseAsset_);
        operator = msg.sender;
        prizePeriodDuration = prizePeriodDuration_;
    }

    function setPrizePeriodDuration(uint256 duration) external onlyOperator {
        if (duration == 0 || duration > MAX_PRIZE_PERIOD) revert InvalidPrizePeriod();
        uint256 previous = prizePeriodDuration;
        prizePeriodDuration = duration;
        emit PrizePeriodDurationUpdated(previous, duration);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function addYield(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        totalYield += amount;
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
        emit YieldAdded(msg.sender, amount);
    }

    function deposit(uint256 amount) external {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall();

        if (balances[msg.sender] == 0 && _depositorIndex[msg.sender] == 0) {
            _depositorIndex[msg.sender] = _depositors.length + 1;
            _depositors.push(msg.sender);
        }

        balances[msg.sender] += amount;
        totalDeposits += amount;

        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        uint256 userBalance = balances[msg.sender];
        if (amount > userBalance) revert InsufficientBalance();

        balances[msg.sender] = userBalance - amount;
        totalDeposits -= amount;

        if (balances[msg.sender] == 0) {
            _removeDepositor(msg.sender);
        }

        baseAsset.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function _removeDepositor(address user) internal {
        uint256 idx = _depositorIndex[user];
        if (idx == 0) return;

        uint256 lastIndex = _depositors.length - 1;
        if (idx - 1 != lastIndex) {
            address lastUser = _depositors[lastIndex];
            _depositors[idx - 1] = lastUser;
            _depositorIndex[lastUser] = idx;
        }
        _depositors.pop();
        delete _depositorIndex[user];
    }

    function startPrizeRound() external onlyOperator {
        if (currentRoundId > 0) {
            Round storage previous = rounds[currentRoundId];
            if (!previous.concluded) {
                if (block.timestamp < previous.startTime + prizePeriodDuration) {
                    revert RoundStillActive();
                }
                if (!previous.claimed) {
                    totalYield += previous.yieldAmount;
                }
                previous.concluded = true;
            }
        }

        if (totalYield == 0) revert NoEligibleDepositors();

        uint256 yieldAmount = totalYield;
        totalYield = 0;

        address winner = _selectWinner();

        uint256 newRoundId = currentRoundId + 1;
        rounds[newRoundId] = Round({
            startTime: block.timestamp,
            yieldAmount: yieldAmount,
            winner: winner,
            claimed: false,
            concluded: false
        });
        currentRoundId = newRoundId;

        emit PrizeRoundStarted(newRoundId, block.timestamp, yieldAmount);
        emit WinnerAnnounced(newRoundId, winner, yieldAmount);
    }

    function _selectWinner() internal view returns (address) {
        uint256 count = _depositors.length;
        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < count; i++) {
            if (balances[_depositors[i]] >= MIN_DEPOSIT) {
                eligibleCount++;
            }
        }
        if (eligibleCount == 0) revert NoEligibleDepositors();

        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    totalDeposits,
                    eligibleCount,
                    currentRoundId
                )
            )
        );
        uint256 pick = seed % eligibleCount;

        uint256 seen = 0;
        for (uint256 i = 0; i < count; i++) {
            if (balances[_depositors[i]] >= MIN_DEPOSIT) {
                if (seen == pick) {
                    return _depositors[i];
                }
                unchecked {
                    seen++;
                }
            }
        }
        revert NoEligibleDepositors();
    }

    function claimPrize(uint256 roundId) external {
        Round storage round = rounds[roundId];
        if (msg.sender != round.winner) revert NotWinner();
        if (round.claimed) revert PrizeAlreadyClaimed();

        round.claimed = true;
        round.concluded = true;

        uint256 prize = round.yieldAmount;
        baseAsset.safeTransfer(msg.sender, prize);

        emit PrizeClaimed(roundId, msg.sender, prize);
    }

    function getDepositorsCount() external view returns (uint256) {
        return _depositors.length;
    }

    function getDepositorAt(uint256 index) external view returns (address) {
        return _depositors[index];
    }

    function getRound(uint256 roundId)
        external
        view
        returns (
            uint256 startTime,
            uint256 yieldAmount,
            address winner,
            bool claimed,
            bool concluded
        )
    {
        Round storage r = rounds[roundId];
        return (r.startTime, r.yieldAmount, r.winner, r.claimed, r.concluded);
    }

    function isEligible(address user) external view returns (bool) {
        return balances[user] >= MIN_DEPOSIT;
    }
}
