// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    function getAssetValue(address asset) external view returns (uint256);
}

contract ReserveCurrency {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error AssetNotApproved(address asset);
    error AssetAlreadyApproved(address asset);
    error ZeroAddress();
    error ZeroAmount();
    error ZeroPrice();
    error BelowMinimumMint(uint256 minted, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error ZeroTotalSupply();
    error InvalidFee(uint256 feeBps);
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed minter, address indexed asset, uint256 assetAmount, uint256 reserveMinted, uint256 fee);
    event Burn(address indexed burner, uint256 reserveBurned);
    event Redeemed(address indexed burner, address indexed asset, uint256 assetAmount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event BackingAssetApproved(address indexed asset, uint256 assetValue);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    /*//////////////////////////////////////////////////////////////
                          STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    string public constant name = "Decentralized Reserve Currency";
    string public constant symbol = "DRC";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    IPriceOracle public oracle;

    address public owner;
    address public operator;

    uint256 public mintFeeBps; // basis points, default 50 = 0.5%
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint256 public constant MIN_MINT = 100 * 10 ** 18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant VALUE_SCALE = 10 ** 18;

    address[] public backingAssets;
    mapping(address => bool) public isApprovedAsset;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _oracle, address _operator) {
        if (_oracle == address(0) || _operator == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        owner = msg.sender;
        operator = _operator;
        mintFeeBps = 50; // 0.5%
        emit FeeUpdated(0, mintFeeBps);
        emit OperatorUpdated(address(0), _operator);
        emit OracleUpdated(address(0), _oracle);
    }

    /*//////////////////////////////////////////////////////////////
                       ACCESS CONTROL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    /*//////////////////////////////////////////////////////////////
                       BACKING ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function approveBackingAsset(address asset) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (isApprovedAsset[asset]) revert AssetAlreadyApproved(asset);
        isApprovedAsset[asset] = true;
        backingAssets.push(asset);
        uint256 assetValue = oracle.getAssetValue(asset);
        emit BackingAssetApproved(asset, assetValue);
    }

    function backingAssetCount() external view returns (uint256) {
        return backingAssets.length;
    }

    function getBackingAssets() external view returns (address[] memory) {
        return backingAssets;
    }

    function setMintFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps);
        uint256 old = mintFeeBps;
        mintFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(address asset, uint256 assetAmount) external returns (uint256) {
        if (assetAmount == 0) revert ZeroAmount();
        if (!isApprovedAsset[asset]) revert AssetNotApproved(asset);

        uint256 assetValue = oracle.getAssetValue(asset);
        if (assetValue == 0) revert ZeroPrice();

        // Compute gross mint value in reserve units (18 decimals)
        uint256 grossMint = (assetAmount * assetValue) / VALUE_SCALE;

        // Compute fee using full-precision numerator to avoid divide-before-multiply
        // fee = (assetAmount * assetValue * mintFeeBps) / (VALUE_SCALE * BPS_DENOMINATOR)
        uint256 fee = (assetAmount * assetValue * mintFeeBps) / (VALUE_SCALE * BPS_DENOMINATOR);
        uint256 netMint = grossMint - fee;

        if (netMint < MIN_MINT) revert BelowMinimumMint(netMint, MIN_MINT);

        // Transfer backing asset from minter to contract
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), assetAmount);
        if (!ok) revert TransferFailed();

        // Effects: mint reserve to user
        _totalSupply += grossMint;
        _balances[msg.sender] += netMint;

        // Fee is retained by the protocol (added to owner balance) to keep backing fully reserved
        if (fee > 0) {
            _balances[owner] += fee;
            emit Transfer(address(0), owner, fee);
        }

        emit Transfer(address(0), msg.sender, netMint);
        emit Mint(msg.sender, asset, assetAmount, netMint, fee);

        return netMint;
    }

    /*//////////////////////////////////////////////////////////////
                            BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 reserveAmount) external returns (uint256[] memory redeemed) {
        if (reserveAmount == 0) revert ZeroAmount();
        if (_totalSupply == 0) revert ZeroTotalSupply();
        if (_balances[msg.sender] < reserveAmount) revert InsufficientBalance(_balances[msg.sender], reserveAmount);

        uint256 len = backingAssets.length;
        redeemed = new uint256[](len);

        // Effects: burn reserve currency before external interactions (checks-effects-interactions)
        _balances[msg.sender] -= reserveAmount;
        _totalSupply -= reserveAmount;

        // Interactions: proportionally redeem each backing asset based on contract holdings
        for (uint256 i = 0; i < len; i++) {
            address asset = backingAssets[i];
            uint256 contractBalance = IERC20(asset).balanceOf(address(this));
            uint256 share = (contractBalance * reserveAmount) / (_totalSupply + reserveAmount);
            redeemed[i] = share;
            if (share > 0) {
                bool ok = IERC20(asset).transfer(msg.sender, share);
                if (!ok) revert TransferFailed();
                emit Redeemed(msg.sender, asset, share);
            }
        }

        emit Transfer(msg.sender, address(0), reserveAmount);
        emit Burn(msg.sender, reserveAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < amount) revert InsufficientBalance(_balances[msg.sender], amount);

        _balances[msg.sender] -= amount;
        _balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getContractAssetBalance(address asset) external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function getAssetValue(address asset) external view returns (uint256) {
        return oracle.getAssetValue(asset);
    }
}
