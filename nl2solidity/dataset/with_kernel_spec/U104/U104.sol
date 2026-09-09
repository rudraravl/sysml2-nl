// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PriceFeedAggregator {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error ZeroAddress();
    error NotOperator();
    error AlreadyOperator();
    error OperatorNotFound();
    error AssetNotAuthorized();
    error ZeroPrice();
    error InvalidFeeAmount();
    error FeeTransferFailed();
    error ZeroMinSubmissions();
    error AssetNotListed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event AssetAuthorizationUpdated(address indexed operator, address indexed asset, bool status);
    event MinValidSubmissionsUpdated(uint256 oldMin, uint256 newMin);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event PriceSubmitted(address indexed operator, address indexed asset, uint256 price);
    event AggregatePriceUpdated(address indexed asset, uint256 price, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant SUBMISSION_FEE = 0.01 ether;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public treasury;
    uint256 public minValidSubmissions;

    mapping(address => bool) public isOperator;
    address[] public allOperators;

    mapping(address => mapping(address => bool)) public authorizedAssets;

    mapping(address => mapping(address => uint256)) public operatorAssetPrice;
    mapping(address => mapping(address => uint256)) public operatorAssetTimestamp;

    mapping(address => uint256) public aggregatePrice;
    mapping(address => uint256) public aggregateTimestamp;
    mapping(address => bool) public isListed;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyActiveOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        treasury = _treasury;
        minValidSubmissions = 3;
        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
        emit MinValidSubmissionsUpdated(0, 3);
    }

    /*//////////////////////////////////////////////////////////////
                          OWNERSHIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /*//////////////////////////////////////////////////////////////
                           OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function setMinValidSubmissions(uint256 _min) external onlyOwner {
        if (_min == 0) revert ZeroMinSubmissions();
        emit MinValidSubmissionsUpdated(minValidSubmissions, _min);
        minValidSubmissions = _min;
    }

    function addOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        if (isOperator[_operator]) revert AlreadyOperator();
        isOperator[_operator] = true;
        allOperators.push(_operator);
        emit OperatorAdded(_operator);
    }

    function removeOperator(address _operator) external onlyOwner {
        if (!isOperator[_operator]) revert OperatorNotFound();
        isOperator[_operator] = false;
        uint256 len = allOperators.length;
        for (uint256 i = 0; i < len; i++) {
            if (allOperators[i] == _operator) {
                allOperators[i] = allOperators[len - 1];
                allOperators.pop();
                break;
            }
        }
        emit OperatorRemoved(_operator);
    }

    function setAuthorizedAsset(address _operator, address _asset, bool _status) external onlyOwner {
        if (!isOperator[_operator]) revert OperatorNotFound();
        if (_asset == address(0)) revert ZeroAddress();
        authorizedAssets[_operator][_asset] = _status;
        emit AssetAuthorizationUpdated(_operator, _asset, _status);
    }

    function setAuthorizedAssets(address _operator, address[] calldata _assets, bool _status) external onlyOwner {
        if (!isOperator[_operator]) revert OperatorNotFound();
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i] == address(0)) revert ZeroAddress();
            authorizedAssets[_operator][_assets[i]] = _status;
            emit AssetAuthorizationUpdated(_operator, _assets[i], _status);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function submitPrice(address _asset, uint256 _price) external payable onlyActiveOperator {
        if (_asset == address(0)) revert ZeroAddress();
        if (!authorizedAssets[msg.sender][_asset]) revert AssetNotAuthorized();
        if (_price == 0) revert ZeroPrice();
        if (msg.value != SUBMISSION_FEE) revert InvalidFeeAmount();

        operatorAssetPrice[msg.sender][_asset] = _price;
        operatorAssetTimestamp[msg.sender][_asset] = block.timestamp;
        emit PriceSubmitted(msg.sender, _asset, _price);

        _updateAggregate(_asset);

        (bool success, ) = payable(treasury).call{value: msg.value}("");
        if (!success) revert FeeTransferFailed();
    }

    function _updateAggregate(address _asset) internal {
        uint256 validCount = 0;
        uint256 sumPrice = 0;
        uint256 len = allOperators.length;

        for (uint256 i = 0; i < len; i++) {
            address operator = allOperators[i];
            if (isOperator[operator] && authorizedAssets[operator][_asset]) {
                uint256 opPrice = operatorAssetPrice[operator][_asset];
                if (opPrice > 0) {
                    validCount++;
                    sumPrice += opPrice;
                }
            }
        }

        if (validCount >= minValidSubmissions) {
            uint256 newPrice = sumPrice / validCount;
            aggregatePrice[_asset] = newPrice;
            aggregateTimestamp[_asset] = block.timestamp;
            isListed[_asset] = true;
            emit AggregatePriceUpdated(_asset, newPrice, block.timestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAggregatePrice(address _asset) external view returns (uint256 price, uint256 timestamp, bool isValid) {
        if (!isListed[_asset]) revert AssetNotListed();
        return (aggregatePrice[_asset], aggregateTimestamp[_asset], true);
    }

    function getOperatorPrice(address _operator, address _asset) external view returns (uint256 price, uint256 timestamp) {
        if (!isOperator[_operator]) revert NotOperator();
        return (operatorAssetPrice[_operator][_asset], operatorAssetTimestamp[_operator][_asset]);
    }

    function getAllOperators() external view returns (address[] memory) {
        return allOperators;
    }

    function getOperatorCount() external view returns (uint256) {
        return allOperators.length;
    }

    function isAssetListed(address _asset) external view returns (bool) {
        return isListed[_asset];
    }

    function getValidSubmissionCount(address _asset) external view returns (uint256) {
        uint256 count = 0;
        uint256 len = allOperators.length;
        for (uint256 i = 0; i < len; i++) {
            address operator = allOperators[i];
            if (isOperator[operator] && authorizedAssets[operator][_asset]) {
                if (operatorAssetPrice[operator][_asset] > 0) {
                    count++;
                }
            }
        }
        return count;
    }
}
