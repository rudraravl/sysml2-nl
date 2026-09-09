// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IExternalVault {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external;
    function balanceOf(address token) external view returns (uint256);
}

contract StrategyVault {
    error NotOwner();
    error ZeroAddress();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error TokenHasDeposits();
    error VaultNotApproved();
    error VaultAlreadyApproved();
    error MaxVaultsReached();
    error InvalidAllocation();
    error InvalidFee();
    error ZeroAmount();
    error InsufficientBalance();
    error NoYieldToClaim();
    error NoFeesToClaim();
    error TransferFailed();
    error RecallShortfall();
    error Reentrancy();

    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 totalDeposited);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 fee, uint256 totalDeposited);
    event YieldClaimed(address indexed user, address indexed token, uint256 amount);
    event FeesClaimed(address indexed token, address indexed recipient, uint256 amount);
    event VaultAdded(address indexed vault);
    event AllocationUpdated(address indexed vault, address indexed token, uint256 allocationBps);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event YieldHarvested(address indexed token, uint256 yieldAmount);
    event TokenSupported(address indexed token);
    event TokenRemoved(address indexed token);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MAX_VAULTS = 10;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant YIELD_PRECISION = 1e18;

    address public owner;
    uint256 public withdrawalFeeBps = 50; // 0.5%

    mapping(address => bool) public supportedTokens;

    mapping(address => mapping(address => uint256)) public userDeposits; // token => user => principal
    mapping(address => uint256) public totalDeposits; // token => total principal

    address[] public vaults;
    mapping(address => bool) public isApprovedVault;
    mapping(address => mapping(address => uint256)) public vaultAllocations; // vault => token => bps

    mapping(address => mapping(address => uint256)) public vaultDeployed; // vault => token => principal deployed
    mapping(address => uint256) public deployedAmount; // token => total principal deployed to vaults

    mapping(address => uint256) public accYieldPerShare; // token => accumulated yield per share (scaled 1e18)
    mapping(address => mapping(address => uint256)) public userYieldDebt; // token => user => debt
    mapping(address => mapping(address => uint256)) public userYield; // token => user => claimable yield

    mapping(address => uint256) public accumulatedFees; // token => protocol fees

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address[] memory supportedTokens_) {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        for (uint256 i = 0; i < supportedTokens_.length; i++) {
            address token = supportedTokens_[i];
            if (token == address(0)) revert ZeroAddress();
            if (supportedTokens[token]) revert TokenAlreadySupported();
            supportedTokens[token] = true;
            emit TokenSupported(token);
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (supportedTokens[token]) revert TokenAlreadySupported();
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (totalDeposits[token] > 0) revert TokenHasDeposits();
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function addVault(address vault) external onlyOwner {
        if (vault == address(0)) revert ZeroAddress();
        if (isApprovedVault[vault]) revert VaultAlreadyApproved();
        if (vaults.length >= MAX_VAULTS) revert MaxVaultsReached();
        isApprovedVault[vault] = true;
        vaults.push(vault);
        emit VaultAdded(vault);
    }

    function updateAllocation(address vault, address token, uint256 allocationBps) external onlyOwner {
        if (!isApprovedVault[vault]) revert VaultNotApproved();
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (allocationBps > FEE_PRECISION) revert InvalidAllocation();
        uint256 sum = allocationBps;
        for (uint256 i = 0; i < vaults.length; i++) {
            address v = vaults[i];
            if (v == vault) continue;
            sum += vaultAllocations[v][token];
        }
        if (sum > FEE_PRECISION) revert InvalidAllocation();
        vaultAllocations[vault][token] = allocationBps;
        emit AllocationUpdated(vault, token, allocationBps);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_PRECISION) revert InvalidFee();
        emit WithdrawalFeeUpdated(withdrawalFeeBps, newFeeBps);
        withdrawalFeeBps = newFeeBps;
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();

        _settlePending(token, msg.sender);

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        userDeposits[token][msg.sender] += amount;
        totalDeposits[token] += amount;
        userYieldDebt[token][msg.sender] =
            (userDeposits[token][msg.sender] * accYieldPerShare[token]) / YIELD_PRECISION;

        _deployFunds(token, amount);

        emit Deposit(msg.sender, token, amount, totalDeposits[token]);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();
        uint256 userBal = userDeposits[token][msg.sender];
        if (userBal < amount) revert InsufficientBalance();

        _settlePending(token, msg.sender);
        _recallFunds(token, amount);

        userDeposits[token][msg.sender] = userBal - amount;
        totalDeposits[token] -= amount;
        userYieldDebt[token][msg.sender] =
            (userDeposits[token][msg.sender] * accYieldPerShare[token]) / YIELD_PRECISION;

        uint256 fee = (amount * withdrawalFeeBps) / FEE_PRECISION;
        uint256 payout = amount - fee;
        accumulatedFees[token] += fee;

        bool ok = IERC20(token).transfer(msg.sender, payout);
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, token, amount, fee, totalDeposits[token]);
    }

    function claimYield(address token) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        _settlePending(token, msg.sender);
        uint256 yieldAmount = userYield[token][msg.sender];
        if (yieldAmount == 0) revert NoYieldToClaim();
        userYield[token][msg.sender] = 0;
        bool ok = IERC20(token).transfer(msg.sender, yieldAmount);
        if (!ok) revert TransferFailed();
        emit YieldClaimed(msg.sender, token, yieldAmount);
    }

    function claimFees(address token) external onlyOwner nonReentrant {
        uint256 fees = accumulatedFees[token];
        if (fees == 0) revert NoFeesToClaim();
        accumulatedFees[token] = 0;
        bool ok = IERC20(token).transfer(owner, fees);
        if (!ok) revert TransferFailed();
        emit FeesClaimed(token, owner, fees);
    }

    function harvest(address token) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        uint256 totalYield = 0;
        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = vaults[i];
            uint256 deployed = vaultDeployed[vault][token];
            if (deployed == 0) continue;
            uint256 vaultBal = IExternalVault(vault).balanceOf(token);
            if (vaultBal <= deployed) continue;
            uint256 yieldAmount = vaultBal - deployed;
            vaultDeployed[vault][token] -= yieldAmount;
            deployedAmount[token] -= yieldAmount;
            IExternalVault(vault).withdraw(token, yieldAmount);
            totalYield += yieldAmount;
        }
        if (totalYield == 0) return;
        if (totalDeposits[token] > 0) {
            accYieldPerShare[token] += (totalYield * YIELD_PRECISION) / totalDeposits[token];
        } else {
            accumulatedFees[token] += totalYield;
        }
        emit YieldHarvested(token, totalYield);
    }

    function pendingYield(address token, address user) external view returns (uint256) {
        uint256 pending =
            (userDeposits[token][user] * accYieldPerShare[token]) / YIELD_PRECISION - userYieldDebt[token][user];
        return pending + userYield[token][user];
    }

    function vaultCount() external view returns (uint256) {
        return vaults.length;
    }

    function totalDeployed(address token) external view returns (uint256) {
        return deployedAmount[token];
    }

    function _settlePending(address token, address user) internal {
        uint256 pending =
            (userDeposits[token][user] * accYieldPerShare[token]) / YIELD_PRECISION - userYieldDebt[token][user];
        if (pending > 0) {
            userYield[token][user] += pending;
        }
        userYieldDebt[token][user] = (userDeposits[token][user] * accYieldPerShare[token]) / YIELD_PRECISION;
    }

    function _deployFunds(address token, uint256 amount) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = vaults[i];
            uint256 bps = vaultAllocations[vault][token];
            if (bps == 0) continue;
            uint256 deployAmount = (amount * bps) / FEE_PRECISION;
            if (deployAmount == 0) continue;

            vaultDeployed[vault][token] += deployAmount;
            deployedAmount[token] += deployAmount;

            bool ok = IERC20(token).approve(vault, 0);
            if (!ok) revert TransferFailed();
            ok = IERC20(token).approve(vault, deployAmount);
            if (!ok) revert TransferFailed();

            IExternalVault(vault).deposit(token, deployAmount);
        }
    }

    function _recallFunds(address token, uint256 amount) internal {
        uint256 contractBal = IERC20(token).balanceOf(address(this));
        if (contractBal >= amount) return;
        uint256 needed = amount - contractBal;

        for (uint256 i = 0; i < vaults.length && needed > 0; i++) {
            address vault = vaults[i];
            uint256 deployed = vaultDeployed[vault][token];
            if (deployed == 0) continue;

            uint256 toPull = deployed < needed ? deployed : needed;
            if (toPull < 1) continue;

            vaultDeployed[vault][token] -= toPull;
            deployedAmount[token] -= toPull;

            IExternalVault(vault).withdraw(token, toPull);

            contractBal = IERC20(token).balanceOf(address(this));
            needed = amount > contractBal ? amount - contractBal : 0;
        }

        contractBal = IERC20(token).balanceOf(address(this));
        if (contractBal < amount) revert RecallShortfall();
    }
}
