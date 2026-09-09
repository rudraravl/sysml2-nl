// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract NonCustodialPaymentSystem {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_FEE_BPS = 500; // 5% cap
    uint256 public constant MAX_TOKENS_PER_PROCESSOR = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ============ Custom Errors ============

    error Unauthorized();
    error ReentrantCall();
    error ProcessorNotFound(uint256 processorId);
    error ProcessorInactive(uint256 processorId);
    error TokenNotSupported(uint256 processorId, address token);
    error MaxTokensExceeded(uint256 processorId, uint256 provided, uint256 maxAllowed);
    error TokenAlreadySupported(uint256 processorId, address token);
    error TokenNotInProcessor(uint256 processorId, address token);
    error ZeroAddress();
    error ZeroAmount();
    error SystemPaused();
    error FeeExceedsCap(uint256 feeBps, uint256 maxAllowed);
    error SelfPayment();

    // ============ Events ============

    event PaymentProcessed(
        uint256 indexed processorId,
        address indexed payer,
        address indexed payee,
        address token,
        uint256 amount,
        uint256 fee
    );

    event ProcessorAdded(uint256 indexed processorId, address indexed account, uint256 feeBps);

    event ProcessorConfigUpdated(uint256 indexed processorId, uint256 feeBps);

    event ProcessorStatusChanged(uint256 indexed processorId, bool active);

    event TokenSupported(uint256 indexed processorId, address indexed token);

    event TokenUnsupported(uint256 indexed processorId, address indexed token);

    event SystemPausedChanged(bool paused);

    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    event FeeCollected(uint256 indexed processorId, address indexed token, address indexed recipient, uint256 amount);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ State ============

    struct Processor {
        address account;
        bool active;
        uint256 feeBps;
        uint256 totalVolume;
        uint256 totalFeesCollected;
        uint256 paymentCount;
    }

    address public owner;
    address public feeRecipient;
    bool public paused;
    uint256 public processorCount;

    mapping(uint256 => Processor) private processors;
    mapping(uint256 => address[]) private processorTokensList;
    mapping(uint256 => mapping(address => bool)) private tokenSupported;
    mapping(uint256 => bool) public processorExists;
    uint256[] private allProcessorIds;

    // Reentrancy guard
    uint256 private _guardStatus;
    uint256 private constant _GUARD_NOT_ENTERED = 1;
    uint256 private constant _GUARD_ENTERED = 2;

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert SystemPaused();
        _;
    }

    modifier nonReentrant() {
        if (_guardStatus == _GUARD_ENTERED) revert ReentrantCall();
        _guardStatus = _GUARD_ENTERED;
        _;
        _guardStatus = _GUARD_NOT_ENTERED;
    }

    // ============ Constructor ============

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        owner = msg.sender;
        _guardStatus = _GUARD_NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ Payment ============

    /// @notice Initiates a non-custodial payment from caller to payee via a chosen processor.
    /// @dev The contract pulls `amount` from the payer to the payee and `fee` to the fee recipient.
    /// @param processorId The ID of the payment processor to use.
    /// @param payee The recipient of the payment.
    /// @param token The ERC20 token to transfer.
    /// @param amount The amount of tokens to send to the payee.
    function pay(
        uint256 processorId,
        address payee,
        address token,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        Processor storage p = processors[processorId];
        if (!p.active) revert ProcessorInactive(processorId);
        if (!tokenSupported[processorId][token]) revert TokenNotSupported(processorId, token);
        if (payee == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (payee == msg.sender) revert SelfPayment();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * p.feeBps) / BPS_DENOMINATOR;

        // Effects
        p.totalVolume += amount;
        p.paymentCount += 1;
        if (fee > 0) {
            p.totalFeesCollected += fee;
        }

        // Interactions — non-custodial direct routing
        IERC20(token).safeTransferFrom(msg.sender, payee, amount);
        if (fee > 0) {
            IERC20(token).safeTransferFrom(msg.sender, feeRecipient, fee);
            emit FeeCollected(processorId, token, feeRecipient, fee);
        }

        emit PaymentProcessed(processorId, msg.sender, payee, token, amount, fee);
    }

    // ============ Operator: Processor Management ============

    /// @notice Adds a new payment processor with supported tokens and a fee.
    /// @param account The processor's identifying account address.
    /// @param feeBps The fee in basis points (50 = 0.5%).
    /// @param tokens The initial list of supported tokens (max 10).
    function addProcessor(
        address account,
        uint256 feeBps,
        address[] calldata tokens
    ) external onlyOwner returns (uint256 processorId) {
        if (account == address(0)) revert ZeroAddress();
        if (feeBps > MAX_FEE_BPS) revert FeeExceedsCap(feeBps, MAX_FEE_BPS);
        if (tokens.length > MAX_TOKENS_PER_PROCESSOR) {
            revert MaxTokensExceeded(0, tokens.length, MAX_TOKENS_PER_PROCESSOR);
        }

        processorId = ++processorCount;
        processorExists[processorId] = true;
        allProcessorIds.push(processorId);

        Processor storage p = processors[processorId];
        p.account = account;
        p.active = true;
        p.feeBps = feeBps;

        for (uint256 i = 0; i < tokens.length; i++) {
            address t = tokens[i];
            if (t == address(0)) revert ZeroAddress();
            if (tokenSupported[processorId][t]) revert TokenAlreadySupported(processorId, t);
            tokenSupported[processorId][t] = true;
            processorTokensList[processorId].push(t);
            emit TokenSupported(processorId, t);
        }

        emit ProcessorAdded(processorId, account, feeBps);
    }

    /// @notice Updates the fee for an existing processor.
    /// @param processorId The processor ID.
    /// @param feeBps The new fee in basis points.
    function updateProcessorFee(uint256 processorId, uint256 feeBps) external onlyOwner {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        if (feeBps > MAX_FEE_BPS) revert FeeExceedsCap(feeBps, MAX_FEE_BPS);

        processors[processorId].feeBps = feeBps;

        emit ProcessorConfigUpdated(processorId, feeBps);
    }

    /// @notice Replaces the entire supported token list for a processor.
    /// @param processorId The processor ID.
    /// @param tokens The new list of supported tokens (max 10).
    function updateProcessorTokens(uint256 processorId, address[] calldata tokens) external onlyOwner {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        if (tokens.length > MAX_TOKENS_PER_PROCESSOR) {
            revert MaxTokensExceeded(processorId, tokens.length, MAX_TOKENS_PER_PROCESSOR);
        }

        // Clear existing tokens
        address[] storage existing = processorTokensList[processorId];
        for (uint256 i = 0; i < existing.length; i++) {
            tokenSupported[processorId][existing[i]] = false;
            emit TokenUnsupported(processorId, existing[i]);
        }
        delete processorTokensList[processorId];

        // Set new tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            address t = tokens[i];
            if (t == address(0)) revert ZeroAddress();
            if (tokenSupported[processorId][t]) revert TokenAlreadySupported(processorId, t);
            tokenSupported[processorId][t] = true;
            processorTokensList[processorId].push(t);
            emit TokenSupported(processorId, t);
        }

        emit ProcessorConfigUpdated(processorId, processors[processorId].feeBps);
    }

    /// @notice Adds a single supported token to a processor.
    /// @param processorId The processor ID.
    /// @param token The token address to support.
    function addSupportedToken(uint256 processorId, address token) external onlyOwner {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        if (token == address(0)) revert ZeroAddress();
        if (processorTokensList[processorId].length >= MAX_TOKENS_PER_PROCESSOR) {
            revert MaxTokensExceeded(
                processorId,
                processorTokensList[processorId].length + 1,
                MAX_TOKENS_PER_PROCESSOR
            );
        }
        if (tokenSupported[processorId][token]) revert TokenAlreadySupported(processorId, token);

        tokenSupported[processorId][token] = true;
        processorTokensList[processorId].push(token);

        emit TokenSupported(processorId, token);
        emit ProcessorConfigUpdated(processorId, processors[processorId].feeBps);
    }

    /// @notice Removes a single supported token from a processor.
    /// @param processorId The processor ID.
    /// @param token The token address to remove.
    function removeSupportedToken(uint256 processorId, address token) external onlyOwner {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        if (!tokenSupported[processorId][token]) revert TokenNotInProcessor(processorId, token);

        tokenSupported[processorId][token] = false;
        address[] storage list = processorTokensList[processorId];
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == token) {
                list[i] = list[len - 1];
                list.pop();
                break;
            }
        }

        emit TokenUnsupported(processorId, token);
        emit ProcessorConfigUpdated(processorId, processors[processorId].feeBps);
    }

    /// @notice Activates or deactivates a processor.
    /// @param processorId The processor ID.
    /// @param active The new active status.
    function setProcessorActive(uint256 processorId, bool active) external onlyOwner {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        processors[processorId].active = active;
        emit ProcessorStatusChanged(processorId, active);
    }

    /// @notice Pauses or unpauses the entire payment system.
    /// @param _paused The new pause state.
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit SystemPausedChanged(_paused);
    }

    /// @notice Updates the fee recipient address.
    /// @param newRecipient The new fee recipient.
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    /// @notice Transfers ownership to a new address.
    /// @param newOwner The new owner address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /// @notice Rescues tokens accidentally sent to the contract.
    /// @param token The token to rescue.
    /// @param recipient The recipient of rescued tokens.
    /// @param amount The amount to rescue.
    function rescueToken(address token, address recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(recipient, amount);
    }

    // ============ View Functions ============

    /// @notice Returns the full configuration and stats of a processor.
    function getProcessor(uint256 processorId)
        external
        view
        returns (
            address account,
            bool active,
            uint256 feeBps,
            uint256 totalVolume,
            uint256 totalFeesCollected,
            uint256 paymentCount
        )
    {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        Processor storage p = processors[processorId];
        return (p.account, p.active, p.feeBps, p.totalVolume, p.totalFeesCollected, p.paymentCount);
    }

    /// @notice Returns the list of supported tokens for a processor.
    function getProcessorTokens(uint256 processorId) external view returns (address[] memory) {
        return processorTokensList[processorId];
    }

    /// @notice Returns whether a token is supported by a processor.
    function isTokenSupported(uint256 processorId, address token) external view returns (bool) {
        return tokenSupported[processorId][token];
    }

    /// @notice Returns all processor IDs.
    function getAllProcessorIds() external view returns (uint256[] memory) {
        return allProcessorIds;
    }

    /// @notice Returns the expected fee for a given amount via a processor.
    function getExpectedFee(uint256 processorId, uint256 amount) external view returns (uint256) {
        if (!processorExists[processorId]) revert ProcessorNotFound(processorId);
        return (amount * processors[processorId].feeBps) / BPS_DENOMINATOR;
    }
}
