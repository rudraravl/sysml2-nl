// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CreatorSocialToken
 * @notice A social token for content creators with a linear bonding curve,
 *         5% protocol fees on buys/sells, and a capped total supply.
 */
contract CreatorSocialToken {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientPayment();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error ExceedsMaxSupply();
    error InvalidCurveParameters();
    error CurveNotConfigured();
    error NotCreator();
    error NothingToWithdraw();
    error TransferFailed();
    error ReentrantCall();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 rawCost, uint256 fee);
    event TokensSold(address indexed seller, uint256 amount, uint256 rawRefund, uint256 fee);
    event CurveConfigured(uint256 basePrice, uint256 slope);
    event FeesWithdrawn(address indexed creator, uint256 amount);
    event CreatorTransferred(address indexed previousCreator, address indexed newCreator);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public creator;

    uint256 public basePrice;
    uint256 public slope;
    bool public curveConfigured;

    uint256 public accumulatedFees;
    uint256 public reserveBalance;
    uint256 public constant FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    bool private _locked;

    modifier onlyCreator() {
        if (msg.sender != creator) revert NotCreator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(string memory _name, string memory _symbol, address _creator) {
        if (_creator == address(0)) revert ZeroAddress();
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0) revert ZeroAmount();
        name = _name;
        symbol = _symbol;
        creator = _creator;
        emit CreatorTransferred(address(0), _creator);
    }

    function configureBondingCurve(uint256 _basePrice, uint256 _slope) external onlyCreator {
        if (_basePrice == 0 && _slope == 0) revert InvalidCurveParameters();
        basePrice = _basePrice;
        slope = _slope;
        curveConfigured = true;
        emit CurveConfigured(_basePrice, _slope);
    }

    function transferCreator(address _newCreator) external onlyCreator {
        if (_newCreator == address(0)) revert ZeroAddress();
        address prev = creator;
        creator = _newCreator;
        emit CreatorTransferred(prev, _newCreator);
    }

    function withdrawFees() external onlyCreator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool ok, ) = payable(creator).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(creator, amount);
    }

    function getCurrentPrice() public view returns (uint256) {
        return basePrice + (slope * totalSupply) / 10 ** 18;
    }

    function getBuyCost(uint256 amount)
        public
        view
        returns (uint256 rawCost, uint256 fee, uint256 totalCost)
    {
        if (!curveConfigured) revert CurveNotConfigured();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        uint256 s = totalSupply;
        if (s > MAX_SUPPLY - amount) revert ExceedsMaxSupply();

        rawCost = basePrice * amount + (slope * amount * (2 * s + amount)) / (2 * 10 ** 18);
        fee = (rawCost * FEE_BPS) / BPS_DENOMINATOR;
        totalCost = rawCost + fee;
    }

    function getSellRefund(uint256 amount)
        public
        view
        returns (uint256 rawRefund, uint256 fee, uint256 netRefund)
    {
