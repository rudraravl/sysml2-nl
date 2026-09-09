// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), errorMessage);
        (bool success, bytes memory returndata) = target.call(data);
        if (success) {
            if (returndata.length == 0) {
                return returndata;
            }
            return abi.decode(returndata, (bytes));
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

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    constructor() {
        _status = NOT_ENTERED;
    }
}

/**
 * @title TradeReceivablesPool
 * @notice Manages the lifecycle of tokenized real-world trade receivables backed by stablecoin collateral.
 *         Liquidity providers deposit stablecoins, operators issue receivable tokens against verified
 *         real-world assets, and receivable tokens can be redeemed for stablecoins after maturity.
 */
contract TradeReceivablesPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error CallerNotOperator();
    error CallerNotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error ReceivableNotMatured();
    error ReceivableAlreadyApproved();
    error ReceivableNotApproved();
    error ReceivableAlreadyRedeemed();
    error ReceivableDoesNotExist();
    error ContractPaused();
    error InvalidMaturityDate();
    error AlreadyOperator();
    error NotOperator();
    error AlreadyPaused();
    error NotPaused();

    event StablecoinDeposited(address indexed provider, uint256 amount);
    event StablecoinWithdrawn(address indexed provider, uint256 amount, uint256 fee);
    event ReceivableTokenIssued(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 faceValue,
        uint256 maturityDate
    );
    event ReceivableTokenApproved(uint256 indexed tokenId, address indexed operator);
    event ReceivableTokenRedeemed(uint256 indexed tokenId, address indexed redeemer, uint256 amount);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeWithdrawn(address indexed owner, uint256 amount);

    struct ReceivableToken {
        uint256 faceValue;
        uint256 maturityDate;
        address issuer;
        address redeemer;
        bool approved;
        bool redeemed;
    }

    IERC20 public immutable stablecoin;
    address public owner;
    bool public paused;

    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public nextTokenId;
    uint256 public totalStablecoinBalance;
    uint256 public totalLiquidityDeposits;
    uint256 public accumulatedFees;

    mapping(address => uint256) public liquidityProviderBalances;
    mapping(uint256 => ReceivableToken) public receivableTokens;
    mapping(address => bool) public isOperator;
    uint256[] public receivableTokenRegistry;

    modifier onlyOwner() {
        if (msg.sender != owner) revert CallerNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert CallerNotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        address previousOwner = owner;
        owner = msg.sender;
        nextTokenId = 1;
        emit OwnershipTransferred(previousOwner, msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function addOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (isOperator[operator]) revert AlreadyOperator();
        isOperator[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        if (!isOperator[operator]) revert NotOperator();
        isOperator[operator] = false;
        emit OperatorRemoved(operator);
    }

    function pause() external onlyOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function depositStablecoin(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        liquidityProviderBalances[msg.sender] += amount;
        totalLiquidityDeposits += amount;
        totalStablecoinBalance += amount;

        emit StablecoinDeposited(msg.sender, amount);
    }

    function withdrawStablecoin(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (liquidityProviderBalances[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        liquidityProviderBalances[msg.sender] -= amount;
        totalLiquidityDeposits -= amount;
        totalStablecoinBalance -= amount;
        if (fee > 0) {
            accumulatedFees += fee;
        }

        stablecoin.safeTransfer(msg.sender, netAmount);

        emit StablecoinWithdrawn(msg.sender, amount, fee);
    }

    function issueReceivableToken(
        uint256 faceValue,
        uint256 maturityDate,
        address issuer
    ) external onlyOperator whenNotPaused returns (uint256 tokenId) {
        if (faceValue == 0) revert ZeroAmount();
        if (maturityDate <= block.timestamp) revert InvalidMaturityDate();
        if (issuer == address(0)) revert ZeroAddress();
        if (totalStablecoinBalance < faceValue) revert InsufficientBalance();

        tokenId = nextTokenId;
        nextTokenId++;

        receivableTokens[tokenId] = ReceivableToken({
            faceValue: faceValue,
            maturityDate: maturityDate,
            issuer: issuer,
            redeemer: address(0),
            approved: false,
            redeemed: false
        });

        receivableTokenRegistry.push(tokenId);

        totalStablecoinBalance -= faceValue;

        emit ReceivableTokenIssued(tokenId, issuer, faceValue, maturityDate);
    }

    function approveReceivableToken(uint256 tokenId) external onlyOperator whenNotPaused {
        ReceivableToken storage token = receivableTokens[tokenId];
        if (token.faceValue == 0) revert ReceivableDoesNotExist();
        if (token.approved) revert ReceivableAlreadyApproved();
        if (token.redeemed) revert ReceivableAlreadyRedeemed();

        token.approved = true;

        emit ReceivableTokenApproved(tokenId, msg.sender);
    }

    function redeemReceivableToken(uint256 tokenId) external nonReentrant whenNotPaused {
        ReceivableToken storage token = receivableTokens[tokenId];
        if (token.faceValue == 0) revert ReceivableDoesNotExist();
        if (!token.approved) revert ReceivableNotApproved();
        if (token.redeemed) revert ReceivableAlreadyRedeemed();
        if (block.timestamp < token.maturityDate) revert ReceivableNotMatured();

        uint256 redemptionAmount = token.faceValue;
        if (stablecoin.balanceOf(address(this)) < redemptionAmount) revert InsufficientBalance();

        token.redeemed = true;

        stablecoin.safeTransfer(msg.sender, redemptionAmount);

        emit ReceivableTokenRedeemed(tokenId, msg.sender, redemptionAmount);
    }

    function withdrawFees(address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        stablecoin.safeTransfer(recipient, amount);
        emit FeeWithdrawn(msg.sender, amount);
    }

    function getReceivableToken(uint256 tokenId)
        external
        view
        returns (
            uint256 faceValue,
            uint256 maturityDate,
            address issuer,
            address redeemer,
            bool approved,
            bool redeemed
        )
    {
        ReceivableToken storage token = receivableTokens[tokenId];
        return (
            token.faceValue,
            token.maturityDate,
            token.issuer,
            token.redeemer,
            token.approved,
            token.redeemed
        );
    }

    function getLiquidityProviderBalance(address provider) external view returns (uint256) {
        return liquidityProviderBalances[provider];
    }

    function getTotalStablecoinBalance() external view returns (uint256) {
        return totalStablecoinBalance;
    }

    function getReceivableTokenRegistry() external view returns (uint256[] memory) {
        return receivableTokenRegistry;
    }

    function getReceivableTokenRegistryLength() external view returns (uint256) {
        return receivableTokenRegistry.length;
    }
}
