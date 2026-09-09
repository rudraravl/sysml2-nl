// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            value == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Ownable__UnauthorizedAccount(address account);
    error Ownable__NewOwnerIsZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert Ownable__NewOwnerIsZeroAddress();
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Ownable__UnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert Ownable__NewOwnerIsZeroAddress();
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/**
 * @title AssetFractionalizer
 * @notice Facilitates fractional ownership and management of high-value physical
 *         assets represented by wrapped ERC-20 tokens. Users deposit wrapped asset
 *         tokens to fractionalize them, transfer fraction ownership, and redeem
 *         fractions for the underlying wrapped asset token.
 */
contract AssetFractionalizer is Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Basis points denominator (10000 = 100%).
    uint256 public constant BPS_DENOMINATOR = 10_000;
    /// @dev Default redemption fee of 0.5% (50 bps).
    uint256 public constant DEFAULT_REDEMPTION_FEE_BPS = 50;
    /// @dev Maximum allowable redemption fee (10%).
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 1000;
    /// @dev Minimum number of fractions required to initiate a redemption request.
    uint256 public constant MIN_REDEMPTION_FRACTIONS = 100;

    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetFractionalizer__ZeroAddress();
    error AssetFractionalizer__ZeroAmount();
    error AssetFractionalizer__NotOperator();
    error AssetFractionalizer__AssetNotRegistered(uint256 assetId);
    error AssetFractionalizer__AssetAlreadyRegistered(uint256 assetId);
    error AssetFractionalizer__InsufficientFractions(uint256 available, uint256 required);
    error AssetFractionalizer__BelowMinRedemption(uint256 amount, uint256 minimum);
    error AssetFractionalizer__NoActiveRedemption(uint256 assetId, address account);
    error AssetFractionalizer__FeeTooHigh(uint256 fee, uint256 max);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetRegistered(
        uint256 indexed assetId,
        address indexed wrappedToken,
        uint256 fractionsPerUnit,
        string metadataURI
    );
    event AssetFractionalized(
        uint256 indexed assetId,
        address indexed depositor,
        address indexed recipient,
        uint256 wrappedAmount,
        uint256 fractionsMinted
    );
    event FractionsTransferred(
        uint256 indexed assetId,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event RedemptionRequested(
        uint256 indexed assetId,
        address indexed redeemer,
        uint256 fractionAmount,
        uint256 wrappedAmount,
        uint256 fee
    );
    event RedemptionFulfilled(
        uint256 indexed assetId,
        address indexed redeemer,
        uint256 wrappedAmount,
        uint256 fee
    );
    event RedemptionCancelled(uint256 indexed assetId, address indexed redeemer, uint256 fractionAmount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);

    /*//////////////////////////////////////////////////////////////
                              DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct Asset {
        address wrappedToken;
        uint256 totalFractions;
        uint256 fractionsPerUnit;
        bool registered;
        string metadataURI;
    }

    struct RedemptionRequest {
        uint256 fractionAmount;
        uint256 wrappedAmount;
        uint256 fee;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public feeRecipient;
    uint256 public redemptionFeeBps;

    uint256 public nextAssetId;

    mapping(uint256 => Asset) public assets;
    mapping(uint256 => mapping(address => uint256)) public fractionBalances;
    mapping(uint256 => mapping(address => RedemptionRequest)) public redemptionRequests;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert AssetFractionalizer__NotOperator();
        _;
    }

    modifier onlyRegisteredAsset(uint256 assetId) {
        if (!assets[assetId].registered) revert AssetFractionalizer__AssetNotRegistered(assetId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator, address _feeRecipient) Ownable(msg.sender) {
        if (_operator == address(0) || _feeRecipient == address(0)) {
            revert AssetFractionalizer__ZeroAddress();
        }
        operator = _operator;
        feeRecipient = _feeRecipient;
        redemptionFeeBps = DEFAULT_REDEMPTION_FEE_BPS;
        nextAssetId = 1;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit RedemptionFeeUpdated(0, DEFAULT_REDEMPTION_FEE_BPS);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function registerAsset(
        address wrappedToken,
        uint256 fractionsPerUnit,
        string calldata metadataURI
    ) external onlyOperator returns (uint256 assetId) {
        if (wrappedToken == address(0)) revert AssetFractionalizer__ZeroAddress();
        if (fractionsPerUnit == 0) revert AssetFractionalizer__ZeroAmount();

        assetId = nextAssetId++;
        if (assets[assetId].registered) revert AssetFractionalizer__AssetAlreadyRegistered(assetId);

        assets[assetId] = Asset({
            wrappedToken: wrappedToken,
            totalFractions: 0,
            fractionsPerUnit: fractionsPerUnit,
            registered: true,
            metadataURI: metadataURI
        });

        emit AssetRegistered(assetId, wrappedToken, fractionsPerUnit, metadataURI);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert AssetFractionalizer__ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert AssetFractionalizer__ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_REDEMPTION_FEE_BPS) {
            revert AssetFractionalizer__FeeTooHigh(newFeeBps, MAX_REDEMPTION_FEE_BPS);
        }
        emit RedemptionFeeUpdated(redemptionFeeBps, newFeeBps);
        redemptionFeeBps = newFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                          FRACTIONALIZATION
    //////////////////////////////////////////////////////////////*/

    function fractionalize(
        uint256 assetId,
        uint256 amount,
        address recipient
    ) external onlyRegisteredAsset(assetId) returns (uint256 fractionsMinted) {
        if (amount == 0) revert AssetFractionalizer__ZeroAmount();
        if (recipient == address(0)) revert AssetFractionalizer__ZeroAddress();

        Asset storage asset = assets[assetId];

        // Checks-effects-interactions: update state before pulling tokens.
        fractionsMinted = amount * asset.fractionsPerUnit;
        asset.totalFractions += fractionsMinted;
        fractionBalances[assetId][recipient] += fractionsMinted;

        IERC20(asset.wrappedToken).safeTransferFrom(msg.sender, address(this), amount);

        emit AssetFractionalized(assetId, msg.sender, recipient, amount, fractionsMinted);
    }

    /*//////////////////////////////////////////////////////////////
                          FRACTION TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function transferFractions(
        uint256 assetId,
        address to,
        uint256 amount
    ) external onlyRegisteredAsset(assetId) {
        if (amount == 0) revert AssetFractionalizer__ZeroAmount();
        if (to == address(0)) revert AssetFractionalizer__ZeroAddress();

        uint256 senderBalance = fractionBalances[assetId][msg.sender];
        if (senderBalance < amount) {
            revert AssetFractionalizer__InsufficientFractions(senderBalance, amount);
        }

        fractionBalances[assetId][msg.sender] = senderBalance - amount;
        fractionBalances[assetId][to] += amount;

        emit FractionsTransferred(assetId, msg.sender, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            REDEMPTION FLOW
    //////////////////////////////////////////////////////////////*/

    function requestRedemption(uint256 assetId, uint256 fractionAmount)
        external
        onlyRegisteredAsset(assetId)
    {
        if (fractionAmount < MIN_REDEMPTION_FRACTIONS) {
            revert AssetFractionalizer__BelowMinRedemption(fractionAmount, MIN_REDEMPTION_FRACTIONS);
        }

        uint256 senderBalance = fractionBalances[assetId][msg.sender];
        if (senderBalance < fractionAmount) {
            revert AssetFractionalizer__InsufficientFractions(senderBalance, fractionAmount);
        }

        Asset storage asset = assets[assetId];

        uint256 wrappedAmount = fractionAmount / asset.fractionsPerUnit;
        if (wrappedAmount == 0) revert AssetFractionalizer__ZeroAmount();

        // Compute the fee directly from the fraction amount so the multiplication
        // precedes the (single) division. This avoids the precision loss of
        // divide-before-multiply that would occur if we reused the floored
        // `wrappedAmount` to scale the fee. Mathematically equivalent (in exact
        // arithmetic) to `(fractionAmount / fractionsPerUnit) * redemptionFeeBps /
        // BPS_DENOMINATOR`, but with reduced rounding error.
        uint256 fee = (fractionAmount * redemptionFeeBps) / (BPS_DENOMINATOR * asset.fractionsPerUnit);

        // Lock the fractions by deducting them from the caller's balance.
        fractionBalances[assetId][msg.sender] = senderBalance - fractionAmount;

        RedemptionRequest storage request = redemptionRequests[assetId][msg.sender];
        request.fractionAmount = fractionAmount;
        request.wrappedAmount = wrappedAmount;
        request.fee = fee;
        request.active = true;

        emit RedemptionRequested(assetId, msg.sender, fractionAmount, wrappedAmount, fee);
    }

    function cancelRedemption(uint256 assetId) external onlyRegisteredAsset(assetId) {
        RedemptionRequest storage request = redemptionRequests[assetId][msg.sender];
        if (!request.active) revert AssetFractionalizer__NoActiveRedemption(assetId, msg.sender);

        uint256 fractionAmount = request.fractionAmount;

        // Return locked fractions.
        fractionBalances[assetId][msg.sender] += fractionAmount;

        // Clear the request.
        request.fractionAmount = 0;
        request.wrappedAmount = 0;
        request.fee = 0;
        request.active = false;

        emit RedemptionCancelled(assetId, msg.sender, fractionAmount);
    }

    function fulfillRedemption(uint256 assetId) external onlyRegisteredAsset(assetId) {
        RedemptionRequest storage request = redemptionRequests[assetId][msg.sender];
        if (!request.active) revert AssetFractionalizer__NoActiveRedemption(assetId, msg.sender);

        uint256 wrappedAmount = request.wrappedAmount;
        uint256 fee = request.fee;
        uint256 fractionAmount = request.fractionAmount;

        Asset storage asset = assets[assetId];

        // Reduce total fraction supply.
        asset.totalFractions -= fractionAmount;

        // Clear the request before external transfers (checks-effects-interactions).
        request.fractionAmount = 0;
        request.wrappedAmount = 0;
        request.fee = 0;
        request.active = false;

        IERC20 wrapped = IERC20(asset.wrappedToken);

        // The redeemer receives the wrapped amount net of the fee; the fee is sent
        // to the fee recipient. The combined outflow equals `wrappedAmount`, which
        // is exactly the amount of wrapped tokens the contract holds for these
        // fractions, so no over-transfer occurs. `fee` is always <= `wrappedAmount`
        // because `redemptionFeeBps < BPS_DENOMINATOR`.
        uint256 amountToRedeemer = wrappedAmount - fee;
        wrapped.safeTransfer(msg.sender, amountToRedeemer);

        if (fee > 0) {
            wrapped.safeTransfer(feeRecipient, fee);
        }

        emit RedemptionFulfilled(assetId, msg.sender, wrappedAmount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAsset(uint256 assetId) external view returns (Asset memory) {
        return assets[assetId];
    }

    function getFractionBalance(uint256 assetId, address account) external view returns (uint256) {
        return fractionBalances[assetId][account];
    }

    function getRedemptionRequest(uint256 assetId, address account)
        external
        view
        returns (RedemptionRequest memory)
    {
        return redemptionRequests[assetId][account];
    }

    function computeFee(uint256 wrappedAmount) external view returns (uint256) {
        return (wrappedAmount * redemptionFeeBps) / BPS_DENOMINATOR;
    }

    function fractionsForAmount(uint256 assetId, uint256 amount)
        external
        view
        onlyRegisteredAsset(assetId)
        returns (uint256)
    {
        return amount * assets[assetId].fractionsPerUnit;
    }

    function isAssetRegistered(uint256 assetId) external view returns (bool) {
        return assets[assetId].registered;
    }
}
