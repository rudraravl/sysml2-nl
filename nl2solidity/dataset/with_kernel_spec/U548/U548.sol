// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BasketETP
 * @notice A decentralized exchange-traded product that wraps a basket of diverse
 *         digital assets into a single ERC20-style basket token.
 */
contract BasketETP {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant BPS = 10_000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT = 1e16; // 0.01 basket tokens (18 decimals)
    uint256 public constant BASKET_DECIMALS = 18;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ArrayLengthMismatch();
    error InvalidWeight();
    error InvalidWeightsSum();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error AssetHasReserves();
    error AssetWeightNotZero();
    error DepositTooSmall();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error SlippageExceeded();
    error ZeroAmount();
    error SameAsset();
    error InvalidTransfer();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Minted(address indexed user, uint256 indexed basketAmount, address[] assets, uint256[] amounts);
    event Burned(address indexed user, uint256 indexed basketAmount, address[] assets, uint256[] amounts);
    event AllocationUpdated(address[] assets, uint256[] weights);
    event AssetAdded(address indexed asset, uint256 weight);
    event AssetRemoved(address indexed asset);
    event Rebalanced(address indexed caller, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -----------------------------------------------------------------------
    // ERC20 token state
    // -----------------------------------------------------------------------

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // -----------------------------------------------------------------------
    // Basket composition state
    // -----------------------------------------------------------------------

    address[] internal _assetList;
    mapping(address => bool) internal _isAsset;
    mapping(address => uint256) public targetWeight; // in basis points
    mapping(address => uint256) public reserves; // internal accounting of held assets
    mapping(address => uint256) public assetUnitScale; // 10**(BASKET_DECIMALS - assetDecimals)
    uint256 public totalTargetWeight;

    // -----------------------------------------------------------------------
    // Access control
    // -----------------------------------------------------------------------

    address public owner;
    address public operator;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory assets,
        uint256[] memory weights,
        address operator_
    ) {
        if (operator_ == address(0)) revert ZeroAddress();
        if (assets.length == 0 || assets.length != weights.length) revert ArrayLengthMismatch();

        owner = msg.sender;
        operator = operator_;
        name = name_;
        symbol = symbol_;
        _status = _NOT_ENTERED;

        uint256 weightSum = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            if (asset == address(0)) revert ZeroAddress();
            if (_isAsset[asset]) revert AssetAlreadySupported();
            if (weights[i] == 0 || weights[i] > BPS) revert InvalidWeight();

            _isAsset[asset] = true;
            _assetList.push(asset);
            targetWeight[asset] = weights[i];
            assetUnitScale[asset] = 10 ** (BASKET_DECIMALS - _getDecimals(asset));
            weightSum += weights[i];
        }
        if (weightSum != BPS) revert InvalidWeightsSum();
        totalTargetWeight = weightSum;

        emit AllocationUpdated(assets, weights);
        emit OperatorUpdated(address(0), operator_);
    }

    // -----------------------------------------------------------------------
    // ERC20 views
    // -----------------------------------------------------------------------

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (_balances[from] < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] -= amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // Basket views
    // -----------------------------------------------------------------------

    function getAssets() external view returns (address[] memory) {
        return _assetList;
    }

    function getAssetCount() external view returns (uint256) {
        return _assetList.length;
    }

    function isSupportedAsset(address asset) external view returns (bool) {
        return _isAsset[asset];
    }

    function basketUnitValue() external view returns (uint256) {
        if (_totalSupply == 0) return 0;
        uint256 total = 0;
        for (uint256 i = 0; i < _assetList.length; i++) {
            total += reserves[_assetList[i]] * assetUnitScale[_assetList[i]];
        }
        return total / _totalSupply;
    }

    // -----------------------------------------------------------------------
    // Deposit / mint
    // -----------------------------------------------------------------------

    function deposit(uint256[] calldata amounts, uint256 minBasketOut) external nonReentrant returns (uint256 basketAmount) {
        uint256 count = _assetList.length;
        if (amounts.length != count) revert ArrayLengthMismatch();

        uint256 supply = _totalSupply;

        if (supply == 0) {
            for (uint256 i = 0; i < count; i++) {
                if (amounts[i] == 0) revert ZeroAmount();
                basketAmount += amounts[i] * assetUnitScale[_assetList[i]];
            }
        } else {
            basketAmount = type(uint256).max;
            for (uint256 i = 0; i < count; i++) {
                address asset = _assetList[i];
                uint256 reserve = reserves[asset];
                if (reserve == 0) revert InsufficientReserve();
                uint256 contrib = (amounts[i] * supply) / reserve;
                if (contrib < basketAmount) {
                    basketAmount = contrib;
                }
            }
        }

        if (basketAmount < MIN_DEPOSIT) revert DepositTooSmall();
        if (basketAmount < minBasketOut) revert SlippageExceeded();

        uint256[] memory deposited = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            address asset = _assetList[i];
            uint256 required;
            if (supply == 0) {
                required = amounts[i];
            } else {
                required = (basketAmount * reserves[asset]) / supply;
            }
            if (amounts[i] < required) revert InsufficientDeposit();
            deposited[i] = required;
            reserves[asset] += required;
        }

        _mint(msg.sender, basketAmount);

        for (uint256 i = 0; i < count; i++) {
            _safeTransferFrom(_assetList[i], msg.sender, address(this), deposited[i]);
        }

        emit Minted(msg.sender, basketAmount, _assetList, deposited);
    }

    // -----------------------------------------------------------------------
    // Withdraw / burn
    // -----------------------------------------------------------------------

    function withdraw(uint256 basketAmount) external nonReentrant returns (address[] memory assets, uint256[] memory netOut) {
        if (basketAmount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < basketAmount) revert InsufficientBalance();

        uint256 count = _assetList.length;
        uint256 supply = _totalSupply;
        if (supply == 0) revert InsufficientReserve();

        assets = new address[](count);
        netOut = new uint256[](count);

        // Compute net output directly to avoid divide-before-multiply precision loss.
        // netOut = grossOut * (BPS - WITHDRAWAL_FEE_BPS) / BPS
        //        = (basketAmount * reserves[asset] / supply) * (BPS - WITHDRAWAL_FEE_BPS) / BPS
        //        = (basketAmount * reserves[asset] * (BPS - WITHDRAWAL_FEE_BPS)) / (supply * BPS)
        uint256 feeMultiplier = BPS - WITHDRAWAL_FEE_BPS;
        uint256 denominator = supply * BPS;

        for (uint256 i = 0; i < count; i++) {
            address asset = _assetList[i];
            assets[i] = asset;
            netOut[i] = (basketAmount * reserves[asset] * feeMultiplier) / denominator;
        }

        _burn(msg.sender, basketAmount);
        for (uint256 i = 0; i < count; i++) {
            address asset = assets[i];
            if (netOut[i] > 0) {
                reserves[asset] -= netOut[i];
            }
        }

        for (uint256 i = 0; i < count; i++) {
            if (netOut[i] > 0) {
                _safeTransfer(assets[i], msg.sender, netOut[i]);
            }
        }

        emit Burned(msg.sender, basketAmount, assets, netOut);
    }

    // -----------------------------------------------------------------------
    // Rebalancing
    // -----------------------------------------------------------------------

    function rebalance(
        address assetIn,
        uint256 amountIn,
        address assetOut,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (!_isAsset[assetIn]) revert AssetNotSupported();
        if (!_isAsset[assetOut]) revert AssetNotSupported();
        if (assetIn == assetOut) revert SameAsset();
        if (amountIn == 0) revert ZeroAmount();

        uint256 unitValue = amountIn * assetUnitScale[assetIn];
        amountOut = unitValue / assetUnitScale[assetOut];
        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (reserves[assetOut] < amountOut) revert InsufficientReserve();

        reserves[assetIn] += amountIn;
        reserves[assetOut] -= amountOut;

        _safeTransferFrom(assetIn, msg.sender, address(this), amountIn);
        _safeTransfer(assetOut, msg.sender, amountOut);

        emit Rebalanced(msg.sender, assetIn, assetOut, amountIn, amountOut);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    function setAllocation(address[] calldata assets, uint256[] calldata weights) external onlyOperator {
        if (assets.length != weights.length) revert ArrayLengthMismatch();
        if (assets.length != _assetList.length) revert ArrayLengthMismatch();

        uint256 weightSum = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!_isAsset[assets[i]]) revert AssetNotSupported();
            if (weights[i] > BPS) revert InvalidWeight();
            weightSum += weights[i];
        }
        if (weightSum != BPS) revert InvalidWeightsSum();

        for (uint256 i = 0; i < assets.length; i++) {
            targetWeight[assets[i]] = weights[i];
        }
        totalTargetWeight = weightSum;

        emit AllocationUpdated(assets, weights);
    }

    function addAsset(address asset, uint256 weight) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (_isAsset[asset]) revert AssetAlreadySupported();
        if (weight == 0 || weight > BPS) revert InvalidWeight();
        if (totalTargetWeight + weight != BPS) revert InvalidWeightsSum();

        _isAsset[asset] = true;
        _assetList.push(asset);
        targetWeight[asset] = weight;
        assetUnitScale[asset] = 10 ** (BASKET_DECIMALS - _getDecimals(asset));
        totalTargetWeight += weight;

        emit AssetAdded(asset, weight);
    }

    function removeAsset(address asset) external onlyOperator {
        if (!_isAsset[asset]) revert AssetNotSupported();
        if (targetWeight[asset] != 0) revert AssetWeightNotZero();
        if (reserves[asset] != 0) revert AssetHasReserves();

        _isAsset[asset] = false;
        targetWeight[asset] = 0;
        assetUnitScale[asset] = 0;

        uint256 count = _assetList.length;
        for (uint256 i = 0; i < count; i++) {
            if (_assetList[i] == asset) {
                _assetList[i] = _assetList[count - 1];
                _assetList.pop();
                break;
            }
        }

        emit AssetRemoved(asset);
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _getDecimals(address asset) internal view returns (uint8) {
        (bool success, bytes memory data) = asset.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }
        return 18;
    }

    function _safeTransfer(address asset, address to, uint256 amount) internal {
        (bool success, bytes memory data) = asset.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert InvalidTransfer();
    }

    function _safeTransferFrom(address asset, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = asset.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert InvalidTransfer();
    }
}
