// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IValidatorNetwork {
    function requestUnstake(uint256 amount) external;
}

contract LiquidStaking {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error NoRewardsToClaim();
    error InvalidRatio();
    error ExceedsFeeCap();
    error TransferFailed();
    error CannotRecoverBaseAsset();
    error ReentrantCall();

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdrawal(address indexed user, uint256 shares, uint256 amount, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 reward, uint256 sharesBurned);
    event StakingRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event FeeChanged(uint256 oldFee, uint256 newFee);
    event UnstakingInitiated(uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event ValidatorNetworkUpdated(address indexed oldNetwork, address indexed newNetwork);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event FeesSwept(address indexed to, uint256 amount);
    event TokenRecovered(address indexed token, address indexed to, uint256 amount);

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant MIN_DEPOSIT = 100 * 10**18;

    IERC20 public immutable baseAsset;
    IValidatorNetwork public validatorNetwork;
    address public operator;

    uint256 public totalLSDSupply;
    mapping(address => uint256) public lsdBalances;
    mapping(address => uint256) public claimedBaseAmount;

    uint256 public stakingRatio;
    uint256 public withdrawalFeeBps;
    uint256 public accumulatedFees;

    bool private _locked;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _baseAsset, address _validatorNetwork) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        baseAsset = IERC20(_baseAsset);
        validatorNetwork = IValidatorNetwork(_validatorNetwork);
        operator = msg.sender;
        stakingRatio = PRECISION;
        withdrawalFeeBps = 50;
        emit OperatorUpdated(address(0), operator);
        emit ValidatorNetworkUpdated(address(0), _validatorNetwork);
        emit FeeChanged(0, withdrawalFeeBps);
    }

    function balanceOf(address account) external view returns (uint256) {
        return lsdBalances[account];
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();

        uint256 sharesToMint = (amount * PRECISION) / stakingRatio;
        if (sharesToMint == 0) revert ZeroAmount();

        lsdBalances[msg.sender] += sharesToMint;
        totalLSDSupply += sharesToMint;
        claimedBaseAmount[msg.sender] += amount;

        _safeTransferFrom(address(baseAsset), msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 lsdAmount) external nonReentrant {
        if (lsdAmount == 0) revert ZeroAmount();
        if (lsdBalances[msg.sender] < lsdAmount) revert InsufficientBalance();

        uint256 product = lsdAmount * stakingRatio;
        uint256 baseValue = product / PRECISION;
        uint256 fee = (product * withdrawalFeeBps) / (PRECISION * BPS_DENOMINATOR);
        uint256 netAmount = baseValue - fee;

        uint256 balanceBefore = lsdBalances[msg.sender];
        lsdBalances[msg.sender] -= lsdAmount;
        totalLSDSupply -= lsdAmount;

        uint256 principalOut = (claimedBaseAmount[msg.sender] * lsdAmount) / balanceBefore;
        claimedBaseAmount[msg.sender] -= principalOut;

        accumulatedFees += fee;

        _safeTransfer(address(baseAsset), msg.sender, netAmount);

        emit Withdrawal(msg.sender, lsdAmount, netAmount, fee);
    }

    function claimRewards() external nonReentrant {
        uint256 balance = lsdBalances[msg.sender];
        if (balance == 0) revert InsufficientBalance();

        uint256 currentValue = (balance * stakingRatio) / PRECISION;
        uint256 claimed = claimedBaseAmount[msg.sender];

        if (currentValue <= claimed) revert NoRewardsToClaim();

        uint256 reward = currentValue - claimed;
        uint256 rewardShares = (reward * PRECISION) / stakingRatio;
        if (rewardShares == 0) revert NoRewardsToClaim();
        if (rewardShares > balance) revert NoRewardsToClaim();

        lsdBalances[msg.sender] -= rewardShares;
        totalLSDSupply -= rewardShares;

        _safeTransfer(address(baseAsset), msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward, rewardShares);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (lsdBalances[msg.sender] < amount) revert InsufficientBalance();

        uint256 balanceBefore = lsdBalances[msg.sender];
        lsdBalances[msg.sender] -= amount;
        lsdBalances[to] += amount;

        uint256 claimedReduction = (claimedBaseAmount[msg.sender] * amount) / balanceBefore;
        claimedBaseAmount[msg.sender] -= claimedReduction;
        claimedBaseAmount[to] += claimedReduction;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function updateStakingRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0) revert InvalidRatio();

        uint256 contractBalance = baseAsset.balanceOf(address(this));
        if (contractBalance < accumulatedFees) revert InsufficientLiquidity();
        uint256 availableBase = contractBalance - accumulatedFees;

        uint256 totalValue = (totalLSDSupply * newRatio) / PRECISION;
        if (totalValue > availableBase) revert InsufficientLiquidity();

        emit StakingRatioUpdated(stakingRatio, newRatio);
        stakingRatio = newRatio;
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert ExceedsFeeCap();
        emit FeeChanged(withdrawalFeeBps, newFeeBps);
        withdrawalFeeBps = newFeeBps;
    }

    function initiateUnstake(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (address(validatorNetwork) != address(0)) {
            validatorNetwork.requestUnstake(amount);
        }
        emit UnstakingInitiated(amount);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setValidatorNetwork(address newNetwork) external onlyOperator {
        if (newNetwork == address(0)) revert ZeroAddress();
        address old = address(validatorNetwork);
        validatorNetwork = IValidatorNetwork(newNetwork);
        emit ValidatorNetworkUpdated(old, newNetwork);
    }

    function sweepFees(address to) external onlyOperator nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        _safeTransfer(address(baseAsset), to, amount);
        emit FeesSwept(to, amount);
    }

    function recoverToken(address token, address to, uint256 amount) external onlyOperator nonReentrant {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token == address(baseAsset)) revert CannotRecoverBaseAsset();
        _safeTransfer(token, to, amount);
        emit TokenRecovered(token, to, amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 0x20), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 0x20), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
