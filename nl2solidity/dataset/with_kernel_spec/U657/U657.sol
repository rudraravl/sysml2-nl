// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract OnChainCollectibles is IERC165 {
    error NotAuthorized();
    error NotOwnerOrApproved();
    error ZeroAddress();
    error TokenNotMinted();
    error MintPaused();
    error MaxSupplyReached();
    error ExceedsMaxPerTransaction();
    error InvalidTokenId();
    error UnsafeRecipient();
    error WrongFromAddress();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CollectibleMinted(uint256 indexed tokenId, address indexed owner);
    event BaseURISet(string baseURI);
    event MintPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    string public name;
    string public symbol;
    string public baseURI;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MAX_PER_TRANSACTION = 5;
    uint256 public totalSupply;
    uint256 internal _nextTokenId;

    address public owner;
    address public operator;
    bool public mintPaused;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (mintPaused) revert MintPaused();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _operator
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        owner = msg.sender;
        operator = _operator;
        _nextTokenId = 1;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _operator;
        emit OperatorChanged(previous, _operator);
    }

    function transferOwnership(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
    }

    function setBaseURI(string calldata _baseURI) external onlyOperator {
        baseURI = _baseURI;
        emit BaseURISet(_baseURI);
    }

    function setMintPaused(bool _paused) external onlyOperator {
        mintPaused = _paused;
        emit MintPausedChanged(_paused);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == 0x01ffc9a7 ||
            interfaceId == 0x80ac58cd ||
            interfaceId == 0x5b5e139f;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        if (_owner == address(0)) revert ZeroAddress();
        return _balanceOf[_owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert TokenNotMinted();
        return tokenOwner;
    }

    function approve(address spender, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) {
            revert NotOwnerOrApproved();
        }
        getApproved[tokenId] = spender;
        emit Approval(tokenOwner, spender, tokenId);
    }

    function setApprovalForAll(address operator_, bool approved) external {
        if (operator_ == msg.sender) revert NotOwnerOrApproved();
        isApprovedForAll[msg.sender][operator_] = approved;
        emit ApprovalForAll(msg.sender, operator_, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (_ownerOf[tokenId] != from) revert WrongFromAddress();
        if (to == address(0)) revert ZeroAddress();
        if (
            msg.sender != from &&
            msg.sender != getApproved[tokenId] &&
            !isApprovedForAll[from][msg.sender]
        ) {
            revert NotOwnerOrApproved();
        }

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;
        delete getApproved[tokenId];
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        _safeTransferFrom(from, to, tokenId, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
            } catch {
                revert UnsafeRecipient();
            }
        }
    }

    function mint(uint256 count) external whenNotPaused {
        if (count == 0 || count > MAX_PER_TRANSACTION) revert ExceedsMaxPerTransaction();
        if (totalSupply + count > MAX_SUPPLY) revert MaxSupplyReached();

        uint256 startId = _nextTokenId;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = startId + i;
            _mint(msg.sender, tokenId);
        }
        _nextTokenId = startId + count;
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_ownerOf[tokenId] != address(0)) revert InvalidTokenId();

        _ownerOf[tokenId] = to;
        unchecked {
            _balanceOf[to]++;
            totalSupply++;
        }
        delete getApproved[tokenId];
        emit Transfer(address(0), to, tokenId);
        emit CollectibleMinted(tokenId, to);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        string memory idStr = _toString(tokenId);
        string memory svg = svgImage(tokenId);
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            ' #',
            idStr,
            '","description":"On-chain SVG digital collectible.","image_data":"data:image/svg+xml;utf8,',
            svg,
            '","external_url":"',
            baseURI,
            idStr,
            '"}'
        );
        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    function svgImage(uint256 tokenId) public pure returns (string memory) {
        if (tokenId >= MAX_SUPPLY) revert InvalidTokenId();
        return _buildSVG(tokenId);
    }

    function _buildSVG(uint256 tokenId) internal pure returns (string memory) {
        bytes memory header = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="0 0 500 500">',
            '<defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">'
        );

        bytes memory stops = abi.encodePacked(
            '<stop offset="0%" stop-color="',
            _colorFromToken(tokenId, 137, 0),
            '"/><stop offset="50%" stop-color="',
            _colorFromToken(tokenId, 271, 47),
            '"/><stop offset="100%" stop-color="',
            _colorFromToken(tokenId, 53, 120),
            '"/></linearGradient></defs>'
        );

        bytes memory body = abi.encodePacked(
            '<rect width="500" height="500" fill="url(#g)"/>',
            '<circle cx="',
            _toString(200 + ((tokenId * 61) % 200)),
            '" cy="',
            _toString(150 + ((tokenId * 97) % 150)),
            '" r="',
            _toString(40 + ((tokenId * 31) % 60)),
            '" fill="rgba(255,255,255,0.25)"/>',
            '<text x="250" y="470" font-family="monospace" font-size="28" fill="white" text-anchor="middle">#',
            _toString(tokenId),
            '</text></svg>'
        );

        return string(abi.encodePacked(header, stops, body));
    }

    function _colorFromToken(uint256 tokenId, uint256 multiplier, uint256 offset) internal pure returns (string memory) {
        uint256 hue = (tokenId * multiplier + offset) % 360;
        return _hslToString(hue, 70, 50);
    }

    function getMetadata(uint256 tokenId) external view returns (string memory uri, string memory svg) {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        return (tokenURI(tokenId), svgImage(tokenId));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _hslToString(uint256 h, uint256 s, uint256 l) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "hsl(",
                _toString(h),
                ",",
                _toString(s),
                "%,",
                _toString(l),
                "%)"
            )
        );
    }
}
