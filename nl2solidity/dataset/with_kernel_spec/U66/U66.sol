// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStaking
 * @notice A liquid staking contract that mints a synthetic ERC20 token representing
 *         native assets staked on an external ledger. Users deposit native assets to
 *         mint synthetic tokens 1:1, redeem synthetic tokens to initiate unstaking on
 *         the external ledger, and claim native assets once the operator confirms the
 *         unstake has completed. A 0.5% fee is charged on redemptions and accrued to
 *         the contract, withdrawable by the owner.
 */
contract LiquidStaking {
    /* ================================================================== */
    /* ERC20 Metadata                                                     */
    /* ================================================================== */
    string public constant name = "Liquid Staked Asset";
    string public constant symbol = "lsASSET";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* ================================================================== */
    /* Staking / Ledger State                                             */
    /* ================================================================== */
    /// @notice Native assets deposited per user (gross, before any redemption).
    mapping(address => uint256) public stakedBalance;

    /// @notice Total native assets reported as locked on the external ledger.
    uint256 public totalAssetsLocked;

    /// @notice Total native assets reserved in-contract for pending unstake claims.
    uint256 public totalPendingUnstake;

    /// @notice Total fees accrued from redemptions, withdrawable by the owner.
    uint256 public accumulatedFees;

    /// @notice Per-user unstake requests.
    struct UnstakeRequest {
        uint256 nativeAmount; // native assets to return (net of fee)
        uint256 feeAmount;    // fee retained by the contract
        bool claimable;       // operator confirms external unstake completed
        bool claimed;         // user has claimed the native assets
    }
    mapping(address => UnstakeRequest[]) public unstakeRequests;

    /* ================================================================== */
    /* Constants                                                          */
    /* ================================================================== */
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant FEE_BIPS = 50; // 0.5%
    uint256 public constant BIPS_DENOMINATOR = 10_000;

    /* ================================================================== */
    /* Access Control                                                     */
    /* ================================================================== */
    address public owner;
    address public operator;

    /* ================================================================== */
    /* Re-entrancy Guard                                                  */
    /* ================================================================== */
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ErrReentrant();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    /* ================================================================== */
    /* Events                                                             */
    /* ================================================================== */
    event Deposit(address indexed user, uint256 nativeAmount, uint256 mintedTokens);
    event Redemption(
        address indexed user,
        uint256 tokenAmount,
        uint256 nativeAmount,
        uint256 feeAmount,
        uint256 requestIndex
    );
    event UnstakeClaimable(address indexed user, uint256 requestIndex);
    event UnstakeClaimed(address indexed user, uint256 requestIndex, uint256 nativeAmount);
    event TotalAssetsLockedUpdated(uint256 oldAmount, uint256 newAmount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /* ================================================================== */
    /* Errors                                                             */
    /* ================================================================== */
    error ErrZeroAddress();
    error ErrInsufficientDeposit();
    error ErrInsufficientBalance();
    error ErrInsufficientAllowance();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrNotClaimable();
    error ErrAlreadyClaimed();
    error ErrNoPendingRequest();
    error ErrAmountZero();
    error ErrReentrant();
    error ErrTransferFailed();
    error ErrInsufficientContractBalance();

    /* ================================================================== */
    /* Constructor                                                        */
    /* ================================================================== */
    constructor(address _operator) {
        if (_operator == address(0)) revert ErrZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    /* ================================================================== */
    /* ERC20 — Internal Helpers                                           */
    /* ================================================================== */
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert ErrInsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ErrZeroAddress();
        if (balanceOf[from] < amount) revert ErrInsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    /* ================================================================== */
    /* ERC20 — Public Interface                                           */
    /* ================================================================== */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ErrZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert ErrInsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    /* ================================================================== */
    /* Staking — Deposit native assets and mint synthetic tokens 1:1     */
    /* ================================================================== */
    function deposit() external payable {
        if (msg.value < MIN_DEPOSIT) revert ErrInsufficientDeposit();

        stakedBalance[msg.sender] += msg.value;
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value, msg.value);
    }

    /* ================================================================== */
    /* Staking — Redeem synthetic tokens to initiate external unstaking  */
    /* ================================================================== */
    function redeem(uint256 tokenAmount) external nonReentrant {
        if (tokenAmount == 0) revert ErrAmountZero();
        if (balanceOf[msg.sender] < tokenAmount) revert ErrInsufficientBalance();

        // Burn synthetic tokens first (checks-effects)
        _burn(msg.sender, tokenAmount);

        // Compute 0.5% fee on the redeemed native-equivalent amount
        uint256 fee = (tokenAmount * FEE_BIPS) / BIPS_DENOMINATOR;
        uint256 nativeAmount = tokenAmount - fee;

        // Record the unstake request
        uint256 requestIndex = unstakeRequests[msg.sender].length;
        unstakeRequests[msg.sender].push(
            UnstakeRequest({
                nativeAmount: nativeAmount,
                feeAmount: fee,
                claimable: false,
                claimed: false
            })
        );

        // Reserve native assets for the future claim and accrue the fee
        totalPendingUnstake += nativeAmount;
        accumulatedFees += fee;

        emit Redemption(msg.sender, tokenAmount, nativeAmount, fee, requestIndex);
    }

    /* ================================================================== */
    /* Operator — Mark an unstake request as claimable once the external  */
    /* ledger confirms the unstake has completed.                         */
    /* ================================================================== */
    function setUnstakeClaimable(address user, uint256 requestIndex) external onlyOperator {
        if (user == address(0)) revert ErrZeroAddress();
        if (requestIndex >= unstakeRequests[user].length) revert ErrNoPendingRequest();

        UnstakeRequest storage req = unstakeRequests[user][requestIndex];
        if (req.claimed) revert ErrAlreadyClaimed();
        req.claimable = true;

        emit UnstakeClaimable(user, requestIndex);
    }

    /* ================================================================== */
    /* Staking — Claim native assets once the request is claimable        */
    /* ================================================================== */
    function claimUnstake(uint256 requestIndex) external nonReentrant {
        if (requestIndex >= unstakeRequests[msg.sender].length) revert ErrNoPendingRequest();

        UnstakeRequest storage req = unstakeRequests[msg.sender][requestIndex];
        if (!req.claimable) revert ErrNotClaimable();
        if (req.claimed) revert ErrAlreadyClaimed();

        // Effects
        req.claimed = true;
        uint256 amount = req.nativeAmount;
        totalPendingUnstake -= amount;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert ErrTransferFailed();

        emit UnstakeClaimed(msg.sender, requestIndex, amount);
    }

    /* ================================================================== */
    /* Operator — Update total assets locked on the external ledger       */
    /* ================================================================== */
    function updateTotalAssetsLocked(uint256 newAmount) external onlyOperator {
        uint256 old = totalAssetsLocked;
        totalAssetsLocked = newAmount;
        emit TotalAssetsLockedUpdated(old, newAmount);
    }

    /* ================================================================== */
    /* Admin — Operator & Ownership Management, Fee Withdrawal           */
    /* ================================================================== */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ErrAmountZero();
        if (address(this).balance < amount) revert ErrInsufficientContractBalance();

        accumulatedFees = 0;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert ErrTransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /* ================================================================== */
    /* Views                                                              */
    /* ================================================================== */
    function getUnstakeRequest(address user, uint256 index)
        external
        view
        returns (uint256 nativeAmount, uint256 feeAmount, bool claimable, bool claimed)
    {
        UnstakeRequest storage req = unstakeRequests[user][index];
        return (req.nativeAmount, req.feeAmount, req.claimable, req.claimed);
    }

    function getUnstakeRequestCount(address user) external view returns (uint256) {
        return unstakeRequests[user].length;
    }

    function contractNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /* ================================================================== */
    /* Receive native assets (e.g. external staking rewards or fees)      */
    /* ================================================================== */
    receive() external payable {}
}
