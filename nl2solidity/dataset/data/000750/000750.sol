// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IExchangeRouter} from "../interfaces/IExchangeRouter.sol";
import {IDataStore} from "../interfaces/IDataStore.sol";
import {Keys} from "../lib/Keys.sol";
import "../Constants.sol";

contract ClaimFundingFees {
    IDataStore constant dataStore = IDataStore(DATA_STORE);
    IExchangeRouter constant exchangeRouter = IExchangeRouter(EXCHANGE_ROUTER);

    // Task 1 - Get claimable funding fee
    function getClaimableAmount(address market, address token)
        external
        view
        returns (uint256)
    {}

    // Task 2 - Claim funding fees
    function claimFundingFees() external {}
}
