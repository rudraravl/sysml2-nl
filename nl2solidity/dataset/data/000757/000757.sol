// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IRewardRouterV2} from "../interfaces/IRewardRouterV2.sol";
import {IRewardTracker} from "../interfaces/IRewardTracker.sol";
import {IGovToken} from "../interfaces/IGovToken.sol";
import "../Constants.sol";

contract Stake {
    IERC20 constant gmx = IERC20(GMX);
    IGovToken constant gmxDao = IGovToken(GMX_DAO);
    IRewardRouterV2 constant rewardRouter = IRewardRouterV2(REWARD_ROUTER_V2);
    IRewardTracker constant rewardTracker = IRewardTracker(REWARD_TRACKER);

    // Task 1 - Stake GMX
    function stake(uint256 gmxAmount) external {}

    // Task 2 - Unstake GMX
    function unstake(uint256 gmxAmount) external {}

    // Task 3 - Claim rewards
    function claimRewards() external {}

    // Task 4 - Get staked amount
    function getStakedAmount() external view returns (uint256) {}

    // Task 5 - Delegate
    function delegate(address delegatee) external {}
}
