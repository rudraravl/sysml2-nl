// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract SyntheticAsset {
    ////////////////////////////////////////////////////////////////
    //                           ERRORS                            //
    ////////////////////////////////////////////////////////////////

    error OnlyOwner();
    error OnlyOperator();
    error ContractPaused();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientReserve();
    error InvalidAmount();
    error InvalidFee();
    error PriceInvalid();
    error Reentrancy();
    error NotSweepableToken();
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    ////////////////////////////////////////////////////////////////
    //                           EVENTS                            //
    ////////////////////////////////////////////////////////////////

    event Mint(
        address indexed caller,
        address indexed to,
        uint256 baseDeposited,
        uint256 syntheticMinted,
        uint256 fee
    );
    event Burn(
        address indexed caller,
        address indexed from,
        uint256 syntheticBurned,
        uint256 baseRedeemed,
        uint256 fee
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event FeeUpdated(
        address indexed operator,
        uint256 oldMintFee,
        uint256 newMintFee,
        uint256 oldBurnFee,
        uint256 newBurnFee
    );
    event Paused(address indexed owner);
    event Unpaused(address indexed owner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReserveUpdated(uint256 oldReserve, uint256 newReserve);
    event Swept(address indexed token, address indexed to, uint256 amount);

    ////////////////////////////////////////////////////////////////
    //                        CONSTANTS                            //
    ////////////////////////////////////////////////////////////////

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant DEFAULT_MINT_FEE = 10; // 0.1%
    uint256 public constant DEFAULT_BURN_FEE = 10; // 0.1%
    uint256 public constant MAX_FEE = 1_000; // 10% cap
    uint256 private constant MIN_AMOUNT = 1;

    ////////////////////////////////////////////////////////////////
    //                         STORAGE                             //
    ////////////////////////////////////////////////////////////////

    string public name;
    string public symbol;
    uint8 public decimals;

    address public owner;
    address public operator;
    bool public paused;

    IERC20 public immutable baseAsset;
    address public immutable targetAsset;
    IPriceOracle public immutable priceOracle;

    uint256 public mintFeeBps;
    uint256 public burnFeeBps;

    uint256 public totalSupply;
    uint256 public reserve; // accounting of base stablecoin backing the synthetic

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private _locked = 1;

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                           //
    ////////////////////////////////////////////////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR                          //
    ////////////////////////////////////////////////////////////////

    constructor(
        address _owner,
        address _operator,
        address _baseAsset,
        address _targetAsset,
        address _priceOracle,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_targetAsset == address(0)) revert ZeroAddress();
        if (_priceOracle == address(0)) revert ZeroAddress();

        owner = _owner;
        operator = _operator;
        baseAsset = IERC20(_baseAsset);
        targetAsset = _targetAsset;
        priceOracle = IPriceOracle(_priceOracle);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        mintFeeBps = DEFAULT_MINT_FEE;
        burnFeeBps = DEFAULT_BURN_FEE;

        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
        emit FeeUpdated(_operator, 0, DEFAULT_MINT_FEE, 0, DEFAULT_BURN_FEE);
    }

    ////////////////////////////////////////////////////////////////
    //                       ADMIN FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setFees(uint256 _mintFeeBps, uint256 _burnFeeBps) external onlyOperator {
        if (_mintFeeBps > MAX_FEE || _burnFeeBps > MAX_FEE) revert InvalidFee();
        uint256 oldMint = mintFeeBps;
        uint256 oldBurn = burnFeeBps;
        mintFeeBps = _mintFeeBps;
        burnFeeBps = _burnFeeBps;
        emit FeeUpdated(msg.sender, oldMint, _mintFeeBps, oldBurn, _burnFeeBps);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function transferOwnership(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    function sweep(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(baseAsset)) revert NotSweepableToken();
        _safeTransfer(IERC20(token), to, amount);
        emit Swept(token, to, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                       ERC20 LOGIC                           //
    ////////////////////////////////////////////////////////////////

    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        address spender = msg.sender;
        uint256 allowed = allowance[from][spender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][spender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount < MIN_AMOUNT) revert InvalidAmount();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                       CORE MECHANICS                        //
    ////////////////////////////////////////////////////////////////

    function mint(address to, uint256 baseAmount) external whenNotPaused nonReentrant returns (uint256 syntheticAmount) {
        if (to == address(0)) revert ZeroAddress();
        if (baseAmount < MIN_AMOUNT) revert InvalidAmount();

        uint256 price = _getTargetPrice();
        if (price == 0) revert PriceInvalid();

        // Fee on deposited base; remains in reserve as protocol revenue.
        uint256 fee = (baseAmount * mintFeeBps) / FEE_DENOMINATOR;
        uint256 netBase = baseAmount - fee;

        // 1 synthetic unit corresponds to 1 target asset, priced in base (PRICE_PRECISION).
        syntheticAmount = (netBase * PRICE_PRECISION) / price;
        if (syntheticAmount < MIN_AMOUNT) revert InvalidAmount();

        // Effects first (checks-effects-interactions).
        uint256 oldReserve = reserve;
        reserve = oldReserve + baseAmount;
        totalSupply += syntheticAmount;
        balanceOf[to] += syntheticAmount;

        // Interaction: pull base stablecoins from caller.
        _safeTransferFrom(baseAsset, msg.sender, address(this), baseAmount);

        emit Mint(msg.sender, to, baseAmount, syntheticAmount, fee);
        emit Transfer(address(0), to, syntheticAmount);
        emit ReserveUpdated(oldReserve, reserve);
    }

    function burn(address from, uint256 syntheticAmount) external whenNotPaused nonReentrant returns (uint256 baseRedeemed) {
        if (from == address(0)) revert ZeroAddress();
        if (syntheticAmount < MIN_AMOUNT) revert InvalidAmount();

        // Authorization: caller must be `from` or an approved spender.
        if (msg.sender != from) {
            address spender = msg.sender;
            uint256 allowed = allowance[from][spender];
            if (allowed < syntheticAmount) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                allowance[from][spender] = allowed - syntheticAmount;
            }
        }

        uint256 userBal = balanceOf[from];
        if (userBal < syntheticAmount) revert InsufficientBalance();

        uint256 price = _getTargetPrice();
        if (price == 0) revert PriceInvalid();

        // Compute fee with full precision to avoid divide-before-multiply.
        // notional = syntheticAmount * price (in base units * PRICE_PRECISION)
        uint256 notional = syntheticAmount * price;
        uint256 fee = (notional * burnFeeBps) / (PRICE_PRECISION * FEE_DENOMINATOR);
        uint256 grossBase = notional / PRICE_PRECISION;
        baseRedeemed = grossBase - fee;

        if (baseRedeemed > reserve) revert InsufficientReserve();

        // Effects first (checks-effects-interactions).
        unchecked {
            balanceOf[from] = userBal - syntheticAmount;
        }
        totalSupply -= syntheticAmount;
        uint256 oldReserve = reserve;
        reserve = oldReserve - baseRedeemed; // fee remains in reserve

        // Interaction.
        _safeTransfer(baseAsset, from, baseRedeemed);

        emit Burn(msg.sender, from, syntheticAmount, baseRedeemed, fee);
        emit Transfer(from, address(0), syntheticAmount);
        emit ReserveUpdated(oldReserve, reserve);
    }

    ////////////////////////////////////////////////////////////////
    //                         VIEWS                               //
    ////////////////////////////////////////////////////////////////

    function _getTargetPrice() internal view returns (uint256) {
        return priceOracle.getPrice(targetAsset);
    }

    function getTargetPrice() external view returns (uint256) {
        return _getTargetPrice();
    }

    function getBaseAsset() external view returns (address) {
        return address(baseAsset);
    }

    function getTargetAsset() external view returns (address) {
        return targetAsset;
    }

    function getPriceOracle() external view returns (address) {
        return address(priceOracle);
    }

    function collateralizationRatio() external view returns (uint256) {
        uint256 price = _getTargetPrice();
        if (price == 0) return 0;
        uint256 syntheticValue = (totalSupply * price) / PRICE_PRECISION;
        if (syntheticValue < MIN_AMOUNT) return PRICE_PRECISION;
        return (reserve * PRICE_PRECISION) / syntheticValue;
    }

    function previewMint(uint256 baseAmount) external view returns (uint256 syntheticAmount, uint256 fee) {
        uint256 price = _getTargetPrice();
        if (price == 0) return (0, 0);
        fee = (baseAmount * mintFeeBps) / FEE_DENOMINATOR;
        uint256 netBase = baseAmount - fee;
        syntheticAmount = (netBase * PRICE_PRECISION) / price;
    }

    function previewBurn(uint256 syntheticAmount) external view returns (uint256 baseRedeemed, uint256 fee) {
        uint256 price = _getTargetPrice();
        if (price == 0) return (0, 0);
        uint256 notional = syntheticAmount * price;
        fee = (notional * burnFeeBps) / (PRICE_PRECISION * FEE_DENOMINATOR);
        uint256 grossBase = notional / PRICE_PRECISION;
        baseRedeemed = grossBase - fee;
    }

    ////////////////////////////////////////////////////////////////
    //                  INTERNAL SAFE TRANSFERS                   //
    ////////////////////////////////////////////////////////////////

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFromFailed();
        }
    }
}
