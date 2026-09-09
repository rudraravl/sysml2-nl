// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            } else {
                revert("SafeERC20: call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation failed");
        }
    }
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
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract GuildTreasury is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error ZeroAddress();
    error AssetAlreadyWhitelisted(address asset);
    error AssetNotWhitelisted(address asset);
    error ExceedsVotingCap(uint256 requested, uint256 cap);
    error InsufficientTreasury(address token, uint256 available, uint256 required);
    error InsufficientDelegation(uint256 available, uint256 required);
    error InsufficientDelegatedPower(uint256 available, uint256 required);
    error InvalidWithdrawalId();
    error WithdrawalNotReady(uint256 unlockTime);
    error WithdrawalAlreadyProcessed();
    error NotWithdrawalRequester();
    error InvalidProposalId();
    error ProposalNotPending();
    error ProposalNotApproved();
    error NotProposerOrOwner();
    error NotCounterparty();
    error NFTNotOwnedByTreasury(address nftContract, uint256 tokenId);
    error NFTNotOwnedByCounterparty(address nftContract, uint256 tokenId);

    uint256 public constant VOTING_CAP_BIPS = 1000;
    uint256 public constant WITHDRAWAL_DELAY = 72 hours;

    IERC20 public immutable governanceToken;

    mapping(address => bool) public isWhitelistedGameAsset;

    mapping(address => uint256) public delegatedVotingPower;
    mapping(address => mapping(address => uint256)) public delegationAmounts;
    mapping(address => uint256) public lockedVotingTokens;
    uint256 public totalDelegatedVotingPower;

    mapping(address => uint256) public treasuryBalance;
    mapping(address => uint256) public pendingWithdrawalBalance;

    struct WithdrawalRequest {
        address token;
        address member;
        uint256 amount;
        uint256 requestedAt;
        bool processed;
        bool cancelled;
    }

    WithdrawalRequest[] public withdrawalRequests;

    enum NFTProposalType { Purchase, Sale }
    enum NFTProposalStatus { Pending, Approved, Rejected, Executed, Cancelled }

    struct NFTProposal {
        address proposer;
        address nftContract;
        uint256 tokenId;
        NFTProposalType proposalType;
        uint256 price;
        address paymentToken;
        address counterparty;
        uint256 createdAt;
        NFTProposalStatus status;
    }

    NFTProposal[] public nftProposals;

    event GameAssetWhitelisted(address indexed asset);
    event GameAssetRemoved(address indexed asset);
    event Deposited(address indexed token, address indexed member, uint256 amount);
    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed token,
        address indexed member,
        uint256 amount,
        uint256 unlockTime
    );
    event WithdrawalProcessed(
        uint256 indexed requestId,
        address indexed token,
        address indexed member,
        uint256 amount
    );
    event WithdrawalCancelled(uint256 indexed requestId);
    event TreasuryTransfer(address indexed token, address indexed to, uint256 amount);
    event VotingPowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 newDelegateePower
    );
    event VotingPowerRevoked(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 newDelegateePower
    );
    event NFTProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed nftContract,
        uint256 tokenId,
        bool isPurchase,
        uint256 price,
        address paymentToken,
        address counterparty
    );
    event NFTProposalApproved(uint256 indexed proposalId);
    event NFTProposalRejected(uint256 indexed proposalId);
    event NFTProposalExecuted(uint256 indexed proposalId);
    event NFTProposalCancelled(uint256 indexed proposalId);

    constructor(address _governanceToken) Ownable(msg.sender) {
        if (_governanceToken == address(0)) revert ZeroAddress();
        governanceToken = IERC20(_governanceToken);
    }

    function votingPowerCap() public view returns (uint256) {
        return (governanceToken.totalSupply() * VOTING_CAP_BIPS) / 10000;
    }

    function addGameAsset(address nftContract) external onlyOwner {
        if (nftContract == address(0)) revert ZeroAddress();
        if (isWhitelistedGameAsset[nftContract]) revert AssetAlreadyWhitelisted(nftContract);
        isWhitelistedGameAsset[nftContract] = true;
        emit GameAssetWhitelisted(nftContract);
    }

    function removeGameAsset(address nftContract) external onlyOwner {
        if (!isWhitelistedGameAsset[nftContract]) revert AssetNotWhitelisted(nftContract);
        isWhitelistedGameAsset[nftContract] = false;
        emit GameAssetRemoved(nftContract);
    }

    function delegateVotingPower(address delegatee, uint256 amount) external nonReentrant {
        if (delegatee == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 newDelegateePower = delegatedVotingPower[delegatee] + amount;
        uint256 cap = votingPowerCap();
        if (newDelegateePower > cap) revert ExceedsVotingCap(newDelegateePower, cap);

        delegatedVotingPower[delegatee] = newDelegateePower;
        delegationAmounts[msg.sender][delegatee] += amount;
        lockedVotingTokens[msg.sender] += amount;
        totalDelegatedVotingPower += amount;

        governanceToken.safeTransferFrom(msg.sender, address(this), amount);

        emit VotingPowerDelegated(msg.sender, delegatee, amount, newDelegateePower);
    }

    function undelegateVotingPower(address delegatee, uint256 amount) external nonReentrant {
        if (delegatee == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = delegationAmounts[msg.sender][delegatee];
        if (available < amount) revert InsufficientDelegation(available, amount);
        if (delegatedVotingPower[delegatee] < amount) {
            revert InsufficientDelegatedPower(delegatedVotingPower[delegatee], amount);
        }

        uint256 newDelegateePower = delegatedVotingPower[delegatee] - amount;
        delegatedVotingPower[delegatee] = newDelegateePower;
        delegationAmounts[msg.sender][delegatee] = available - amount;
        lockedVotingTokens[msg.sender] -= amount;
        totalDelegatedVotingPower -= amount;

        governanceToken.safeTransfer(msg.sender, amount);

        emit VotingPowerRevoked(msg.sender, delegatee, amount, newDelegateePower);
    }

    function depositFungible(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        treasuryBalance[token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(token, msg.sender, amount);
    }

    function requestWithdrawal(address token, uint256 amount) external returns (uint256 requestId) {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = treasuryBalance[token];
        if (available < amount) revert InsufficientTreasury(token, available, amount);

        treasuryBalance[token] = available - amount;
        pendingWithdrawalBalance[token] += amount;

        requestId = withdrawalRequests.length;
        withdrawalRequests.push(
            WithdrawalRequest({
                token: token,
                member: msg.sender,
                amount: amount,
                requestedAt: block.timestamp,
                processed: false,
                cancelled: false
            })
        );

        emit WithdrawalRequested(requestId, token, msg.sender, amount, block.timestamp + WITHDRAWAL_DELAY);
    }

    function processWithdrawal(uint256 requestId) external nonReentrant {
        if (requestId >= withdrawalRequests.length) revert InvalidWithdrawalId();
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.processed || req.cancelled) revert WithdrawalAlreadyProcessed();
        if (req.member != msg.sender) revert NotWithdrawalRequester();

        uint256 unlockTime = req.requestedAt + WITHDRAWAL_DELAY;
        if (block.timestamp < unlockTime) revert WithdrawalNotReady(unlockTime);

        req.processed = true;
        uint256 amount = req.amount;
        pendingWithdrawalBalance[req.token] -= amount;

        IERC20(req.token).safeTransfer(req.member, amount);

        emit WithdrawalProcessed(requestId, req.token, req.member, amount);
    }

    function cancelWithdrawal(uint256 requestId) external {
        if (requestId >= withdrawalRequests.length) revert InvalidWithdrawalId();
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.processed || req.cancelled) revert WithdrawalAlreadyProcessed();
        if (req.member != msg.sender) revert NotWithdrawalRequester();

        req.cancelled = true;
        uint256 amount = req.amount;
        pendingWithdrawalBalance[req.token] -= amount;
        treasuryBalance[req.token] += amount;

        emit WithdrawalCancelled(requestId);
    }

    function transferTreasuryFungible(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = treasuryBalance[token];
        if (available < amount) revert InsufficientTreasury(token, available, amount);

        treasuryBalance[token] = available - amount;
        IERC20(token).safeTransfer(to, amount);

        emit TreasuryTransfer(token, to, amount);
    }

    function proposeNFTPurchase(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        address counterparty
    ) external returns (uint256 proposalId) {
        if (!isWhitelistedGameAsset[nftContract]) revert AssetNotWhitelisted(nftContract);
        if (price == 0) revert ZeroAmount();
        if (paymentToken == address(0) || counterparty == address(0)) revert ZeroAddress();
        if (IERC721(nftContract).ownerOf(tokenId) != counterparty) {
            revert NFTNotOwnedByCounterparty(nftContract, tokenId);
        }

        proposalId = nftProposals.length;
        nftProposals.push(
            NFTProposal({
                proposer: msg.sender,
                nftContract: nftContract,
                tokenId: tokenId,
                proposalType: NFTProposalType.Purchase,
                price: price,
                paymentToken: paymentToken,
                counterparty: counterparty,
                createdAt: block.timestamp,
                status: NFTProposalStatus.Pending
            })
        );

        emit NFTProposalCreated(proposalId, msg.sender, nftContract, tokenId, true, price, paymentToken, counterparty);
    }

    function proposeNFTSale(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        address counterparty
    ) external returns (uint256 proposalId) {
        if (!isWhitelistedGameAsset[nftContract]) revert AssetNotWhitelisted(nftContract);
        if (price == 0) revert ZeroAmount();
        if (paymentToken == address(0) || counterparty == address(0)) revert ZeroAddress();
        if (IERC721(nftContract).ownerOf(tokenId) != address(this)) {
            revert NFTNotOwnedByTreasury(nftContract, tokenId);
        }

        proposalId = nftProposals.length;
        nftProposals.push(
            NFTProposal({
                proposer: msg.sender,
                nftContract: nftContract,
                tokenId: tokenId,
                proposalType: NFTProposalType.Sale,
                price: price,
                paymentToken: paymentToken,
                counterparty: counterparty,
                createdAt: block.timestamp,
                status: NFTProposalStatus.Pending
            })
        );

        emit NFTProposalCreated(proposalId, msg.sender, nftContract, tokenId, false, price, paymentToken, counterparty);
    }

    function approveNFTProposal(uint256 proposalId) external onlyOwner {
        if (proposalId >= nftProposals.length) revert InvalidProposalId();
        NFTProposal storage proposal = nftProposals[proposalId];
        if (proposal.status != NFTProposalStatus.Pending) revert ProposalNotPending();

        proposal.status = NFTProposalStatus.Approved;
        emit NFTProposalApproved(proposalId);
    }

    function rejectNFTProposal(uint256 proposalId) external onlyOwner {
        if (proposalId >= nftProposals.length) revert InvalidProposalId();
        NFTProposal storage proposal = nftProposals[proposalId];
        if (proposal.status != NFTProposalStatus.Pending) revert ProposalNotPending();

        proposal.status = NFTProposalStatus.Rejected;
        emit NFTProposalRejected(proposalId);
    }

    function cancelNFTProposal(uint256 proposalId) external {
        if (proposalId >= nftProposals.length) revert InvalidProposalId();
        NFTProposal storage proposal = nftProposals[proposalId];
        if (proposal.status != NFTProposalStatus.Pending) revert ProposalNotPending();
        if (msg.sender != proposal.proposer && msg.sender != owner()) revert NotProposerOrOwner();

        proposal.status = NFTProposalStatus.Cancelled;
        emit NFTProposalCancelled(proposalId);
    }

    function executeNFTProposal(uint256 proposalId) external nonReentrant {
        if (proposalId >= nftProposals.length) revert InvalidProposalId();
        NFTProposal storage proposal = nftProposals[proposalId];
        if (proposal.status != NFTProposalStatus.Approved) revert ProposalNotApproved();
        if (msg.sender != proposal.counterparty) revert NotCounterparty();

        proposal.status = NFTProposalStatus.Executed;

        if (proposal.proposalType == NFTProposalType.Purchase) {
            _executePurchase(proposal);
        } else {
            _executeSale(proposal);
        }

        emit NFTProposalExecuted(proposalId);
    }

    function _executePurchase(NFTProposal storage proposal) internal {
        address paymentToken = proposal.paymentToken;
        uint256 price = proposal.price;
        uint256 available = treasuryBalance[paymentToken];
        if (available < price) revert InsufficientTreasury(paymentToken, available, price);

        treasuryBalance[paymentToken] = available - price;
        IERC20(paymentToken).safeTransfer(proposal.counterparty, price);
        IERC721(proposal.nftContract).safeTransferFrom(msg.sender, address(this), proposal.tokenId);
    }

    function _executeSale(NFTProposal storage proposal) internal {
        address nftContract = proposal.nftContract;
        uint256 tokenId = proposal.tokenId;
        address paymentToken = proposal.paymentToken;
        uint256 price = proposal.price;

        if (IERC721(nftContract).ownerOf(tokenId) != address(this)) {
            revert NFTNotOwnedByTreasury(nftContract, tokenId);
        }

        treasuryBalance[paymentToken] += price;
        IERC721(nftContract).safeTransferFrom(address(this), proposal.counterparty, tokenId);
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), price);
    }

    function getWithdrawalRequest(uint256 requestId) external view returns (WithdrawalRequest memory) {
        if (requestId >= withdrawalRequests.length) revert InvalidWithdrawalId();
        return withdrawalRequests[requestId];
    }

    function withdrawalUnlockTime(uint256 requestId) external view returns (uint256) {
        if (requestId >= withdrawalRequests.length) revert InvalidWithdrawalId();
        return withdrawalRequests[requestId].requestedAt + WITHDRAWAL_DELAY;
    }

    function withdrawalCount() external view returns (uint256) {
        return withdrawalRequests.length;
    }

    function getNFTProposal(uint256 proposalId) external view returns (NFTProposal memory) {
        if (proposalId >= nftProposals.length) revert InvalidProposalId();
        return nftProposals[proposalId];
    }

    function nftProposalCount() external view returns (uint256) {
        return nftProposals.length;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
