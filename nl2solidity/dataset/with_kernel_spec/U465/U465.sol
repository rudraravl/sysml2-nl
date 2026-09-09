// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

/**
 * @title DataPaymentGateway
 * @notice Custodies user-deposited stablecoin balances and charges a global,
 *         administrator-configured fee for verifiable on-demand data requests.
 *         A designated administrator may update the data request fee and the
 *         signer address used for signature verification.
 */
contract DataPaymentGateway {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error DepositCapExceeded(uint256 attempted, uint256 cap);
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidSignature();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event DataRequested(address indexed requester, uint256 fee);
    event DataRequestFeeUpdated(uint256 oldFee, uint256 newFee);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    // ---------------------------------------------------------------------
    // Constants & immutables
    // ---------------------------------------------------------------------

    /// @notice Maximum stablecoin deposit allowed per user (10,000 tokens, assuming 18 decimals).
    uint256 public constant MAX_DEPOSIT = 10_000 * 1e18;

    /// @notice The stablecoin token used for all deposits and fee payments.
    IERC20 public immutable stablecoin;

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    /// @notice Administrator address allowed to update fee and signer.
    address public admin;

    /// @notice Address derived from the data provider's public key, used for signature verification.
    address public signer;

    /// @notice Current fee in stablecoin base units required to request data.
    uint256 public dataRequestFee;

    /// @notice Deposited stablecoin balance for each user.
    mapping(address => uint256) public balances;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /**
     * @param _stablecoin Address of the ERC20 stablecoin.
     * @param _admin Address of the administrator.
     * @param _signer Address derived from the data provider's public key.
     * @param _initialFee Initial data request fee, must be > 0.
     */
    constructor(
        address _stablecoin,
        address _admin,
        address _signer,
        uint256 _initialFee
    ) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();
        if (_signer == address(0)) revert ZeroAddress();
        if (_initialFee == 0) revert InvalidFee();

        stablecoin = IERC20(_stablecoin);
        admin = _admin;
        signer = _signer;
        dataRequestFee = _initialFee;

        emit DataRequestFeeUpdated(0, _initialFee);
        emit SignerUpdated(address(0), _signer);
    }

    // ---------------------------------------------------------------------
    // External / public functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit stablecoins into the caller's custodied balance.
     * @param amount Amount of stablecoins to deposit (must be > 0).
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 newBalance = balances[msg.sender] + amount;
        if (newBalance > MAX_DEPOSIT) {
            revert DepositCapExceeded(newBalance, MAX_DEPOSIT);
        }

        // Effects
        balances[msg.sender] = newBalance;

        // Interactions
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount, newBalance);
    }

    /**
     * @notice Withdraw stablecoins from the caller's custodied balance.
     * @param amount Amount of stablecoins to withdraw (must be > 0).
     */
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        // Effects
        unchecked {
            balances[msg.sender] = available - amount;
        }

        // Interactions
        stablecoin.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, balances[msg.sender]);
    }

    /**
     * @notice Request verifiable data by paying the current data request fee
     *         from the caller's custodied balance.
     */
    function requestData() external {
        uint256 fee = dataRequestFee;
        uint256 available = balances[msg.sender];
        if (available < fee) revert InsufficientBalance(available, fee);

        // Effects
        unchecked {
            balances[msg.sender] = available - fee;
        }

        emit DataRequested(msg.sender, fee);
    }

    /**
     * @notice Verify that a given signature over the digest was produced by
     *         the configured signer. Returns true if valid.
     * @param digest The EIP-191/EIP-712 typed-data hash that was signed.
     * @param v      Signature recovery byte.
     * @param r      Signature r component.
     * @param s      Signature s component.
     */
    function verifySignature(
        bytes32 digest,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        address recovered = ecrecover(digest, v, r, s);
        return recovered != address(0) && recovered == signer;
    }

    /**
     * @notice Returns the stablecoin balance custodied for a given user.
     * @param user The address whose balance to query.
     */
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    /**
     * @notice Update the global data request fee. Must be a positive integer.
     * @param newFee New fee per data request.
     */
    function setDataRequestFee(uint256 newFee) external onlyAdmin {
        if (newFee == 0) revert InvalidFee();
        uint256 oldFee = dataRequestFee;
        dataRequestFee = newFee;
        emit DataRequestFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Update the signer address used for signature verification.
     * @param newSigner New signer address, must not be zero.
     */
    function setSigner(address newSigner) external onlyAdmin {
        if (newSigner == address(0)) revert ZeroAddress();
        address old = signer;
        signer = newSigner;
        emit SignerUpdated(old, newSigner);
    }

    /**
     * @notice Transfer the admin role to a new address.
     * @param newAdmin Address of the new administrator.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        admin = newAdmin;
    }
}
