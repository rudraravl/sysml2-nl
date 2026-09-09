// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedBitcoin {
    string public constant name = "Wrapped Bitcoin";
    string public constant symbol = "WBTC";
    uint8 public constant decimals = 8;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public operator;
    address public multisigWallet;
    address public treasury;

    uint256 public constant MIN_DEPOSIT = 100_000; // 0.001 BTC in satoshis (8 decimals)
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct MintRequest {
        address requester;
        uint256 amount;
        bytes proof;
        bool processed;
    }

    struct WithdrawalRequest {
        address requester;
        uint256 amount;
        bool processed;
    }

    mapping(uint256 => MintRequest) public mintRequests;
    uint256 public nextMintRequestId;

    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 public nextWithdrawalRequestId;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event MintRequested(uint256 indexed requestId, address indexed requester, uint256 amount, bytes proof);
    event MintApproved(uint256 indexed requestId, address indexed requester, uint256 amount);
    event RedemptionRequested(uint256 indexed requestId, address indexed requester, uint256 amount, uint256 fee);
    event WithdrawalProcessed(uint256 indexed requestId, address indexed requester, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);
    event MultisigWalletChanged(address indexed previousWallet, address indexed newWallet);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OnlyOwner();
    error OnlyOperator();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountTooLow();
    error RequestAlreadyProcessed();
    error InvalidAmount();
    error InvalidRequest();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(address _multisigWallet, address _operator, address _treasury) {
        if (_multisigWallet == address(0) || _operator == address(0) || _treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        multisigWallet = _multisigWallet;
        operator = _operator;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    function setMultisigWallet(address _multisigWallet) external onlyOwner {
        if (_multisigWallet == address(0)) revert ZeroAddress();
        emit MultisigWalletChanged(multisigWallet, _multisigWallet);
        multisigWallet = _multisigWallet;
    }

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
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _requestMintLogic(uint256 amount, bytes calldata proof) internal returns (uint256 requestId) {
        if (amount < MIN_DEPOSIT) revert AmountTooLow();
        requestId = nextMintRequestId++;
        mintRequests[requestId] = MintRequest({
            requester: msg.sender,
            amount: amount,
            proof: proof,
            processed: false
        });
        emit MintRequested(requestId, msg.sender, amount, proof);
    }

    function requestMint(uint256 amount, bytes calldata proof) external returns (uint256 requestId) {
        return _requestMintLogic(amount, proof);
    }

    function mint(uint256 amount, bytes calldata proof) external returns (uint256 requestId) {
        return _requestMintLogic(amount, proof);
    }

    function approveMint(uint256 requestId) external onlyOperator {
        MintRequest storage req = mintRequests[requestId];
        if (req.requester == address(0)) revert InvalidRequest();
        if (req.processed) revert RequestAlreadyProcessed();
        if (req.amount < MIN_DEPOSIT) revert AmountTooLow();
        req.processed = true;

        address requester = req.requester;
        uint256 amount = req.amount;

        totalSupply += amount;
        balanceOf[requester] += amount;

        emit Transfer(address(0), requester, amount);
        emit MintApproved(requestId, requester, amount);
    }

    function _redeemLogic(uint256 amount) internal returns (uint256 requestId) {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 burnAmount = amount - fee;

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);

        if (fee > 0) {
            balanceOf[treasury] += fee;
            totalSupply += fee;
            emit Transfer(address(0), treasury, fee);
        }

        requestId = nextWithdrawalRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            requester: msg.sender,
            amount: burnAmount,
            processed: false
        });

        emit RedemptionRequested(requestId, msg.sender, burnAmount, fee);
    }

    function redeem(uint256 amount) external returns (uint256 requestId) {
        return _redeemLogic(amount);
    }

    function burn(uint256 amount) external returns (uint256 requestId) {
        return _redeemLogic(amount);
    }

    function processWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert InvalidRequest();
        if (req.processed) revert RequestAlreadyProcessed();
        req.processed = true;

        emit WithdrawalProcessed(requestId, req.requester, req.amount);
    }
}
