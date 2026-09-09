// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GroupChat
 * @notice Manages on-chain group chat memberships and message posting with required fees.
 *         Creating a chat costs 0.01 ether (non-refundable) and posting a message costs
 *         0.0001 ether. A designated operator may pause chat creation and message posting,
 *         and may remove any member from any chat.
 */
contract GroupChat {
    /// @notice Emitted when a new chat is created.
    event ChatCreated(uint256 indexed chatId, address indexed creator);

    /// @notice Emitted when a user joins a chat.
    event MemberJoined(uint256 indexed chatId, address indexed member);

    /// @notice Emitted when a user leaves a chat.
    event MemberLeft(uint256 indexed chatId, address indexed member);

    /// @notice Emitted when a message is posted to a chat.
    event MessagePosted(
        uint256 indexed chatId,
        address indexed sender,
        bytes32 indexed contentHash,
        uint256 messageId
    );

    /// @notice Emitted when the operator removes a member from a chat.
    event MemberRemoved(uint256 indexed chatId, address indexed member, address indexed operator);

    /// @notice Emitted when the contract pause state changes.
    event PausedStateChanged(bool paused);

    /// @notice Emitted when collected fees are withdrawn by the operator.
    event FeesWithdrawn(address indexed operator, address indexed to, uint256 amount);

    error NotOperator();
    error WhenPaused();
    error InvalidChatId();
    error AlreadyMember();
    error NotMember();
    error IncorrectFee();
    error InsufficientBalance();
    error WithdrawFailed();
    error ZeroAddress();

    /// @notice Fee required to create a new chat.
    uint256 public constant CREATE_CHAT_FEE = 0.01 ether;

    /// @notice Fee required to post a single message.
    uint256 public constant POST_MESSAGE_FEE = 0.0001 ether;

    /// @notice The designated operator with administrative privileges.
    address public operator;

    /// @notice Whether chat creation and message posting are currently paused.
    bool public paused;

    /// @notice Global counter used to assign unique chat identifiers. Starts at 1.
    uint256 public nextChatId;

    /// @notice Membership records: chatId => member => isMember.
    mapping(uint256 => mapping(address => bool)) public isMember;

    /// @notice Per-chat message counter: chatId => number of messages posted.
    mapping(uint256 => uint256) public messageCount;

    /// @notice Creator of each chat: chatId => creator address.
    mapping(uint256 => address) public chatCreator;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier validChat(uint256 chatId) {
        if (chatId == 0 || chatId >= nextChatId) revert InvalidChatId();
        _;
    }

    /**
     * @notice Initializes the contract, setting the deployer as the operator.
     */
    constructor() {
        operator = msg.sender;
        nextChatId = 1;
    }

    /**
     * @notice Creates a new chat. The caller must send exactly 0.01 ether, which is non-refundable.
     *         The creator is automatically added as the first member.
     * @return chatId The unique identifier of the newly created chat.
     */
    function createChat() external payable whenNotPaused returns (uint256 chatId) {
        if (msg.value != CREATE_CHAT_FEE) revert IncorrectFee();

        chatId = nextChatId++;
        chatCreator[chatId] = msg.sender;
        isMember[chatId][msg.sender] = true;

        emit ChatCreated(chatId, msg.sender);
        emit MemberJoined(chatId, msg.sender);
    }

    /**
     * @notice Joins an existing chat. The caller must not already be a member.
     * @param chatId The identifier of the chat to join.
     */
    function joinChat(uint256 chatId) external validChat(chatId) {
        if (isMember[chatId][msg.sender]) revert AlreadyMember();

        isMember[chatId][msg.sender] = true;
        emit MemberJoined(chatId, msg.sender);
    }

    /**
     * @notice Posts a message to a chat. The caller must be a member and must send exactly 0.0001 ether.
     * @param chatId The identifier of the chat to post to.
     * @param content The content of the message; only its hash is stored on-chain.
     * @return messageId The sequential identifier assigned to this message within the chat.
     */
    function postMessage(uint256 chatId, string calldata content)
        external
        payable
        whenNotPaused
        validChat(chatId)
        returns (uint256 messageId)
    {
        if (msg.value != POST_MESSAGE_FEE) revert IncorrectFee();
        if (!isMember[chatId][msg.sender]) revert NotMember();

        messageId = messageCount[chatId]++;
        bytes32 contentHash = keccak256(bytes(content));

        emit MessagePosted(chatId, msg.sender, contentHash, messageId);
    }

    /**
     * @notice Leaves a chat. The caller must currently be a member.
     * @param chatId The identifier of the chat to leave.
     */
    function leaveChat(uint256 chatId) external validChat(chatId) {
        if (!isMember[chatId][msg.sender]) revert NotMember();

        isMember[chatId][msg.sender] = false;
        emit MemberLeft(chatId, msg.sender);
    }

    /**
     * @notice Removes a member from a chat. Only callable by the operator.
     * @param chatId The identifier of the chat.
     * @param member The address of the member to remove.
     */
    function removeMember(uint256 chatId, address member) external onlyOperator validChat(chatId) {
        if (member == address(0)) revert ZeroAddress();
        if (!isMember[chatId][member]) revert NotMember();

        isMember[chatId][member] = false;
        emit MemberRemoved(chatId, member, msg.sender);
        emit MemberLeft(chatId, member);
    }

    /**
     * @notice Pauses or unpauses chat creation and message posting. Only callable by the operator.
     * @param _paused True to pause, false to unpause.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /**
     * @notice Withdraws collected fees to a recipient. Only callable by the operator.
     * @param to The payable address to receive the withdrawn ether.
     * @param amount The amount of ether to withdraw.
     */
    function withdraw(address payable to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert WithdrawFailed();

        emit FeesWithdrawn(msg.sender, to, amount);
    }

    /**
     * @notice Returns the total number of chats created so far.
     */
    function totalChats() external view returns (uint256) {
        return nextChatId - 1;
    }

    /**
     * @notice Returns the message count for a given chat.
     * @param chatId The identifier of the chat.
     * @return The number of messages posted to the chat.
     */
    function getChatMessageCount(uint256 chatId) external view returns (uint256) {
        return messageCount[chatId];
    }

    /**
     * @notice Convenience view to check whether a user is a member of a chat.
     * @param chatId The identifier of the chat.
     * @param user The address to check.
     * @return True if the user is a member of the chat.
     */
    function isChatMember(uint256 chatId, address user) external view returns (bool) {
        return isMember[chatId][user];
    }
}
