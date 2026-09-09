// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract MultiChainAssetWallet is IERC721Receiver {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    uint256 public constant MAX_LINKED_ACCOUNTS = 10;
    uint256 public constant FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error NotOwner();
    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error MaxLinkedAccountsReached();
    error AccountNotLinked();
    error AccountAlreadyLinked();
    error TokenNotOwned();
    error TransferFailed();
    error InvalidFeeRecipient();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event DepositERC20(address indexed user, address indexed token, uint256 amount);
    event DepositERC721(address indexed user, address indexed token, uint256 tokenId);
    event TransferERC20(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 fee);
    event TransferERC721(address indexed from, address indexed to, address indexed token, uint256 tokenId);
    event CrossChainTransfer(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 chainId);
    event CrossChainTransferERC721(address indexed from, address indexed to, address indexed token, uint256 tokenId, uint256 chainId);
    event Approval(address indexed owner, address indexed spender, address indexed token, uint256 amount);
    event AccountLinked(address indexed user, address indexed account);
    event AccountUnlinked(address indexed user, address indexed account);
    event PausedEvent(address indexed owner);
    event UnpausedEvent(address indexed owner);
    event Upgraded(address indexed implementation);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    address public owner;
    address public feeRecipient;
    address public implementation;
    bool public paused;

    mapping(address => mapping(address => uint256)) public erc20Balances;
    mapping(address => mapping(address => mapping(address => uint256))) public erc20Allowances;
    mapping(address => mapping(address => mapping(uint256 => bool))) public erc721Owners;

    mapping(address => address[]) public linkedAccounts;
    mapping(address => mapping(address => bool)) public isLinked;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODIFIERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        paused = false;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function pause() external onlyOwner {
        paused = true;
        emit PausedEvent(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit UnpausedEvent(msg.sender);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPOSIT FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function depositERC20(address token, uint256 amount) external whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        erc20Balances[msg.sender][token] += amount;
        emit DepositERC20(msg.sender, token, amount);
    }

    function depositERC721(address token, uint256 tokenId) external whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
        erc721Owners[msg.sender][token][tokenId] = true;
        emit DepositERC721(msg.sender, token, tokenId);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TRANSFER FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function transferERC20(address token, address to, uint256 amount) external whenNotPaused {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (erc20Balances[msg.sender][token] < amount) revert InsufficientBalance();
        _transferERC20(token, msg.sender, to, amount);
    }

    function transferFromERC20(address token, address from, address to, uint256 amount) external whenNotPaused {
        if (token == address(0) || to == address(0) || from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (erc20Balances[from][token] < amount) revert InsufficientBalance();
        uint256 allowed = erc20Allowances[from][token][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            erc20Allowances[from][token][msg.sender] = allowed - amount;
        }
        _transferERC20(token, from, to, amount);
    }

    function transferERC721(address token, address to, uint256 tokenId) external whenNotPaused {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (!erc721Owners[msg.sender][token][tokenId]) revert TokenNotOwned();
        erc721Owners[msg.sender][token][tokenId] = false;
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
        emit TransferERC721(msg.sender, to, token, tokenId);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    APPROVAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function approveERC20(address token, address spender, uint256 amount) external {
        if (token == address(0) || spender == address(0)) revert ZeroAddress();
        erc20Allowances[msg.sender][token][spender] = amount;
        emit Approval(msg.sender, spender, token, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CROSS-CHAIN FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function crossChainTransfer(address token, address to, uint256 amount, uint256 chainId) external whenNotPaused {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (!isLinked[msg.sender][to]) revert AccountNotLinked();
        if (amount == 0) revert ZeroAmount();
        if (erc20Balances[msg.sender][token] < amount) revert InsufficientBalance();
        erc20Balances[msg.sender][token] -= amount;
        // Tokens are locked in this contract; a bridge relayer will mint on the destination chain.
        emit CrossChainTransfer(msg.sender, to, token, amount, chainId);
    }

    function crossChainTransferERC721(address token, address to, uint256 tokenId, uint256 chainId) external whenNotPaused {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (!isLinked[msg.sender][to]) revert AccountNotLinked();
        if (!erc721Owners[msg.sender][token][tokenId]) revert TokenNotOwned();
        erc721Owners[msg.sender][token][tokenId] = false;
        // NFT is locked in this contract; a bridge relayer will mint on the destination chain.
        emit CrossChainTransferERC721(msg.sender, to, token, tokenId, chainId);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  LINKED ACCOUNTS FUNCTIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function linkAccount(address account) external {
        if (account == address(0)) revert ZeroAddress();
        if (isLinked[msg.sender][account]) revert AccountAlreadyLinked();
        if (linkedAccounts[msg.sender].length >= MAX_LINKED_ACCOUNTS) revert MaxLinkedAccountsReached();
        isLinked[msg.sender][account] = true;
        linkedAccounts[msg.sender].push(account);
        emit AccountLinked(msg.sender, account);
    }

    function unlinkAccount(address account) external {
        if (!isLinked[msg.sender][account]) revert AccountNotLinked();
        isLinked[msg.sender][account] = false;
        address[] storage accounts = linkedAccounts[msg.sender];
        uint256 len = accounts.length;
        for (uint256 i = 0; i < len; i++) {
            if (accounts[i] == account) {
                accounts[i] = accounts[len - 1];
                accounts.pop();
                break;
            }
        }
        emit AccountUnlinked(msg.sender, account);
    }

    function getLinkedAccounts(address user) external view returns (address[] memory) {
        return linkedAccounts[user];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERNAL HELPERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function _transferERC20(address token, address from, address to, uint256 amount) internal {
        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = amount - fee;

        erc20Balances[from][token] -= amount;

        if (amountAfterFee > 0) {
            if (!IERC20(token).transfer(to, amountAfterFee)) revert TransferFailed();
        }
        if (fee > 0) {
            if (!IERC20(token).transfer(feeRecipient, fee)) revert TransferFailed();
        }

        emit TransferERC20(from, to, token, amountAfterFee, fee);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC721 RECEIVER                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
