// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LuxuryBenefitToken {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error InsufficientBalance(address account, uint256 requested, uint256 available);
    error InsufficientAllowance(address spender, address owner, uint256 requested, uint256 available);
    error TransferToZeroAddress(address from);
    error TransferFromZeroAddress();
    error MintExceedsCap(uint256 requested, uint256 remaining);
    error Unauthorized(address caller);
    error InvalidTier(uint256 tier);
    error BelowMinimumBurn(uint256 provided, uint256 minimum);
    error ZeroAddress();
    error CapTooLow(uint256 proposed, uint256 currentSupply);
    error BurnAmountZero();
    error TierNotActive(uint256 tier);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BenefitRedeemed(address indexed account, uint256 indexed tier, uint256 tokensBurned, uint256 timestamp);
    event Mint(address indexed to, uint256 value);
    event CapUpdated(uint256 oldCap, uint256 newCap);
    event TierConfigured(uint256 indexed tier, uint256 requiredTokens, bool active);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    string public constant name = "Luxury Benefit Token";
    string public constant symbol = "LUX";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    uint256 public supplyCap;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    struct Tier {
        uint256 requiredTokens;
        bool active;
    }

    mapping(uint256 => Tier) public tiers;

    uint256 public constant DEFAULT_CAP = 100_000_000 * 10**18;
    uint256 public constant LOWEST_TIER_MINIMUM = 1_000 * 10**18;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        owner = msg.sender;
        supplyCap = DEFAULT_CAP;
        emit OwnershipTransferred(address(0), msg.sender);
        emit CapUpdated(0, supplyCap);

        _configureTier(1, LOWEST_TIER_MINIMUM, true);
        _configureTier(2, 10_000 * 10**18, true);
        _configureTier(3, 50_000 * 10**18, true);
        _configureTier(4, 100_000 * 10**18, true);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /*//////////////////////////////////////////////////////////////
                            SUPPLY CAP LOGIC
    //////////////////////////////////////////////////////////////*/
    function setSupplyCap(uint256 newCap) external onlyOwner {
        if (newCap < totalSupply) revert CapTooLow(newCap, totalSupply);
        emit CapUpdated(supplyCap, newCap);
        supplyCap = newCap;
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply + amount > supplyCap) {
            revert MintExceedsCap(amount, supplyCap - totalSupply);
        }

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            TIER CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    function configureTier(uint256 tierId, uint256 requiredTokens, bool active) external onlyOwner {
        if (tierId == 0) revert InvalidTier(tierId);
        if (tierId == 1 && requiredTokens < LOWEST_TIER_MINIMUM) {
            revert BelowMinimumBurn(requiredTokens, LOWEST_TIER_MINIMUM);
        }
        _configureTier(tierId, requiredTokens, active);
    }

    function _configureTier(uint256 tierId, uint256 requiredTokens, bool active) internal {
        tiers[tierId] = Tier({requiredTokens: requiredTokens, active: active});
        emit TierConfigured(tierId, requiredTokens, active);
    }

    function getTier(uint256 tierId) external view returns (uint256 requiredTokens, bool active) {
        Tier memory t = tiers[tierId];
        return (t.requiredTokens, t.active);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(msg.sender, from, amount, currentAllowance);
        }

        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert TransferFromZeroAddress();
        if (to == address(0)) revert TransferToZeroAddress(from);

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(from, amount, fromBalance);
        }

        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       BENEFIT REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function redeemBenefit(uint256 tierId) external returns (bool) {
        Tier memory tier = tiers[tierId];
        if (!tier.active) revert TierNotActive(tierId);

        uint256 required = tier.requiredTokens;
        if (required < LOWEST_TIER_MINIMUM) {
            required = LOWEST_TIER_MINIMUM;
        }

        uint256 callerBalance = balanceOf[msg.sender];
        if (callerBalance < required) {
            revert InsufficientBalance(msg.sender, required, callerBalance);
        }

        // Effects
        balanceOf[msg.sender] = callerBalance - required;
        totalSupply -= required;

        emit Transfer(msg.sender, address(0), required);
        emit BenefitRedeemed(msg.sender, tierId, required, block.timestamp);
        return true;
    }

    function burn(uint256 amount) external {
        if (amount == 0) revert BurnAmountZero();
        uint256 callerBalance = balanceOf[msg.sender];
        if (callerBalance < amount) {
            revert InsufficientBalance(msg.sender, amount, callerBalance);
        }

        balanceOf[msg.sender] = callerBalance - amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function remainingMintable() external view returns (uint256) {
        return supplyCap - totalSupply;
    }
}
