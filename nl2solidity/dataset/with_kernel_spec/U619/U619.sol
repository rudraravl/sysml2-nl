// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MetaverseLandRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ParcelClaimed(uint256 indexed parcelId, address indexed owner, uint256 fee);
    event ParcelTransferred(uint256 indexed parcelId, address indexed previousOwner, address indexed newOwner);
    event EditorAdded(uint256 indexed parcelId, address indexed editor);
    event EditorRemoved(uint256 indexed parcelId, address indexed editor);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event ClaimPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event AdditionalOperatorChanged(address indexed account, bool status);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error NotParcelOwner();
    error ParcelAlreadyOwned();
    error ZeroAddress();
    error EditorAlreadyExists();
    error EditorDoesNotExist();
    error MaxEditorsReached();
    error ClaimIsPaused();
    error InsufficientFee();
    error InvalidParcelId();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_EDITORS = 10;
    uint256 public constant DEFAULT_FEE = 0.01 ether;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    mapping(address => bool) public additionalOperators;

    struct Parcel {
        address owner;
        address[] editors;
        mapping(address => bool) isEditor;
    }

    mapping(uint256 => Parcel) private parcels;

    uint256 public claimFee;
    bool public claimPaused;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator && !additionalOperators[msg.sender]) {
            revert NotOperator();
        }
        _;
    }

    modifier onlyParcelOwner(uint256 parcelId) {
        if (parcels[parcelId].owner != msg.sender) {
            revert NotParcelOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        operator = msg.sender;
        claimFee = DEFAULT_FEE;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeUpdated(0, DEFAULT_FEE);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator;
        emit OperatorChanged(previousOperator, newOperator);
    }

    function setAdditionalOperator(address account, bool status) external onlyOperator {
        if (account == address(0)) revert ZeroAddress();
        additionalOperators[account] = status;
        emit AdditionalOperatorChanged(account, status);
    }

    function setClaimFee(uint256 newFee) external onlyOperator {
        uint256 oldFee = claimFee;
        claimFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setClaimPaused(bool paused) external onlyOperator {
        claimPaused = paused;
        emit ClaimPausedChanged(paused);
    }

    /*//////////////////////////////////////////////////////////////
                         PARCEL LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimParcel(uint256 parcelId) external payable {
        if (claimPaused) revert ClaimIsPaused();
        if (parcelId == 0) revert InvalidParcelId();
        if (parcels[parcelId].owner != address(0)) revert ParcelAlreadyOwned();
        if (msg.value < claimFee) revert InsufficientFee();

        parcels[parcelId].owner = msg.sender;

        emit ParcelClaimed(parcelId, msg.sender, claimFee);
    }

    function transferParcel(uint256 parcelId, address newOwner)
        external
        onlyParcelOwner(parcelId)
    {
        if (newOwner == address(0)) revert ZeroAddress();

        address previousOwner = parcels[parcelId].owner;
        parcels[parcelId].owner = newOwner;

        emit ParcelTransferred(parcelId, previousOwner, newOwner);
    }

    function addEditor(uint256 parcelId, address editor)
        external
        onlyParcelOwner(parcelId)
    {
        if (editor == address(0)) revert ZeroAddress();
        Parcel storage parcel = parcels[parcelId];
        if (parcel.isEditor[editor]) revert EditorAlreadyExists();
        if (parcel.editors.length >= MAX_EDITORS) revert MaxEditorsReached();

        parcel.editors.push(editor);
        parcel.isEditor[editor] = true;

        emit EditorAdded(parcelId, editor);
    }

    function removeEditor(uint256 parcelId, address editor)
        external
        onlyParcelOwner(parcelId)
    {
        Parcel storage parcel = parcels[parcelId];
        if (!parcel.isEditor[editor]) revert EditorDoesNotExist();

        parcel.isEditor[editor] = false;

        address[] storage editorList = parcel.editors;
        uint256 length = editorList.length;
        for (uint256 i = 0; i < length; i++) {
            if (editorList[i] == editor) {
                editorList[i] = editorList[length - 1];
                editorList.pop();
                break;
            }
        }

        emit EditorRemoved(parcelId, editor);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getParcelOwner(uint256 parcelId) external view returns (address) {
        return parcels[parcelId].owner;
    }

    function isParcelOwned(uint256 parcelId) external view returns (bool) {
        return parcels[parcelId].owner != address(0);
    }

    function isEditorOf(uint256 parcelId, address editor) external view returns (bool) {
        return parcels[parcelId].isEditor[editor];
    }

    function getEditorCount(uint256 parcelId) external view returns (uint256) {
        return parcels[parcelId].editors.length;
    }

    function getEditors(uint256 parcelId) external view returns (address[] memory) {
        return parcels[parcelId].editors;
    }
}
