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

/**
 * @title TokenLaunchpad
 * @notice Facilitates the launch of new ERC20 tokens by holding deposited
 *         stablecoin funds and the newly minted tokens for distribution.
 *         A designated operator creates launches, sets parameters, and
 *         finalizes them. Participants deposit funds, claim tokens on a
 *         successful launch, or withdraw their deposits on a failed launch.
 */
contract TokenLaunchpad {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NotOperator();
    error ZeroAddress();
    error GoalBelowMinimum();
    error ZeroAmount();
    error LaunchNotActive();
    error LaunchAlreadyFinalized();
    error LaunchNotFinalized();
    error LaunchSuccessful();
    error LaunchFailed();
    error DepositWindowClosed();
    error DepositWindowOpen();
    error NothingToClaim();
    error NothingToWithdraw();
    error GoalNotReached();
    error InsufficientTokenAllowance();
    error InsufficientTokenBalance();
    error TokenTransferFailed();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event LaunchCreated(
        uint256 indexed launchId,
        address indexed token,
        address indexed beneficiary,
        uint256 totalSupply,
        uint256 goal,
        uint256 startTime,
        uint256 endTime
    );
    event Deposited(
        uint256 indexed launchId,
        address indexed participant,
        uint256 amount
    );
    event LaunchFinalized(
        uint256 indexed launchId,
        bool successful,
        uint256 raised,
        uint256 fee
    );
    event TokensClaimed(
        uint256 indexed launchId,
        address indexed participant,
        uint256 tokenAmount
    );
    event FundsWithdrawn(
        uint256 indexed launchId,
        address indexed participant,
        uint256 amount
    );
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant MINIMUM_GOAL = 100_000 * 1e18;
    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_LAUNCH_DURATION = 7 days;

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    address public operator;
    address public treasury;
    IERC20 public immutable paymentToken;

    struct Launch {
        address token;
        address beneficiary;
        uint256 totalSupply;
        uint256 goal;
        uint256 raised;
        uint256 startTime;
        uint256 endTime;
        bool finalized;
        bool successful;
    }

    mapping(uint256 => Launch) private s_launches;
    mapping(uint256 => mapping(address => uint256)) private s_contributions;
    uint256 public nextLaunchId;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _paymentToken, address _treasury) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        operator = msg.sender;
        emit OperatorUpdated(address(0), operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    /**
     * @notice Creates a new token launch.
     * @param token The ERC20 token being launched.
     * @param beneficiary The address that will receive the raised funds (minus fee).
     * @param totalSupply The total amount of launch tokens to be distributed.
     * @param goal The minimum fundraising goal in payment token units.
     * @param duration The duration of the deposit window in seconds.
     */
    function createLaunch(
        address token,
        address beneficiary,
        uint256 totalSupply,
        uint256 goal,
        uint256 duration
    ) external onlyOperator returns (uint256 launchId) {
        if (token == address(0)) revert ZeroAddress();
        if (beneficiary == address(0)) revert ZeroAddress();
        if (totalSupply == 0) revert ZeroAmount();
        if (goal < MINIMUM_GOAL) revert GoalBelowMinimum();
        if (duration == 0) revert ZeroAmount();

        launchId = nextLaunchId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        s_launches[launchId] = Launch({
            token: token,
            beneficiary: beneficiary,
            totalSupply: totalSupply,
            goal: goal,
            raised: 0,
            startTime: startTime,
            endTime: endTime,
            finalized: false,
            successful: false
        });

        emit LaunchCreated(launchId, token, beneficiary, totalSupply, goal, startTime, endTime);
    }

    /**
     * @notice Finalizes a launch. If the goal was reached, the launch is
     *         marked successful, launch tokens are pulled from the operator,
     *         the 2% fee is sent to the treasury, and the net raised funds
     *         are sent to the beneficiary. Otherwise the launch is marked
     *         failed and participants may withdraw their deposits.
     */
    function finalizeLaunch(uint256 launchId) external onlyOperator {
        Launch storage launch = s_launches[launchId];
        if (launch.token == address(0)) revert LaunchNotActive();
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < launch.endTime && launch.raised < launch.goal) {
            revert DepositWindowOpen();
        }

        launch.finalized = true;

        if (launch.raised >= launch.goal) {
            launch.successful = true;

            // Pull the launched tokens from the operator.
            IERC20 token = IERC20(launch.token);
            uint256 operatorBalance = token.balanceOf(operator);
            if (operatorBalance < launch.totalSupply) revert InsufficientTokenBalance();
            uint256 allowance = token.allowance(operator, address(this));
            if (allowance < launch.totalSupply) revert InsufficientTokenAllowance();

            bool tokenOk = token.transferFrom(operator, address(this), launch.totalSupply);
            if (!tokenOk) revert TokenTransferFailed();

            // Distribute fee and net raised funds.
            uint256 fee = (launch.raised * FEE_BPS) / BPS_DENOMINATOR;
            uint256 net = launch.raised - fee;

            if (fee > 0) {
                bool feeOk = paymentToken.transfer(treasury, fee);
                if (!feeOk) revert TokenTransferFailed();
            }
            if (net > 0) {
                bool netOk = paymentToken.transfer(launch.beneficiary, net);
                if (!netOk) revert TokenTransferFailed();
            }

            emit LaunchFinalized(launchId, true, launch.raised, fee);
        } else {
            launch.successful = false;
            emit LaunchFinalized(launchId, false, launch.raised, 0);
        }
    }

    // ---------------------------------------------------------------------
    // Participant functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposits payment tokens into an active launch.
     * @param launchId The identifier of the launch.
     * @param amount The amount of payment tokens to deposit.
     */
    function deposit(uint256 launchId, uint256 amount) external {
        Launch storage launch = s_launches[launchId];
        if (launch.token == address(0)) revert LaunchNotActive();
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < launch.startTime || block.timestamp > launch.endTime) {
            revert DepositWindowClosed();
        }
        if (amount == 0) revert ZeroAmount();

        // Effects
        s_contributions[launchId][msg.sender] += amount;
        launch.raised += amount;

        // Interactions
        bool ok = paymentToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TokenTransferFailed();

        emit Deposited(launchId, msg.sender, amount);
    }

    /**
     * @notice Claims allocated launch tokens after a successful launch.
     * @param launchId The identifier of the launch.
     */
    function claimTokens(uint256 launchId) external {
        Launch storage launch = s_launches[launchId];
        if (!launch.finalized) revert LaunchNotFinalized();
        if (!launch.successful) revert LaunchFailed();

        uint256 contribution = s_contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToClaim();

        // Allocation is proportional to contribution relative to total raised.
        uint256 allocation = (contribution * launch.totalSupply) / launch.raised;

        // Effects
        s_contributions[launchId][msg.sender] = 0;

        // Interactions
        bool ok = IERC20(launch.token).transfer(msg.sender, allocation);
        if (!ok) revert TokenTransferFailed();

        emit TokensClaimed(launchId, msg.sender, allocation);
    }

    /**
     * @notice Withdraws deposited funds if a launch failed.
     * @param launchId The identifier of the launch.
     */
    function withdraw(uint256 launchId) external {
        Launch storage launch = s_launches[launchId];
        if (!launch.finalized) revert LaunchNotFinalized();
        if (launch.successful) revert LaunchSuccessful();

        uint256 contribution = s_contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToWithdraw();

        // Effects
        s_contributions[launchId][msg.sender] = 0;

        // Interactions
        bool ok = paymentToken.transfer(msg.sender, contribution);
        if (!ok) revert TokenTransferFailed();

        emit FundsWithdrawn(launchId, msg.sender, contribution);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    function getLaunch(uint256 launchId) external view returns (Launch memory) {
        return s_launches[launchId];
    }

    function getContribution(uint256 launchId, address participant) external view returns (uint256) {
        return s_contributions[launchId][participant];
    }
}
