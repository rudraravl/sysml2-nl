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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            amount == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = _functionCall(address(token), data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }

    function _functionCall(address target, bytes memory data) private returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        return returndata;
    }
}

interface IVerifier {
    function verify(
        bytes32 depositId,
        bytes32 shieldedAddress,
        uint256 amount,
        bytes calldata proof
    ) external view returns (bool);
}

contract ShieldedEscrow {
    using SafeERC20 for IERC20;

    uint256 private constant FEE_NUMERATOR = 5;
    uint256 private constant FEE_DENOMINATOR = 100;
    uint256 private constant MAX_DEPOSIT_NUMERATOR = 10_000;
    uint256 private constant MAX_DEPOSIT_DENOMINATOR = 1;

    struct DepositRecord {
        address asset;
        uint256 amount;
        bytes32 shieldedAddress;
        address depositor;
        bool exists;
    }

    address public operator;
    address public feeRecipient;
    address public verifier;
    bool public paused;

    mapping(bytes32 depositId => DepositRecord) public deposits;
    mapping(address asset => uint256 fee) public withdrawalFee;
    mapping(address asset => uint256 maxAmount) public maxDepositAmount;

    event DepositEvent(
        bytes32 indexed depositId,
        address indexed asset,
        uint256 amount,
        bytes32 shieldedAddress,
        address indexed depositor
    );

    event WithdrawalEvent(
        bytes32 indexed depositId,
        address indexed asset,
        uint256 amount,
        bytes32 shieldedAddress,
        uint256 fee
    );

    event EmergencyWithdrawalEvent(
        bytes32 indexed depositId,
        address indexed asset,
        uint256 amount,
        address indexed depositor
    );

    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event VerifierUpdated(address indexed previousVerifier, address indexed newVerifier);
    event PausedStatus(bool paused);
    event WithdrawalFeeSet(address indexed asset, uint256 fee);
    event MaxDepositAmountSet(address indexed asset, uint256 maxAmount);

    error Unauthorized();
    error InvalidAddress();
    error DepositAlreadyExists(bytes32 depositId);
    error DepositNotFound(bytes32 depositId);
    error DepositAlreadyWithdrawn(bytes32 depositId);
    error InsufficientDepositAmount(bytes32 depositId, uint256 requested, uint256 available);
    error ExceedsMaxDepositAmount(address asset, uint256 amount, uint256 maxAllowed);
    error ProofInvalid();
    error ZeroAmount();
    error EnforcedPause();
    error InvalidProof();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor(address _operator, address _feeRecipient, address _verifier) {
        if (_operator == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        verifier = _verifier;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        if (_verifier != address(0)) {
            emit VerifierUpdated(address(0), _verifier);
        }
    }

    function deposit(
        bytes32 depositId,
        address asset,
        uint256 amount,
        bytes32 shieldedAddress
    ) external whenNotPaused {
        if (deposits[depositId].exists) revert DepositAlreadyExists(depositId);
        if (amount == 0) revert ZeroAmount();
        if (asset == address(0)) revert InvalidAddress();

        uint256 maxAllowed = _getMaxDepositAmount(asset);
        if (amount > maxAllowed) revert ExceedsMaxDepositAmount(asset, amount, maxAllowed);

        deposits[depositId] = DepositRecord({
            asset: asset,
            amount: amount,
            shieldedAddress: shieldedAddress,
            depositor: msg.sender,
            exists: true
        });

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositEvent(depositId, asset, amount, shieldedAddress, msg.sender);
    }

    function withdraw(
        bytes32 depositId,
        bytes32 shieldedAddress,
        uint256 amount,
        bytes calldata proof
    ) external whenNotPaused {
        DepositRecord storage dep = deposits[depositId];
        if (!dep.exists) revert DepositNotFound(depositId);
        if (dep.amount == 0) revert DepositAlreadyWithdrawn(depositId);
        if (amount == 0) revert ZeroAmount();
        if (amount > dep.amount) revert InsufficientDepositAmount(depositId, amount, dep.amount);
        if (verifier == address(0)) revert InvalidAddress();
        if (proof.length == 0) revert InvalidProof();

        bool valid = IVerifier(verifier).verify(depositId, shieldedAddress, amount, proof);
        if (!valid) revert ProofInvalid();

        uint256 fee = _getWithdrawalFee(dep.asset);
        if (fee > amount) fee = amount;

        dep.amount -= amount;

        if (fee > 0) {
            IERC20(dep.asset).safeTransfer(feeRecipient, fee);
        }

        emit WithdrawalEvent(depositId, dep.asset, amount, shieldedAddress, fee);
    }

    function emergencyWithdraw(bytes32 depositId) external {
        DepositRecord storage dep = deposits[depositId];
        if (!dep.exists) revert DepositNotFound(depositId);
        if (dep.amount == 0) revert DepositAlreadyWithdrawn(depositId);
        if (msg.sender != dep.depositor) revert Unauthorized();

        uint256 amount = dep.amount;
        dep.amount = 0;

        IERC20(dep.asset).safeTransfer(msg.sender, amount);

        emit EmergencyWithdrawalEvent(depositId, dep.asset, amount, msg.sender);
    }

    function setPause(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStatus(_paused);
    }

    function setVerifier(address _verifier) external onlyOperator {
        if (_verifier == address(0)) revert InvalidAddress();
        emit VerifierUpdated(verifier, _verifier);
        verifier = _verifier;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert InvalidAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setWithdrawalFee(address asset, uint256 fee) external onlyOperator {
        if (asset == address(0)) revert InvalidAddress();
        withdrawalFee[asset] = fee;
        emit WithdrawalFeeSet(asset, fee);
    }

    function setMaxDepositAmount(address asset, uint256 maxAmount) external onlyOperator {
        if (asset == address(0)) revert InvalidAddress();
        maxDepositAmount[asset] = maxAmount;
        emit MaxDepositAmountSet(asset, maxAmount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function _getWithdrawalFee(address asset) internal view returns (uint256) {
        uint256 fee = withdrawalFee[asset];
        if (fee != 0) return fee;

        uint8 decimals = IERC20Metadata(asset).decimals();
        return (FEE_NUMERATOR * 10 ** decimals) / FEE_DENOMINATOR;
    }

    function _getMaxDepositAmount(address asset) internal view returns (uint256) {
        uint256 max = maxDepositAmount[asset];
        if (max != 0) return max;

        uint8 decimals = IERC20Metadata(asset).decimals();
        return (MAX_DEPOSIT_NUMERATOR * 10 ** decimals) / MAX_DEPOSIT_DENOMINATOR;
    }

    function getDeposit(bytes32 depositId) external view returns (DepositRecord memory) {
        return deposits[depositId];
    }
}
