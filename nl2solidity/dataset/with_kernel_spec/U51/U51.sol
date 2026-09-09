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

contract LiquidStaking {
    // ERC20 state
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Ownable state
    address public owner;

    // ReentrancyGuard state
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // LiquidStaking state
    IERC20 public immutable baseToken;
    address public stakingStrategy;
    address public treasury;
    uint256 public totalBaseDeposited;
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 public rewardFee = 500; // 5% in basis points

    struct UnbondingRequest {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }
    mapping(address => UnbondingRequest[]) public unbondingRequests;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Deposit(address indexed depositor, uint256 amount);
    event Redemption(address indexed redeemer, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardFeeUpdated(uint256 oldFee, uint256 newFee);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event RewardsHarvested(uint256 netRewards, uint256 fee);

    // Errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error UnbondingPeriodNotOver();
    error AlreadyClaimed();
    error InvalidIndex();
    error InsufficientBalance();
    error InsufficientAllowance();
    error Unauthorized();
    error ReentrantCall();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(
        address _baseToken,
        address _stakingStrategy,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) {
        if (_baseToken == address(0) || _stakingStrategy == address(0) || _treasury == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        stakingStrategy = _stakingStrategy;
        treasury = _treasury;
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ERC20 internal functions
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ERC20 external functions
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        if (allowance[from][msg.sender] < amount) revert InsufficientAllowance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // SafeERC20 internal functions — handle tokens that don't return a bool
    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    // LiquidStaking functions
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Effects: calculate shares and update state before interaction
        uint256 sharesToMint;
        uint256 _totalSupply = totalSupply;
        uint256 _totalBaseDeposited = totalBaseDeposited;
        if (_totalSupply == 0 || _totalBaseDeposited == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * _totalSupply) / _totalBaseDeposited;
        }
        if (sharesToMint == 0) revert ZeroAmount();

        totalBaseDeposited += amount;
        _mint(msg.sender, sharesToMint);

        // Interaction
        _safeTransferFrom(baseToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function redeem(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();

        uint256 baseAmount;
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            baseAmount = 0;
        } else {
            baseAmount = (lstAmount * totalBaseDeposited) / _totalSupply;
        }

        _burn(msg.sender, lstAmount);
        totalBaseDeposited -= baseAmount;

        unbondingRequests[msg.sender].push(UnbondingRequest({
            amount: baseAmount,
            unlockTime: block.timestamp + UNBONDING_PERIOD,
            claimed: false
        }));

        emit Redemption(msg.sender, baseAmount);
    }

    function claimUnbonded(uint256 requestIndex) external nonReentrant {
        if (requestIndex >= unbondingRequests[msg.sender].length) revert InvalidIndex();
        UnbondingRequest storage req = unbondingRequests[msg.sender][requestIndex];

        if (block.timestamp < req.unlockTime) revert UnbondingPeriodNotOver();
        if (req.claimed) revert AlreadyClaimed();

        // Effects
        req.claimed = true;
        uint256 amount = req.amount;

        // Interaction
        _safeTransfer(baseToken, msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    function harvestRewards() external nonReentrant {
        uint256 contractBalance = baseToken.balanceOf(address(this));
        if (contractBalance <= totalBaseDeposited) {
            return;
        }

        uint256 rewards = contractBalance - totalBaseDeposited;
        uint256 fee = (rewards * rewardFee) / 10000;
        uint256 netRewards = rewards - fee;

        // Effects: update state before interaction
        totalBaseDeposited += netRewards;

        // Interaction
        if (fee > 0) {
            _safeTransfer(baseToken, treasury, fee);
        }

        emit RewardsHarvested(netRewards, fee);
    }

    function setRewardFee(uint256 newFee) external onlyOwner {
        if (newFee > 10000) revert InvalidFee();
        emit RewardFeeUpdated(rewardFee, newFee);
        rewardFee = newFee;
    }

    function setStakingStrategy(address newStrategy) external onlyOwner {
        if (newStrategy == address(0)) revert ZeroAddress();
        address oldStrategy = stakingStrategy;
        stakingStrategy = newStrategy;
        emit StrategyUpdated(oldStrategy, newStrategy);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function getUnbondingRequestsCount(address user) external view returns (uint256) {
        return unbondingRequests[user].length;
    }

    function previewRedeem(uint256 lstAmount) external view returns (uint256) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) return 0;
        return (lstAmount * totalBaseDeposited) / _totalSupply;
    }

    function previewDeposit(uint256 baseAmount) external view returns (uint256) {
        uint256 _totalSupply = totalSupply;
        uint256 _totalBaseDeposited = totalBaseDeposited;
        // Avoid strict combined equality; guard each divisor condition independently.
        if (_totalSupply == 0) {
            return baseAmount;
        }
        if (_totalBaseDeposited == 0) {
            return baseAmount;
        }
        return (baseAmount * _totalSupply) / _totalBaseDeposited;
    }
}
