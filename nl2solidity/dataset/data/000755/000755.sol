// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {IReader} from "../interfaces/IReader.sol";
import {IDataStore} from "../interfaces/IDataStore.sol";
import {Order} from "../types/Order.sol";
import {IBaseOrderUtils} from "../types/IBaseOrderUtils.sol";
import "../Constants.sol";

contract MarketSwap {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant dai = IERC20(DAI);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);
    IDataStore constant dataStore = IDataStore(DATA_STORE);
    IReader constant reader = IReader(READER);

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Create an order to swap WETH to DAI
    function createOrder(uint256 wethAmount)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;
        weth.transferFrom(msg.sender, address(this), wethAmount);

        // Task 2.1 - Send execution fee to the order vault

        // Task 2.2 - Send WETH to the order vault

        // Task 2.3 - Create an order to swap WETH to DAI
    }

    // Task 3 - Get order
    function getOrder(bytes32 key) external view returns (Order.Props memory) {}
}
