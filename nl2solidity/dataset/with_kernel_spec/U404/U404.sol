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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract FractionalEtherStablecoin is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================================
    // Constants
    // ============================================================

    /// @dev Value of 1 stablecoin (1e18 base units) expressed in wei (1e14 wei = 0.0001 ether).
    uint256 public constant PEG = 1e14;
    /// @dev Swap fee charged when swapping stablecoins for the reserve token (50 = 0.5%).
    uint256 public constant SWAP_FEE_BPS = 50;
    /// @dev Basis points denominator.
    uint256 public constant BPS = 10000;
    /// @dev Minimum target collateralization ratio in basis points (5000 = 50%).
    uint256 public constant MIN_RATIO_BPS = 5000;
    /// @dev Maximum target collateralization ratio in basis points (10000 = 100%).
    uint256 public constant MAX_RATIO_BPS = 10000;
    /// @dev One whole token in its smallest unit (1e18 for 18-decimal tokens).
    uint256 private constant ONE = 1e18;

    // ============================================================
    // ERC-20 metadata
    // ============================================================

    string public name = "Fractional Ether Stablecoin";
    string public symbol = "fETH";
    uint8 public decimals = 18;

    // ============================================================
    // ERC-20 storage
    // ============================================================

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============================================================
    // Vault state
    // ============================================================

    /// @dev Total ether held as collateral (in wei), deposited via mint().
    uint256 public etherCollateral;
    /// @dev Total reserve token held by the vault (internal accounting).
    uint256 public reserveBalance;
    /// @dev Target collateralization ratio in basis points, within [MIN_RATIO_BPS, MAX_RATIO_BPS].
    uint256 public targetRatioBps;
    /// @dev The volatile reserve token backing the stablecoin supply.
    IERC20 public immutable reserveToken;
    /// @dev Authorized operator that can adjust the ratio and manage the reserve token.
    address public operator;

    // ============================================================
    // Events
    // ============================================================

    event Mint(address indexed minter, uint256 stablecoinAmount, uint256 etherDeposited);
    event Redeem(address indexed redeemer, uint256 stablecoinAmount, uint256 etherReturned);
    event Swap(address indexed swapper, uint256 stablecoinAmount, uint256 reserveReceived, uint256 fee);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event ReserveDeposited(address indexed by, uint256 amount);
    event ReserveWithdrawn(address indexed by, address indexed to, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============================================================
    // Errors
    // ============================================================

    error NotOperator();
    error RatioOutOfBounds(uint256 ratio);
    error InsufficientEtherCollateral(uint256 available, uint256 needed);
    error InsufficientBalance(uint256 available, uint256 needed);
    error InsufficientAllowance(uint256 available, uint256 needed);
    error InsufficientReserve(uint256 available, uint256 needed);
    error ZeroAddress();
    error ZeroAmount();
    error EtherTransferFailed();
    error NotContract();
    error AmountTooLarge();

    // ============================================================
    // Modifiers
    // ============================================================

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ============================================================
    // Constructor
    // ============================================================

    constructor(address _reserveToken, address _operator, uint256 _initialRatioBps) {
        if (_reserveToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_reserveToken.code.length == 0) revert NotContract();
        if (_initialRatioBps < MIN_RATIO_BPS || _initialRatioBps > MAX_RATIO_BPS) {
            revert RatioOutOfBounds(_initialRatioBps);
        }
        reserveToken = IERC20(_reserveToken);
        operator = _operator;
        targetRatioBps = _initialRatioBps;
        emit CollateralizationRatioUpdated(0, _initialRatioBps);
        emit OperatorChanged(address(0), _operator);
    }

    // ============================================================
    // Operator: collateralization ratio management
    // ============================================================

    /// @notice Update the target collateralization ratio. Must be within [50%, 100%].
    function setTargetRatio(uint256 _ratioBps) external onlyOperator {
        if (_ratioBps < MIN_RATIO_BPS || _ratioBps > MAX_RATIO_BPS) revert RatioOutOfBounds(_ratioBps);
        uint256 old = targetRatioBps;
        targetRatioBps = _ratioBps;
        emit CollateralizationRatioUpdated(old, _ratioBps);
    }

    // ============================================================
    // Operator: reserve token management
    // ============================================================

    /// @notice Operator deposits reserve tokens into the vault.
    function depositReserve(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        reserveToken.safeTransferFrom(msg.sender, address(this), amount);
        reserveBalance += amount;
        emit ReserveDeposited(msg.sender, amount);
    }

    /// @notice Operator withdraws reserve tokens from the vault.
    function withdrawReserve(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > reserveBalance) revert InsufficientReserve(reserveBalance, amount);
        reserveBalance -= amount;
        reserveToken.safeTransfer(to, amount);
        emit ReserveWithdrawn(msg.sender, to, amount);
    }

    // ============================================================
    // Operator: operator management
    // ============================================================

    /// @notice Transfer the operator role to a new address.
    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _newOperator;
        emit OperatorChanged(old, _newOperator);
    }

    // ============================================================
    // Core: mint stablecoins by depositing ether
    // ============================================================

    /// @notice Mint stablecoins to the caller by depositing ether at the current target ratio.
    /// @dev The number of stablecoins minted equals msg.value * ONE * BPS / (PEG * targetRatioBps).
    function mint() external payable nonReentrant returns (uint256) {
        if (msg.value == 0) revert ZeroAmount();
        uint256 mintAmount = (msg.value * ONE * BPS) / (PEG * targetRatioBps);
        _mint(msg.sender, mintAmount);
        etherCollateral += msg.value;
        emit Mint(msg.sender, mintAmount, msg.value);
        return mintAmount;
    }

    // ============================================================
    // Core: redeem stablecoins for ether
    // ============================================================

    /// @notice Burn stablecoins from the caller and return ether at the current target ratio.
    /// @dev The ether returned equals stablecoinAmount * PEG * targetRatioBps / (ONE * BPS).
    function redeem(uint256 stablecoinAmount) external nonReentrant returns (uint256) {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (stablecoinAmount > type(uint256).max / (PEG * MAX_RATIO_BPS)) revert AmountTooLarge();
        uint256 etherOut = (stablecoinAmount * PEG * targetRatioBps) / (ONE * BPS);
        if (etherOut > etherCollateral) {
            revert InsufficientEtherCollateral(etherCollateral, etherOut);
        }
        _burn(msg.sender, stablecoinAmount);
        etherCollateral -= etherOut;
        (bool ok, ) = payable(msg.sender).call{value: etherOut}("");
        if (!ok) revert EtherTransferFailed();
        emit Redeem(msg.sender, stablecoinAmount, etherOut);
        return etherOut;
    }

    // ============================================================
    // Core: swap stablecoins for the reserve token
    // ============================================================

    /// @notice Burn stablecoins from the caller and transfer reserve tokens out of the vault.
    /// @dev A 0.5% fee is retained inside the reserve pool: reserveBalance only decreases
    /// by the post-fee amount, so the remaining value stays backing the system.
    function swap(uint256 stablecoinAmount) external nonReentrant returns (uint256) {
        if (stablecoinAmount == 0) revert ZeroAmount();
        uint256 reserveOut = (stablecoinAmount * (BPS - SWAP_FEE_BPS)) / BPS;
        if (reserveOut > reserveBalance) {
            revert InsufficientReserve(reserveBalance, reserveOut);
        }
        uint256 fee = stablecoinAmount - reserveOut;
        _burn(msg.sender, stablecoinAmount);
        reserveBalance -= reserveOut;
        reserveToken.safeTransfer(msg.sender, reserveOut);
        emit Swap(msg.sender, stablecoinAmount, reserveOut, fee);
        return reserveOut;
    }

    // ============================================================
    // ERC-20 transfer / approve
    // ============================================================

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            if (allowance[from][msg.sender] < amount) {
                revert InsufficientAllowance(allowance[from][msg.sender], amount);
            }
            allowance[from][msg.sender] -= amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ============================================================
    // Internal mint / burn / transfer
    // ============================================================

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance(balanceOf[from], amount);
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
        if (balanceOf[from] < amount) revert InsufficientBalance(balanceOf[from], amount);
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ============================================================
    // Views
    // ============================================================

    /// @notice Current ether collateralization ratio (in basis points) based on actual ether held.
    function currentEtherCollateralizationRatio() external view returns (uint256) {
        if (totalSupply == 0) return 0;
        uint256 stablecoinValueInWei = (totalSupply * PEG) / ONE;
        if (stablecoinValueInWei == 0) return 0;
        return (etherCollateral * BPS) / stablecoinValueInWei;
    }

    /// @notice Ether required to mint a given amount of stablecoins at the current ratio.
    function etherRequiredForMint(uint256 stablecoinAmount) external view returns (uint256) {
        if (stablecoinAmount > type(uint256).max / (PEG * MAX_RATIO_BPS)) revert AmountTooLarge();
        return (stablecoinAmount * PEG * targetRatioBps) / (ONE * BPS);
    }

    /// @notice Ether returned when redeeming a given amount of stablecoins at the current ratio.
    function etherReturnedForRedeem(uint256 stablecoinAmount) external view returns (uint256) {
        if (stablecoinAmount > type(uint256).max / (PEG * MAX_RATIO_BPS)) revert AmountTooLarge();
        return (stablecoinAmount * PEG * targetRatioBps) / (ONE * BPS);
    }

    /// @notice Reserve tokens received when swapping a given amount of stablecoins (post fee).
    function reserveOutForSwap(uint256 stablecoinAmount) external pure returns (uint256) {
        return (stablecoinAmount * (BPS - SWAP_FEE_BPS)) / BPS;
    }

    /// @notice Fee retained in the reserve pool when swapping a given amount of stablecoins.
    function swapFeeForAmount(uint256 stablecoinAmount) external pure returns (uint256) {
        return (stablecoinAmount * SWAP_FEE_BPS) / BPS;
    }

    /// @notice Total ether balance held by the contract.
    function totalEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Actual reserve token balance held by the contract.
    function actualReserveBalance() external view returns (uint256) {
        return reserveToken.balanceOf(address(this));
    }
}
