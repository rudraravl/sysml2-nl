// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Permissionless Price Reporting System
/// @notice A permissionless oracle where any user can report or dispute prices for asset pairs
///         by bonding a specified amount of two custodied ERC20 tokens. There are no privileged
///         roles: anyone may propose a new price (bonding at least 100 units of each token) or
///         dispute an existing price (bonding at least 10% more of each token than the current bond).
contract PermissionlessPriceReporter {
    //---------------------------------------------------------------------------
    // Constants
    //---------------------------------------------------------------------------

    /// @notice Minimum bond (in raw token units) required for a new price proposal.
    uint256 public constant MINIMUM_BOND = 100;

    /// @notice A dispute bond must be at least this many percent larger than the current bond.
    uint256 public constant DISPUTE_BOND_PREMIUM_PERCENT = 10;

    //---------------------------------------------------------------------------
    // Storage
    //---------------------------------------------------------------------------

    /// @notice First bonding token custodied by the contract.
    IERC20 public immutable token0;

    /// @notice Second bonding token custodied by the contract.
    IERC20 public immutable token1;

    /// @param price       The reported price for the asset pair.
    /// @param bondAmount   Amount of *each* bonding token locked by the current reporter.
    /// @param reporter     Address that posted the current bond and price.
    /// @param lastUpdate   Block timestamp of the most recent price update for this pair.
    /// @param active       Whether this pair has an active (non-disputed-away) report.
    struct Report {
        uint256 price;
        uint256 bondAmount;
        address reporter;
        uint32 lastUpdate;
        bool active;
    }

    /// @dev Maps an asset-pair identifier to its current price report.
    mapping(bytes32 => Report) public reports;

    //---------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------

    /// @notice Emitted when a new price is proposed for a pair.
    /// @param pairId     Identifier of the asset pair.
    /// @param reporter   Address that posted the bond and price.
    /// @param price      The proposed price.
    /// @param bondAmount Amount of each bonding token locked.
    /// @param timestamp  Block timestamp of the proposal.
    event PriceProposed(
        bytes32 indexed pairId,
        address indexed reporter,
        uint256 price,
        uint256 bondAmount,
        uint32 timestamp
    );

    /// @notice Emitted when an existing price is disputed and replaced.
    /// @param pairId    Identifier of the asset pair.
    /// @param disputer  Address that posted the dispute bond.
    /// @param oldPrice   Previous price that was disputed.
    /// @param newPrice   The new price set by the disputer.
    /// @param oldBond     Previous bond amount.
    /// @param newBond     New bond amount posted by the disputer.
    /// @param timestamp   Block timestamp of the dispute.
    event PriceDisputed(
        bytes32 indexed pairId,
        address indexed disputer,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 oldBond,
        uint256 newBond,
        uint32 timestamp
    );

    //---------------------------------------------------------------------------
    // Errors
    //---------------------------------------------------------------------------

    error PairAlreadyActive();
    error PairNotActive();
    error BondBelowMinimum();
    error DisputeBondTooSmall();
    error ZeroAddress();
    error IdenticalTokens();
    error TransferFailed();

    //---------------------------------------------------------------------------
    // Constructor
    //---------------------------------------------------------------------------

    /// @param _token0 Address of the first bonding token.
    /// @param _token1 Address of the second bonding token.
    constructor(address _token0, address _token1) {
        if (_token0 == address(0)) revert ZeroAddress();
        if (_token1 == address(0)) revert ZeroAddress();
        if (_token0 == _token1) revert IdenticalTokens();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    //---------------------------------------------------------------------------
    // Public Functions
    //---------------------------------------------------------------------------

    /// @notice Propose a new price for an asset pair by bonding tokens.
    /// @dev    Requires that no active report exists for the pair. The caller must have approved
    ///         the contract to transfer `bondAmount` of both token0 and token1.
    /// @param  pairId     Identifier for the asset pair being reported.
    /// @param  price      The proposed price.
    /// @param  bondAmount Amount of each bonding token to lock (must be >= 100).
    /// @return success    True if the proposal was accepted.
    function propose(bytes32 pairId, uint256 price, uint256 bondAmount) external returns (bool) {
        if (reports[pairId].active) revert PairAlreadyActive();
        if (bondAmount < MINIMUM_BOND) revert BondBelowMinimum();

        // ---- effects ----
        reports[pairId] = Report({
            price: price,
            bondAmount: bondAmount,
            reporter: msg.sender,
            lastUpdate: uint32(block.timestamp),
            active: true
        });

        // ---- interactions ----
        _safeTransferFrom(token0, msg.sender, address(this), bondAmount);
        _safeTransferFrom(token1, msg.sender, address(this), bondAmount);

        emit PriceProposed(pairId, msg.sender, price, bondAmount, uint32(block.timestamp));
        return true;
    }

    /// @notice Dispute an existing price by bonding a larger amount at a new price.
    /// @dev    The dispute bond must be at least 10% larger than the current bond. The caller
    ///         must have approved the contract to transfer `newBondAmount` of both token0 and token1.
    /// @param  pairId       Identifier for the asset pair being disputed.
    /// @param  newPrice     The new proposed price.
    /// @param  newBondAmount Amount of each bonding token to lock for the dispute.
    /// @return success      True if the dispute was accepted.
    function dispute(bytes32 pairId, uint256 newPrice, uint256 newBondAmount) external returns (bool) {
        Report storage r = reports[pairId];
        if (!r.active) revert PairNotActive();

        // Minimum dispute bond = current bond + 10% of current bond.
        uint256 minBond = r.bondAmount + (r.bondAmount * DISPUTE_BOND_PREMIUM_PERCENT) / 100;
        if (newBondAmount < minBond) revert DisputeBondTooSmall();

        // ---- effects ----
        uint256 oldPrice = r.price;
        uint256 oldBond = r.bondAmount;

        r.price = newPrice;
        r.bondAmount = newBondAmount;
        r.reporter = msg.sender;
        r.lastUpdate = uint32(block.timestamp);

        // ---- interactions ----
        _safeTransferFrom(token0, msg.sender, address(this), newBondAmount);
        _safeTransferFrom(token1, msg.sender, address(this), newBondAmount);

        emit PriceDisputed(
            pairId,
            msg.sender,
            oldPrice,
            newPrice,
            oldBond,
            newBondAmount,
            uint32(block.timestamp)
        );
        return true;
    }

    //---------------------------------------------------------------------------
    // View Functions
    //---------------------------------------------------------------------------

    /// @notice Retrieves the full report for a given asset pair.
    /// @param  pairId      Identifier for the asset pair.
    /// @return price       The reported price.
    /// @return bondAmount  The amount of each token bonded.
    /// @return reporter    The address of the current reporter.
    /// @return lastUpdate  The timestamp of the last update.
    /// @return active       Whether the report is active.
    function getReport(bytes32 pairId)
        external
        view
        returns (uint256 price, uint256 bondAmount, address reporter, uint32 lastUpdate, bool active)
    {
        Report storage r = reports[pairId];
        return (r.price, r.bondAmount, r.reporter, r.lastUpdate, r.active);
    }

    /// @notice Returns the total balances of both bonding tokens held by the contract.
    /// @return balance0 Balance of token0 held by the contract.
    /// @return balance1 Balance of token1 held by the contract.
    function totalBonded() external view returns (uint256 balance0, uint256 balance1) {
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
    }

    //---------------------------------------------------------------------------
    // Internal Helpers
    //---------------------------------------------------------------------------

    /// @dev Safely transfers tokens from `from` to `to`. Handles both reverting and
    ///      boolean-returning ERC20 implementations exactly once.
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
