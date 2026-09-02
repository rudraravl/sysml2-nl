// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {IDataStore} from "../interfaces/IDataStore.sol";
import {IReader} from "../interfaces/IReader.sol";
import {Order} from "../types/Order.sol";
import {Position} from "../types/Position.sol";
import {IBaseOrderUtils} from "../types/IBaseOrderUtils.sol";
import {Oracle} from "../lib/Oracle.sol";
import "../Constants.sol";

contract Short {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);
    IDataStore constant dataStore = IDataStore(DATA_STORE);
    IReader constant reader = IReader(READER);
    Oracle immutable oracle;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Create an order to short ETH with USDC collateral
    function createShortOrder(uint256 leverage, uint256 usdcAmount)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        // Task 2.1 - Send execution fee to the order vault

        // Task 2.2 - Send USDC to the order vault

        // Task 2.3 - Create an order to short ETH with USDC collateral
    }

    // Task 3 - Get position key
    function getPositionKey() public view returns (bytes32 key) {}

    // Task 4 - Get position
    function getPosition(bytes32 key)
        public
        view
        returns (Position.Props memory)
    {}

    // Task 5 - Create an order to close the short position created by this contract
    function createCloseOrder() external payable returns (bytes32 key) {
        uint256 executionFee = 0.1 * 1e18;

        // Task 5.1 - Send execution fee to the order vault

        // Task 5.2 - Create an order to close the short position
    }
}
