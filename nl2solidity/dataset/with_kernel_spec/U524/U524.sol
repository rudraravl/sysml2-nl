// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBaseToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract ReserveBackedToken {
    string public constant name = "Reserve Backed Token";
    string public constant symbol = "RBT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IBaseToken public immutable wbtc;
    IBaseToken public immutable weth;
    IBaseToken public immutable stable;

    uint8 public immutable wbtcDecimals;
    uint8 public immutable wethDecimals;
    uint8 public immutable stableDecimals;

    uint256 public immutable wbtcScale;
    uint256 public immutable wethScale;
    uint256 public immutable stableScale;

    uint256 public wbtcBalance;
    uint256 public wethBalance;
    uint256 public stableBalance;

    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public weightWbtc;
    uint256 public weightWeth;
    uint256 public weightStable;

    uint256 public constant TIMELOCK = 48 hours;

    struct RebalanceParams {
        uint256 weightWbtc;
        uint256 weightWeth;
        uint256 weightStable;
        uint64 proposedAt;
        bool exists;
    }
    RebalanceParams public pendingRebalance;

    uint256 public constant MINT_FEE_BPS = 10;
    address public feeRecipient;

    address public owner;

    uint256 private _locked = 1;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Minted(
        address indexed minter,
        uint256 amount,
        uint256 wbtcDeposited,
        uint256 wethDeposited,
        uint256 stableDeposited,
        uint256 fee
    );
    event Redeemed(
        address indexed redeemer,
        uint256 amount,
        uint256 wbtcReturned,
        uint256 wethReturned,
        uint256 stableReturned
    );
    event MintFeeCollected(address indexed recipient, uint256 amount);

    event RebalanceParamsProposed(
        uint256 weightWbtc,
        uint256 weightWeth,
        uint256 weightStable,
        uint256 effectiveAt
    );
    event RebalanceParamsApplied(
        uint256 weightWbtc,
        uint256 weightWeth,
        uint256 weightStable
    );
    event RebalanceParamsCancelled();

    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    error ZeroAmount();
    error ZeroAddress();
    error SumWeightsInvalid();
    error InvalidDecimals();
    error NotOwner();
    error TimelockNotElapsed();
    error NoPendingRebalance();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error TransferFailed();
    error TransferFromFailed();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _wbtc,
        address _weth,
        address _stable,
        uint256 _weightWbtc,
        uint256 _weightWeth,
        uint256 _weightStable,
        address _feeRecipient,
        address _owner
    ) {
        if (_wbtc == address(0) || _weth == address(0) || _stable == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0) || _owner == address(0)) revert ZeroAddress();
        if (_weightWbtc + _weightWeth + _weightStable != BPS_DENOMINATOR) revert SumWeightsInvalid();

        wbtc = IBaseToken(_wbtc);
        weth = IBaseToken(_weth);
        stable = IBaseToken(_stable);

        uint8 dWbtc = wbtc.decimals();
        uint8 dWeth = weth.decimals();
        uint8 dStable = stable.decimals();
        if (dWbtc > 18 || dWeth > 18 || dStable > 18) revert InvalidDecimals();

        wbtcDecimals = dWbtc;
        wethDecimals = dWeth;
        stableDecimals = dStable;

        wbtcScale = 10 ** (18 - dWbtc);
        wethScale = 10 ** (18 - dWeth);
        stableScale = 10 ** (18 - dStable);

        weightWbtc = _weightWbtc;
        weightWeth = _weightWeth;
        weightStable = _weightStable;

        feeRecipient = _feeRecipient;
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    function mint(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        (uint256 reqWbtc, uint256 reqWeth, uint256 reqStable) = _requiredDeposits(amount);

        uint256 recvWbtc = _pullToken(wbtc, msg.sender, reqWbtc);
        uint256 recvWeth = _pullToken(weth, msg.sender, reqWeth);
        uint256 recvStable = _pullToken(stable, msg.sender, reqStable);

        wbtcBalance += recvWbtc;
        wethBalance += recvWeth;
        stableBalance += recvStable;

        uint256 fee = (amount * MINT_FEE_BPS) / BPS_DENOMINATOR;

        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        emit Transfer(address(0), msg.sender, amount);

        if (fee > 0) {
            totalSupply += fee;
            balanceOf[feeRecipient] += fee;
            emit Transfer(address(0), feeRecipient, fee);
            emit MintFeeCollected(feeRecipient, fee);
        }

        emit Minted(msg.sender, amount, recvWbtc, recvWeth, recvStable, fee);
    }

    function redeem(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        (uint256 outWbtc, uint256 outWeth, uint256 outStable) = _requiredDeposits(amount);

        if (wbtcBalance < outWbtc || wethBalance < outWeth || stableBalance < outStable) {
            revert InsufficientLiquidity();
        }

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);

        wbtcBalance -= outWbtc;
        wethBalance -= outWeth;
        stableBalance -= outStable;

        _safeTransfer(wbtc, msg.sender, outWbtc);
        _safeTransfer(weth, msg.sender, outWeth);
        _safeTransfer(stable, msg.sender, outStable);

        emit Redeemed(msg.sender, amount, outWbtc, outWeth, outStable);
    }

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
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function proposeRebalance(
        uint256 _weightWbtc,
        uint256 _weightWeth,
        uint256 _weightStable
    ) external onlyOwner {
        if (_weightWbtc + _weightWeth + _weightStable != BPS_DENOMINATOR) revert SumWeightsInvalid();

        uint64 proposedAt = uint64(block.timestamp);
        pendingRebalance = RebalanceParams({
            weightWbtc: _weightWbtc,
            weightWeth: _weightWeth,
            weightStable: _weightStable,
            proposedAt: proposedAt,
            exists: true
        });

        emit RebalanceParamsProposed(_weightWbtc, _weightWeth, _weightStable, proposedAt + TIMELOCK);
    }

    function applyRebalance() external onlyOwner {
        RebalanceParams memory p = pendingRebalance;
        if (!p.exists) revert NoPendingRebalance();
        if (block.timestamp < p.proposedAt + TIMELOCK) revert TimelockNotElapsed();

        weightWbtc = p.weightWbtc;
        weightWeth = p.weightWeth;
        weightStable = p.weightStable;

        delete pendingRebalance;

        emit RebalanceParamsApplied(weightWbtc, weightWeth, weightStable);
    }

    function cancelRebalance() external onlyOwner {
        if (!pendingRebalance.exists) revert NoPendingRebalance();
        delete pendingRebalance;
        emit RebalanceParamsCancelled();
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function requiredDeposits(uint256 amount)
        external
        view
        returns (uint256 wbtcReq, uint256 wethReq, uint256 stableReq)
    {
        return _requiredDeposits(amount);
    }

    function currentWeights()
        external
        view
        returns (uint256 _weightWbtc, uint256 _weightWeth, uint256 _weightStable)
    {
        return (weightWbtc, weightWeth, weightStable);
    }

    function pendingRebalanceInfo()
        external
        view
        returns (
            uint256 _weightWbtc,
            uint256 _weightWeth,
            uint256 _weightStable,
            uint256 effectiveAt,
            bool exists
        )
    {
        RebalanceParams memory p = pendingRebalance;
        return (
            p.weightWbtc,
            p.weightWeth,
            p.weightStable,
            p.exists ? uint256(p.proposedAt) + TIMELOCK : 0,
            p.exists
        );
    }

    function basketHoldings()
        external
        view
        returns (uint256 _wbtcBalance, uint256 _wethBalance, uint256 _stableBalance)
    {
        return (wbtcBalance, wethBalance, stableBalance);
    }

    function _requiredDeposits(uint256 amount)
        internal
        view
        returns (uint256 wbtcReq, uint256 wethReq, uint256 stableReq)
    {
        wbtcReq = (amount * weightWbtc) / BPS_DENOMINATOR / wbtcScale;
        wethReq = (amount * weightWeth) / BPS_DENOMINATOR / wethScale;
        stableReq = (amount * weightStable) / BPS_DENOMINATOR / stableScale;
    }

    function _pullToken(IBaseToken token, address from, uint256 amount) internal returns (uint256 received) {
        uint256 before = token.balanceOf(address(this));
        _safeTransferFrom(token, from, address(this), amount);
        received = token.balanceOf(address(this)) - before;
    }

    function _safeTransfer(IBaseToken token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IBaseToken.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IBaseToken token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IBaseToken.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFromFailed();
    }
}
