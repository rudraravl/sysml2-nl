// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GreetingService {
    event Greeted(address indexed greeter, address indexed referrer, uint256 fee);
    event ReferralRewardClaimed(address indexed referrer, uint256 amount);
    event GreetingFeeUpdated(uint256 oldFee, uint256 newFee);
    event ReferralRewardPercentUpdated(uint256 oldPercent, uint256 newPercent);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error ErrIncorrectFee(uint256 expected, uint256 received);
    error ErrSelfReferral();
    error ErrZeroGreetingFee();
    error ErrInvalidRewardPercent(uint256 percent);
    error ErrNothingToClaim();
    error ErrTransferFailed();
    error ErrUnauthorized();
    error ErrZeroAddress();

    uint256 public constant DEFAULT_GREETING_FEE = 0.001 ether;
    uint256 public constant DEFAULT_REFERRAL_REWARD_PERCENT = 20;
    uint256 public constant PERCENT_BASE = 100;

    address public owner;
    uint256 public greetingFee;
    uint256 public referralRewardPercent;
    uint256 public accumulatedFees;
    uint256 public totalReferralRewardsPending;

    mapping(address => uint256) public referralCount;
    mapping(address => uint256) public pendingReferralRewards;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrUnauthorized();
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "ReentrancyGuard: reentrant call");
        _locked = 2;
        _;
        _locked = 1;
    }

    uint256 private _locked = 1;

    constructor() {
        owner = msg.sender;
        greetingFee = DEFAULT_GREETING_FEE;
        referralRewardPercent = DEFAULT_REFERRAL_REWARD_PERCENT;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function greet(address referrer) external payable nonReentrant {
        if (msg.value != greetingFee) {
            revert ErrIncorrectFee(greetingFee, msg.value);
        }

        address ref = referrer;
        uint256 reward = 0;

        if (ref != address(0)) {
            if (ref == msg.sender) {
                revert ErrSelfReferral();
            }
            reward = (greetingFee * referralRewardPercent) / PERCENT_BASE;
            pendingReferralRewards[ref] += reward;
            referralCount[ref] += 1;
            totalReferralRewardsPending += reward;
        }

        accumulatedFees += (greetingFee - reward);

        emit Greeted(msg.sender, ref, greetingFee);
    }

    function claimReferralRewards() external nonReentrant {
        uint256 amount = pendingReferralRewards[msg.sender];
        if (amount == 0) {
            revert ErrNothingToClaim();
        }

        pendingReferralRewards[msg.sender] = 0;
        totalReferralRewardsPending -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert ErrTransferFailed();
        }

        emit ReferralRewardClaimed(msg.sender, amount);
    }

    function setGreetingFee(uint256 newFee) external onlyOwner {
        if (newFee == 0) {
            revert ErrZeroGreetingFee();
        }
        emit GreetingFeeUpdated(greetingFee, newFee);
        greetingFee = newFee;
    }

    function setReferralRewardPercent(uint256 newPercent) external onlyOwner {
        if (newPercent > PERCENT_BASE) {
            revert ErrInvalidRewardPercent(newPercent);
        }
        emit ReferralRewardPercentUpdated(referralRewardPercent, newPercent);
        referralRewardPercent = newPercent;
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) {
            revert ErrNothingToClaim();
        }

        accumulatedFees = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert ErrTransferFailed();
        }

        emit FeesWithdrawn(msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ErrZeroAddress();
        }
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function pendingReferralRewardOf(address user) external view returns (uint256) {
        return pendingReferralRewards[user];
    }

    function referralCountOf(address user) external view returns (uint256) {
        return referralCount[user];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdrawableFees() external view returns (uint256) {
        return accumulatedFees;
    }
}
