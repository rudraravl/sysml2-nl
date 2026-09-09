// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

/**
 * @title MetaStableSystem
 * @notice Manages minting and burning of a metastable token (MST) and a superstable token (SST).
 *         MST is minted 1:1 against a base asset. SST is minted against MST at a configurable
 *         collateralization ratio and redeemed with a configurable stability fee.
 */
contract MetaStableSystem {
    using SafeERC20 for IERC20;

    error OnlyOperator();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountZero();
    error CollateralizationRatioOutOfRange(uint256 ratio);
    error StabilityFeeOutOfRange(uint256 feeBps);
    error ReentrantCall();

    event MetaStableMinted(address indexed account, uint256 baseDeposited, uint256 minted);
    event MetaStableBurned(address indexed account, uint256 burned, uint256 baseRedeemed);
    event SuperStableMinted(address indexed account, uint256 mstDeposited, uint256 minted);
    event SuperStableBurned(address indexed account, uint256 burned, uint256 mstRedeemed, uint256 feeTaken);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event StabilityFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event MetaStableTransfer(address indexed from, address indexed to, uint256 amount);
    event SuperStableTransfer(address indexed from, address indexed to, uint256 amount);
    event MetaStableApproval(address indexed owner, address indexed spender, uint256 amount);
    event SuperStableApproval(address indexed owner, address indexed spender, uint256 amount);
    event SystemStateAnnounced(uint256 metaStableSupply, uint256 superStableSupply, uint256 collateralizationRatio, uint256 stabilityFeeBps);

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant RATIO_DENOMINATOR = 100;
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 100;
    uint256 public constant MAX_COLLATERALIZATION_RATIO = 150;
    uint256 public constant DEFAULT_STABILITY_FEE_BPS = 50;

    IERC20 public immutable baseAsset;

    address public operator;

    string public constant metaStableName = "MetaStable Token";
    string public constant metaStableSymbol = "MST";
    uint8 public constant metaStableDecimals = 18;

    string public constant superStableName = "SuperStable Token";
    string public constant superStableSymbol = "SST";
    uint8 public constant superStableDecimals = 18;

    uint256 public metaStableTotalSupply;
    uint256 public superStableTotalSupply;

    mapping(address => uint256) public metaStableBalanceOf;
    mapping(address => uint256) public superStableBalanceOf;

    mapping(address => mapping(address => uint256)) public metaStableAllowance;
    mapping(address => mapping(address => uint256)) public superStableAllowance;

    uint256 public collateralizationRatio;
    uint256 public stabilityFeeBps;

    uint256 private _locked;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address baseAsset_, address operator_, uint256 initialCollateralizationRatio) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (
            initialCollateralizationRatio < MIN_COLLATERALIZATION_RATIO
                || initialCollateralizationRatio > MAX_COLLATERALIZATION_RATIO
        ) {
            revert CollateralizationRatioOutOfRange(initialCollateralizationRatio);
        }

        baseAsset = IERC20(baseAsset_);
        operator = operator_;
        collateralizationRatio = initialCollateralizationRatio;
        stabilityFeeBps = DEFAULT_STABILITY_FEE_BPS;

        emit OperatorTransferred(address(0), operator_);
        emit CollateralizationRatioUpdated(0, collateralizationRatio);
        emit StabilityFeeUpdated(0, stabilityFeeBps);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function mintMetaStable(address account, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (account == address(0)) revert ZeroAddress();

        // Effects: update state before external interaction.
        metaStableTotalSupply += amount;
        metaStableBalanceOf[account] += amount;

        // Interactions: SafeERC20 reverts on failed transfer.
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);

        emit MetaStableMinted(account, amount, amount);
        emit MetaStableTransfer(address(0), account, amount);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function burnMetaStable(address account, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();

        uint256 callerBal = metaStableBalanceOf[msg.sender];
        if (callerBal < amount) revert InsufficientBalance();

        if (account != msg.sender) {
            uint256 allowed = metaStableAllowance[account][msg.sender];
            if (allowed < amount) revert InsufficientAllowance();
            metaStableAllowance[account][msg.sender] = allowed - amount;
        } else {
            account = msg.sender;
        }

        // Effects
        metaStableBalanceOf[msg.sender] -= amount;
        metaStableTotalSupply -= amount;

        // Interactions
        baseAsset.safeTransfer(msg.sender, amount);

        emit MetaStableBurned(msg.sender, amount, amount);
        emit MetaStableTransfer(msg.sender, address(0), amount);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function mintSuperStable(address account, uint256 sstAmount) external nonReentrant {
        if (sstAmount == 0) revert AmountZero();
        if (account == address(0)) revert ZeroAddress();

        uint256 mstRequired = (sstAmount * collateralizationRatio) / RATIO_DENOMINATOR;
        if (mstRequired == 0) revert AmountZero();

        uint256 callerBal = metaStableBalanceOf[msg.sender];
        if (callerBal < mstRequired) revert InsufficientBalance();

        // Effects
        metaStableBalanceOf[msg.sender] -= mstRequired;
        metaStableTotalSupply -= mstRequired;

        superStableTotalSupply += sstAmount;
        superStableBalanceOf[account] += sstAmount;

        emit SuperStableMinted(account, mstRequired, sstAmount);
        emit MetaStableTransfer(msg.sender, address(0), mstRequired);
        emit SuperStableTransfer(address(0), account, sstAmount);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function burnSuperStable(address account, uint256 sstAmount) external nonReentrant {
        if (sstAmount == 0) revert AmountZero();

        uint256 callerBal = superStableBalanceOf[msg.sender];
        if (callerBal < sstAmount) revert InsufficientBalance();

        if (account != msg.sender) {
            uint256 allowed = superStableAllowance[account][msg.sender];
            if (allowed < sstAmount) revert InsufficientAllowance();
            superStableAllowance[account][msg.sender] = allowed - sstAmount;
        } else {
            account = msg.sender;
        }

        // Effects: burn SST
        superStableBalanceOf[msg.sender] -= sstAmount;
        superStableTotalSupply -= sstAmount;

        // Calculate MST to return without divide-before-multiply.
        // grossMst = sstAmount * ratio / RATIO_DENOMINATOR
        // fee = sstAmount * ratio * feeBps / (RATIO_DENOMINATOR * BPS_DENOMINATOR)
        // netMst = grossMst - fee
        uint256 grossMst = (sstAmount * collateralizationRatio) / RATIO_DENOMINATOR;
        uint256 fee = (sstAmount * collateralizationRatio * stabilityFeeBps) / (RATIO_DENOMINATOR * BPS_DENOMINATOR);
        uint256 netMst = grossMst - fee;

        metaStableTotalSupply += netMst;
        metaStableBalanceOf[msg.sender] += netMst;

        emit SuperStableBurned(msg.sender, sstAmount, netMst, fee);
        emit SuperStableTransfer(msg.sender, address(0), sstAmount);
        emit MetaStableTransfer(address(0), msg.sender, netMst);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function transferMetaStable(address to, uint256 amount) external returns (bool) {
        _transferMetaStable(msg.sender, to, amount);
        return true;
    }

    function approveMetaStable(address spender, uint256 amount) external returns (bool) {
        metaStableAllowance[msg.sender][spender] = amount;
        emit MetaStableApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFromMetaStable(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = metaStableAllowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            metaStableAllowance[from][msg.sender] = allowed - amount;
        }
        _transferMetaStable(from, to, amount);
        return true;
    }

    function transferSuperStable(address to, uint256 amount) external returns (bool) {
        _transferSuperStable(msg.sender, to, amount);
        return true;
    }

    function approveSuperStable(address spender, uint256 amount) external returns (bool) {
        superStableAllowance[msg.sender][spender] = amount;
        emit SuperStableApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFromSuperStable(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = superStableAllowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            superStableAllowance[from][msg.sender] = allowed - amount;
        }
        _transferSuperStable(from, to, amount);
        return true;
    }

    function _transferMetaStable(address from, address to, uint256 amount) internal {
        if (amount == 0) revert AmountZero();
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBal = metaStableBalanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();

        metaStableBalanceOf[from] = fromBal - amount;
        metaStableBalanceOf[to] += amount;

        emit MetaStableTransfer(from, to, amount);
    }

    function _transferSuperStable(address from, address to, uint256 amount) internal {
        if (amount == 0) revert AmountZero();
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBal = superStableBalanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();

        superStableBalanceOf[from] = fromBal - amount;
        superStableBalanceOf[to] += amount;

        emit SuperStableTransfer(from, to, amount);
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_COLLATERALIZATION_RATIO || newRatio > MAX_COLLATERALIZATION_RATIO) {
            revert CollateralizationRatioOutOfRange(newRatio);
        }
        uint256 old = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(old, newRatio);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function setStabilityFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > BPS_DENOMINATOR) revert StabilityFeeOutOfRange(newFeeBps);
        uint256 old = stabilityFeeBps;
        stabilityFeeBps = newFeeBps;
        emit StabilityFeeUpdated(old, newFeeBps);
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorTransferred(old, newOperator);
    }

    function totalSupplies() external view returns (uint256 metaStableSupply, uint256 superStableSupply) {
        return (metaStableTotalSupply, superStableTotalSupply);
    }

    function systemParameters() external view returns (uint256 ratio, uint256 feeBps) {
        return (collateralizationRatio, stabilityFeeBps);
    }

    function mstRequiredForSst(uint256 sstAmount) external view returns (uint256) {
        return (sstAmount * collateralizationRatio) / RATIO_DENOMINATOR;
    }

    function mstReturnedForSstBurn(uint256 sstAmount) external view returns (uint256 netMst, uint256 fee) {
        uint256 gross = (sstAmount * collateralizationRatio) / RATIO_DENOMINATOR;
        fee = (sstAmount * collateralizationRatio * stabilityFeeBps) / (RATIO_DENOMINATOR * BPS_DENOMINATOR);
        netMst = gross - fee;
        return (netMst, fee);
    }

    function announceState() external {
        emit SystemStateAnnounced(metaStableTotalSupply, superStableTotalSupply, collateralizationRatio, stabilityFeeBps);
    }
}
