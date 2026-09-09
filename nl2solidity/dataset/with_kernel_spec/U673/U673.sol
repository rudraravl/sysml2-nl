// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract PreLaunchDistribution {
    // --------- Custom Errors ---------
    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error EligibleTokenNotSet();
    error DistributionTokenNotSet();
    error DistributionCapExceeded();
    error InsufficientDeposit();
    error NothingToClaim();
    error TransferFailed();
    error NonExistentToken();
    error WrongFromAddress();
    error NotApprovedOrOwner();
    error NFTAlreadyClaimed();
    error ReentrancyDetected();
    error CannotRecoverCoreToken();
    error EthNotAccepted();

    // --------- Events ---------
    event EligibleTokenSet(address indexed token);
    event DistributionTokenSet(address indexed token);
    event DistributionReleased(uint256 timestamp, uint256 amount, uint256 totalAllocated);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 depositedAmount, uint256 distributionAmount);
    event RewardNFTClaimed(address indexed user, uint256 tokenId);
    event NFTTransferred(address indexed from, address indexed to, uint256 tokenId);
    event EthRecovered(address indexed to, uint256 amount);

    // --------- Constants ---------
    uint256 public constant DISTRIBUTION_CAP = 70_000_000 * 10 ** 18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant NFT_CLAIM_THRESHOLD = 1e15;

    // --------- State Variables ---------
    address public operator;
    address public eligibleYieldToken;
    address public distributionToken;

    uint256 public totalDistributionAllocated;
    uint256 public totalDeposited;
    uint256 public totalDistributionClaimed;

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userDistributionClaimed;
    mapping(address => bool) public hasClaimedNFT;

    // --------- Reentrancy Guard ---------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyDetected();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // --------- NFT State ---------
    string public name;
    string public symbol;

    uint256 private _nextTokenId = 1;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // --------- Modifiers ---------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier nonZero(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    modifier whenEligibleTokenSet() {
        if (eligibleYieldToken == address(0)) revert EligibleTokenNotSet();
        _;
    }

    modifier whenDistributionTokenSet() {
        if (distributionToken == address(0)) revert DistributionTokenNotSet();
        _;
    }

    // --------- Constructor ---------
    constructor(address _operator) nonZero(_operator) {
        operator = _operator;
        name = "PreLaunch Reward NFT";
        symbol = "PLRNFT";
    }

    // --------- Operator Functions ---------

    function setEligibleYieldToken(address token) external onlyOperator nonZero(token) {
        eligibleYieldToken = token;
        emit EligibleTokenSet(token);
    }

    function setDistributionToken(address token) external onlyOperator nonZero(token) {
        distributionToken = token;
        emit DistributionTokenSet(token);
    }

    function releaseDistribution(uint256 amount)
        external
        onlyOperator
        whenDistributionTokenSet
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (totalDistributionAllocated + amount > DISTRIBUTION_CAP) revert DistributionCapExceeded();

        // Effects: update state before external call (checks-effects-interactions)
        totalDistributionAllocated += amount;

        // Interactions
        bool ok = IERC20(distributionToken).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit DistributionReleased(block.timestamp, amount, totalDistributionAllocated);
    }

    function recoverERC20(address token, uint256 amount) external onlyOperator {
        if (token == eligibleYieldToken || token == distributionToken) revert CannotRecoverCoreToken();
        bool ok = IERC20(token).transfer(operator, amount);
        if (!ok) revert TransferFailed();
    }

    function recoverETH() external onlyOperator {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToClaim();
        (bool ok, ) = payable(operator).call{value: balance}("");
        if (!ok) revert TransferFailed();
        emit EthRecovered(operator, balance);
    }

    // --------- User Functions ---------

    function deposit(uint256 amount) external nonReentrant whenEligibleTokenSet {
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external call (checks-effects-interactions)
        userDeposits[msg.sender] += amount;
        totalDeposited += amount;

        // Interactions
        bool ok = IERC20(eligibleYieldToken).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(msg.sender, amount);
    }

    function withdraw() external nonReentrant whenDistributionTokenSet {
        uint256 deposited = userDeposits[msg.sender];
        if (deposited == 0) revert InsufficientDeposit();

        uint256 distributionAmount = pendingDistribution(msg.sender);

        // Effects
        userDeposits[msg.sender] = 0;
        userDistributionClaimed[msg.sender] += distributionAmount;
        totalDeposited -= deposited;
        totalDistributionClaimed += distributionAmount;

        // Interactions
        bool ok1 = IERC20(eligibleYieldToken).transfer(msg.sender, deposited);
        if (!ok1) revert TransferFailed();

        if (distributionAmount > 0) {
            bool ok2 = IERC20(distributionToken).transfer(msg.sender, distributionAmount);
            if (!ok2) revert TransferFailed();
        }

        emit Withdrawn(msg.sender, deposited, distributionAmount);
    }

    function claimRewardNFT() external nonReentrant whenEligibleTokenSet {
        if (hasClaimedNFT[msg.sender]) revert NFTAlreadyClaimed();
        if (userDeposits[msg.sender] < NFT_CLAIM_THRESHOLD) revert InsufficientDeposit();

        hasClaimedNFT[msg.sender] = true;

        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        emit RewardNFTClaimed(msg.sender, tokenId);
    }

    // --------- View Functions ---------

    function pendingDistribution(address user) public view returns (uint256) {
        uint256 deposited = totalDeposited;
        if (deposited < 1) return 0;

        uint256 userShare = (userDeposits[user] * totalDistributionAllocated) / deposited;
        uint256 claimed = userDistributionClaimed[user];
        if (userShare <= claimed) return 0;
        uint256 pending = userShare - claimed;

        uint256 contractBalance = IERC20(distributionToken).balanceOf(address(this));
        if (pending > contractBalance) pending = contractBalance;
        return pending;
    }

    function totalDistributionAvailable() external pure returns (uint256) {
        return DISTRIBUTION_CAP;
    }

    // --------- ERC721 Core ---------

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert NonExistentToken();
        return owner;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (to == owner) revert NotApprovedOrOwner();
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender])
            revert NotApprovedOrOwner();
        _tokenApprovals[tokenId] = to;
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_owners[tokenId] == address(0)) revert NonExistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operatorAddr, bool approved) external {
        if (operatorAddr == msg.sender) revert NotApprovedOrOwner();
        _operatorApprovals[msg.sender][operatorAddr] = approved;
    }

    function isApprovedForAll(address owner, address operatorAddr) public view returns (bool) {
        return _operatorApprovals[owner][operatorAddr];
    }

    function transferFrom(address from, address to, uint256 tokenId) public nonReentrant {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        address owner = ownerOf(tokenId);
        if (owner != from) revert WrongFromAddress();

        bool approved = (msg.sender == owner) ||
            (getApproved(tokenId) == msg.sender) ||
            isApprovedForAll(owner, msg.sender);
        if (!approved) revert NotApprovedOrOwner();

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    // --------- Internal NFT Functions ---------

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert NonExistentToken();

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit NFTTransferred(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = address(0);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit NFTTransferred(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        uint256 size;
        assembly {
            size := extcodesize(to)
        }
        if (size > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector)
                    revert NotApprovedOrOwner();
            } catch {
                revert NotApprovedOrOwner();
            }
        }
    }

    // --------- Receive ---------
    receive() external payable {
        revert EthNotAccepted();
    }
}
