// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidStakingVault is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientIdleAssets();
    error WithdrawalNotReady();
    error PendingWithdrawalExists();
    error NoPendingWithdrawal();
    error FeeExceedsCap();
    error InvalidStakingRatio();
    error DuplicateValidatorKey();
    error ValidatorKeyNotFound();
    error NotOperator();
    error StakingAmountExceedsIdle();
    error InvalidPubkeyLength();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed caller, address indexed owner, uint256 baseAssets, uint256 lstMinted);
    event RedemptionRequested(address indexed owner, uint256 lstAmount, uint256 baseAssets, uint256 fee);
    event RedemptionClaimed(address indexed receiver, address indexed owner, uint256 baseAssets);
    event StakingRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event StakingInitiated(uint256 amount, uint256 totalStaked);
    event ValidatorKeyAdded(bytes indexed pubkey);
    event ValidatorKeyRemoved(bytes indexed pubkey);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WITHDRAWAL_DELAY = 7 days;
    uint256 public constant FEE_CAP = 50; // 0.5% in basis points
    uint256 public constant RATIO_PRECISION = 1e18;

    IERC20 public immutable baseAsset;

    uint256 public stakingRatio; // base asset per 1 LST, in RATIO_PRECISION
    uint256 public protocolFeeBps; // protocol fee in basis points
    address public feeRecipient;
    address public operator;

    uint256 public idleAssets; // base assets available in the vault
    uint256 public stakedAssets; // base assets sent to staking (managed by operator)

    mapping(address => uint256) public userDeposits; // cumulative base asset deposited by each user

    struct WithdrawalRequest {
        uint256 lstAmount;
        uint256 baseAssetAmount;
        uint256 requestTime;
        bool active;
    }
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    mapping(bytes32 => bool) public validatorKeyActive;
    bytes[] public validatorPubkeys;
    uint256 public activeValidatorCount;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _baseAsset,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        address _operator
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        baseAsset = IERC20(_baseAsset);
        stakingRatio = RATIO_PRECISION; // 1:1 initially
        protocolFeeBps = 0;
        feeRecipient = _feeRecipient;
        operator = _operator;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroAmount();

        baseAsset.safeTransferFrom(msg.sender, address(this), assets);

        idleAssets += assets;
        userDeposits[msg.sender] += assets;
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, msg.sender, assets, shares);
    }

    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroAmount();

        baseAsset.safeTransferFrom(msg.sender, address(this), assets);

        idleAssets += assets;
        userDeposits[receiver] += assets;
        _mint(receiver, shares);

        emit Deposited(msg.sender, receiver, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                           REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/

    function requestRedeem(uint256 lstAmount) external nonReentrant returns (uint256 baseAssets, uint256 fee) {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < lstAmount) revert InsufficientBalance();
        if (withdrawalRequests[msg.sender].active) revert PendingWithdrawalExists();

        uint256 grossAssets = convertToAssets(lstAmount);
        fee = (grossAssets * protocolFeeBps) / 10000;
        baseAssets = grossAssets - fee;

        if (baseAssets == 0) revert ZeroAmount();
        if (idleAssets < baseAssets) revert InsufficientIdleAssets();

        // Effects
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            lstAmount: lstAmount,
            baseAssetAmount: baseAssets,
            requestTime: block.timestamp,
            active: true
        });

        _burn(msg.sender, lstAmount);

        // Pay fee immediately in base asset
        if (fee > 0) {
            idleAssets -= fee;
            baseAsset.safeTransfer(feeRecipient, fee);
        }

        emit RedemptionRequested(msg.sender, lstAmount, baseAssets, fee);
    }

    function claimRedeem() external nonReentrant returns (uint256 baseAssets) {
        WithdrawalRequest storage req = withdrawalRequests[msg.sender];
        if (!req.active) revert NoPendingWithdrawal();
        if (block.timestamp < req.requestTime + WITHDRAWAL_DELAY) revert WithdrawalNotReady();

        baseAssets = req.baseAssetAmount;

        // Effects
        req.active = false;
        req.lstAmount = 0;
        req.baseAssetAmount = 0;
        req.requestTime = 0;

        idleAssets -= baseAssets;

        // Interaction
        baseAsset.safeTransfer(msg.sender, baseAssets);

        emit RedemptionClaimed(msg.sender, msg.sender, baseAssets);
    }

    function claimRedeem(address receiver) external nonReentrant returns (uint256 baseAssets) {
        if (receiver == address(0)) revert ZeroAddress();

        WithdrawalRequest storage req = withdrawalRequests[msg.sender];
        if (!req.active) revert NoPendingWithdrawal();
        if (block.timestamp < req.requestTime + WITHDRAWAL_DELAY) revert WithdrawalNotReady();

        baseAssets = req.baseAssetAmount;

        // Effects
        req.active = false;
        req.lstAmount = 0;
        req.baseAssetAmount = 0;
        req.requestTime = 0;

        idleAssets -= baseAssets;

        // Interaction
        baseAsset.safeTransfer(receiver, baseAssets);

        emit RedemptionClaimed(receiver, msg.sender, baseAssets);
    }

    function pendingWithdrawal(address account) external view returns (
        uint256 lstAmount,
        uint256 baseAssetAmount,
        uint256 requestTime,
        bool active,
        uint256 claimableAt
    ) {
        WithdrawalRequest storage req = withdrawalRequests[account];
        return (req.lstAmount, req.baseAssetAmount, req.requestTime, req.active, req.requestTime + WITHDRAWAL_DELAY);
    }

    /*//////////////////////////////////////////////////////////////
                          CONVERSION ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0 || stakingRatio == 0) {
            return assets; // 1:1 at inception
        }
        return (assets * RATIO_PRECISION) / stakingRatio;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalSupply() == 0 || stakingRatio == 0) {
            return shares;
        }
        return (shares * stakingRatio) / RATIO_PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR: STAKING & VALIDATORS
    //////////////////////////////////////////////////////////////*/

    function initiateStaking(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > idleAssets) revert StakingAmountExceedsIdle();

        idleAssets -= amount;
        stakedAssets += amount;

        baseAsset.safeTransfer(operator, amount);

        emit StakingInitiated(amount, stakedAssets);
    }

    function addValidatorKey(bytes calldata pubkey) external onlyOperator {
        if (pubkey.length != 48) revert InvalidPubkeyLength();
        bytes32 keyHash = keccak256(pubkey);
        if (validatorKeyActive[keyHash]) revert DuplicateValidatorKey();

        validatorKeyActive[keyHash] = true;
        validatorPubkeys.push(pubkey);
        activeValidatorCount++;

        emit ValidatorKeyAdded(pubkey);
    }

    function removeValidatorKey(bytes calldata pubkey) external onlyOperator {
        bytes32 keyHash = keccak256(pubkey);
        if (!validatorKeyActive[keyHash]) revert ValidatorKeyNotFound();

        validatorKeyActive[keyHash] = false;
        activeValidatorCount--;

        emit ValidatorKeyRemoved(pubkey);
    }

    function validatorKeyCount() external view returns (uint256) {
        return validatorPubkeys.length;
    }

    /*//////////////////////////////////////////////////////////////
                          OWNER: ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setStakingRatio(uint256 newRatio) external onlyOwner {
        if (newRatio == 0) revert InvalidStakingRatio();
        uint256 oldRatio = stakingRatio;
        stakingRatio = newRatio;
        emit StakingRatioUpdated(oldRatio, newRatio);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_CAP) revert FeeExceedsCap();
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                          RESCUE / RECOVERY
    //////////////////////////////////////////////////////////////*/

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (token == address(baseAsset)) {
            uint256 balance = baseAsset.balanceOf(address(this));
            if (amount > balance || balance - amount < idleAssets) revert InsufficientBalance();
        }
        IERC20(token).safeTransfer(owner(), amount);
    }
}
