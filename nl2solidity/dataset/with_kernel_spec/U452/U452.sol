// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SyntheticYieldToken {
    //---------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed caller, address indexed asset, uint256 amountDeposited, uint256 sharesMinted);
    event Redeem(address indexed caller, uint256 sharesBurned, uint256 feeAmount);
    event AssetPayout(address indexed asset, address indexed to, uint256 amount);
    event StrategyAdded(address indexed asset);
    event StrategyRemoved(address indexed asset);
    event AllocationUpdated(address indexed asset, uint256 oldAllocation, uint256 newAllocation);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    //---------------------------------------------------------------------------
    // Errors
    //---------------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error StrategyAlreadyApproved();
    error StrategyNotApproved();
    error StrategyHasBalance();
    error StrategyAllocationNotZero();
    error AllocationSumInvalid(uint256 sum);
    error FeeExceedsMax(uint256 fee);
    error InsufficientBalance();
    error InsufficientAllowance();
    error ArrayLengthMismatch();
    error TransferFailed();
    error Reentrancy();
    error EmptyStrategyList();

    //---------------------------------------------------------------------------
    // Constants
    //---------------------------------------------------------------------------
    uint8 public constant decimals = 18;
    uint256 public constant HUNDRED_PERCENT = 10000;
    uint256 public constant MAX_REDEMPTION_FEE = 1000; // 10% cap

    //---------------------------------------------------------------------------
    // Token State
    //---------------------------------------------------------------------------
    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    //---------------------------------------------------------------------------
    // Operator & Fee
    //---------------------------------------------------------------------------
    address public operator;
    uint256 public redemptionFee; // basis points

    //---------------------------------------------------------------------------
    // Strategies
    //---------------------------------------------------------------------------
    struct StrategyInfo {
        bool approved;
        uint256 allocation; // basis points (10000 = 100%)
    }
    mapping(address => StrategyInfo) internal _strategies;
    address[] public strategyList;
    mapping(address => uint256) public assetBalance; // tracked custody balance per asset

    //---------------------------------------------------------------------------
    // Reentrancy Guard
    //---------------------------------------------------------------------------
    uint256 private _status;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NOT_ENTERED = 1;

    //---------------------------------------------------------------------------
    // Modifiers
    //---------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    //---------------------------------------------------------------------------
    // Constructor
    //---------------------------------------------------------------------------
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        redemptionFee = 50; // 0.5%
        _status = _NOT_ENTERED;
        emit OperatorUpdated(address(0), _operator);
        emit RedemptionFeeUpdated(0, 50);
    }

    //---------------------------------------------------------------------------
    // ERC20 Transfer / Approval
    //---------------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
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
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    //---------------------------------------------------------------------------
    // Safe ERC20 Helpers
    //---------------------------------------------------------------------------
    function _safeTransferFrom(address asset, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = asset.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address asset, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = asset.call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    //---------------------------------------------------------------------------
    // Deposit
    //---------------------------------------------------------------------------
    function deposit(address asset, uint256 amount) external nonReentrant {
        if (!_strategies[asset].approved) revert StrategyNotApproved();
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(asset, msg.sender, address(this), amount);
        assetBalance[asset] += amount;
        _mint(msg.sender, amount);

        emit Deposit(msg.sender, asset, amount, amount);
    }

    //---------------------------------------------------------------------------
    // Redeem
    //---------------------------------------------------------------------------
    function redeem(uint256 syntheticAmount) external nonReentrant {
        if (syntheticAmount == 0) revert ZeroAmount();
        if (strategyList.length == 0) revert EmptyStrategyList();
        if (balanceOf[msg.sender] < syntheticAmount) revert InsufficientBalance();

        uint256 supply = totalSupply;
        if (supply == 0) revert InsufficientBalance();

        uint256 feeAmount = (syntheticAmount * redemptionFee) / HUNDRED_PERCENT;
        uint256 netAmount = syntheticAmount - feeAmount;

        // Effects: burn net shares from caller.
        _burn(msg.sender, netAmount);

        // Fee shares are redirected from the caller to the operator.
        if (feeAmount > 0) {
            balanceOf[msg.sender] -= feeAmount;
            balanceOf[operator] += feeAmount;
            emit Transfer(msg.sender, operator, feeAmount);
        }

        uint256 len = strategyList.length;
        address[] memory assets = new address[](len);
        uint256[] memory payouts = new uint256[](len);

        // Effects: compute payouts and update custody balances before any external call.
        for (uint256 i = 0; i < len; ) {
            address asset = strategyList[i];
            uint256 bal = assetBalance[asset];
            uint256 payout = (netAmount * bal) / supply;
            assets[i] = asset;
            payouts[i] = payout;
            if (payout > 0) {
                assetBalance[asset] = bal - payout;
            }
            unchecked {
                ++i;
            }
        }

        // Interactions: transfer underlying assets to the redeemer.
        for (uint256 i = 0; i < len; ) {
            if (payouts[i] > 0) {
                _safeTransfer(assets[i], msg.sender, payouts[i]);
                emit AssetPayout(assets[i], msg.sender, payouts[i]);
            }
            unchecked {
                ++i;
            }
        }

        emit Redeem(msg.sender, netAmount, feeAmount);
    }

    //---------------------------------------------------------------------------
    // Operator Management
    //---------------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    //---------------------------------------------------------------------------
    // Redemption Fee
    //---------------------------------------------------------------------------
    function setRedemptionFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_REDEMPTION_FEE) revert FeeExceedsMax(newFee);
        emit RedemptionFeeUpdated(redemptionFee, newFee);
        redemptionFee = newFee;
    }

    //---------------------------------------------------------------------------
    // Strategy Management
    //---------------------------------------------------------------------------
    function addStrategy(address asset) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (_strategies[asset].approved) revert StrategyAlreadyApproved();
        _strategies[asset] = StrategyInfo({approved: true, allocation: 0});
        strategyList.push(asset);
        emit StrategyAdded(asset);
    }

    function removeStrategy(address asset) external onlyOperator {
        if (!_strategies[asset].approved) revert StrategyNotApproved();
        if (assetBalance[asset] > 0) revert StrategyHasBalance();
        if (_strategies[asset].allocation != 0) revert StrategyAllocationNotZero();

        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ) {
            if (strategyList[i] == asset) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        delete _strategies[asset];
        emit StrategyRemoved(asset);
    }

    function setAllocations(uint256[] calldata allocations) external onlyOperator {
        uint256 len = allocations.length;
        if (len != strategyList.length) revert ArrayLengthMismatch();
        if (len == 0) revert EmptyStrategyList();

        uint256 sum = 0;
        for (uint256 i = 0; i < len; ) {
            sum += allocations[i];
            unchecked {
                ++i;
            }
        }
        if (sum != HUNDRED_PERCENT) revert AllocationSumInvalid(sum);

        for (uint256 i = 0; i < len; ) {
            address asset = strategyList[i];
            uint256 oldAlloc = _strategies[asset].allocation;
            _strategies[asset].allocation = allocations[i];
            emit AllocationUpdated(asset, oldAlloc, allocations[i]);
            unchecked {
                ++i;
            }
        }
    }

    //---------------------------------------------------------------------------
    // View Functions
    //---------------------------------------------------------------------------
    function isApprovedStrategy(address asset) external view returns (bool) {
        return _strategies[asset].approved;
    }

    function getStrategyInfo(address asset) external view returns (bool approved, uint256 allocation) {
        StrategyInfo memory s = _strategies[asset];
        return (s.approved, s.allocation);
    }

    function getStrategies() external view returns (address[] memory) {
        return strategyList;
    }

    function strategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function totalAllocation() external view returns (uint256 sum) {
        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ) {
            sum += _strategies[strategyList[i]].allocation;
            unchecked {
                ++i;
            }
        }
    }

    function totalAssets() external view returns (uint256 total) {
        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ) {
            total += assetBalance[strategyList[i]];
            unchecked {
                ++i;
            }
        }
    }

    function previewRedeem(uint256 syntheticAmount)
        external
        view
        returns (address[] memory assets, uint256[] memory payouts, uint256 feeAmount)
    {
        uint256 fee = (syntheticAmount * redemptionFee) / HUNDRED_PERCENT;
        uint256 net = syntheticAmount - fee;
        feeAmount = fee;

        uint256 len = strategyList.length;
        assets = new address[](len);
        payouts = new uint256[](len);

        if (totalSupply == 0) {
            return (assets, payouts, feeAmount);
        }

        for (uint256 i = 0; i < len; ) {
            address asset = strategyList[i];
            assets[i] = asset;
            payouts[i] = (net * assetBalance[asset]) / totalSupply;
            unchecked {
                ++i;
            }
        }
    }
}
