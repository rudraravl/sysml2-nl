// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IGlvRouter} from "../interfaces/IGlvRouter.sol";
import {GlvDepositUtils} from "../types/GlvDepositUtils.sol";
import {GlvWithdrawalUtils} from "../types/GlvWithdrawalUtils.sol";
import "../Constants.sol";

contract GlvLiquidity {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IERC20 constant glvToken = IERC20(GLV_TOKEN_WETH_USDC);
    IGlvRouter constant glvRouter = IGlvRouter(GLV_ROUTER);

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Create an order to deposit USDC into GLV vault
    function createGlvDeposit(uint256 usdcAmount, uint256 minGlvAmount)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        // Task 2.1 - Send execution fee to GLV vault

        // Task 2.2 - Send USDC to GLV vault

        // Task 2.3 - Create an order to deposit USDC
    }

    // Task 3 - Create an order to withdraw liquidity
    function createGlvWithdrawal(uint256 minWethAmount, uint256 minUsdcAmount)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;

        // 3.1 Send execution fee to GLV vault

        // 3.2 - Send USDC to GLV vault

        // 3.3 Create an order to withdraw liquidity
    }
}
