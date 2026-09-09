// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedStablecoin {
    string public constant name = "Decentralized Stablecoin";
    string public constant symbol = "DSC";
    uint8 public constant decimals = 18;

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant PEG_SCALE = 1e18;

    IERC20 public immutable reserveAsset;
    uint256 public totalSupply;
    uint256 public reserveBalance;
    uint256 public targetPeg; // 1e18 represents a 1:1 ratio

    mapping(address => uint256) public balanceOf;

    address public owner;
    address public operator;
    bool public paused;

    uint256 private _locked = 1;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event ReserveBalanceChanged(uint256 newBalance, uint256 changeAmount, bool isIncrease);
    event TargetPegUpdated(uint256 oldPeg, uint256 newPeg);
    event PausedStateChanged(bool isPaused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOwner();
    error NotOperator();
    error PausedError();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidPeg();
    error SupplyCapExceeded();
    error InsufficientBalance();
    error InsufficientReserve();
    error TransferFailed();
    error ReentrancyDetected();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _reserveAsset, address _operator, uint256 _initialPeg) {
        if (_reserveAsset == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialPeg == 0) revert InvalidPeg();
        reserveAsset = IERC20(_reserveAsset);
        operator = _operator;
        owner = msg.sender;
        targetPeg = _initialPeg;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    function mint(uint256 stablecoinAmount) external whenNotPaused nonReentrant {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (totalSupply + stablecoinAmount > MAX_SUPPLY) revert SupplyCapExceeded();

        uint256 reserveAmount = (stablecoinAmount * targetPeg) / PEG_SCALE;

        // Effects before interactions
        reserveBalance += reserveAmount;
        balanceOf[msg.sender] += stablecoinAmount;
        totalSupply += stablecoinAmount;

        emit ReserveBalanceChanged(reserveBalance, reserveAmount, true);
        emit Transfer(address(0), msg.sender, stablecoinAmount);

        // Interaction
        _safeTransferFrom(reserveAsset, msg.sender, address(this), reserveAmount);
    }

    function redeem(uint256 stablecoinAmount) external whenNotPaused nonReentrant {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < stablecoinAmount) revert InsufficientBalance();

        // Compute fee without divide-before-multiply: apply fee to the raw product
        uint256 grossProduct = stablecoinAmount * targetPeg;
        uint256 feeProduct = (grossProduct * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = (grossProduct - feeProduct) / PEG_SCALE;
        uint256 fee = (grossProduct / PEG_SCALE) - payout;

        if (reserveBalance < payout + fee) revert InsufficientReserve();

        // Effects before interactions
        balanceOf[msg.sender] -= stablecoinAmount;
        totalSupply -= stablecoinAmount;
        reserveBalance -= payout;

        emit ReserveBalanceChanged(reserveBalance, payout, false);
        emit Transfer(msg.sender, address(0), stablecoinAmount);

        // Interaction
        _safeTransfer(reserveAsset, msg.sender, payout);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function setTargetPeg(uint256 newPeg) external onlyOperator {
        if (newPeg == 0) revert InvalidPeg();
        uint256 oldPeg = targetPeg;
        targetPeg = newPeg;
        emit TargetPegUpdated(oldPeg, newPeg);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
