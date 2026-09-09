// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract NFTAMM {
    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 nftAmount, uint256 lpTokensMinted);
    event LiquidityRemoved(address indexed provider, uint256 tokenAmount, uint256 nftAmount, uint256 lpTokensBurned);
    event TokensSwapped(address indexed user, bool buyNFT, uint256 amountIn, uint256 amountOut, uint256 tradingFee, uint256 royaltyFee);
    event FeesClaimed(address indexed provider, uint256 amount);
    event TradingFeeUpdated(uint256 newFee);
    event OperatorSet(address indexed newOperator);
    event PausedSet(bool paused);
    event RoyaltyRecipientSet(address indexed newRecipient);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InvalidAmount();
    error PoolNotInitialized();
    error InsufficientBalance();
    error SlippageExceeded();
    error FeeTooHigh();
    error Unauthorized();
    error TradingPaused();
    error InvalidRatio();
    error ExceedsMaxTokens();
    error ZeroAddress();
    error Reentrancy();
    error TransferFailed();

    uint256 public constant MAX_TRADING_FEE_BPS = 250; // 2.5%
    uint256 public constant ROYALTY_FEE_BPS = 50; // 0.5%
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant PRECISION = 1e18;

    address public immutable nftToken;
    address public immutable token;

    address public owner;
    address public operator;
    address public royaltyRecipient;
    bool public paused;
    uint256 public tradingFeeBps;

    uint256 public tokenReserve;
    uint256 public nftCount;
    uint256[] internal nftTokenIds;

    uint256 public feePool;
    uint256 public feePerShare;
    mapping(address => uint256) public userFeePerSharePaid;

    string public constant name = "NFTAMM LP Token";
    string public constant symbol = "NFTAMM-LP";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private _status = 1;
    modifier nonReentrant() {
        if (_status == 2) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        address _nftToken,
        address _token,
        uint256 _initialTradingFeeBps,
        address _owner
    ) {
        if (_nftToken == address(0) || _token == address(0) || _owner == address(0)) revert ZeroAddress();
        if (_initialTradingFeeBps > MAX_TRADING_FEE_BPS) revert FeeTooHigh();
        nftToken = _nftToken;
        token = _token;
        owner = _owner;
        operator = _owner;
        royaltyRecipient = _owner;
        tradingFeeBps = _initialTradingFeeBps;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientBalance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256[] calldata nftIds)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 lpTokens)
    {
        uint256 nftAmount = nftIds.length;
        if (tokenAmount == 0 || nftAmount == 0) revert InvalidAmount();

        if (totalSupply == 0) {
            tokenReserve = tokenAmount;
            nftCount = nftAmount;
            lpTokens = _sqrt(tokenAmount * nftAmount);
            if (lpTokens == 0) revert InvalidAmount();
            totalSupply = lpTokens;
            balanceOf[msg.sender] = lpTokens;
            emit Transfer(address(0), msg.sender, lpTokens);
        } else {
            if (tokenAmount * nftCount != tokenReserve * nftAmount) revert InvalidRatio();
            lpTokens = (tokenAmount * totalSupply) / tokenReserve;
            if (lpTokens == 0) revert InvalidAmount();
            unchecked {
                totalSupply += lpTokens;
                balanceOf[msg.sender] += lpTokens;
                tokenReserve += tokenAmount;
                nftCount += nftAmount;
            }
            emit Transfer(address(0), msg.sender, lpTokens);
        }

        // Effects: record deposited token ids before interactions
        for (uint256 i = 0; i < nftAmount; ) {
            nftTokenIds.push(nftIds[i]);
            unchecked { ++i; }
        }

        // Interactions
        _safeTransferFromERC20(token, msg.sender, address(this), tokenAmount);
        for (uint256 i = 0; i < nftAmount; ) {
            IERC721(nftToken).safeTransferFrom(msg.sender, address(this), nftIds[i]);
            unchecked { ++i; }
        }

        emit LiquidityAdded(msg.sender, tokenAmount, nftAmount, lpTokens);
    }

    function removeLiquidity(uint256 lpTokens, uint256 minTokenOut, uint256 minNftOut)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokenAmount, uint256[] memory removedIds)
    {
        if (totalSupply == 0) revert PoolNotInitialized();
        if (balanceOf[msg.sender] < lpTokens || lpTokens == 0) revert InsufficientBalance();

        // Compute pending fees first (no external call yet)
        uint256 pending = _pendingFees(msg.sender);

        tokenAmount = (lpTokens * tokenReserve) / totalSupply;
        uint256 nftAmount = (lpTokens * nftCount) / totalSupply;
        if (tokenAmount < minTokenOut || nftAmount < minNftOut) revert SlippageExceeded();
        if (nftAmount == 0 && tokenAmount == 0) revert InvalidAmount();

        // Effects: update fee accounting
        if (pending > 0) {
            userFeePerSharePaid[msg.sender] = feePerShare;
            feePool -= pending;
        }

        // Effects: burn LP tokens and update reserves
        unchecked {
            balanceOf[msg.sender] -= lpTokens;
            totalSupply -= lpTokens;
            tokenReserve -= tokenAmount;
            nftCount -= nftAmount;
        }
        emit Transfer(msg.sender, address(0), lpTokens);

        // Effects: collect ids to return and shrink the deposited array
        removedIds = new uint256[](nftAmount);
        for (uint256 i = 0; i < nftAmount; ) {
            uint256 idx = nftTokenIds.length - 1 - i;
            removedIds[i] = nftTokenIds[idx];
            unchecked { ++i; }
        }
        for (uint256 i = 0; i < nftAmount; ) {
            nftTokenIds.pop();
            unchecked { ++i; }
        }

        // Interactions
        uint256 totalTokenOut = tokenAmount + pending;
        _safeTransferERC20(token, msg.sender, totalTokenOut);
        for (uint256 i = 0; i < nftAmount; ) {
            IERC721(nftToken).safeTransferFrom(address(this), msg.sender, removedIds[i]);
            unchecked { ++i; }
        }

        if (pending > 0) {
            emit FeesClaimed(msg.sender, pending);
        }
        emit LiquidityRemoved(msg.sender, tokenAmount, nftAmount, lpTokens);
    }

    function swapNFTsForTokens(uint256[] calldata nftIds)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokensReceived)
    {
        if (totalSupply == 0) revert PoolNotInitialized();
        uint256 nftAmount = nftIds.length;
        if (nftAmount == 0) revert InvalidAmount();

        // Multiply before divide to avoid precision loss
        uint256 numerator = tokenReserve * nftAmount;
        uint256 denom = nftCount + nftAmount;
        uint256 deltaT = numerator / denom;
        if (deltaT == 0) revert InvalidAmount();

        uint256 tradingFee = (numerator * tradingFeeBps) / (denom * BASIS_POINTS);
        uint256 royaltyFee = (numerator * ROYALTY_FEE_BPS) / (denom * BASIS_POINTS);
        tokensReceived = deltaT - tradingFee - royaltyFee;
        if (tokensReceived == 0) revert InvalidAmount();

        // Effects
        tokenReserve -= deltaT;
        nftCount += nftAmount;
        feePool += tradingFee;
        _updateFeePerShare(tradingFee);

        for (uint256 i = 0; i < nftAmount; ) {
            nftTokenIds.push(nftIds[i]);
            unchecked { ++i; }
        }

        // Interactions
        for (uint256 i = 0; i < nftAmount; ) {
            IERC721(nftToken).safeTransferFrom(msg.sender, address(this), nftIds[i]);
            unchecked { ++i; }
        }

        _safeTransferERC20(token, msg.sender, tokensReceived);
        if (royaltyFee > 0) {
            _safeTransferERC20(token, royaltyRecipient, royaltyFee);
        }

        emit TokensSwapped(msg.sender, false, nftAmount, tokensReceived, tradingFee, royaltyFee);
    }

    function swapTokensForNFTs(uint256 maxTokensToSpend, uint256 nftAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokensSpent)
    {
        if (totalSupply == 0) revert PoolNotInitialized();
        if (nftAmount == 0 || nftAmount > nftCount) revert InvalidAmount();

        // Multiply before divide to avoid precision loss
        uint256 numerator = tokenReserve * nftAmount;
        uint256 denom = nftCount - nftAmount;
        uint256 deltaT = numerator / denom;
        unchecked { deltaT += 1; } // round up to preserve invariant

        uint256 tradingFee = (numerator * tradingFeeBps) / (denom * BASIS_POINTS);
        uint256 royaltyFee = (numerator * ROYALTY_FEE_BPS) / (denom * BASIS_POINTS);
        tokensSpent = deltaT + tradingFee + royaltyFee;
        if (tokensSpent > maxTokensToSpend) revert ExceedsMaxTokens();

        // Effects
        tokenReserve += deltaT;
        nftCount -= nftAmount;
        feePool += tradingFee;
        _updateFeePerShare(tradingFee);

        uint256[] memory removedIds = new uint256[](nftAmount);
        for (uint256 i = 0; i < nftAmount; ) {
            uint256 idx = nftTokenIds.length - 1 - i;
            removedIds[i] = nftTokenIds[idx];
            unchecked { ++i; }
        }
        for (uint256 i = 0; i < nftAmount; ) {
            nftTokenIds.pop();
            unchecked { ++i; }
        }

        // Interactions
        _safeTransferFromERC20(token, msg.sender, address(this), tokensSpent);

        if (royaltyFee > 0) {
            _safeTransferERC20(token, royaltyRecipient, royaltyFee);
        }

        for (uint256 i = 0; i < nftAmount; ) {
            IERC721(nftToken).safeTransferFrom(address(this), msg.sender, removedIds[i]);
            unchecked { ++i; }
        }

        emit TokensSwapped(msg.sender, true, tokensSpent, nftAmount, tradingFee, royaltyFee);
    }

    function claimFees() external nonReentrant returns (uint256 amount) {
        amount = _pendingFees(msg.sender);
        if (amount == 0) revert InvalidAmount();

        // Effects
        userFeePerSharePaid[msg.sender] = feePerShare;
        feePool -= amount;

        // Interactions
        _safeTransferERC20(token, msg.sender, amount);

        emit FeesClaimed(msg.sender, amount);
    }

    function _pendingFees(address user) internal view returns (uint256) {
        uint256 userBalance = balanceOf[user];
        if (userBalance == 0 || totalSupply == 0) return 0;
        return (userBalance * (feePerShare - userFeePerSharePaid[user])) / PRECISION;
    }

    function _updateFeePerShare(uint256 feeAmount) internal {
        if (totalSupply > 0) {
            feePerShare += (feeAmount * PRECISION) / totalSupply;
        }
    }

    function pendingFees(address user) external view returns (uint256) {
        return _pendingFees(user);
    }

    function getQuoteBuyNFT(uint256 nftAmount) external view returns (uint256 totalTokens) {
        if (totalSupply == 0 || nftAmount == 0 || nftAmount > nftCount) revert InvalidAmount();
        uint256 numerator = tokenReserve * nftAmount;
        uint256 denom = nftCount - nftAmount;
        uint256 deltaT = numerator / denom;
        unchecked { deltaT += 1; }
        uint256 tradingFee = (numerator * tradingFeeBps) / (denom * BASIS_POINTS);
        uint256 royaltyFee = (numerator * ROYALTY_FEE_BPS) / (denom * BASIS_POINTS);
        totalTokens = deltaT + tradingFee + royaltyFee;
    }

    function getQuoteSellNFT(uint256 nftAmount) external view returns (uint256 tokensReceived) {
        if (totalSupply == 0 || nftAmount == 0) revert InvalidAmount();
        uint256 numerator = tokenReserve * nftAmount;
        uint256 denom = nftCount + nftAmount;
        uint256 deltaT = numerator / denom;
        uint256 tradingFee = (numerator * tradingFeeBps) / (denom * BASIS_POINTS);
        uint256 royaltyFee = (numerator * ROYALTY_FEE_BPS) / (denom * BASIS_POINTS);
        tokensReceived = deltaT - tradingFee - royaltyFee;
    }

    function getPoolState() external view returns (uint256 _tokenReserve, uint256 _nftCount, uint256 _totalSupply) {
        return (tokenReserve, nftCount, totalSupply);
    }

    function getDepositedTokenIdsLength() external view returns (uint256) {
        return nftTokenIds.length;
    }

    function setTradingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_TRADING_FEE_BPS) revert FeeTooHigh();
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(newFeeBps);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedSet(_paused);
    }

    function setRoyaltyRecipient(address _royaltyRecipient) external onlyOwner {
        if (_royaltyRecipient == address(0)) revert ZeroAddress();
        royaltyRecipient = _royaltyRecipient;
        emit RoyaltyRecipientSet(_royaltyRecipient);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function _safeTransferERC20(address _token, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFromERC20(address _token, address _from, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
