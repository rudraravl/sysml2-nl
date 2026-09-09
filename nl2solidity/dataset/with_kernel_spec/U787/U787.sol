// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GameAssetManager {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error ZeroAddress();
    error AssetNotOwned();
    error AssetDoesNotExist();
    error MaxSupplyReached();
    error InsufficientUtilityTokens();
    error InvalidAmount();
    error SelfTransfer();
    error InvalidPower();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AssetTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed assetId,
        uint256 feePaid
    );
    event AssetMinted(address indexed to, uint256 indexed assetId, uint256 power);
    event AssetBurned(address indexed from, uint256 indexed assetId);
    event UtilityTokenBalanceChanged(
        address indexed player,
        uint256 newBalance,
        bool isCredit
    );
    event UtilityTokensMinted(address indexed to, uint256 amount);
    event EmissionRateUpdated(uint256 oldRate, uint256 newRate);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Character {
        uint256 id;
        uint256 power;
        uint256 mintedAt;
    }

    /*//////////////////////////////////////////////////////////////
                          ACCESS CONTROL STATE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;
    address public treasury;

    /*//////////////////////////////////////////////////////////////
                       UNIQUE DIGITAL ASSET STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public totalAssets;
    uint256 private _nextAssetId;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public assetBalanceOf;
    mapping(uint256 => Character) public characters;

    /*//////////////////////////////////////////////////////////////
                        UTILITY TOKEN STATE
    //////////////////////////////////////////////////////////////*/
    string public constant UTILITY_TOKEN_NAME = "Game Utility Token";
    string public constant UTILITY_TOKEN_SYMBOL = "GUT";
    uint8 public constant DECIMALS = 18;

    uint256 public totalUtilitySupply;
    mapping(address => uint256) public utilityBalanceOf;

    /// @dev Utility tokens emitted to a player when a new asset is minted/acquired.
    uint256 public emissionRate;
    /// @dev Utility tokens required for a player to acquire a new asset.
    uint256 public mintPrice;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _treasury,
        uint256 _emissionRate,
        uint256 _mintPrice
    ) {
        if (_treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = msg.sender;
        treasury = _treasury;
        emissionRate = _emissionRate;
        mintPrice = _mintPrice;
        _nextAssetId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
    }

    /*//////////////////////////////////////////////////////////////
                      ADMINISTRATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setEmissionRate(uint256 newRate) external onlyOperator {
        emit EmissionRateUpdated(emissionRate, newRate);
        emissionRate = newRate;
    }

    function setMintPrice(uint256 newPrice) external onlyOperator {
        emit MintPriceUpdated(mintPrice, newPrice);
        mintPrice = newPrice;
    }

    /*//////////////////////////////////////////////////////////////
                    UTILITY TOKEN INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function _mintUtility(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        unchecked {
            totalUtilitySupply += amount;
            utilityBalanceOf[to] += amount;
        }
        emit UtilityTokenBalanceChanged(to, utilityBalanceOf[to], true);
    }

    function _burnUtility(address from, uint256 amount) internal {
        if (utilityBalanceOf[from] < amount) revert InsufficientUtilityTokens();
        unchecked {
            utilityBalanceOf[from] -= amount;
            totalUtilitySupply -= amount;
        }
        emit UtilityTokenBalanceChanged(from, utilityBalanceOf[from], false);
    }

    function _transferUtility(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (utilityBalanceOf[from] < amount) revert InsufficientUtilityTokens();
        unchecked {
            utilityBalanceOf[from] -= amount;
            utilityBalanceOf[to] += amount;
        }
        emit UtilityTokenBalanceChanged(from, utilityBalanceOf[from], false);
        emit UtilityTokenBalanceChanged(to, utilityBalanceOf[to], true);
    }

    /*//////////////////////////////////////////////////////////////
                  UNIQUE DIGITAL ASSET INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function _mintAsset(address to, uint256 power)
        internal
        returns (uint256 id)
    {
        if (totalAssets >= MAX_SUPPLY) revert MaxSupplyReached();
        id = _nextAssetId++;
        totalAssets++;
        ownerOf[id] = to;
        unchecked {
            assetBalanceOf[to]++;
        }
        characters[id] = Character({
            id: id,
            power: power,
            mintedAt: block.timestamp
        });
        emit AssetMinted(to, id, power);
    }

    function _burnAsset(uint256 id) internal {
        address currentOwner = ownerOf[id];
        if (currentOwner == address(0)) revert AssetDoesNotExist();
        unchecked {
            assetBalanceOf[currentOwner]--;
            totalAssets--;
        }
        delete ownerOf[id];
        delete characters[id];
        emit AssetBurned(currentOwner, id);
    }

    /*//////////////////////////////////////////////////////////////
                       PUBLIC PLAYER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice A player acquires a new character by paying utility tokens.
    function acquireCharacter(uint256 power) external {
        if (power == 0) revert InvalidPower();
        if (utilityBalanceOf[msg.sender] < mintPrice)
            revert InsufficientUtilityTokens();

        _burnUtility(msg.sender, mintPrice);
        _mintAsset(msg.sender, power);

        if (emissionRate > 0) {
            _mintUtility(msg.sender, emissionRate);
        }
    }

    /// @notice Operator mints a new character to a specified player.
    function mintCharacter(address to, uint256 power) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (power == 0) revert InvalidPower();
        _mintAsset(to, power);
        if (emissionRate > 0) {
            _mintUtility(to, emissionRate);
        }
    }

    /// @notice Operator burns an existing character.
    function burnCharacter(uint256 id) external onlyOperator {
        _burnAsset(id);
    }

    /// @notice Operator mints utility tokens to a specified player.
    function mintUtilityTokens(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        _mintUtility(to, amount);
        emit UtilityTokensMinted(to, amount);
    }

    /// @notice Transfer a character to another player. A 2% fee (based on
    /// character power) in utility tokens is sent to the treasury.
    function transferCharacter(address to, uint256 id) external {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert SelfTransfer();
        if (ownerOf[id] != msg.sender) revert AssetNotOwned();

        uint256 fee = (characters[id].power * 2) / 100;
        if (fee > 0) {
            _transferUtility(msg.sender, treasury, fee);
        }

        unchecked {
            assetBalanceOf[msg.sender]--;
            assetBalanceOf[to]++;
        }
        ownerOf[id] = to;

        emit AssetTransferred(msg.sender, to, id, fee);
    }

    /// @notice A player spends utility tokens for an in-game action (burned).
    function spendUtilityTokens(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        _burnUtility(msg.sender, amount);
    }

    /// @notice A player transfers utility tokens to another player.
    function transferUtilityTokens(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert SelfTransfer();
        if (amount == 0) revert InvalidAmount();
        _transferUtility(msg.sender, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getCharacter(uint256 id)
        external
        view
        returns (Character memory)
    {
        if (ownerOf[id] == address(0)) revert AssetDoesNotExist();
        return characters[id];
    }

    function nextAssetId() external view returns (uint256) {
        return _nextAssetId;
    }

    function utilityBalanceOfPlayer(address player)
        external
        view
        returns (uint256)
    {
        return utilityBalanceOf[player];
    }

    function characterOwnerOf(uint256 id) external view returns (address) {
        address currentOwner = ownerOf[id];
        if (currentOwner == address(0)) revert AssetDoesNotExist();
        return currentOwner;
    }
}
