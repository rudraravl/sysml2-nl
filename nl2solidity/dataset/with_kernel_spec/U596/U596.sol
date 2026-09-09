// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract USDzStablecoin {
    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------
    string public constant name = "USDz";
    string public constant symbol = "USDz";
    uint8 public constant decimals = 18;
    uint256 private constant USDZ_UNIT = 1e18;
    uint256 public constant MIN_MINT_VALUE = 1000 * USDZ_UNIT;
    uint256 public constant REDEMPTION_FEE_BPS = 1;
    uint256 public constant BPS_DENOMINATOR = 1000;

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error WhenNotPaused();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotApproved();
    error AssetAlreadyApproved();
    error InsufficientDepositValue();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidDecimals();
    error InvalidValuation();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(address indexed minter, address indexed asset, uint256 assetAmount, uint256 usdzAmount);
    event Redeem(address indexed redeemer, address indexed asset, uint256 usdzAmount, uint256 assetAmount, uint256 fee);
    event AssetApproved(address indexed asset, uint8 decimals, uint256 valuation);
    event AssetValuationUpdated(address indexed asset, uint256 oldValuation, uint256 newValuation);
    event AssetDisapproved(address indexed asset);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    bool public paused;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public accumulatedFees;

    struct AssetInfo {
        bool approved;
        uint8 decimals;
        uint256 valuation;
    }
    mapping(address => AssetInfo) public assetRegistry;
    address[] public approvedAssets;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert WhenNotPaused();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OperatorSet(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _operator;
        emit OperatorSet(previous, _operator);
    }

    function pause() external onlyOperator {
        if (paused) revert WhenPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert WhenNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function approveAsset(address asset, uint256 valuation) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (valuation == 0) revert InvalidValuation();
        if (assetRegistry[asset].approved) revert AssetAlreadyApproved();

        uint8 dec = 18;
        try IERC20(asset).decimals() returns (uint8 d) {
            dec = d;
        } catch {
            dec = 18;
        }
        if (dec > 36) revert InvalidDecimals();

        assetRegistry[asset] = AssetInfo({approved: true, decimals: dec, valuation: valuation});
        approvedAssets.push(asset);
        emit AssetApproved(asset, dec, valuation);
    }

    function updateValuation(address asset, uint256 newValuation) external onlyOperator {
        if (!assetRegistry[asset].approved) revert AssetNotApproved();
        if (newValuation == 0) revert InvalidValuation();
        uint256 oldValuation = assetRegistry[asset].valuation;
        assetRegistry[asset].valuation = newValuation;
        emit AssetValuationUpdated(asset, oldValuation, newValuation);
    }

    function disapproveAsset(address asset) external onlyOperator {
        if (!assetRegistry[asset].approved) revert AssetNotApproved();
        assetRegistry[asset].approved = false;
        uint256 len = approvedAssets.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedAssets[i] == asset) {
                approvedAssets[i] = approvedAssets[len - 1];
                approvedAssets.pop();
                break;
            }
        }
        emit AssetDisapproved(asset);
    }

    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        balanceOf[address(this)] -= amount;
        balanceOf[to] += amount;
        emit Transfer(address(this), to, amount);
        emit FeesWithdrawn(to, amount);
    }

    // ---------------------------------------------------------------------
    // ERC20 logic
    // ---------------------------------------------------------------------
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed < amount) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Safe ERC20 helpers
    // ---------------------------------------------------------------------
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // Minting / Redemption
    // ---------------------------------------------------------------------
    function assetToUsdz(address asset, uint256 assetAmount) public view returns (uint256) {
        AssetInfo memory info = assetRegistry[asset];
        if (!info.approved) revert AssetNotApproved();
        return (assetAmount * info.valuation) / (10 ** info.decimals);
    }

    function usdzToAsset(address asset, uint256 usdzAmount) public view returns (uint256) {
        AssetInfo memory info = assetRegistry[asset];
        if (!info.approved) revert AssetNotApproved();
        return (usdzAmount * (10 ** info.decimals)) / info.valuation;
    }

    function mint(address asset, uint256 assetAmount) external whenNotPaused returns (uint256 usdzAmount) {
        if (assetAmount == 0) revert ZeroAmount();
        AssetInfo memory info = assetRegistry[asset];
        if (!info.approved) revert AssetNotApproved();

        usdzAmount = assetToUsdz(asset, assetAmount);
        if (usdzAmount < MIN_MINT_VALUE) revert InsufficientDepositValue();

        _safeTransferFrom(asset, msg.sender, address(this), assetAmount);

        totalSupply += usdzAmount;
        balanceOf[msg.sender] += usdzAmount;
        emit Transfer(address(0), msg.sender, usdzAmount);
        emit Mint(msg.sender, asset, assetAmount, usdzAmount);
    }

    function redeem(address asset, uint256 usdzAmount) external whenNotPaused returns (uint256 assetAmount) {
        if (usdzAmount == 0) revert ZeroAmount();
        AssetInfo memory info = assetRegistry[asset];
        if (!info.approved) revert AssetNotApproved();
        if (balanceOf[msg.sender] < usdzAmount) revert InsufficientBalance();

        uint256 fee = (usdzAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 redeemable = usdzAmount - fee;

        assetAmount = usdzToAsset(asset, redeemable);
        if (assetAmount == 0) revert ZeroAmount();

        balanceOf[msg.sender] -= usdzAmount;
        totalSupply -= redeemable;

        if (fee > 0) {
            accumulatedFees += fee;
            balanceOf[address(this)] += fee;
            emit Transfer(msg.sender, address(this), fee);
        }

        _safeTransfer(asset, msg.sender, assetAmount);

        emit Redeem(msg.sender, asset, usdzAmount, assetAmount, fee);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function isAssetApproved(address asset) external view returns (bool) {
        return assetRegistry[asset].approved;
    }

    function assetValuation(address asset) external view returns (uint256) {
        return assetRegistry[asset].valuation;
    }

    function assetDecimals(address asset) external view returns (uint8) {
        return assetRegistry[asset].decimals;
    }

    function approvedAssetCount() external view returns (uint256) {
        return approvedAssets.length;
    }

    function getApprovedAssets() external view returns (address[] memory) {
        return approvedAssets;
    }
}
