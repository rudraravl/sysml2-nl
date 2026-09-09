// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract TokenPresale is Ownable {
    error PresaleNotActive();
    error PresaleNotEnded();
    error PresaleNotSuccessful();
    error PresaleNotFailed();
    error PresaleNotPending();
    error PresaleNotRejectedOrFinalized();
    error InsufficientContribution();
    error HardCapExceeded();
    error InsufficientTokens();
    error AlreadyClaimed();
    error AlreadyRefunded();
    error InvalidPresaleParameters();
    error NotOperator();
    error CreationFeeNotPaid();
    error NotCreator();
    error NoUnsoldTokens();
    error TransferFailed();
    error PresaleDoesNotExist();
    error ZeroAddress();

    event PresaleCreated(
        uint256 indexed presaleId,
        address indexed creator,
        address token,
        uint256 tokenAmount,
        uint256 tokensPerETH,
        uint256 softCap,
        uint256 hardCap,
        uint256 startTime,
        uint256 endTime
    );
    event ContributionMade(uint256 indexed presaleId, address indexed contributor, uint256 amount, uint256 tokensPurchased);
    event TokensClaimed(uint256 indexed presaleId, address indexed contributor, uint256 tokenAmount);
    event FundsRefunded(uint256 indexed presaleId, address indexed contributor, uint256 amount);
    event PresaleApproved(uint256 indexed presaleId);
    event PresaleRejected(uint256 indexed presaleId);
    event PresaleFinalized(uint256 indexed presaleId, bool successful);
    event CreationFeeUpdated(uint256 newFee);
    event OperatorUpdated(address indexed operator, bool status);
    event TokensWithdrawn(uint256 indexed presaleId, address indexed creator, uint256 amount);
    event FeesWithdrawn(address indexed owner, uint256 amount);

    enum PresaleStatus { Pending, Active, Successful, Failed, Rejected }

    struct Presale {
        address creator;
        IERC20 token;
        uint256 tokenAmount;
        uint256 tokensPerETH;
        uint256 softCap;
        uint256 hardCap;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 totalTokensSold;
        uint256 totalTokensClaimed;
        PresaleStatus status;
        mapping(address => uint256) contributions;
        mapping(address => uint256) purchasedTokens;
        mapping(address => bool) claimed;
        mapping(address => bool) refunded;
    }

    uint256 public creationFee = 0.1 ether;
    mapping(address => bool) public operators;
    uint256 public presaleCount;
    mapping(uint256 => Presale) private presales;
    uint256 public totalFees;

    constructor() Ownable(msg.sender) {
        operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier presaleExists(uint256 _presaleId) {
        if (_presaleId == 0 || _presaleId > presaleCount) revert PresaleDoesNotExist();
        _;
    }

    function setCreationFee(uint256 _fee) external onlyOwner {
        creationFee = _fee;
        emit CreationFeeUpdated(_fee);
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = totalFees;
        totalFees = 0;
        (bool success, ) = payable(owner()).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeesWithdrawn(owner(), amount);
    }

    function createPresale(
        IERC20 _token,
        uint256 _tokenAmount,
        uint256 _tokensPerETH,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime
    ) external payable returns (uint256 presaleId) {
        if (msg.value != creationFee) revert CreationFeeNotPaid();
        if (
            address(_token) == address(0) ||
            _tokenAmount == 0 ||
            _tokensPerETH == 0 ||
            _softCap == 0 ||
            _hardCap < _softCap ||
            _startTime >= _endTime ||
            _startTime < block.timestamp
        ) revert InvalidPresaleParameters();

        bool ok = _token.transferFrom(msg.sender, address(this), _tokenAmount);
        if (!ok) revert TransferFailed();

        totalFees += msg.value;

        presaleId = ++presaleCount;
        Presale storage p = presales[presaleId];
        p.creator = msg.sender;
        p.token = _token;
        p.tokenAmount = _tokenAmount;
        p.tokensPerETH = _tokensPerETH;
        p.softCap = _softCap;
        p.hardCap = _hardCap;
        p.startTime = _startTime;
        p.endTime = _endTime;
        p.status = PresaleStatus.Pending;

        emit PresaleCreated(
            presaleId,
            msg.sender,
            address(_token),
            _tokenAmount,
            _tokensPerETH,
            _softCap,
            _hardCap,
            _startTime,
            _endTime
        );
    }

    function approvePresale(uint256 _presaleId) external onlyOperator presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Pending) revert PresaleNotPending();
        p.status = PresaleStatus.Active;
        emit PresaleApproved(_presaleId);
    }

    function rejectPresale(uint256 _presaleId) external onlyOperator presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Pending) revert PresaleNotPending();
        p.status = PresaleStatus.Rejected;
        emit PresaleRejected(_presaleId);
    }

    function finalizePresale(uint256 _presaleId) external presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Active) revert PresaleNotActive();
        if (block.timestamp <= p.endTime) revert PresaleNotEnded();

        bool successful = p.totalRaised >= (p.softCap * 50) / 100;
        if (successful) {
            p.status = PresaleStatus.Successful;
        } else {
            p.status = PresaleStatus.Failed;
        }
        emit PresaleFinalized(_presaleId, successful);
    }

    function contribute(uint256 _presaleId) external payable presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Active) revert PresaleNotActive();
        if (block.timestamp < p.startTime || block.timestamp > p.endTime) revert PresaleNotActive();
        if (msg.value == 0) revert InsufficientContribution();

        uint256 newTotal = p.totalRaised + msg.value;
        if (newTotal > p.hardCap) revert HardCapExceeded();

        uint256 tokensToBuy = (msg.value * p.tokensPerETH) / 1 ether;
        if (tokensToBuy == 0) revert InsufficientContribution();
        if (p.totalTokensSold + tokensToBuy > p.tokenAmount) revert InsufficientTokens();

        p.totalRaised = newTotal;
        p.totalTokensSold += tokensToBuy;
        p.contributions[msg.sender] += msg.value;
        p.purchasedTokens[msg.sender] += tokensToBuy;

        emit ContributionMade(_presaleId, msg.sender, msg.value, tokensToBuy);
    }

    function claimTokens(uint256 _presaleId) external presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Successful) revert PresaleNotSuccessful();
        if (p.claimed[msg.sender]) revert AlreadyClaimed();

        uint256 tokenAmount = p.purchasedTokens[msg.sender];
        if (tokenAmount == 0) revert InsufficientContribution();

        p.claimed[msg.sender] = true;
        p.totalTokensClaimed += tokenAmount;

        bool ok = p.token.transfer(msg.sender, tokenAmount);
        if (!ok) revert TransferFailed();

        emit TokensClaimed(_presaleId, msg.sender, tokenAmount);
    }

    function refund(uint256 _presaleId) external presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (p.status != PresaleStatus.Failed) revert PresaleNotFailed();
        if (p.refunded[msg.sender]) revert AlreadyRefunded();

        uint256 contribution = p.contributions[msg.sender];
        if (contribution == 0) revert InsufficientContribution();

        p.refunded[msg.sender] = true;
        p.contributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: contribution}("");
        if (!success) revert TransferFailed();

        emit FundsRefunded(_presaleId, msg.sender, contribution);
    }

    function withdrawTokens(uint256 _presaleId) external presaleExists(_presaleId) {
        Presale storage p = presales[_presaleId];
        if (msg.sender != p.creator) revert NotCreator();

        if (p.status == PresaleStatus.Rejected || p.status == PresaleStatus.Failed) {
            uint256 amount = p.tokenAmount;
            p.tokenAmount = 0;
            bool ok = p.token.transfer(msg.sender, amount);
            if (!ok) revert TransferFailed();
            emit TokensWithdrawn(_presaleId, msg.sender, amount);
        } else if (p.status == PresaleStatus.Successful) {
            uint256 unsold = p.tokenAmount - p.totalTokensClaimed;
            if (unsold == 0) revert NoUnsoldTokens();
            p.tokenAmount = p.totalTokensClaimed;
            bool ok = p.token.transfer(msg.sender, unsold);
            if (!ok) revert TransferFailed();
            emit TokensWithdrawn(_presaleId, msg.sender, unsold);
        } else {
            revert PresaleNotRejectedOrFinalized();
        }
    }

    function getPresaleConfig(uint256 _presaleId)
        external
        view
        presaleExists(_presaleId)
        returns (
            address creator,
            address token,
            uint256 tokenAmount,
            uint256 tokensPerETH,
            uint256 softCap,
            uint256 hardCap
        )
    {
        Presale storage p = presales[_presaleId];
        return (
            p.creator,
            address(p.token),
            p.tokenAmount,
            p.tokensPerETH,
            p.softCap,
            p.hardCap
        );
    }

    function getPresaleSchedule(uint256 _presaleId)
        external
        view
        presaleExists(_presaleId)
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 totalRaised,
            uint256 totalTokensSold,
            uint256 totalTokensClaimed,
            PresaleStatus status
        )
    {
        Presale storage p = presales[_presaleId];
        return (
            p.startTime,
            p.endTime,
            p.totalRaised,
            p.totalTokensSold,
            p.totalTokensClaimed,
            p.status
        );
    }

    function getContribution(uint256 _presaleId, address _contributor)
        external
        view
        presaleExists(_presaleId)
        returns (uint256)
    {
        return presales[_presaleId].contributions[_contributor];
    }

    function getPurchasedTokens(uint256 _presaleId, address _contributor)
        external
        view
        presaleExists(_presaleId)
        returns (uint256)
    {
        return presales[_presaleId].purchasedTokens[_contributor];
    }

    function hasClaimed(uint256 _presaleId, address _contributor)
        external
        view
        presaleExists(_presaleId)
        returns (bool)
    {
        return presales[_presaleId].claimed[_contributor];
    }

    function hasRefunded(uint256 _presaleId, address _contributor)
        external
        view
        presaleExists(_presaleId)
        returns (bool)
    {
        return presales[_presaleId].refunded[_contributor];
    }
}
