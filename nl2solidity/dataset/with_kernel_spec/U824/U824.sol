// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract LiquidStakingPool {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error Paused();
    error InsufficientBalance();
    error DepositTooSmall();
    error ZeroShares();
    error ZeroAssets();
    error InvalidRate();
    error NoRewards();
    error ReentrantCall();
    error ZeroAddress();
    error InvalidMinDeposit();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 shares, uint256 assets, uint256 fee);
    event RewardsClaimed(address indexed caller, uint256 assets);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 rewardAssets);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesSwept(address indexed operator, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant RATE_SCALE = 1e18;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable asset;
    uint256 public immutable minDepositAmount;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public operator;
    bool public paused;

    string public name;
    string public symbol;

    uint256 public exchangeRate; // base assets per LST, scaled by RATE_SCALE
    uint256 public totalSupply; // total liquid staking token supply
    uint256 public totalAssets; // total base assets staked / tracked
    uint256 public accumulatedFees; // withdrawal fees, claimable by operator

    mapping(address => uint256) public balanceOf; // user LST balance
    mapping(address => uint256) public lastClaimRate; // rate at last reward settlement

    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _asset,
        uint256 _initialRate,
        address _operator,
        uint256 _minDeposit,
        string memory _name,
        string memory _symbol
    ) {
        if (_asset == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialRate == 0) revert InvalidRate();
        if (_minDeposit == 0) revert InvalidMinDeposit();

        asset = IERC20(_asset);
        exchangeRate = _initialRate;
        operator = _operator;
        minDepositAmount = _minDeposit;
        paused = false;
        name = _name;
        symbol = _symbol;

        emit ExchangeRateUpdated(0, _initialRate, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/
    function minDeposit() public view returns (uint256) {
        return minDepositAmount;
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 shares = balanceOf[user];
        uint256 last = lastClaimRate[user];
        if (shares == 0 || last == 0 || exchangeRate <= last) return 0;
        return (shares * (exchangeRate - last)) / RATE_SCALE;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * RATE_SCALE) / exchangeRate;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * exchangeRate) / RATE_SCALE;
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 assets, address receiver) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets < minDepositAmount) revert DepositTooSmall();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();

        // Effects
        uint256 oldShares = balanceOf[receiver];
        uint256 oldLast = lastClaimRate[receiver];

        totalAssets += assets;
        totalSupply += shares;
        balanceOf[receiver] = oldShares + shares;

        // Settle reward checkpoint so new shares do not inherit old pending rewards.
        if (oldShares == 0) {
            lastClaimRate[receiver] = exchangeRate;
        } else {
            // Weighted average preserves the pending reward of the old shares.
            lastClaimRate[receiver] = (oldShares * oldLast + shares * exchangeRate) / (oldShares + shares);
        }

        // Interaction
        asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    /*//////////////////////////////////////////////////////////////
                              WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function withdraw(uint256 shares, address receiver) external nonReentrant whenNotPaused returns (uint256 payout) {
        if (shares == 0) revert ZeroShares();
        if (shares > balanceOf[msg.sender]) revert InsufficientBalance();

        uint256 assets = convertToAssets(shares);
        if (assets == 0) revert ZeroAssets();

        uint256 fee = (assets * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        payout = assets - fee;

        // Effects
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        accumulatedFees += fee;

        if (balanceOf[msg.sender] == 0) {
            lastClaimRate[msg.sender] = 0;
        }

        // Interaction
        asset.safeTransfer(receiver, payout);

        emit Withdraw(msg.sender, receiver, shares, payout, fee);
        emit Transfer(msg.sender, address(0), shares);
    }

    /*//////////////////////////////////////////////////////////////
                              CLAIM REWARDS
    //////////////////////////////////////////////////////////////*/
    function claimRewards() external nonReentrant whenNotPaused returns (uint256 rewardAssets) {
        uint256 shares = balanceOf[msg.sender];
        uint256 last = lastClaimRate[msg.sender];
        if (shares == 0 || last == 0 || exchangeRate <= last) revert NoRewards();

        rewardAssets = (shares * (exchangeRate - last)) / RATE_SCALE;
        if (rewardAssets == 0) revert NoRewards();
        if (rewardAssets > totalAssets) revert InsufficientBalance();

        // Effects
        totalAssets -= rewardAssets;
        lastClaimRate[msg.sender] = exchangeRate;

        // Interaction
        asset.safeTransfer(msg.sender, rewardAssets);

        emit RewardsClaimed(msg.sender, rewardAssets);
    }

    /*//////////////////////////////////////////////////////////////
                              OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function updateExchangeRate(uint256 newRate, uint256 rewardAssets) external onlyOperator {
        if (newRate == 0) revert InvalidRate();

        if (rewardAssets > 0) {
            asset.safeTransferFrom(msg.sender, address(this), rewardAssets);
            totalAssets += rewardAssets;
        }

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;

        emit ExchangeRateUpdated(oldRate, newRate, rewardAssets);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function sweepFees() external onlyOperator {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAssets();
        accumulatedFees = 0;
        asset.safeTransfer(operator, amount);
        emit FeesSwept(operator, amount);
    }
}
