// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract BondTokenizationVault {
    /*//////////////////////////////////////////////////////////////
                              ERC20 METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    /*//////////////////////////////////////////////////////////////
                              ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;

    /*//////////////////////////////////////////////////////////////
                              CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    bool public mintingPaused;
    bool public redemptionPaused;
    mapping(address => bool) public isCollateralApproved;
    uint256 public collateralizationRatio; // in basis points, 10000 == 100%
    uint256 public redemptionFeeRate; // in basis points, 10 == 0.1%
    address public feeRecipient;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Mint(
        address indexed caller,
        address indexed recipient,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 bondAmount
    );
    event Redeem(
        address indexed caller,
        address indexed collateralToken,
        uint256 bondAmount,
        uint256 collateralReturned,
        uint256 fee
    );

    event CollateralTokenUpdated(address indexed token, bool approved);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event RedemptionFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MintingPaused(address indexed by);
    event MintingUnpaused(address indexed by);
    event RedemptionPaused(address indexed by);
    event RedemptionUnpaused(address indexed by);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotOperator();
    error MintingIsPaused();
    error RedemptionIsPaused();
    error ZeroAddress();
    error CollateralNotApproved();
    error InsufficientBalance();
    error InsufficientAllowance();
    error RatioTooLow();
    error FeeRateTooHigh();
    error TransferFailed();
    error InvalidAmount();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenMintingNotPaused() {
        if (mintingPaused) revert MintingIsPaused();
        _;
    }

    modifier whenRedemptionNotPaused() {
        if (redemptionPaused) revert RedemptionIsPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory _collateralTokens,
        address _operator,
        address _feeRecipient
    ) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();

        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        collateralizationRatio = 10000; // 100%
        redemptionFeeRate = 10; // 0.1%

        for (uint256 i = 0; i < _collateralTokens.length; ++i) {
            if (_collateralTokens[i] == address(0)) revert ZeroAddress();
            isCollateralApproved[_collateralTokens[i]] = true;
            emit CollateralTokenUpdated(_collateralTokens[i], true);
        }

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit CollateralizationRatioUpdated(0, 10000);
        emit RedemptionFeeRateUpdated(0, 10);
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

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        unchecked {
            allowance[msg.sender][spender] = currentAllowance - subtractedValue;
        }
        emit Approval(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                          MINT / REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(
        address collateralToken,
        uint256 collateralAmount,
        address recipient
    ) external whenMintingNotPaused returns (uint256 bondAmount) {
        if (!isCollateralApproved[collateralToken]) revert CollateralNotApproved();
        if (collateralAmount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Collateralization ratio expressed in basis points.
        // At 100% (10000 bps), 1 unit of collateral yields 1 bond.
        bondAmount = (collateralAmount * 10000) / collateralizationRatio;
        if (bondAmount == 0) revert InvalidAmount();

        // Effects
        _mint(recipient, bondAmount);

        // Interactions
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) revert TransferFailed();

        emit Mint(msg.sender, recipient, collateralToken, collateralAmount, bondAmount);
    }

    function redeem(
        address collateralToken,
        uint256 bondAmount
    ) external whenRedemptionNotPaused returns (uint256 returned, uint256 fee) {
        if (!isCollateralApproved[collateralToken]) revert CollateralNotApproved();
        if (bondAmount == 0) revert InvalidAmount();

        fee = (bondAmount * redemptionFeeRate) / 10000;
        returned = bondAmount - fee;

        // Effects
        _burn(msg.sender, bondAmount);

        // Interactions
        if (returned > 0) {
            bool ok1 = IERC20(collateralToken).transfer(msg.sender, returned);
            if (!ok1) revert TransferFailed();
        }
        if (fee > 0) {
            bool ok2 = IERC20(collateralToken).transfer(feeRecipient, fee);
            if (!ok2) revert TransferFailed();
        }

        emit Redeem(msg.sender, collateralToken, bondAmount, returned, fee);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN / CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    function setCollateralToken(address token, bool approved) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        isCollateralApproved[token] = approved;
        emit CollateralTokenUpdated(token, approved);
    }

    function setCollateralizationRatio(uint256 newRatio) external onlyOwner {
        // Minimum 100% to ensure bonds are never under-collateralized.
        if (newRatio < 10000) revert RatioTooLow();
        uint256 old = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(old, newRatio);
    }

    function setRedemptionFeeRate(uint256 newRate) external onlyOwner {
        if (newRate > 10000) revert FeeRateTooHigh();
        uint256 old = redemptionFeeRate;
        redemptionFeeRate = newRate;
        emit RedemptionFeeRateUpdated(old, newRate);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function pauseMinting() external onlyOperator {
        mintingPaused = true;
        emit MintingPaused(msg.sender);
    }

    function unpauseMinting() external onlyOperator {
        mintingPaused = false;
        emit MintingUnpaused(msg.sender);
    }

    function pauseRedemption() external onlyOperator {
        redemptionPaused = true;
        emit RedemptionPaused(msg.sender);
    }

    function unpauseRedemption() external onlyOperator {
        redemptionPaused = false;
        emit RedemptionUnpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function collateralReserve(address collateralToken) external view returns (uint256) {
        return IERC20(collateralToken).balanceOf(address(this));
    }
}
