// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Order} from "./Order.sol";
import {Market} from "./Market.sol";

library BaseOrderUtils {
    struct ExecuteOrderParams {
        ExecuteOrderParamsContracts contracts;
        bytes32 key;
        Order.Props order;
        Market.Props[] swapPathMarkets;
        uint256 minOracleTimestamp;
        uint256 maxOracleTimestamp;
        Market.Props market;
        address keeper;
        uint256 startingGas;
        Order.SecondaryOrderType secondaryOrderType;
    }

    struct ExecuteOrderParamsContracts {
        address dataStore;
        address eventEmitter;
        address orderVault;
        address oracle;
        address swapHandler;
        address referralStorage;
    }

    struct GetExecutionPriceCache {
        uint256 price;
        uint256 executionPrice;
        int256 adjustedPriceImpactUsd;
    }
}
