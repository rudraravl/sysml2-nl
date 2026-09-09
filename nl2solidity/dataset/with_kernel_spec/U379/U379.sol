// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LaunchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error TransferToZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ApproveToZeroAddress();

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address mintTo) {
        if (mintTo == address(0)) revert TransferToZeroAddress();
        name = name_;
        symbol = symbol_;
        totalSupply = totalSupply_;
        balanceOf[mintTo] = totalSupply_;
        emit Transfer(address(0), mintTo, totalSupply_);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 fromBalance = balanceOf[msg.sender];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = fromBalance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ApproveToZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = currentAllowance - amount;
            }
        }
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract TokenLaunchpad {
    error NotOwner();
    error ContractPaused();
    error ReentrantCall();
    error ZeroAddress();
    error InvalidParameter();
    error LaunchNotFound();
    error LaunchAlreadyConcluded();
    error LaunchNotEnded();
    error LaunchEnded();
    error LaunchNotConcluded();
    error LaunchNotSuccessful();
    error LaunchSuccessful();
    error NothingToClaim();
    error AlreadyClaimed();
    error NothingToWithdraw();
    error AlreadyWithdrawn();
    error NotCreator();
    error TransferFailed();
    error TransferFromFailed();
    error AlreadyPaused();
    error NotPaused();
    error ZeroAmount();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BaseCurrencyUpdated(address indexed newBaseCurrency);
    event TreasuryUpdated(address indexed newTreasury);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event LaunchCreated(
        uint256 indexed launchId,
        address indexed creator,
        address indexed token,
        string name,
        string symbol,
        uint256 totalSupply,
        uint256 startTime,
        uint256 endTime
    );
    event ContributionMade(
        uint256 indexed launchId,
        address indexed contributor,
        uint256 amount,
        uint256 netAmount,
        uint256 fee
    );
    event LaunchConcluded(uint256 indexed launchId, bool successful, uint256 totalRaised);
    event TokensClaimed(uint256 indexed launchId, address indexed claimant, uint256 tokenAmount);
    event RefundClaimed(uint256 indexed launchId, address indexed claimant, uint256 baseAmount);
    event RaisedWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);

    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_RAISE = 1000;

    address public owner;
    address public baseCurrency;
    address public treasury;
    bool public paused;
    uint256 public launchCount;

    struct Launch {
        address token;
        address creator;
        address baseCurrency;
        uint256 totalSupply;
        uint256 totalRaised;
        uint256 startTime;
        uint256 endTime;
        bool concluded;
        bool successful;
        bool withdrawn;
    }

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public claimed;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _baseCurrency, address _treasury) {
        if (_baseCurrency == address(0) || _treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        baseCurrency = _baseCurrency;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), msg.sender);
        emit BaseCurrencyUpdated(_baseCurrency);
        emit TreasuryUpdated(_treasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setBaseCurrency(address _baseCurrency) external onlyOwner {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        baseCurrency = _baseCurrency;
        emit BaseCurrencyUpdated(_baseCurrency);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
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

    function createLaunch(
        string calldata name_,
        string calldata symbol_,
        uint256 tokenSupply,
        uint256 duration
    ) external whenNotPaused returns (uint256 launchId) {
        if (bytes(name_).length == 0 || bytes(symbol_).length == 0) revert InvalidParameter();
        if (tokenSupply == 0) revert InvalidParameter();
        if (duration == 0) revert InvalidParameter();

        address token = address(new LaunchToken(name_, symbol_, tokenSupply, address(this)));

        launchId = ++launchCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        launches[launchId] = Launch({
            token: token,
            creator: msg.sender,
            baseCurrency: baseCurrency,
            totalSupply: tokenSupply,
            totalRaised: 0,
            startTime: startTime,
            endTime: endTime,
            concluded: false,
            successful: false,
            withdrawn: false
        });

        emit LaunchCreated(launchId, msg.sender, token, name_, symbol_, tokenSupply, startTime, endTime);
    }

    function contribute(uint256 launchId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound();
        if (launch.concluded) revert LaunchAlreadyConcluded();
        if (block.timestamp > launch.endTime) revert LaunchEnded();

        address currency = launch.baseCurrency;
        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects: update state before external interactions
        launch.totalRaised += netAmount;
        contributions[launchId][msg.sender] += netAmount;

        // Interactions: pull funds in
        _safeTransferFrom(currency, msg.sender, address(this), amount);

        // Interactions: send fee to treasury
        if (fee > 0) {
            _safeTransfer(currency, treasury, fee);
        }

        emit ContributionMade(launchId, msg.sender, amount, netAmount, fee);
    }

    function concludeLaunch(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound();
        if (launch.concluded) revert LaunchAlreadyConcluded();
        if (block.timestamp < launch.endTime) revert LaunchNotEnded();

        launch.concluded = true;
        launch.successful = launch.totalRaised >= MIN_RAISE;

        emit LaunchConcluded(launchId, launch.successful, launch.totalRaised);
    }

    function claimTokens(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound();
        if (!launch.concluded) revert LaunchNotConcluded();
        if (!launch.successful) revert LaunchNotSuccessful();
        if (claimed[launchId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToClaim();

        uint256 tokenAmount = (launch.totalSupply * contribution) / launch.totalRaised;

        // Effects
        claimed[launchId][msg.sender] = true;
        contributions[launchId][msg.sender] = 0;

        // Interactions
        _safeTransfer(launch.token, msg.sender, tokenAmount);
        emit TokensClaimed(launchId, msg.sender, tokenAmount);
    }

    function claimRefund(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound();
        if (!launch.concluded) revert LaunchNotConcluded();
        if (launch.successful) revert LaunchSuccessful();
        if (claimed[launchId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = contributions[launchId][msg.sender];
        if (contribution == 0) revert NothingToClaim();

        // Effects
        claimed[launchId][msg.sender] = true;
        contributions[launchId][msg.sender] = 0;

        // Interactions
        _safeTransfer(launch.baseCurrency, msg.sender, contribution);
        emit RefundClaimed(launchId, msg.sender, contribution);
    }

    function withdrawRaised(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound();
        if (msg.sender != launch.creator) revert NotCreator();
        if (!launch.concluded) revert LaunchNotConcluded();
        if (!launch.successful) revert LaunchNotSuccessful();
        if (launch.withdrawn) revert AlreadyWithdrawn();
        if (launch.totalRaised == 0) revert NothingToWithdraw();

        // Effects
        launch.withdrawn = true;
        uint256 amount = launch.totalRaised;

        // Interactions
        _safeTransfer(launch.baseCurrency, launch.creator, amount);
        emit RaisedWithdrawn(launchId, launch.creator, amount);
    }

    function getLaunch(uint256 launchId)
        external
        view
        returns (
            address token,
            address creator,
            address baseCurrency_,
            uint256 totalSupply,
            uint256 totalRaised,
            uint256 startTime,
            uint256 endTime,
            bool concluded,
            bool successful,
            bool withdrawn
        )
    {
        Launch storage l = launches[launchId];
        return (
            l.token,
            l.creator,
            l.baseCurrency,
            l.totalSupply,
            l.totalRaised,
            l.startTime,
            l.endTime,
            l.concluded,
            l.successful,
            l.withdrawn
        );
    }

    function getContribution(uint256 launchId, address account) external view returns (uint256) {
        return contributions[launchId][account];
    }

    function hasClaimed(uint256 launchId, address account) external view returns (bool) {
        return claimed[launchId][account];
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) revert TransferFromFailed();
    }
}
