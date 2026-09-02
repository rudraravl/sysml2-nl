// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {IReader} from "../interfaces/IReader.sol";
import {Order} from "../types/Order.sol";
import {IBaseOrderUtils} from "../types/IBaseOrderUtils.sol";
import "../Constants.sol";

contract LimitSwap {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Create a limit order to swap USDC to WETH
    function createLimitOrder(uint256 usdcAmount, uint256 maxEthPrice)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        // Task 2.1 - Send execution fee to the order vault

        // Task 2.2 - Send USDC to the order vault

        // Task 2.3 - Create an order to swap USDC to WETH
    }
}
