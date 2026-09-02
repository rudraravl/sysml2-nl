// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {Order} from "../types/Order.sol";
import {IBaseOrderUtils} from "../types/IBaseOrderUtils.sol";
import {Oracle} from "../lib/Oracle.sol";
import "../Constants.sol";

contract TakeProfitAndStopLoss {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);
    Oracle immutable oracle;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Create orders to
    // 1. Long ETH with USDC collateral
    // 2. Stop loss for ETH price below 90% of current price
    // 3. Take profit for ETH price above 110% of current price
    function createTakeProfitAndStopLossOrders(
        uint256 leverage,
        uint256 usdcAmount
    ) external payable returns (bytes32[] memory keys) {
        uint256 executionFee = 0.1 * 1e18;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        // Task 2.1 - Send execution fee to the order vault

        // Task 2.2 - Send USDC to the order vault

        // Task 2.3 - Create a long order to long ETH with USDC collateral

        // Task 2.4 - Send execution fee to the order vault

        // Task 2.5 - Create a stop loss for 90% of current ETH price

        // Task 2.6 - Send execution fee to the order vault

        // Task 2.7 - Create an order to take profit above 110% of current price
    }
}
