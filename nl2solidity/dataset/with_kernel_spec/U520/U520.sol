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

contract BasketToken {
    uint8   public constant decimals             = 18;
    uint256 public constant BPS_DENOMINATOR      = 10_000;
    uint256 public constant FEE_BPS              = 10;
    uint256 public constant MAX_DAILY_CHANGE_BPS = 1_000;
    uint256 public constant ONE_DAY              = 1 days;
    uint256 public constant BOOTSTRAP_SUPPLY     = 1e18;

    string  public name;
    string  public symbol;
    uint256 public totalSupply;
    mapping(address => uint256)                     public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address[]                   public underlyingTokens;
    mapping(address => bool)    public isUnderlying;
    mapping(address => uint256) public amountHeld;
    mapping(address => uint256) public targetWeight;
    mapping(address => uint256) public rebalanceWindowStart;
    mapping(address => uint256) public rebalanceWindowStartWeight;

    address public operator;
    address public feeCollector;
    bool    public paused;
    uint256 private _reentrancy;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Minted(
        address indexed caller,
        address indexed receiver,
        uint256 basketAmount,
        address[] tokens,
        uint256[] amounts,
        uint256[] fees
    );
    event Redeemed(
        address indexed caller,
        address indexed receiver,
        uint256 basketAmount,
        address[] tokens,
        uint256[] amounts
    );
    event Rebalanced(
        address indexed operator,
        address[] tokens,
        uint256[] oldWeights,
        uint256[] newWeights
    );
    event Bootstrapped(
        address indexed caller,
        uint256 basketAmount,
        address[] tokens,
        uint256[] amounts
    );
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeCollectorChanged(address indexed previousCollector, address indexed newCollector);
    event Recovered(address indexed operator, address indexed token, address indexed to, uint256 amount);

    modifier onlyOperator() {
        require(msg.sender == operator, "BasketToken: only operator");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "BasketToken: paused");
        _;
    }
    modifier nonReentrant() {
        require(_reentrancy == 0, "BasketToken: reentrancy");
        _reentrancy = 1;
        _;
        _reentrancy = 0;
    }

    constructor(
        string   memory _name,
        string   memory _symbol,
        address[] memory _tokens,
        uint256[] memory _weights,
        address  _operator,
        address  _feeCollector
    ) {
        require(_tokens.length > 0, "BasketToken: no tokens");
        require(_tokens.length == _weights.length, "BasketToken: length mismatch");
        require(_operator != address(0), "BasketToken: zero operator");
        require(_feeCollector != address(0), "BasketToken: zero feeCollector");

        name         = _name;
        symbol       = _symbol;
        operator     = _operator;
        feeCollector = _feeCollector;

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            require(token != address(0), "BasketToken: zero token");
            require(!isUnderlying[token], "BasketToken: duplicate token");
            require(_weights[i] > 0, "BasketToken: zero weight");
            totalWeight += _weights[i];

            underlyingTokens.push(token);
            isUnderlying[token]               = true;
            targetWeight[token]               = _weights[i];
            rebalanceWindowStart[token]       = block.timestamp;
            rebalanceWindowStartWeight[token] = _weights[i];
        }
        require(totalWeight == BPS_DENOMINATOR, "BasketToken: weights must sum to 10000");
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "BasketToken: mint to zero address");
        totalSupply   += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BasketToken: burn exceeds balance");
        balanceOf[from] -= amount;
        totalSupply     -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "BasketToken: transfer from zero address");
        require(to != address(0), "BasketToken: transfer to zero address");
        require(balanceOf[from] >= amount, "BasketToken: transfer exceeds balance");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "BasketToken: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "BasketToken: approve to zero address");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "BasketToken: transfer failed"
        );
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "BasketToken: transferFrom failed"
        );
    }

    function underlyingTokensList() external view returns (address[] memory) {
        return underlyingTokens;
    }

    function basketComposition()
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts, uint256[] memory weights)
    {
        uint256 len = underlyingTokens.length;
        tokens  = new address[](len);
        amounts = new uint256[](len);
        weights = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            tokens[i]  = underlyingTokens[i];
            amounts[i] = amountHeld[underlyingTokens[i]];
            weights[i] = targetWeight[underlyingTokens[i]];
        }
    }

    function previewMint(uint256 basketAmount)
        external
        view
        returns (uint256[] memory depositAmounts, uint256[] memory feeAmounts)
    {
        require(totalSupply > 0, "BasketToken: not bootstrapped");
        uint256 len = underlyingTokens.length;
        depositAmounts = new uint256[](len);
        feeAmounts     = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            address token = underlyingTokens[i];
            uint256 held   = amountHeld[token];
            uint256 proportional = (basketAmount * held) / totalSupply;
            uint256 fee = (basketAmount * held * FEE_BPS) / (totalSupply * BPS_DENOMINATOR);
            depositAmounts[i] = proportional;
            feeAmounts[i]     = fee;
        }
    }

    function previewRedeem(uint256 basketAmount)
        external
        view
        returns (uint256[] memory withdrawAmounts)
    {
        require(totalSupply > 0, "BasketToken: not bootstrapped");
        uint256 len = underlyingTokens.length;
        withdrawAmounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            withdrawAmounts[i] = (basketAmount * amountHeld[underlyingTokens[i]]) / totalSupply;
        }
    }

    function bootstrap(uint256[] calldata amounts) external onlyOperator nonReentrant {
        require(totalSupply == 0, "BasketToken: already bootstrapped");
        require(amounts.length == underlyingTokens.length, "BasketToken: length mismatch");

        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            address token = underlyingTokens[i];
            require(amounts[i] > 0, "BasketToken: zero bootstrap amount");
            amountHeld[token] += amounts[i];
        }
        _mint(msg.sender, BOOTSTRAP_SUPPLY);

        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            _safeTransferFrom(
                IERC20(underlyingTokens[i]),
                msg.sender,
                address(this),
                amounts[i]
            );
        }

        emit Bootstrapped(msg.sender, BOOTSTRAP_SUPPLY, underlyingTokens, amounts);
    }

    function mint(uint256 basketAmount, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(totalSupply > 0, "BasketToken: not bootstrapped");
        require(basketAmount > 0, "BasketToken: zero amount");
        require(receiver != address(0), "BasketToken: zero receiver");

        uint256 supply = totalSupply;
        uint256 len    = underlyingTokens.length;
        address[] memory tokens  = new address[](len);
        uint256[]   memory amounts = new uint256[](len);
        uint256[]   memory fees    = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            address token = underlyingTokens[i];
            uint256 held   = amountHeld[token];
            uint256 proportional = (basketAmount * held) / supply;
            require(proportional > 0, "BasketToken: proportional too small");
            uint256 fee = (basketAmount * held * FEE_BPS) / (supply * BPS_DENOMINATOR);
            amountHeld[token] += proportional;
            tokens[i]   = token;
            amounts[i]  = proportional;
            fees[i]     = fee;
        }
        _mint(receiver, basketAmount);

        for (uint256 i = 0; i < len; i++) {
            uint256 totalPull = amounts[i] + fees[i];
            _safeTransferFrom(IERC20(tokens[i]), msg.sender, address(this), totalPull);
            if (fees[i] > 0) {
                _safeTransfer(IERC20(tokens[i]), feeCollector, fees[i]);
            }
        }

        emit Minted(msg.sender, receiver, basketAmount, tokens, amounts, fees);
        return basketAmount;
    }

    function redeem(uint256 basketAmount, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(totalSupply > 0, "BasketToken: not bootstrapped");
        require(basketAmount > 0, "BasketToken: zero amount");
        require(receiver != address(0), "BasketToken: zero receiver");
        require(balanceOf[msg.sender] >= basketAmount, "BasketToken: insufficient balance");

        uint256 supply = totalSupply;
        uint256 len    = underlyingTokens.length;
        address[] memory tokens  = new address[](len);
        uint256[]   memory amounts = new uint256[](len);

        _burn(msg.sender, basketAmount);
        for (uint256 i = 0; i < len; i++) {
            address token = underlyingTokens[i];
            uint256 proportional = (basketAmount * amountHeld[token]) / supply;
            amountHeld[token] -= proportional;
            tokens[i]  = token;
            amounts[i] = proportional;
        }

        for (uint256 i = 0; i < len; i++) {
            if (amounts[i] > 0) {
                _safeTransfer(IERC20(tokens[i]), receiver, amounts[i]);
            }
        }

        emit Redeemed(msg.sender, receiver, basketAmount, tokens, amounts);
        return basketAmount;
    }

    function rebalance(uint256[] calldata newWeights) external onlyOperator {
        require(newWeights.length == underlyingTokens.length, "BasketToken: length mismatch");

        uint256 len = underlyingTokens.length;
        uint256[] memory oldWeights = new uint256[](len);
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < len; i++) {
            address  token     = underlyingTokens[i];
            uint256 oldWeight  = targetWeight[token];
            uint256 newWeight  = newWeights[i];
            require(newWeight > 0, "BasketToken: zero weight");

            if (block.timestamp - rebalanceWindowStart[token] >= ONE_DAY) {
                rebalanceWindowStart[token]       = block.timestamp;
                rebalanceWindowStartWeight[token] = oldWeight;
            }

            uint256 windowWeight = rebalanceWindowStartWeight[token];
            uint256 maxChange    = (windowWeight * MAX_DAILY_CHANGE_BPS) / BPS_DENOMINATOR;

            if (newWeight > windowWeight) {
                require(
                    newWeight - windowWeight <= maxChange,
                    "BasketToken: daily change limit exceeded"
                );
            } else if (newWeight < windowWeight) {
                require(
                    windowWeight - newWeight <= maxChange,
                    "BasketToken: daily change limit exceeded"
                );
            }

            targetWeight[token] = newWeight;
            oldWeights[i]       = oldWeight;
            totalWeight        += newWeight;
        }
        require(totalWeight == BPS_DENOMINATOR, "BasketToken: weights must sum to 10000");

        emit Rebalanced(msg.sender, underlyingTokens, oldWeights, newWeights);
    }

    function pause() external onlyOperator {
        require(!paused, "BasketToken: already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        require(paused, "BasketToken: not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "BasketToken: zero operator");
        address prev = operator;
        operator = newOperator;
        emit OperatorChanged(prev, newOperator);
    }

    function setFeeCollector(address newCollector) external onlyOperator {
        require(newCollector != address(0), "BasketToken: zero feeCollector");
        address prev = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorChanged(prev, newCollector);
    }

    function recover(address token, address to, uint256 amount) external onlyOperator {
        require(to != address(0), "BasketToken: zero recipient");
        require(amount > 0, "BasketToken: zero amount");
        if (isUnderlying[token]) {
            uint256 balExcess = IERC20(token).balanceOf(address(this)) - amountHeld[token];
            require(amount <= balExcess, "BasketToken: exceeds recoverable excess");
        }
        _safeTransfer(IERC20(token), to, amount);
        emit Recovered(msg.sender, token, to, amount);
    }
}
