// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library SafeTransfer {
    error TransferFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}

contract RiskPool {
    using SafeTransfer for IERC20;

    enum PolicyStatus { Proposed, Active, Rejected, Closed }

    struct Policy {
        address proposer;
        uint256 coverageAmount;
        uint256 premium;
        uint256 payoutAmount;
        PolicyStatus status;
    }

    IERC20 public immutable stablecoin;
    uint256 public constant minDeposit = 100 * 10**18;
    uint256 public constant maxCoverage = 50_000 * 10**18;

    address public owner;
    address public operator;

    mapping(address => uint256) public investorBalances;
    uint256 public totalPoolBalance;
    uint256 public totalInvestorDeposits;

    mapping(uint256 => Policy) public policies;
    uint256 public nextPolicyId;

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, uint256 amount);
    event PolicyProposed(uint256 indexed policyId, address indexed proposer, uint256 coverageAmount, uint256 premium);
    event PolicyApproved(uint256 indexed policyId);
    event PolicyRejected(uint256 indexed policyId);
    event ClaimPayout(uint256 indexed policyId, address indexed payee, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error ZeroAmount();
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error InsufficientBalance();
    error MinimumDepositNotMet(uint256 required);
    error CoverageLimitExceeded(uint256 limit);
    error PolicyNotFound();
    error PolicyNotProposed();
    error PolicyNotActive();
    error ClaimExceedsCoverage();
    error PoolInsolvent();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (investorBalances[msg.sender] == 0 && amount < minDeposit) {
            revert MinimumDepositNotMet(minDeposit);
        }

        investorBalances[msg.sender] += amount;
        totalInvestorDeposits += amount;
        totalPoolBalance += amount;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (amount > investorBalances[msg.sender]) revert InsufficientBalance();

        investorBalances[msg.sender] -= amount;
        totalInvestorDeposits -= amount;
        totalPoolBalance -= amount;

        stablecoin.safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    function proposePolicy(uint256 coverageAmount, uint256 premium) external {
        if (coverageAmount == 0) revert ZeroAmount();
        if (premium == 0) revert ZeroAmount();
        if (coverageAmount > maxCoverage) revert CoverageLimitExceeded(maxCoverage);

        uint256 policyId = nextPolicyId++;
        policies[policyId] = Policy({
            proposer: msg.sender,
            coverageAmount: coverageAmount,
            premium: premium,
            payoutAmount: 0,
            status: PolicyStatus.Proposed
        });

        stablecoin.safeTransferFrom(msg.sender, address(this), premium);
        totalPoolBalance += premium;

        emit PolicyProposed(policyId, msg.sender, coverageAmount, premium);
    }

    function approvePolicy(uint256 policyId) external onlyOperator {
        Policy storage policy = policies[policyId];
        if (policy.proposer == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.Proposed) revert PolicyNotProposed();

        policy.status = PolicyStatus.Active;

        emit PolicyApproved(policyId);
    }

    function rejectPolicy(uint256 policyId) external onlyOperator {
        Policy storage policy = policies[policyId];
        if (policy.proposer == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.Proposed) revert PolicyNotProposed();

        policy.status = PolicyStatus.Rejected;

        uint256 refund = policy.premium;
        policy.premium = 0;
        if (refund > 0) {
            totalPoolBalance -= refund;
            stablecoin.safeTransfer(policy.proposer, refund);
        }

        emit PolicyRejected(policyId);
    }

    function disburseClaim(uint256 policyId, address payee, uint256 amount) external onlyOperator {
        Policy storage policy = policies[policyId];
        if (policy.proposer == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (amount == 0) revert ZeroAmount();
        if (payee == address(0)) revert ZeroAddress();
        if (policy.payoutAmount + amount > policy.coverageAmount) revert ClaimExceedsCoverage();
        if (amount > totalPoolBalance) revert PoolInsolvent();

        policy.payoutAmount += amount;
        if (policy.payoutAmount == policy.coverageAmount) {
            policy.status = PolicyStatus.Closed;
        }

        totalPoolBalance -= amount;

        stablecoin.safeTransfer(payee, amount);

        emit ClaimPayout(policyId, payee, amount);
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function poolTokenBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
