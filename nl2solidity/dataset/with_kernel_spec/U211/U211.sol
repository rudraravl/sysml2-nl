// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedDomainNameService
 * @notice A decentralized registry for human-readable top-level domains and subdomains.
 * @dev Tracks ownership, resolution data, and configuration parameters for registered domains.
 */
contract DecentralizedDomainNameService {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NameTooShort();
    error DomainAlreadyRegistered();
    error DomainNotRegistered();
    error Unauthorized();
    error InsufficientPayment();
    error WithdrawFailed();
    error ZeroAddress();
    error ReentrancyDetected();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DomainRegistered(address indexed owner, string name);
    event SubdomainRegistered(address indexed owner, string parent, string name);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        string name
    );
    event ResolutionUpdated(address indexed owner, string name, bytes resolution);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed admin, address indexed to, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_NAME_LENGTH = 3;

    struct TLD {
        address owner;
        bytes resolution;
        bool exists;
    }

    struct Subdomain {
        address owner;
        bytes resolution;
        bool exists;
    }

    address public admin;
    uint256 public baseRegistrationFee;

    mapping(string => TLD) private _tlds;
    string[] private _tldList;

    mapping(string => mapping(string => Subdomain)) private _subdomains;
    mapping(string => string[]) private _subdomainList;

    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with an administrator and a default registration fee.
     * @param _admin The initial administrator address.
     */
    constructor(address _admin) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        baseRegistrationFee = 0.01 ether;
        emit FeeUpdated(0, baseRegistrationFee);
        emit AdminTransferred(address(0), _admin);
    }

    /*//////////////////////////////////////////////////////////////
                         TLD REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers a new top-level domain by paying the base registration fee.
     * @param name The human-readable name of the top-level domain.
     */
    function registerTLD(string calldata name) external payable {
        if (bytes(name).length < MIN_NAME_LENGTH) revert NameTooShort();
        if (msg.value < baseRegistrationFee) revert InsufficientPayment();
        if (_tlds[name].exists) revert DomainAlreadyRegistered();

        _tldList.push(name);
        _tlds[name].owner = msg.sender;
        _tlds[name].exists = true;

        emit DomainRegistered(msg.sender, name);
    }

    /**
     * @notice Transfers ownership of a top-level domain to a new owner.
     * @param name The name of the top-level domain.
     * @param newOwner The address to receive ownership.
     */
    function transferTLD(string calldata name, address newOwner) external {
        if (!_tlds[name].exists) revert DomainNotRegistered();
        if (newOwner == address(0)) revert ZeroAddress();
        if (msg.sender != _tlds[name].owner) revert Unauthorized();

        address previous = _tlds[name].owner;
        _tlds[name].owner = newOwner;
        emit OwnershipTransferred(previous, newOwner, name);
    }

    /**
     * @notice Sets resolution data for a top-level domain the caller controls.
     * @param name The name of the top-level domain.
     * @param resolution Resolution payload (e.g., ABI-encoded address or content hash).
     */
    function setTLDResolution(string calldata name, bytes calldata resolution) external {
        if (!_tlds[name].exists) revert DomainNotRegistered();
        if (msg.sender != _tlds[name].owner) revert Unauthorized();

        _tlds[name].resolution = resolution;
        emit ResolutionUpdated(msg.sender, name, resolution);
    }

    /*//////////////////////////////////////////////////////////////
                        SUBDOMAIN MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a subdomain under a top-level domain owned by the caller.
     * @param parent The name of the parent top-level domain.
     * @param name The name of the subdomain to create.
     */
    function createSubdomain(string calldata parent, string calldata name) external {
        if (bytes(name).length < MIN_NAME_LENGTH) revert NameTooShort();
        if (!_tlds[parent].exists) revert DomainNotRegistered();
        if (msg.sender != _tlds[parent].owner) revert Unauthorized();
        if (_subdomains[parent][name].exists) revert DomainAlreadyRegistered();

        _subdomainList[parent].push(name);
        _subdomains[parent][name].owner = msg.sender;
        _subdomains[parent][name].exists = true;

        emit SubdomainRegistered(msg.sender, parent, name);
    }

    /**
     * @notice Transfers ownership of a subdomain to a new owner.
     * @param parent The name of the parent top-level domain.
     * @param name The name of the subdomain.
     * @param newOwner The address to receive ownership.
     */
    function transferSubdomain(
        string calldata parent,
        string calldata name,
        address newOwner
    ) external {
        if (!_subdomains[parent][name].exists) revert DomainNotRegistered();
        if (newOwner == address(0)) revert ZeroAddress();
        if (msg.sender != _subdomains[parent][name].owner) revert Unauthorized();

        address previous = _subdomains[parent][name].owner;
        _subdomains[parent][name].owner = newOwner;
        emit OwnershipTransferred(previous, newOwner, name);
    }

    /**
     * @notice Sets resolution data for a subdomain the caller controls.
     * @param parent The name of the parent top-level domain.
     * @param name The name of the subdomain.
     * @param resolution Resolution payload.
     */
    function setSubdomainResolution(
        string calldata parent,
        string calldata name,
        bytes calldata resolution
    ) external {
        if (!_subdomains[parent][name].exists) revert DomainNotRegistered();
        if (msg.sender != _subdomains[parent][name].owner) revert Unauthorized();

        _subdomains[parent][name].resolution = resolution;
        emit ResolutionUpdated(msg.sender, name, resolution);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the base registration fee for new top-level domains.
     * @param newFee The new fee in wei.
     */
    function setBaseRegistrationFee(uint256 newFee) external onlyAdmin {
        uint256 oldFee = baseRegistrationFee;
        baseRegistrationFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Withdraws all collected registration fees to a recipient.
     * @param to The address receiving the collected fees.
     */
    function withdrawFees(address payable to) external onlyAdmin nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount > 0) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert WithdrawFailed();
            emit FeesWithdrawn(msg.sender, to, amount);
        }
    }

    /**
     * @notice Transfers the administrator role to a new address.
     * @param newAdmin The new administrator address.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTLDOwner(string calldata name) external view returns (address) {
        return _tlds[name].owner;
    }

    function getTLDResolution(string calldata name) external view returns (bytes memory) {
        if (!_tlds[name].exists) revert DomainNotRegistered();
        return _tlds[name].resolution;
    }

    function getTLDList() external view returns (string[] memory) {
        return _tldList;
    }

    function tldExists(string calldata name) external view returns (bool) {
        return _tlds[name].exists;
    }

    function getSubdomainOwner(
        string calldata parent,
        string calldata name
    ) external view returns (address) {
        return _subdomains[parent][name].owner;
    }

    function getSubdomainResolution(
        string calldata parent,
        string calldata name
    ) external view returns (bytes memory) {
        if (!_subdomains[parent][name].exists) revert DomainNotRegistered();
        return _subdomains[parent][name].resolution;
    }

    function getSubdomainList(string calldata parent) external view returns (string[] memory) {
        return _subdomainList[parent];
    }

    function subdomainExists(
        string calldata parent,
        string calldata name
    ) external view returns (bool) {
        return _subdomains[parent][name].exists;
    }

    /*//////////////////////////////////////////////////////////////
                               RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}
}
