// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract CrossChainTokenBridge is ReentrancyGuard {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 requested);
    error AlreadyFinalized(bytes32 attestationId);
    error InvalidSignature();
    error FeeRateTooHigh(uint256 rate, uint256 max);
    error TransferFailed();

    event Deposit(
        address indexed depositor,
        uint256 indexed depositId,
        uint256 originChainId,
        uint256 destChainId,
        address indexed recipient,
        uint256 amount,
        uint256 fee
    );
    event Finalized(
        bytes32 indexed attestationId,
        uint256 indexed depositId,
        address indexed recipient,
        uint256 amount,
        uint256 fee,
        uint256 netAmount
    );
    event Withdrawal(address indexed recipient, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRateUpdated(uint256 previousRate, uint256 newRate);

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 5;
    uint256 public constant MAX_FEE_BPS = 100;

    bytes32 private constant ATTESTATION_TYPEHASH =
        keccak256("Attestation(uint256 depositId,address depositor,uint256 originChainId,address recipient,uint256 amount)");

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    IERC20 public immutable token;
    uint8 public immutable tokenDecimals;
    uint256 public immutable MIN_DEPOSIT;

    address public operator;
    uint256 public feeRate;
    uint256 public nextDepositId;

    mapping(address => uint256) public balances;
    mapping(bytes32 => bool) public finalized;

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();

        token = IERC20(token_);
        operator = operator_;
        feeRate = DEFAULT_FEE_BPS;
        nextDepositId = 1;

        uint8 decimals_ = 18;
        try IERC20(token_).decimals() returns (uint8 d) {
            if (d > 0) {
                decimals_ = d;
            }
        } catch {}
        tokenDecimals = decimals_;

        if (decimals_ >= 2) {
            MIN_DEPOSIT = 10 ** (uint256(decimals_) - 2);
        } else {
            MIN_DEPOSIT = 1;
        }
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setFeeRate(uint256 newFeeRate) external onlyOperator {
        if (newFeeRate > MAX_FEE_BPS) revert FeeRateTooHigh(newFeeRate, MAX_FEE_BPS);
        uint256 previous = feeRate;
        feeRate = newFeeRate;
        emit FeeRateUpdated(previous, newFeeRate);
    }

    function deposit(
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = (amount * feeRate) / BPS_DENOMINATOR;

        uint256 depositId = nextDepositId;
        nextDepositId = depositId + 1;

        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposit(
            msg.sender,
            depositId,
            block.chainid,
            destChainId,
            recipient,
            amount,
            fee
        );
    }

    function finalizeTransfer(
        uint256 depositId,
        address depositor,
        uint256 originChainId,
        address recipient,
        uint256 amount,
        bytes calldata signature
    ) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bytes32 attestationId = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ATTESTATION_TYPEHASH,
                    depositId,
                    depositor,
                    originChainId,
                    recipient,
                    amount
                )
            )
        );

        if (finalized[attestationId]) revert AlreadyFinalized(attestationId);

        if (msg.sender != operator) {
            if (signature.length != 65) revert InvalidSignature();
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }
            if (v < 27) v += 27;
            if (v != 27 && v != 28) revert InvalidSignature();
            address signer = ecrecover(attestationId, v, r, s);
            if (signer != operator) revert InvalidSignature();
        }

        finalized[attestationId] = true;

        uint256 fee = (amount * feeRate) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        balances[recipient] += netAmount;

        emit Finalized(attestationId, depositId, recipient, amount, fee, netAmount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        balances[msg.sender] = available - amount;

        _safeTransfer(token, msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function computeFee(uint256 amount) external view returns (uint256) {
        return (amount * feeRate) / BPS_DENOMINATOR;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("CrossChainTokenBridge")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function attestationHash(
        uint256 depositId,
        address depositor,
        uint256 originChainId,
        address recipient,
        uint256 amount
    ) external view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ATTESTATION_TYPEHASH,
                    depositId,
                    depositor,
                    originChainId,
                    recipient,
                    amount
                )
            )
        );
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domainSeparator(), structHash));
    }

    function _safeTransfer(IERC20 tok, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(tok).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 tok, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(tok).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
