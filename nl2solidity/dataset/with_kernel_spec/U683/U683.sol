// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRandomCallback {
    function onRandomNumberFulfilled(uint256 requestId, uint256 random) external;
}

/**
 * @title VerifiableRandomnessProvider
 * @notice Provides verifiable random numbers to other contracts. The contract
 *         charges a configurable fee per request (default 0.01 ether) which is
 *         forwarded immediately to the designated treasury, so the contract
 *         itself never custodies assets. Pending requests expire after 24 hours.
 */
contract VerifiableRandomnessProvider {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientFee();
    error ExcessiveFee();
    error RequestNotFound();
    error RequestAlreadyFulfilled();
    error RequestHasExpired();
    error RequestNotExpired();
    error InvalidProof();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event RandomNumberRequested(
        uint256 indexed requestId,
        address indexed requester,
        address indexed callback,
        uint256 seed,
        uint256 fee
    );

    event RandomNumberGenerated(uint256 indexed requestId, uint256 randomNumber);

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    event OperatorUpdated(address oldOperator, address newOperator);

    event TreasuryUpdated(address oldTreasury, address newTreasury);

    event RequestExpired(uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                          CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant DEFAULT_FEE = 0.01 ether;
    uint256 public constant EXPIRY_WINDOW = 24 hours;
    uint256 public constant MAX_FEE = 1 ether;

    struct Request {
        address requester;
        address callback;
        uint256 seed;
        uint256 requestedAt;
        uint256 feePaid;
        bool fulfilled;
        bool expired;
        uint256 random;
    }

    address public owner;
    address public operator;
    address public treasury;
    uint256 public fee;

    uint256 private s_nextRequestId;

    mapping(uint256 => Request) private s_requests;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _operator, address _treasury) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        fee = DEFAULT_FEE;
        s_nextRequestId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert ExcessiveFee();
        uint256 oldFee = fee;
        fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                       CORE REQUEST LOGIC
    //////////////////////////////////////////////////////////////*/
    function requestRandomNumber(uint256 seed, address callback)
        external
        payable
        returns (uint256 requestId)
    {
        if (callback == address(0)) revert ZeroAddress();
        if (msg.value < fee) revert InsufficientFee();

        // Forward the full payment to the treasury immediately so the
        // contract never custodies assets.
        (bool ok, ) = treasury.call{value: msg.value}("");
        if (!ok) revert TransferFailed();

        requestId = s_nextRequestId++;
        s_requests[requestId] = Request({
            requester: msg.sender,
            callback: callback,
            seed: seed,
            requestedAt: block.timestamp,
            feePaid: msg.value,
            fulfilled: false,
            expired: false,
            random: 0
        });

        emit RandomNumberRequested(requestId, msg.sender, callback, seed, fee);
    }

    function fulfillRequest(
        uint256 requestId,
        bytes calldata proof,
        uint256 random
    ) external onlyOperator {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) revert RequestNotFound();
        if (r.fulfilled) revert RequestAlreadyFulfilled();
        if (r.expired) revert RequestAlreadyFulfilled();
        if (block.timestamp > r.requestedAt + EXPIRY_WINDOW) revert RequestHasExpired();
        if (proof.length == 0) revert InvalidProof();

        r.fulfilled = true;
        r.random = random;

        emit RandomNumberGenerated(requestId, random);

        try IRandomCallback(r.callback).onRandomNumberFulfilled(requestId, random) {}
        catch {
            // Intentionally swallow: fulfillment is already recorded.
        }
    }

    function expireRequest(uint256 requestId) external {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) revert RequestNotFound();
        if (r.fulfilled) revert RequestAlreadyFulfilled();
        if (r.expired) revert RequestAlreadyFulfilled();
        if (block.timestamp <= r.requestedAt + EXPIRY_WINDOW) revert RequestNotExpired();

        r.expired = true;
        emit RequestExpired(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getRandomNumber(uint256 requestId) external view returns (uint256 random) {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) revert RequestNotFound();
        if (!r.fulfilled) revert RequestNotFound();
        return r.random;
    }

    function getRequester(uint256 requestId) external view returns (address requester) {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) revert RequestNotFound();
        return r.requester;
    }

    function getRequest(uint256 requestId)
        external
        view
        returns (
            address requester,
            address callback,
            uint256 seed,
            uint256 requestedAt,
            uint256 feePaid,
            bool fulfilled,
            bool expired,
            uint256 random
        )
    {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) revert RequestNotFound();
        return (
            r.requester,
            r.callback,
            r.seed,
            r.requestedAt,
            r.feePaid,
            r.fulfilled,
            r.expired,
            r.random
        );
    }

    function isPending(uint256 requestId) external view returns (bool) {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) return false;
        return !r.fulfilled && !r.expired;
    }

    function getExpiryTimestamp(uint256 requestId) external view returns (uint256) {
        Request storage r = s_requests[requestId];
        if (r.requester == address(0)) return 0;
        return r.requestedAt + EXPIRY_WINDOW;
    }

    function nextRequestId() external view returns (uint256) {
        return s_nextRequestId;
    }
}
