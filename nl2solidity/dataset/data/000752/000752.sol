// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {IDataStore} from "../interfaces/IDataStore.sol";
import {IReader} from "../interfaces/IReader.sol";
import {Order} from "../types/Order.sol";
import {Market} from "../types/Market.sol";
import {MarketPoolValueInfo} from "../types/MarketPoolValueInfo.sol";
import {Price} from "../types/Price.sol";
import {DepositUtils} from "../types/DepositUtils.sol";
import {WithdrawalUtils} from "../types/WithdrawalUtils.sol";
import {Keys} from "../lib/Keys.sol";
import {Oracle} from "../lib/Oracle.sol";
import "../Constants.sol";

contract GmLiquidity {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IERC20 constant gmToken = IERC20(GM_TOKEN_BTC_WBTC_USDC);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);
    IDataStore constant dataStore = IDataStore(DATA_STORE);
    IReader constant reader = IReader(READER);

    Oracle immutable oracle;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }

    // Task 1 - Receive execution fee refund from GMX

    // Task 2 - Get market token price
    function getMarketTokenPriceUsd() public view returns (uint256) {
        // 1 USD = 1e8
        uint256 btcPrice = oracle.getPrice(CHAINLINK_BTC_USD);
    }

    // Task 3 - Create an order to deposit USDC into GM_TOKEN_BTC_WBTC_USDC
    function createDeposit(uint256 usdcAmount)
        external
        payable
        returns (bytes32 key)
    {
        uint256 executionFee = 0.1 * 1e18;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        // Task 3.1 - Send execution fee to the deposit vault

        // Task 3.2 - Send USDC to the deposit vault

        // Task 3.3 - Create an order to deposit USDC into GM_TOKEN_BTC_WBTC_USDC
        // Assume 1 USDC = 1 USD
        // USDC has 6 decimals
        // Market token has 18 decimals
    }

    // Task 4 - Create an order to withdraw liquidity from GM_TOKEN_BTC_WBTC_USDC
    function createWithdrawal() external payable returns (bytes32 key) {
        uint256 executionFee = 0.1 * 1e18;

        // Task 4.1 - Send execution fee to the withdrawal vault

        // Task 4.2 - Send GM_TOKEN_BTC_WBTC_USDC to the withdrawal vault

        // Task 4.3 - Create an order to withdraw WBTC and USDC from GM_TOKEN_BTC_WBTC_USDC
        // Assume 1 USD = 1 USDC
    }
}
