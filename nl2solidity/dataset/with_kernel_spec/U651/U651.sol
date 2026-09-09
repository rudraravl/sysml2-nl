// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract LiquidStakingDerivative {
    // ---------- Custom errors ----------
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error ZeroAddress();
    error ExceedsMaxDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidRate();
    error NotUnbonded();
    error InvalidIndex();
    error AlreadyClaimed();
    error TransferFailed();
    error ReentrantCall();
    error EthNotAccepted();

    // ---------- Constants ----------
    uint256 public constant UNBONDING_PERIOD = 24 hours;
    uint256 public constant RATE_DENOMINATOR = 1e18;

    // ---------- Immutables ----------
    IERC20 public immutable baseAsset;
    uint8 public immutable baseAssetDecimals;
    uint256 public immutable maxDeposit; // 1000 base units scaled by token decimals

    // ---------- State ----------
    address public owner;
    address public operator;
    bool public paused;

    uint256 public stakingRate; // base asset per receipt token, scaled by 1e18
    uint256 public totalSupply; // total receipt tokens minted
    uint256 public totalStaked; // total base assets custodied

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct Redemption {
        uint256 baseAmount;
        uint256 unlockTime;
        bool claimed;
    }

    mapping(address => Redemption[]) internal pendingRedemptions;

    // Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // ---------- Events ----------
    event Deposit(address indexed caller, address indexed receiver, uint256 baseAmount, uint256 receiptAmount);
    event RedeemRequested(address indexed caller, address indexed receiver, uint256 receiptAmount, uint256 baseAmount, uint256 unlockTime, uint256 index);
    event RedeemClaimed(address indexed receiver, uint256 index, uint256 baseAmount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------- Constructor ----------
    constructor(
        address baseAsset_,
        address operator_,
        uint256 initialRate_,
        string memory name_,
        string memory symbol_
    ) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (initialRate_ == 0) revert InvalidRate();

        baseAsset = IERC20(baseAsset_);
        owner = msg.sender;
        operator = operator_;
        stakingRate = initialRate_;
        name = name_;
        symbol = symbol_;
        _status = _NOT_ENTERED;

        // Retrieve base token decimals defensively.
        (bool success, bytes memory data) = baseAsset_.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (success && data.length >= 32) {
            uint256 decoded = abi.decode(data, (uint256));
            if (decoded <= type(uint8).max) {
                baseAssetDecimals = uint8(decoded);
            } else {
                baseAssetDecimals = 18;
            }
        } else {
            baseAssetDecimals = 18;
        }

        // Max deposit is 1000 base units, scaled by the base asset's decimals.
        maxDeposit = 1000 * (10 ** uint256(baseAssetDecimals));

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
        emit RateUpdated(0, initialRate_);
    }

    // ---------- Admin ----------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setStakingRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = stakingRate;
        stakingRate = newRate;
        emit RateUpdated(oldRate, newRate);
    }

    // ---------- ERC20-like receipt token ----------
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    // ---------- Staking operations ----------
    function deposit(uint256 baseAmount, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 receiptAmount)
    {
        if (baseAmount == 0) revert ZeroAmount();
        if (baseAmount > maxDeposit) revert ExceedsMaxDeposit();
        if (receiver == address(0)) revert ZeroAddress();

        // Receipt tokens are minted 1:1 with the base asset on deposit.
        // Yield accrues via the staking rate applied at redemption time.
        receiptAmount = baseAmount;

        // Effects first (checks-effects-interactions).
        totalStaked += baseAmount;
        totalSupply += receiptAmount;
        balanceOf[receiver] += receiptAmount;

        // Interactions: pull base asset from caller.
        bool ok = baseAsset.transferFrom(msg.sender, address(this), baseAmount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, receiver, baseAmount, receiptAmount);
        emit Transfer(address(0), receiver, receiptAmount);
    }

    function requestRedeem(uint256 receiptAmount, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 index)
    {
        if (receiptAmount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < receiptAmount) revert InsufficientBalance();

        // Base asset owed = receiptAmount * stakingRate / RATE_DENOMINATOR
        uint256 baseAmount = (receiptAmount * stakingRate) / RATE_DENOMINATOR;
        if (baseAmount == 0) revert ZeroAmount();

        // Burn receipt tokens.
        unchecked {
            balanceOf[msg.sender] = senderBalance - receiptAmount;
            totalSupply -= receiptAmount;
        }

        // Queue redemption with unbonding period.
        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        index = pendingRedemptions[receiver].length;
        pendingRedemptions[receiver].push(
            Redemption({
                baseAmount: baseAmount,
                unlockTime: unlockTime,
                claimed: false
            })
        );

        emit Transfer(msg.sender, address(0), receiptAmount);
        emit RedeemRequested(msg.sender, receiver, receiptAmount, baseAmount, unlockTime, index);
    }

    function claimRedeem(uint256 index) external nonReentrant {
        Redemption[] storage queue = pendingRedemptions[msg.sender];
        if (index >= queue.length) revert InvalidIndex();

        Redemption storage r = queue[index];
        if (r.claimed) revert AlreadyClaimed();
        if (block.timestamp < r.unlockTime) revert NotUnbonded();

        // Effects.
        r.claimed = true;
        uint256 baseAmount = r.baseAmount;
        totalStaked -= baseAmount;

        // Interactions.
        bool ok = baseAsset.transfer(msg.sender, baseAmount);
        if (!ok) revert TransferFailed();

        emit RedeemClaimed(msg.sender, index, baseAmount);

        // Compact the queue: swap with last and pop.
        uint256 lastIndex = queue.length - 1;
        if (index != lastIndex) {
            queue[index] = queue[lastIndex];
        }
        queue.pop();
    }

    // ---------- Views ----------
    function pendingRedemptionCount(address account) external view returns (uint256) {
        return pendingRedemptions[account].length;
    }

    function pendingRedemption(address account, uint256 index)
        external
        view
        returns (uint256 baseAmount, uint256 unlockTime, bool claimed)
    {
        if (index >= pendingRedemptions[account].length) revert InvalidIndex();
        Redemption storage r = pendingRedemptions[account][index];
        return (r.baseAmount, r.unlockTime, r.claimed);
    }

    function previewRedeem(uint256 receiptAmount) external view returns (uint256 baseAmount) {
        return (receiptAmount * stakingRate) / RATE_DENOMINATOR;
    }

    function previewDeposit(uint256 baseAmount) external pure returns (uint256 receiptAmount) {
        return baseAmount;
    }

    // ---------- Reject direct ETH and unknown calls ----------
    fallback() external {
        revert EthNotAccepted();
    }
}
