// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// Interfaces
// ============================================================================

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// ============================================================================
// Libraries
// ============================================================================

library EnumerableSet {
    struct UintSet {
        uint256[] _values;
        mapping(uint256 => uint256) _indexes;
    }

    function add(UintSet storage set, uint256 value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            if (toDeleteIndex != lastIndex) {
                uint256 lastValue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastValue;
                set._indexes[lastValue] = valueIndex;
            }
            set._values.pop();
            delete set._indexes[value];
            return true;
        }
        return false;
    }

    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(UintSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return set._values[index];
    }

    function values(UintSet storage set) internal view returns (uint256[] memory) {
        return set._values;
    }
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

// ============================================================================
// Access Control
// ============================================================================

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// ============================================================================
// Reentrancy Guard
// ============================================================================

abstract contract ReentrancyGuard {
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

// ============================================================================
// ERC721
// ============================================================================

abstract contract ERC721 is IERC721 {
    string private _name;
    string private _symbol;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721).interfaceId;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function balanceOf(address tokenOwner) public view virtual override returns (uint256) {
        require(tokenOwner != address(0), "ERC721: balance query for the zero address");
        return _balances[tokenOwner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: owner query for nonexistent token");
        return tokenOwner;
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");
        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address tokenOwner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        transferFrom(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner ||
                isApprovedForAll(tokenOwner, spender) ||
                getApproved(tokenId) == spender);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _tokenApprovals[tokenId] = address(0);
        emit Approval(ownerOf(tokenId), address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _burn(uint256 tokenId) internal virtual {
        address tokenOwner = ownerOf(tokenId);

        _tokenApprovals[tokenId] = address(0);
        emit Approval(tokenOwner, address(0), tokenId);

        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }
}

// ============================================================================
// ERC721 URI Storage Extension
// ============================================================================

abstract contract ERC721URIStorage is ERC721 {
    mapping(uint256 => string) internal _tokenURIs;

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI_) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = tokenURI_;
    }

    function _burn(uint256 tokenId) internal virtual override {
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
        super._burn(tokenId);
    }
}

// ============================================================================
// Crafting System
// ============================================================================

contract CraftingSystem is ERC721URIStorage, IERC721Receiver, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    //-----------------------------------------------------------------------
    // Errors
    //-----------------------------------------------------------------------
    error ErrNotOperator();
    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrLengthMismatch();
    error ErrMaxRecipesReached();
    error ErrRecipeNotFound();
    error ErrRecipeNotActive();
    error ErrRecipeAlreadyRemoved();
    error ErrInsufficientERC20(address token, uint256 required, uint256 available);
    error ErrNFTNotDeposited(address collection, uint256 tokenId);
    error ErrInsufficientFee();
    error ErrFeeTooHigh();
    error ErrInvalidRecipeRequirements();

    //-----------------------------------------------------------------------
    // Events
    //-----------------------------------------------------------------------
    event RecipeAdded(uint256 indexed recipeId, address indexed caller);
    event RecipeRemoved(uint256 indexed recipeId, address indexed caller);
    event ItemCrafted(address indexed user, uint256 indexed recipeId, uint256 indexed outputTokenId);
    event ERC20Deposited(address indexed user, address indexed token, uint256 amount);
    event NFTDeposited(address indexed user, address indexed collection, uint256 indexed tokenId);
    event ERC20Withdrawn(address indexed user, address indexed token, uint256 amount);
    event NFTWithdrawn(address indexed user, address indexed collection, uint256 indexed tokenId);
    event CraftingFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    //-----------------------------------------------------------------------
    // Structs
    //-----------------------------------------------------------------------
    struct ERC20Requirement {
        address token;
        uint256 amount;
    }

    struct NFTRequirement {
        address collection;
        uint256 tokenId;
    }

    struct Recipe {
        ERC20Requirement[] erc20Requirements;
        NFTRequirement[] nftRequirements;
        string outputURI;
        bool active;
        bool exists;
    }

    //-----------------------------------------------------------------------
    // Constants
    //-----------------------------------------------------------------------
    uint256 public constant MAX_RECIPES = 10;
    uint256 public constant MAX_FEE = 100;
    uint256 public constant DEFAULT_FEE = 50;

    //-----------------------------------------------------------------------
    // State Variables
    //-----------------------------------------------------------------------
    address public operator;
    address public immutable primaryToken;
    uint256 public craftingFee;

    uint256 public nextRecipeId;
    uint256 public activeRecipeCount;
    uint256 private _nextCraftedTokenId;

    mapping(uint256 => Recipe) private _recipes;
    uint256[] private _recipeIds;

    /// @dev user => token => amount
    mapping(address => mapping(address => uint256)) public erc20Balances;

    /// @dev user => collection => tokenId => deposited
    mapping(address => mapping(address => mapping(uint256 => bool))) public depositedNFTs;

    /// @dev user => collection => set of deposited tokenIds
    mapping(address => mapping(address => EnumerableSet.UintSet)) private _depositedNFTSets;

    //-----------------------------------------------------------------------
    // Modifiers
    //-----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    //-----------------------------------------------------------------------
    // Constructor
    //-----------------------------------------------------------------------
    constructor(
        address _primaryToken,
        address _operator,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        if (_primaryToken == address(0)) revert ErrZeroAddress();
        if (_operator == address(0)) revert ErrZeroAddress();
        primaryToken = _primaryToken;
        operator = _operator;
        craftingFee = DEFAULT_FEE;
        _nextCraftedTokenId = 1;
        emit CraftingFeeUpdated(0, DEFAULT_FEE);
        emit OperatorUpdated(address(0), _operator);
    }

    //-----------------------------------------------------------------------
    // Operator Management
    //-----------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ErrZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setCraftingFee(uint256 _fee) external onlyOperator {
        if (_fee > MAX_FEE) revert ErrFeeTooHigh();
        uint256 old = craftingFee;
        craftingFee = _fee;
        emit CraftingFeeUpdated(old, _fee);
    }

    //-----------------------------------------------------------------------
    // Recipe Management
    //-----------------------------------------------------------------------
    function addRecipe(
        address[] calldata erc20Tokens,
        uint256[] calldata erc20Amounts,
        address[] calldata nftCollections,
        uint256[] calldata nftTokenIds,
        string calldata outputURI
    ) external onlyOperator returns (uint256 recipeId) {
        if (activeRecipeCount >= MAX_RECIPES) revert ErrMaxRecipesReached();
        if (erc20Tokens.length != erc20Amounts.length) revert ErrLengthMismatch();
        if (nftCollections.length != nftTokenIds.length) revert ErrLengthMismatch();
        if (erc20Tokens.length == 0 && nftCollections.length == 0) revert ErrInvalidRecipeRequirements();

        recipeId = nextRecipeId++;
        Recipe storage recipe = _recipes[recipeId];
        recipe.exists = true;
        recipe.active = true;
        recipe.outputURI = outputURI;

        for (uint256 i = 0; i < erc20Tokens.length; ) {
            if (erc20Tokens[i] == address(0)) revert ErrZeroAddress();
            if (erc20Amounts[i] == 0) revert ErrZeroAmount();
            recipe.erc20Requirements.push(
                ERC20Requirement({token: erc20Tokens[i], amount: erc20Amounts[i]})
            );
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < nftCollections.length; ) {
            if (nftCollections[i] == address(0)) revert ErrZeroAddress();
            recipe.nftRequirements.push(
                NFTRequirement({collection: nftCollections[i], tokenId: nftTokenIds[i]})
            );
            unchecked {
                ++i;
            }
        }

        _recipeIds.push(recipeId);
        activeRecipeCount++;
        emit RecipeAdded(recipeId, msg.sender);
    }

    function removeRecipe(uint256 recipeId) external onlyOperator {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.exists) revert ErrRecipeNotFound();
        if (!recipe.active) revert ErrRecipeAlreadyRemoved();

        recipe.active = false;
        activeRecipeCount--;
        emit RecipeRemoved(recipeId, msg.sender);
    }

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            address[] memory erc20Tokens,
            uint256[] memory erc20Amounts,
            address[] memory nftCollections,
            uint256[] memory nftTokenIds,
            string memory outputURI,
            bool active,
            bool exists
        )
    {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.exists) revert ErrRecipeNotFound();

        uint256 ercLen = recipe.erc20Requirements.length;
        uint256 nftLen = recipe.nftRequirements.length;

        erc20Tokens = new address[](ercLen);
        erc20Amounts = new uint256[](ercLen);
        for (uint256 i = 0; i < ercLen; ) {
            erc20Tokens[i] = recipe.erc20Requirements[i].token;
            erc20Amounts[i] = recipe.erc20Requirements[i].amount;
            unchecked {
                ++i;
            }
        }

        nftCollections = new address[](nftLen);
        nftTokenIds = new uint256[](nftLen);
        for (uint256 i = 0; i < nftLen; ) {
            nftCollections[i] = recipe.nftRequirements[i].collection;
            nftTokenIds[i] = recipe.nftRequirements[i].tokenId;
            unchecked {
                ++i;
            }
        }

        outputURI = recipe.outputURI;
        active = recipe.active;
        exists = recipe.exists;
    }

    function recipeCount() external view returns (uint256) {
        return _recipeIds.length;
    }

    function recipeIdAt(uint256 index) external view returns (uint256) {
        return _recipeIds[index];
    }

    //-----------------------------------------------------------------------
    // Deposit Functions
    //-----------------------------------------------------------------------
    function depositERC20(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrZeroAmount();

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;

        erc20Balances[msg.sender][token] += received;
        emit ERC20Deposited(msg.sender, token, received);
    }

    function depositNFT(address collection, uint256 tokenId) external nonReentrant {
        if (collection == address(0)) revert ErrZeroAddress();

        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);
        depositedNFTs[msg.sender][collection][tokenId] = true;
        _depositedNFTSets[msg.sender][collection].add(tokenId);
        emit NFTDeposited(msg.sender, collection, tokenId);
    }

    //-----------------------------------------------------------------------
    // Withdraw Functions
    //-----------------------------------------------------------------------
    function withdrawERC20(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        uint256 available = erc20Balances[msg.sender][token];
        if (available < amount) revert ErrInsufficientERC20(token, amount, available);

        erc20Balances[msg.sender][token] = available - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit ERC20Withdrawn(msg.sender, token, amount);
    }

    function withdrawNFT(address collection, uint256 tokenId) external nonReentrant {
        if (!depositedNFTs[msg.sender][collection][tokenId])
            revert ErrNFTNotDeposited(collection, tokenId);

        depositedNFTs[msg.sender][collection][tokenId] = false;
        _depositedNFTSets[msg.sender][collection].remove(tokenId);
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
        emit NFTWithdrawn(msg.sender, collection, tokenId);
    }

    //-----------------------------------------------------------------------
    // View Helpers
    //-----------------------------------------------------------------------
    function getDepositedNFTs(address user, address collection) external view returns (uint256[] memory) {
        return _depositedNFTSets[user][collection].values();
    }

    function getDepositedNFTCount(address user, address collection) external view returns (uint256) {
        return _depositedNFTSets[user][collection].length();
    }

    function isNFTDeposited(address user, address collection, uint256 tokenId) external view returns (bool) {
        return depositedNFTs[user][collection][tokenId];
    }

    //-----------------------------------------------------------------------
    // Crafting
    //-----------------------------------------------------------------------
    function craft(uint256 recipeId) external nonReentrant returns (uint256 craftedTokenId) {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.exists) revert ErrRecipeNotFound();
        if (!recipe.active) revert ErrRecipeNotActive();

        // 1. Charge the crafting fee in the primary token
        uint256 feeAvailable = erc20Balances[msg.sender][primaryToken];
        if (feeAvailable < craftingFee) revert ErrInsufficientFee();
        erc20Balances[msg.sender][primaryToken] = feeAvailable - craftingFee;

        // 2. Consume ERC20 requirements
        uint256 ercLen = recipe.erc20Requirements.length;
        for (uint256 i = 0; i < ercLen; ) {
            ERC20Requirement storage req = recipe.erc20Requirements[i];
            uint256 available = erc20Balances[msg.sender][req.token];
            if (available < req.amount) {
                revert ErrInsufficientERC20(req.token, req.amount, available);
            }
            erc20Balances[msg.sender][req.token] = available - req.amount;
            unchecked {
                ++i;
            }
        }

        // 3. Consume NFT requirements (transfer consumed NFTs to the contract owner)
        uint256 nftLen = recipe.nftRequirements.length;
        for (uint256 i = 0; i < nftLen; ) {
            NFTRequirement storage nftReq = recipe.nftRequirements[i];
            if (!depositedNFTs[msg.sender][nftReq.collection][nftReq.tokenId]) {
                revert ErrNFTNotDeposited(nftReq.collection, nftReq.tokenId);
            }
            depositedNFTs[msg.sender][nftReq.collection][nftReq.tokenId] = false;
            _depositedNFTSets[msg.sender][nftReq.collection].remove(nftReq.tokenId);
            IERC721(nftReq.collection).safeTransferFrom(address(this), owner(), nftReq.tokenId);
            unchecked {
                ++i;
            }
        }

        // 4. Mint the crafted output NFT to the user
        craftedTokenId = _nextCraftedTokenId++;
        _safeMint(msg.sender, craftedTokenId);
        _setTokenURI(craftedTokenId, recipe.outputURI);

        emit ItemCrafted(msg.sender, recipeId, craftedTokenId);
    }

    //-----------------------------------------------------------------------
    // ERC721 Receiver
    //-----------------------------------------------------------------------
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
