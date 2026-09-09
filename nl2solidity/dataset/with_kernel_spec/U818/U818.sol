// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Stablecoin {
    error ZeroAddress();
    error ZeroAmount();
    error InvalidRatio(uint256 ratio);
    error MintingPaused();
    error BurningPaused();
    error InsufficientCollateral(uint256 required, uint256 deposited);
    error InsufficientBalance(uint256 required, uint256 held);
    error InsufficientAllowance(uint256 required, uint256 allowance);
    error InsufficientReserve(uint256 required, uint256 available);
    error TransferFailed();
    error OnlyOperator();

    event StablecoinMinted(address indexed minter, address indexed recipient, uint256 stableAmount, uint256 collateralAmount);
    event StablecoinBurned(address indexed burner, uint256 stableAmount, uint256 collateralAmountRedeemed);
    event TransferWithFee(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MintingPausedChanged(bool paused);
    event BurningPausedChanged(bool paused);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    IERC20 public immutable collateralToken;
    uint256 public totalCollateralReserve;

    uint256 public collateralizationRatio; // in basis points (15000 = 150%)
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;

    uint256 public constant TRANSFER_FEE_BIPS = 50; // 0.5%
    address public treasury;

    address public operator;
    bool public mintingPaused;
    bool public burningPaused;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _collateralToken,
        address _operator,
        address _treasury
    ) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();

        name = _name;
        symbol = _symbol;
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        treasury = _treasury;
        collateralizationRatio = 15000; // 150%

        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
        emit CollateralizationRatioUpdated(0, 15000);
    }

    function mint(address recipient, uint256 stableAmount) external {
        if (mintingPaused) revert MintingPaused();
        if (recipient == address(0)) revert ZeroAddress();
        if (stableAmount == 0) revert ZeroAmount();

        uint256 collateralRequired = (stableAmount * collateralizationRatio) / BASIS_POINTS_DENOMINATOR;
        if (collateralRequired == 0) revert InsufficientCollateral(collateralRequired, 0);

        _safeTransferFrom(collateralToken, msg.sender, address(this), collateralRequired);

        totalCollateralReserve += collateralRequired;
        _mint(recipient, stableAmount);

        emit StablecoinMinted(msg.sender, recipient, stableAmount, collateralRequired);
    }

    function burn(uint256 stableAmount) external {
        if (burningPaused) revert BurningPaused();
        if (stableAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < stableAmount) revert InsufficientBalance(stableAmount, balanceOf[msg.sender]);

        uint256 collateralToRedeem = (stableAmount * collateralizationRatio) / BASIS_POINTS_DENOMINATOR;
        if (collateralToRedeem > totalCollateralReserve) revert InsufficientReserve(collateralToRedeem, totalCollateralReserve);

        _burn(msg.sender, stableAmount);
        totalCollateralReserve -= collateralToRedeem;

        _safeTransfer(collateralToken, msg.sender, collateralToRedeem);

        emit StablecoinBurned(msg.sender, stableAmount, collateralToRedeem);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance(amount, balanceOf[msg.sender]);

        uint256 fee = (amount * TRANSFER_FEE_BIPS) / BASIS_POINTS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        balanceOf[msg.sender] -= amount;

        if (fee > 0) {
            balanceOf[treasury] += fee;
            emit Transfer(msg.sender, treasury, fee);
        }

        balanceOf[recipient] += netAmount;
        emit Transfer(msg.sender, recipient, netAmount);
        emit TransferWithFee(msg.sender, recipient, netAmount, fee);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[sender] < amount) revert InsufficientBalance(amount, balanceOf[sender]);
        if (allowance[sender][msg.sender] < amount) revert InsufficientAllowance(amount, allowance[sender][msg.sender]);

        uint256 fee = (amount * TRANSFER_FEE_BIPS) / BASIS_POINTS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;

        if (fee > 0) {
            balanceOf[treasury] += fee;
            emit Transfer(sender, treasury, fee);
        }

        balanceOf[recipient] += netAmount;
        emit Transfer(sender, recipient, netAmount);
        emit TransferWithFee(sender, recipient, netAmount, fee);

        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio == 0 || newRatio > 100 * BASIS_POINTS_DENOMINATOR) revert InvalidRatio(newRatio);
        uint256 oldRatio = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(oldRatio, newRatio);
    }

    function setMintingPaused(bool paused) external onlyOperator {
        mintingPaused = paused;
        emit MintingPausedChanged(paused);
    }

    function setBurningPaused(bool paused) external onlyOperator {
        burningPaused = paused;
        emit BurningPausedChanged(paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function _mint(address account, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        totalSupply -= amount;
        balanceOf[account] -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
