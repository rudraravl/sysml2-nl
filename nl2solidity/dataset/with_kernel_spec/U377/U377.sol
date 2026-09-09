// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PrivateCreditVault {
    uint256 public constant MAX_APPROVED_ASSETS = 10;
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    address public owner;
    address public operator;
    uint256 public redemptionFeeBps; // Fixed at 0.5% (50 bps) initially

    bool public depositsPaused;
    bool public redemptionsPaused;

    mapping(address => bool) public isApprovedAsset;
    address[] internal _approvedAssetList;

    mapping(address => bool) public isEligibleUser;

    mapping(address => mapping(address => uint256)) public depositedAssets;
    mapping(address => mapping(address => uint256)) public ownershipShares;
    mapping(address => uint256) public totalShares;
    mapping(address => uint256) public totalCustodied;
    mapping(address => uint256) public accumulatedFees;

    event AssetDeposited(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event SharesRedeemed(address indexed user, address indexed asset, uint256 shares, uint256 amountReturned, uint256 fee);
    event SharesTransferred(address indexed from, address indexed to, address indexed asset, uint256 shares);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event AssetApproved(address indexed asset);
    event AssetRemoved(address indexed asset);
    event DepositsPaused();
    event DepositsUnpaused();
    event RedemptionsPaused();
    event RedemptionsUnpaused();
    event EligibleUserAdded(address indexed user);
    event EligibleUserRemoved(address indexed user);
    event FeesClaimed(address indexed asset, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOwner();
    error NotOperator();
    error NotOwnerOrOperator();
    error DepositsArePaused();
    error RedemptionsArePaused();
    error AssetNotApproved();
    error AssetAlreadyApproved();
    error MaxApprovedAssetsReached();
    error AssetHasOutstandingShares();
    error InsufficientShares();
    error NotEligible();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error NoFeesToClaim();
    error FeeTooHigh();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner && msg.sender != operator) revert NotOwnerOrOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier whenRedemptionsNotPaused() {
        if (redemptionsPaused) revert RedemptionsArePaused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        redemptionFeeBps = 50; // 0.5%
        isEligibleUser[msg.sender] = true;
        emit EligibleUserAdded(msg.sender);
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit RedemptionFeeUpdated(0, redemptionFeeBps);
    }

    function approveAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (isApprovedAsset[asset]) revert AssetAlreadyApproved();
        if (_approvedAssetList.length >= MAX_APPROVED_ASSETS) revert MaxApprovedAssetsReached();
        isApprovedAsset[asset] = true;
        _approvedAssetList.push(asset);
        emit AssetApproved(asset);
    }

    function removeAsset(address asset) external onlyOwner {
        if (!isApprovedAsset[asset]) revert AssetNotApproved();
        if (totalShares[asset] > 0) revert AssetHasOutstandingShares();
        isApprovedAsset[asset] = false;
        uint256 len = _approvedAssetList.length;
        for (uint256 i = 0; i < len; i++) {
            if (_approvedAssetList[i] == asset) {
                _approvedAssetList[i] = _approvedAssetList[len - 1];
                _approvedAssetList.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }

    function setRedemptionFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFeeBps = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFeeBps, newFeeBps);
    }

    function pauseDeposits() external onlyOperator {
        if (depositsPaused) revert DepositsArePaused();
        depositsPaused = true;
        emit DepositsPaused();
    }

    function unpauseDeposits() external onlyOperator {
        if (!depositsPaused) revert DepositsArePaused();
        depositsPaused = false;
        emit DepositsUnpaused();
    }

    function pauseRedemptions() external onlyOperator {
        if (redemptionsPaused) revert RedemptionsArePaused();
        redemptionsPaused = true;
        emit RedemptionsPaused();
    }

    function unpauseRedemptions() external onlyOperator {
        if (!redemptionsPaused) revert RedemptionsArePaused();
        redemptionsPaused = false;
        emit RedemptionsUnpaused();
    }

    function addEligibleUser(address user) external onlyOwnerOrOperator {
        if (user == address(0)) revert ZeroAddress();
        if (isEligibleUser[user]) revert NotEligible();
        isEligibleUser[user] = true;
        emit EligibleUserAdded(user);
    }

    function removeEligibleUser(address user) external onlyOwnerOrOperator {
        if (!isEligibleUser[user]) revert NotEligible();
        isEligibleUser[user] = false;
        emit EligibleUserRemoved(user);
    }

    function deposit(address asset, uint256 amount) external whenDepositsNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (!isApprovedAsset[asset]) revert AssetNotApproved();
        if (!isEligibleUser[msg.sender]) revert NotEligible();

        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        uint256 received = IERC20(asset).balanceOf(address(this)) - balanceBefore;

        depositedAssets[msg.sender][asset] += received;
        ownershipShares[msg.sender][asset] += received;
        totalShares[asset] += received;
        totalCustodied[asset] += received;

        emit AssetDeposited(msg.sender, asset, received, received);
    }

    function redeem(address asset, uint256 shares) external whenRedemptionsNotPaused {
        if (shares == 0) revert ZeroAmount();
        if (!isApprovedAsset[asset]) revert AssetNotApproved();
        if (ownershipShares[msg.sender][asset] < shares) revert InsufficientShares();

        uint256 fee = (shares * redemptionFeeBps) / 10000;
        uint256 amountToReturn = shares - fee;

        ownershipShares[msg.sender][asset] -= shares;
        totalShares[asset] -= shares;
        totalCustodied[asset] -= amountToReturn;
        
        uint256 userDeposited = depositedAssets[msg.sender][asset];
        if (userDeposited >= shares) {
            depositedAssets[msg.sender][asset] -= shares;
        } else {
            depositedAssets[msg.sender][asset] = 0;
        }

        if (fee > 0) {
            accumulatedFees[asset] += fee;
        }

        bool ok = IERC20(asset).transfer(msg.sender, amountToReturn);
        if (!ok) revert TransferFailed();

        emit SharesRedeemed(msg.sender, asset, shares, amountToReturn, fee);
    }

    function transferShares(address to, address asset, uint256 shares) external {
        if (shares == 0) revert ZeroAmount();
        if (!isApprovedAsset[asset]) revert AssetNotApproved();
        if (!isEligibleUser[msg.sender] || !isEligibleUser[to]) revert NotEligible();
        if (ownershipShares[msg.sender][asset] < shares) revert InsufficientShares();

        ownershipShares[msg.sender][asset] -= shares;
        ownershipShares[to][asset] += shares;

        uint256 senderDeposit = depositedAssets[msg.sender][asset];
        uint256 toTransfer = senderDeposit < shares ? senderDeposit : shares;
        depositedAssets[msg.sender][asset] -= toTransfer;
        depositedAssets[to][asset] += toTransfer;

        emit SharesTransferred(msg.sender, to, asset, shares);
    }

    function claimFees(address asset) external onlyOwner {
        uint256 amount = accumulatedFees[asset];
        if (amount == 0) revert NoFeesToClaim();
        accumulatedFees[asset] = 0;
        totalCustodied[asset] -= amount;
        bool ok = IERC20(asset).transfer(owner, amount);
        if (!ok) revert TransferFailed();
        emit FeesClaimed(asset, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    function getApprovedAssets() external view returns (address[] memory) {
        return _approvedAssetList;
    }

    function getUserShares(address user, address asset) external view returns (uint256) {
        return ownershipShares[user][asset];
    }

    function getUserDeposit(address user, address asset) external view returns (uint256) {
        return depositedAssets[user][asset];
    }

    function getAssetTotals(address asset) external view returns (uint256 shares, uint256 custodied, uint256 fees) {
        return (totalShares[asset], totalCustodied[asset], accumulatedFees[asset]);
    }
}
