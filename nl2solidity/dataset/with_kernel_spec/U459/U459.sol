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

contract CommunityProjectFunding {
    // --------- Errors ---------
    error NotProjectOwner();
    error ZeroAddress();
    error ZeroAmount();
    error DurationInvalid();
    error DurationExceedsMax();
    error CycleNotActive();
    error CycleStillActive();
    error TokenRateInvalid();
    error NothingToClaim();
    error InsufficientTokenBalance();
    error InsufficientBaseAvailable();
    error TransferFailed();
    error NoEtherToWithdraw();

    // --------- Events ---------
    event FundingCycleStarted(uint256 indexed cycleId, uint256 startTime, uint256 endTime, uint256 tokenRate);
    event Contribution(address indexed contributor, uint256 baseAmount, uint256 tokenAmount, uint256 fee);
    event ProjectTokensClaimed(address indexed contributor, uint256 tokenAmount);
    event ProjectTokensRedeemed(address indexed redeemer, uint256 tokenAmount, uint256 baseAmount);
    event BaseWithdrawn(address indexed owner, uint256 amount);
    event ProjectTokensMinted(address indexed to, uint256 amount);
    event MaxFundingDurationUpdated(uint256 newDuration);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // --------- Constants ---------
    uint256 public constant MAX_FUNDING_DURATION = 90 days;
    uint256 public constant FEE_PERCENT = 5;
    uint8 public constant decimals = 18;

    // --------- Token Metadata ---------
    string public name;
    string public symbol;

    // --------- Token State ---------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --------- Project State ---------
    IERC20 public immutable baseCurrency;
    address public projectOwner;
    address public treasury;

    uint256 public maxFundingDuration;
    uint256 public currentCycleId;

    struct FundingCycle {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 tokenRate;
        bool configured;
    }

    FundingCycle public fundingCycle;

    uint256 public remainingBase;
    uint256 public totalIssuedTokens;
    mapping(address => uint256) public baseContributions;
    mapping(address => uint256) public accruedTokens;

    bool private _entered;

    // --------- Modifiers ---------
    modifier nonReentrant() {
        if (_entered) revert TransferFailed();
        _entered = true;
        _;
        _entered = false;
    }

    modifier onlyProjectOwner() {
        if (msg.sender != projectOwner) revert NotProjectOwner();
        _;
    }

    // --------- Constructor ---------
    constructor(
        address baseCurrency_,
        address treasury_,
        string memory name_,
        string memory symbol_
    ) {
        if (baseCurrency_ == address(0)) revert ZeroAddress();
        if (treasury_ == address(0)) revert ZeroAddress();

        baseCurrency = IERC20(baseCurrency_);
        treasury = treasury_;
        projectOwner = msg.sender;
        name = name_;
        symbol = symbol_;

        maxFundingDuration = MAX_FUNDING_DURATION;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --------- Owner: Funding Cycle ---------
    function startFundingCycle(uint256 duration, uint256 tokenRate_) external onlyProjectOwner {
        if (duration == 0) revert DurationInvalid();
        if (duration > maxFundingDuration) revert DurationExceedsMax();
        if (tokenRate_ == 0) revert TokenRateInvalid();

        if (fundingCycle.configured && block.timestamp <= fundingCycle.endTime) {
            revert CycleStillActive();
        }

        currentCycleId++;
        fundingCycle = FundingCycle({
            id: currentCycleId,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            tokenRate: tokenRate_,
            configured: true
        });

        emit FundingCycleStarted(currentCycleId, block.timestamp, block.timestamp + duration, tokenRate_);
    }

    function setMaxFundingDuration(uint256 newDuration) external onlyProjectOwner {
        if (newDuration == 0) revert DurationInvalid();
        if (newDuration > MAX_FUNDING_DURATION) revert DurationExceedsMax();
        maxFundingDuration = newDuration;
        emit MaxFundingDurationUpdated(newDuration);
    }

    function setTreasury(address newTreasury) external onlyProjectOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function transferOwnership(address newOwner) external onlyProjectOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = projectOwner;
        projectOwner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyProjectOwner {
        address old = projectOwner;
        projectOwner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // --------- Owner: Base & Mint ---------
    function withdrawBase(uint256 amount) external nonReentrant onlyProjectOwner {
        if (amount == 0) revert ZeroAmount();
        if (amount > remainingBase) revert InsufficientBaseAvailable();

        remainingBase -= amount;
        if (!baseCurrency.transfer(projectOwner, amount)) revert TransferFailed();

        emit BaseWithdrawn(projectOwner, amount);
    }

    function withdrawEther() external onlyProjectOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance < 1) revert NoEtherToWithdraw();
        (bool success, ) = payable(projectOwner).call{value: balance}("");
        if (!success) revert TransferFailed();
        emit EtherWithdrawn(projectOwner, balance);
    }

    function mintProjectTokens(address to, uint256 amount) external onlyProjectOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
        totalIssuedTokens += amount;

        emit ProjectTokensMinted(to, amount);
    }

    // --------- User: Contribute ---------
    function contribute(uint256 baseAmount) external nonReentrant returns (uint256 tokenAmount) {
        if (!isFundingCycleActive()) revert CycleNotActive();
        if (baseAmount == 0) revert ZeroAmount();

        uint256 fee = (baseAmount * FEE_PERCENT) / 100;
        uint256 net = baseAmount - fee;

        // Calculate and validate token amount before external calls (CEI)
        tokenAmount = (net * fundingCycle.tokenRate) / 1e18;
        if (tokenAmount < 1) revert ZeroAmount();

        // Pull full amount from contributor
        if (!baseCurrency.transferFrom(msg.sender, address(this), baseAmount)) revert TransferFailed();

        // Forward fee to treasury
        if (fee > 0) {
            if (!baseCurrency.transfer(treasury, fee)) revert TransferFailed();
        }

        // Update accounting (effects)
        remainingBase += net;
        baseContributions[msg.sender] += net;
        accruedTokens[msg.sender] += tokenAmount;
        totalIssuedTokens += tokenAmount;

        emit Contribution(msg.sender, baseAmount, tokenAmount, fee);
    }

    // --------- User: Claim ---------
    function claimProjectTokens() external nonReentrant returns (uint256 amount) {
        amount = accruedTokens[msg.sender];
        if (amount == 0) revert NothingToClaim();

        accruedTokens[msg.sender] = 0;
        _mint(msg.sender, amount);

        emit ProjectTokensClaimed(msg.sender, amount);
    }

    // --------- User: Redeem ---------
    function redeemProjectTokens(uint256 tokenAmount) external nonReentrant returns (uint256 baseAmount) {
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < tokenAmount) revert InsufficientTokenBalance();
        if (totalIssuedTokens == 0) revert InsufficientBaseAvailable();
        if (remainingBase == 0) revert InsufficientBaseAvailable();

        baseAmount = (remainingBase * tokenAmount) / totalIssuedTokens;
        if (baseAmount == 0) revert InsufficientBaseAvailable();

        remainingBase -= baseAmount;
        totalIssuedTokens -= tokenAmount;

        if (baseAmount > baseContributions[msg.sender]) {
            baseContributions[msg.sender] = 0;
        } else {
            baseContributions[msg.sender] -= baseAmount;
        }

        _burn(msg.sender, tokenAmount);

        if (!baseCurrency.transfer(msg.sender, baseAmount)) revert TransferFailed();

        emit ProjectTokensRedeemed(msg.sender, tokenAmount, baseAmount);
    }

    // --------- ERC20 Logic ---------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientTokenBalance();

        _transfer(from, to, amount);
        _approve(from, msg.sender, allowed - amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientTokenBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientTokenBalance();

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();

        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // --------- Views ---------
    function isFundingCycleActive() public view returns (bool) {
        return fundingCycle.configured &&
               block.timestamp >= fundingCycle.startTime &&
               block.timestamp <= fundingCycle.endTime;
    }

    function getAccruedTokens(address account) external view returns (uint256) {
        return accruedTokens[account];
    }

    function getRedeemableBase(address account, uint256 tokenAmount) external view returns (uint256) {
        if (tokenAmount < 1 || totalIssuedTokens < 1 || balanceOf[account] < tokenAmount) {
            return 0;
        }
        return (remainingBase * tokenAmount) / totalIssuedTokens;
    }

    function getCycleInfo() external view returns (
        uint256 cycleId,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenRate,
        bool active
    ) {
        FundingCycle memory c = fundingCycle;
        return (c.id, c.startTime, c.endTime, c.tokenRate, isFundingCycleActive());
    }

    receive() external payable {
        revert("Native currency not accepted");
    }
}
