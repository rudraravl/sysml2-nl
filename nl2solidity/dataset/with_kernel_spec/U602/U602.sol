// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Recover {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    // ---------------------------------------------------------------------
    // ERC-20 metadata
    // ---------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------
    // ERC-20 state
    // ---------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Staking state
    // ---------------------------------------------------------------------
    /// @notice Ether per liquid staking token, scaled by 1e18.
    ///         Increases over time as staking rewards accrue.
    uint256 public stakingRatio;

    /// @notice Staking fee in basis points (500 = 5%).
    uint256 public stakingFee;

    /// @notice Minimum deposit amount.
    uint256 public constant MIN_DEPOSIT = 0.01 ether;

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant RATIO_DENOMINATOR = 1e18;

    bool public paused;
    address public owner;

    /// @notice Cumulative amount of Ether deposited by each user.
    mapping(address => uint256) public depositedEther;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed user, uint256 etherAmount, uint256 tokenAmount);
    event Withdraw(address indexed user, uint256 tokenAmount, uint256 etherAmount, uint256 fee);
    event StakingRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event StakingFeeUpdated(uint256 oldFee, uint256 newFee);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error EnforcedPause();
    error ExpectedPause();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidRatio();
    error InvalidFee();
    error ZeroAddress();
    error InvalidAmount();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialRatio
    ) {
        if (_initialRatio == 0) revert InvalidRatio();
        name = _name;
        symbol = _symbol;
        stakingRatio = _initialRatio;
        stakingFee = 500; // 5%
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit StakingRatioUpdated(0, _initialRatio);
        emit StakingFeeUpdated(0, 500);
    }

    // ---------------------------------------------------------------------
    // ERC-20 functions
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
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

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = allowance[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientAllowance();
        unchecked {
            uint256 newAllowance = current - subtractedValue;
            allowance[msg.sender][spender] = newAllowance;
            emit Approval(msg.sender, spender, newAllowance);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // ---------------------------------------------------------------------
    // Staking functions
    // ---------------------------------------------------------------------

    /// @notice Deposit Ether and receive liquid staking tokens at the current ratio.
    function deposit() external payable whenNotPaused {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();

        uint256 tokenAmount = (msg.value * RATIO_DENOMINATOR) / stakingRatio;
        if (tokenAmount == 0) revert InvalidAmount();

        depositedEther[msg.sender] += msg.value;
        _mint(msg.sender, tokenAmount);

        emit Deposit(msg.sender, msg.value, tokenAmount);
    }

    /// @notice Redeem liquid staking tokens for staked Ether plus accrued rewards.
    ///         A staking fee is deducted and sent to the owner.
    function redeem(uint256 tokenAmount) external whenNotPaused {
        if (tokenAmount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientBalance();

        // Compute fee with full precision to avoid divide-before-multiply truncation.
        uint256 fee = (tokenAmount * stakingRatio * stakingFee) /
            (RATIO_DENOMINATOR * FEE_DENOMINATOR);
        uint256 etherAmount = (tokenAmount * stakingRatio) / RATIO_DENOMINATOR;
        if (etherAmount == 0) revert InvalidAmount();

        uint256 payout = etherAmount - fee;

        // Effects
        _burn(msg.sender, tokenAmount);

        // Interactions
        if (fee > 0) {
            (bool feeOk, ) = payable(owner).call{value: fee}("");
            if (!feeOk) revert TransferFailed();
        }
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, tokenAmount, payout, fee);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    /// @notice Set the staking fee in basis points (max 10000 = 100%).
    function setStakingFee(uint256 newFee) external onlyOwner {
        if (newFee > FEE_DENOMINATOR) revert InvalidFee();
        emit StakingFeeUpdated(stakingFee, newFee);
        stakingFee = newFee;
    }

    /// @notice Update the global staking ratio (ether per token, scaled by 1e18).
    function setStakingRatio(uint256 newRatio) external onlyOwner {
        if (newRatio == 0) revert InvalidRatio();
        emit StakingRatioUpdated(stakingRatio, newRatio);
        stakingRatio = newRatio;
    }

    /// @notice Pause all deposit and redemption operations.
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Resume deposit and redemption operations.
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /// @notice Recover ERC-20 tokens accidentally sent to this contract.
    ///         Cannot recover the liquid staking token itself.
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        bool ok = IERC20Recover(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit Recovered(token, to, amount);
    }

    // ---------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------

    /// @notice Preview the amount of liquid staking tokens minted for a given Ether deposit.
    function previewDeposit(uint256 etherAmount) external view returns (uint256) {
        return (etherAmount * RATIO_DENOMINATOR) / stakingRatio;
    }

    /// @notice Preview the Ether payout and fee for redeeming a given token amount.
    function previewRedeem(uint256 tokenAmount) external view returns (uint256 payout, uint256 fee) {
        // Compute fee with full precision to avoid divide-before-multiply truncation.
        fee = (tokenAmount * stakingRatio * stakingFee) /
            (RATIO_DENOMINATOR * FEE_DENOMINATOR);
        uint256 etherAmount = (tokenAmount * stakingRatio) / RATIO_DENOMINATOR;
        payout = etherAmount - fee;
    }

    /// @notice Total Ether custodied by the contract.
    function totalEther() external view returns (uint256) {
        return address(this).balance;
    }
}
