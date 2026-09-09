// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CollectibleCardGame {
    /* ─────────────────────────────────────────────────────────────
                           CUSTOM ERRORS
    ────────────────────────────────────────────────────────────── */
    error NotOperator();
    error NotOwnerNorApproved();
    error ZeroAddress();
    error CardDoesNotExist();
    error InsufficientCurrency();
    error InsufficientAllowance();
    error PackLimitExceeded();
    error NoCardTypes();
    error InvalidAmount();
    error CardTypeNotFound();
    error SelfTransfer();
    error EmptyName();
    error InvalidWeight();
    error NotCardOwner();

    /* ─────────────────────────────────────────────────────────────
                              EVENTS
    ────────────────────────────────────────────────────────────── */
    event CardTransfer(address indexed from, address indexed to, uint256 indexed cardId);
    event CardApproval(address indexed owner, address indexed approved, uint256 indexed cardId);
    event OperatorApproval(address indexed owner, address indexed operator, bool approved);
    event CardPackPurchased(address indexed buyer, uint256 packCount, uint256 totalPrice, uint256[] cardIds);
    event CardPackPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event CardPackSizeUpdated(uint256 oldSize, uint256 newSize);
    event GenerationRateUpdated(uint256 oldRate, uint256 newRate);
    event CardTypeCreated(uint256 indexed typeId, string name, uint256 redemptionValue, uint256 weight);
    event CardTypeWeightUpdated(uint256 indexed typeId, uint256 oldWeight, uint256 newWeight);
    event CardMinted(address indexed to, uint256 indexed cardId, uint256 indexed typeId);
    event CardRedeemed(address indexed owner, uint256 indexed cardId, uint256 value);
    event CurrencyTransfer(address indexed from, address indexed to, uint256 amount);
    event CurrencyMinted(address indexed to, uint256 amount);
    event CurrencyBurned(address indexed from, uint256 amount);
    event CurrencyApproval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

    /* ─────────────────────────────────────────────────────────────
                            CONSTANTS
    ────────────────────────────────────────────────────────────── */
    uint256 public constant MAX_PACKS_PER_TX = 10;
    uint256 public constant TRADE_FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;

    /* ─────────────────────────────────────────────────────────────
                       CARD TYPE DEFINITION
    ────────────────────────────────────────────────────────────── */
    struct CardType {
        string name;
        uint256 redemptionValue;
        uint256 weight;
        bool exists;
    }

    /* ─────────────────────────────────────────────────────────────
                          STATE VARIABLES
    ────────────────────────────────────────────────────────────── */

    // Admin
    address public operator;
    address public treasury;

    // Card types
    CardType[] public cardTypes;
    uint256 public totalWeight;

    // Pack configuration
    uint256 public cardPackPrice;
    uint256 public cardPackSize;
    uint256 public generationRate; // multiplier in basis points (10000 = 1x)

    // In-game currency (ERC20-like internal ledger)
    mapping(address => uint256) public currencyBalanceOf;
    mapping(address => mapping(address => uint256)) internal _currencyAllowance;
    uint256 public totalCurrencySupply;

    // Cards (ERC721-like ownership)
    mapping(uint256 => address) internal _cardOwner;
    mapping(uint256 => uint256) public cardTypeIdOf;
    mapping(uint256 => address) internal _cardApproved;
    mapping(address => mapping(address => bool)) internal _cardOperatorApproval;
    mapping(address => uint256) public cardBalanceOf;
    uint256 public totalCards;
    uint256 internal _nextCardId = 1;

    /* ─────────────────────────────────────────────────────────────
                            MODIFIERS
    ────────────────────────────────────────────────────────────── */
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /* ─────────────────────────────────────────────────────────────
                            CONSTRUCTOR
    ────────────────────────────────────────────────────────────── */
    constructor(uint256 _cardPackPrice, uint256 _cardPackSize, address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_cardPackSize == 0) revert InvalidAmount();
        cardPackPrice = _cardPackPrice;
        cardPackSize = _cardPackSize;
        generationRate = BPS_DENOMINATOR; // 1x by default
        operator = msg.sender;
        treasury = _treasury;
    }

    /* ─────────────────────────────────────────────────────────────
                      CARD TYPE MANAGEMENT
    ────────────────────────────────────────────────────────────── */

    /// @notice Create a new card type that can be minted or drawn from packs.
    function createCardType(
        string calldata _name,
        uint256 _redemptionValue,
        uint256 _weight
    ) external onlyOperator returns (uint256 typeId) {
        if (bytes(_name).length == 0) revert EmptyName();
        if (_weight == 0) revert InvalidWeight();
        typeId = cardTypes.length;
        cardTypes.push(
            CardType({name: _name, redemptionValue: _redemptionValue, weight: _weight, exists: true})
        );
        totalWeight += _weight;
        emit CardTypeCreated(typeId, _name, _redemptionValue, _weight);
    }

    /// @notice Update the generation weight of an existing card type.
    function updateCardTypeWeight(uint256 _typeId, uint256 _newWeight) external onlyOperator {
        if (_typeId >= cardTypes.length || !cardTypes[_typeId].exists) revert CardTypeNotFound();
        if (_newWeight == 0) revert InvalidWeight();
        uint256 oldWeight = cardTypes[_typeId].weight;
        totalWeight = totalWeight - oldWeight + _newWeight;
        cardTypes[_typeId].weight = _newWeight;
        emit CardTypeWeightUpdated(_typeId, oldWeight, _newWeight);
    }

    /// @notice Update the redemption value of an existing card type.
    function updateCardTypeRedemptionValue(uint256 _typeId, uint256 _newValue) external onlyOperator {
        if (_typeId >= cardTypes.length || !cardTypes[_typeId].exists) revert CardTypeNotFound();
        cardTypes[_typeId].redemptionValue = _newValue;
    }

    function cardTypeCount() external view returns (uint256) {
        return cardTypes.length;
    }

    function getCardType(uint256 _typeId)
        external
        view
        returns (string memory _name, uint256 _redemptionValue, uint256 _weight, bool _exists)
    {
        if (_typeId >= cardTypes.length) revert CardTypeNotFound();
        CardType storage ct = cardTypes[_typeId];
        return (ct.name, ct.redemptionValue, ct.weight, ct.exists);
    }

    /* ─────────────────────────────────────────────────────────────
                       CURRENCY (IN-GAME)
    ────────────────────────────────────────────────────────────── */

    function currencyAllowanceOf(address _owner, address _spender) external view returns (uint256) {
        return _currencyAllowance[_owner][_spender];
    }

    function approveCurrency(address _spender, uint256 _amount) external returns (bool) {
        if (_spender == address(0)) revert ZeroAddress();
        _currencyAllowance[msg.sender][_spender] = _amount;
        emit CurrencyApproval(msg.sender, _spender, _amount);
        return true;
    }

    function transferCurrency(address _to, uint256 _amount) external returns (bool) {
        if (_to == address(0)) revert ZeroAddress();
        if (currencyBalanceOf[msg.sender] < _amount) revert InsufficientCurrency();
        currencyBalanceOf[msg.sender] -= _amount;
        currencyBalanceOf[_to] += _amount;
        emit CurrencyTransfer(msg.sender, _to, _amount);
        return true;
    }

    function transferCurrencyFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        if (_to == address(0)) revert ZeroAddress();
        if (currencyBalanceOf[_from] < _amount) revert InsufficientCurrency();
        if (_currencyAllowance[_from][msg.sender] < _amount) revert InsufficientAllowance();
        _currencyAllowance[_from][msg.sender] -= _amount;
        currencyBalanceOf[_from] -= _amount;
        currencyBalanceOf[_to] += _amount;
        emit CurrencyTransfer(_from, _to, _amount);
        return true;
    }

    function mintCurrency(address _to, uint256 _amount) external onlyOperator returns (bool) {
        if (_to == address(0)) revert ZeroAddress();
        currencyBalanceOf[_to] += _amount;
        totalCurrencySupply += _amount;
        emit CurrencyMinted(_to, _amount);
        return true;
    }

    function burnCurrency(address _from, uint256 _amount) external onlyOperator returns (bool) {
        if (currencyBalanceOf[_from] < _amount) revert InsufficientCurrency();
        currencyBalanceOf[_from] -= _amount;
        totalCurrencySupply -= _amount;
        emit CurrencyBurned(_from, _amount);
        return true;
    }

    /* ─────────────────────────────────────────────────────────────
                    CARD OWNERSHIP (ERC721-LIKE)
    ────────────────────────────────────────────────────────────── */

    function _exists(uint256 _cardId) internal view returns (bool) {
        return _cardOwner[_cardId] != address(0);
    }

    function ownerOf(uint256 _cardId) public view returns (address) {
        address owner = _cardOwner[_cardId];
        if (owner == address(0)) revert CardDoesNotExist();
        return owner;
    }

    function getApproved(uint256 _cardId) public view returns (address) {
        if (!_exists(_cardId)) revert CardDoesNotExist();
        return _cardApproved[_cardId];
    }

    function isApprovedForAll(address _owner, address _operator) public view returns (bool) {
        return _cardOperatorApproval[_owner][_operator];
    }

    function _isApprovedOrOwner(address _spender, uint256 _cardId) internal view returns (bool) {
        address owner = _cardOwner[_cardId];
        if (owner == address(0)) revert CardDoesNotExist();
        return (
            _spender == owner ||
            _cardApproved[_cardId] == _spender ||
            _cardOperatorApproval[owner][_spender]
        );
    }

    function _approve(address _owner, address _approved, uint256 _cardId) internal {
        _cardApproved[_cardId] = _approved;
        emit CardApproval(_owner, _approved, _cardId);
    }

    function approveCard(address _approved, uint256 _cardId) external returns (bool) {
        address owner = ownerOf(_cardId);
        if (msg.sender != owner && !_cardOperatorApproval[owner][msg.sender]) {
            revert NotOwnerNorApproved();
        }
        _approve(owner, _approved, _cardId);
        return true;
    }

    function setApprovalForAll(address _operator, bool _approved) external returns (bool) {
        if (_operator == address(0)) revert ZeroAddress();
        _cardOperatorApproval[msg.sender][_operator] = _approved;
        emit OperatorApproval(msg.sender, _operator, _approved);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _cardId) internal {
        _cardApproved[_cardId] = address(0);
        emit CardApproval(_from, address(0), _cardId);

        cardBalanceOf[_from] -= 1;
        cardBalanceOf[_to] += 1;
        _cardOwner[_cardId] = _to;

        emit CardTransfer(_from, _to, _cardId);
    }

    /* ─────────────────────────────────────────────────────────────
                    CARD TRANSFER (WITH 2% TRADE FEE)
    ────────────────────────────────────────────────────────────── */

    /// @notice Transfer a card to another player. A 2% fee based on the
    ///         card type's redemption value is charged in in-game currency.
    function transferCard(address _to, uint256 _cardId) external returns (bool) {
        if (_to == address(0)) revert ZeroAddress();
        if (msg.sender == _to) revert SelfTransfer();
        if (!_isApprovedOrOwner(msg.sender, _cardId)) revert NotOwnerNorApproved();

        address owner = _cardOwner[_cardId];
        uint256 typeId = cardTypeIdOf[_cardId];
        uint256 baseValue = cardTypes[typeId].redemptionValue;
        uint256 fee = (baseValue * TRADE_FEE_BPS) / BPS_DENOMINATOR;

        if (currencyBalanceOf[msg.sender] < fee) revert InsufficientCurrency();

        // Effects
        _transfer(owner, _to, _cardId);

        if (fee > 0) {
            currencyBalanceOf[msg.sender] -= fee;
            currencyBalanceOf[treasury] += fee;
            emit CurrencyTransfer(msg.sender, treasury, fee);
        }

        return true;
    }

    /// @notice Transfer a card on behalf of its owner (requires approval).
    function transferCardFrom(address _from, address _to, uint256 _cardId) external returns (bool) {
        if (_to == address(0)) revert ZeroAddress();
        if (_from == _to) revert SelfTransfer();
        if (!_isApprovedOrOwner(msg.sender, _cardId)) revert NotOwnerNorApproved();
        if (_cardOwner[_cardId] != _from) revert NotCardOwner();

        uint256 typeId = cardTypeIdOf[_cardId];
        uint256 baseValue = cardTypes[typeId].redemptionValue;
        uint256 fee = (baseValue * TRADE_FEE_BPS) / BPS_DENOMINATOR;

        if (currencyBalanceOf[msg.sender] < fee) revert InsufficientCurrency();

        _transfer(_from, _to, _cardId);

        if (fee > 0) {
            currencyBalanceOf[msg.sender] -= fee;
            currencyBalanceOf[treasury] += fee;
            emit CurrencyTransfer(msg.sender, treasury, fee);
        }

        return true;
    }

    /* ─────────────────────────────────────────────────────────────
                        CARD MINTING
    ────────────────────────────────────────────────────────────── */

    function _mintCard(address _to, uint256 _typeId) internal returns (uint256 cardId) {
        if (_typeId >= cardTypes.length || !cardTypes[_typeId].exists) revert CardTypeNotFound();
        cardId = _nextCardId++;
        _cardOwner[cardId] = _to;
        cardTypeIdOf[cardId] = _typeId;
        cardBalanceOf[_to] += 1;
        totalCards += 1;
        emit CardTransfer(address(0), _to, cardId);
        emit CardMinted(_to, cardId, _typeId);
    }

    /// @notice Operator-only: mint a specific card type to a player.
    function mintCard(address _to, uint256 _typeId) external onlyOperator returns (uint256) {
        if (_to == address(0)) revert ZeroAddress();
        return _mintCard(_to, _typeId);
    }

    /* ─────────────────────────────────────────────────────────────
                  WEIGHTED RANDOM CARD TYPE SELECTION
    ────────────────────────────────────────────────────────────── */

    function _drawCardType(uint256 _salt) internal returns (uint256) {
        uint256 len = cardTypes.length;
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    _nextCardId,
                    _salt
                )
            )
        );
        uint256 weightedRandom = random % totalWeight;
        uint256 cumulative = 0;
        for (uint256 i = 0; i < len; i++) {
            cumulative += cardTypes[i].weight;
            if (weightedRandom < cumulative) {
                return i;
            }
        }
        return len - 1;
    }

    /* ─────────────────────────────────────────────────────────────
                       PACK PURCHASE
    ────────────────────────────────────────────────────────────── */

    /// @notice Purchase card packs using in-game currency. Each pack
    ///         contains `cardPackSize` randomly drawn cards. Maximum
    ///         10 packs per transaction.
    function buyCardPacks(uint256 _count) external returns (uint256[] memory mintedCardIds) {
        if (_count == 0 || _count > MAX_PACKS_PER_TX) revert PackLimitExceeded();
        if (cardTypes.length == 0 || totalWeight == 0) revert NoCardTypes();

        uint256 totalPrice = cardPackPrice * _count;
        if (currencyBalanceOf[msg.sender] < totalPrice) revert InsufficientCurrency();

        uint256 totalToMint = cardPackSize * _count;
        mintedCardIds = new uint256[](totalToMint);

        // Effects: deduct currency before minting
        currencyBalanceOf[msg.sender] -= totalPrice;
        currencyBalanceOf[treasury] += totalPrice;

        uint256 idx;
        for (uint256 p = 0; p < _count; p++) {
            for (uint256 c = 0; c < cardPackSize; c++) {
                uint256 typeId = _drawCardType(p * 7919 + c * 31 + 1);
                uint256 cardId = _mintCard(msg.sender, typeId);
                mintedCardIds[idx] = cardId;
                unchecked {
                    ++idx;
                }
            }
        }

        emit CardPackPurchased(msg.sender, _count, totalPrice, mintedCardIds);
        emit CurrencyTransfer(msg.sender, treasury, totalPrice);
    }

    /* ─────────────────────────────────────────────────────────────
                       CARD REDEMPTION
    ────────────────────────────────────────────────────────────── */

    /// @notice Burn a card and receive its redemption value in currency,
    ///         scaled by the current generation rate.
    function redeemCard(uint256 _cardId) external returns (uint256 value) {
        address owner = _cardOwner[_cardId];
        if (owner == address(0)) revert CardDoesNotExist();
        if (owner != msg.sender) revert NotCardOwner();

        uint256 typeId = cardTypeIdOf[_cardId];
        if (typeId >= cardTypes.length || !cardTypes[typeId].exists) revert CardTypeNotFound();

        value = (cardTypes[typeId].redemptionValue * generationRate) / BPS_DENOMINATOR;

        // Burn the card
        _cardApproved[_cardId] = address(0);
        cardBalanceOf[owner] -= 1;
        delete _cardOwner[_cardId];
        delete cardTypeIdOf[_cardId];
        totalCards -= 1;

        // Mint currency to the redeemer
        currencyBalanceOf[owner] += value;
        totalCurrencySupply += value;

        emit CardTransfer(owner, address(0), _cardId);
        emit CardRedeemed(owner, _cardId, value);
        emit CurrencyMinted(owner, value);
    }

    /* ─────────────────────────────────────────────────────────────
                       ADMIN / OPERATOR FUNCTIONS
    ────────────────────────────────────────────────────────────── */

    function setCardPackPrice(uint256 _newPrice) external onlyOperator {
        uint256 old = cardPackPrice;
        cardPackPrice = _newPrice;
        emit CardPackPriceUpdated(old, _newPrice);
    }

    function setCardPackSize(uint256 _newSize) external onlyOperator {
        if (_newSize == 0) revert InvalidAmount();
        uint256 old = cardPackSize;
        cardPackSize = _newSize;
        emit CardPackSizeUpdated(old, _newSize);
    }

    function setGenerationRate(uint256 _newRate) external onlyOperator {
        uint256 old = generationRate;
        generationRate = _newRate;
        emit GenerationRateUpdated(old, _newRate);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _newOperator);
        operator = _newOperator;
    }

    function setTreasury(address _newTreasury) external onlyOperator {
        if (_newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, _newTreasury);
        treasury = _newTreasury;
    }

    /* ─────────────────────────────────────────────────────────────
                       VIEW FUNCTIONS
    ────────────────────────────────────────────────────────────── */

    function cardPackInfo() external view returns (uint256 price, uint256 size) {
        return (cardPackPrice, cardPackSize);
    }

    function getCardInfo(uint256 _cardId)
        external
        view
        returns (address owner, uint256 typeId, uint256 redemptionValue, string memory name)
    {
        owner = _cardOwner[_cardId];
        if (owner == address(0)) revert CardDoesNotExist();
        typeId = cardTypeIdOf[_cardId];
        CardType storage ct = cardTypes[typeId];
        redemptionValue = ct.redemptionValue;
        name = ct.name;
    }

    function getCurrencyBalance(address _player) external view returns (uint256) {
        return currencyBalanceOf[_player];
    }

    function getCardBalance(address _player) external view returns (uint256) {
        return cardBalanceOf[_player];
    }
}
