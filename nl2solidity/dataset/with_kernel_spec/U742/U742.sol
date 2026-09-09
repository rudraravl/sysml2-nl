// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title StablecoinSystem
 * @notice A stablecoin system backed by a reserve of a base ERC20 asset. Users mint
 *         stablecoins by depositing the base asset and redeem stablecoins for the
 *         base asset. A designated operator may adjust the target reserve ratio and
 *         independently pause minting or redemption. The redemption fee is 0.5%.
 */
contract StablecoinSystem {
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Mint(address indexed minter, address indexed to, uint256 baseAssetAmount, uint256 stablecoinAmount);
    event Redeem(address indexed redeemer, address indexed to, uint256 stablecoinAmount, uint256 baseAssetReturned, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event TargetReserveRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event MintingPausedChanged(bool paused);
    event RedemptionPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error MintingIsPaused();
    error RedemptionIsPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error InvalidRatio();
    error InvalidFee();
    error InvalidAddress();
    error ZeroAmount();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_REDEMPTION_FEE = 50;
    uint8   public constant decimals = 18;

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------
    string  public name;
    string  public symbol;

    IERC20  public immutable baseAsset;
    address public operator;

    uint256 public totalSupply;
    uint256 public totalBaseAssetReserve;
    uint256 public targetReserveRatio;
    uint256 public redemptionFee;

    bool    public mintingPaused;
    bool    public redemptionPaused;

    mapping(address => uint256) public stablecoinBalance;
    mapping(address => uint256) public baseAssetDeposited;
    mapping(address => mapping(address => uint256)) private _allowances;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        address _baseAsset,
        address _operator,
        string memory _name,
        string memory _symbol
    ) {
        if (_baseAsset == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        baseAsset = IERC20(_baseAsset);
        operator = _operator;
        name = _name;
        symbol = _symbol;
        targetReserveRatio = 10000;
        redemptionFee = DEFAULT_REDEMPTION_FEE;
    }

    // -----------------------------------------------------------------------
    // ERC20 View Functions
    // -----------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return stablecoinBalance[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // -----------------------------------------------------------------------
    // ERC20 Transfer / Approve
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                _allowances[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Mint
    // -----------------------------------------------------------------------
    function mint(address to, uint256 baseAssetAmount) external {
        if (mintingPaused) revert MintingIsPaused();
        if (to == address(0)) revert InvalidAddress();
        if (baseAssetAmount == 0) revert ZeroAmount();

        uint256 stablecoinAmount = (baseAssetAmount * BASIS_POINTS) / targetReserveRatio;
        if (stablecoinAmount == 0) revert ZeroAmount();

        _safeTransferFrom(baseAsset, msg.sender, address(this), baseAssetAmount);

        totalBaseAssetReserve += baseAssetAmount;
        baseAssetDeposited[to] += baseAssetAmount;
        totalSupply += stablecoinAmount;
        unchecked {
            stablecoinBalance[to] += stablecoinAmount;
        }

        emit Mint(msg.sender, to, baseAssetAmount, stablecoinAmount);
        emit Transfer(address(0), to, stablecoinAmount);
    }

    // -----------------------------------------------------------------------
    // Redeem
    // -----------------------------------------------------------------------
    function redeem(address to, uint256 stablecoinAmount) external {
        if (redemptionPaused) revert RedemptionIsPaused();
        if (to == address(0)) revert InvalidAddress();
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (stablecoinBalance[msg.sender] < stablecoinAmount) revert InsufficientBalance();

        uint256 fee = (stablecoinAmount * redemptionFee) / BASIS_POINTS;
        uint256 netStablecoin = stablecoinAmount - fee;
        uint256 baseAssetReturn = (netStablecoin * BASIS_POINTS) / targetReserveRatio;

        if (baseAssetReturn > totalBaseAssetReserve) revert InsufficientReserve();

        totalSupply -= stablecoinAmount;
        unchecked {
            stablecoinBalance[msg.sender] -= stablecoinAmount;
        }
        totalBaseAssetReserve -= baseAssetReturn;

        uint256 deposited = baseAssetDeposited[msg.sender];
        if (deposited >= baseAssetReturn) {
            baseAssetDeposited[msg.sender] = deposited - baseAssetReturn;
        } else {
            baseAssetDeposited[msg.sender] = 0;
        }

        _safeTransfer(baseAsset, to, baseAssetReturn);

        emit Redeem(msg.sender, to, stablecoinAmount, baseAssetReturn, fee);
        emit Transfer(msg.sender, address(0), stablecoinAmount);
    }

    // -----------------------------------------------------------------------
    // Reserve Ratio (computed)
    // -----------------------------------------------------------------------
    function currentReserveRatio() external view returns (uint256) {
        if (totalSupply == 0) return targetReserveRatio;
        return (totalBaseAssetReserve * BASIS_POINTS) / totalSupply;
    }

    // -----------------------------------------------------------------------
    // Operator Functions
    // -----------------------------------------------------------------------
    function setTargetReserveRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0 || newRatio > BASIS_POINTS) revert InvalidRatio();
        uint256 oldRatio = targetReserveRatio;
        targetReserveRatio = newRatio;
        emit TargetReserveRatioUpdated(oldRatio, newRatio);
    }

    function setRedemptionFee(uint256 newFee) external onlyOperator {
        if (newFee > BASIS_POINTS) revert InvalidFee();
        uint256 oldFee = redemptionFee;
        redemptionFee = newFee;
        emit RedemptionFeeUpdated(oldFee, newFee);
    }

    function setMintingPaused(bool paused) external onlyOperator {
        mintingPaused = paused;
        emit MintingPausedChanged(paused);
    }

    function setRedemptionPaused(bool paused) external onlyOperator {
        redemptionPaused = paused;
        emit RedemptionPausedChanged(paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    // -----------------------------------------------------------------------
    // Internal Functions
    // -----------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        if (stablecoinBalance[from] < amount) revert InsufficientBalance();
        unchecked {
            stablecoinBalance[from] -= amount;
            stablecoinBalance[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert InvalidAddress();
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // Safety: reject accidental ETH transfers.
    // -----------------------------------------------------------------------
    receive() external payable {
        revert("ETH not accepted");
    }
}
