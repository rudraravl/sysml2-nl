// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Position} from "./Position.sol";
import {PositionPricingUtils} from "./PositionPricingUtils.sol";
import {Market} from "./Market.sol";
import {Price} from "./Price.sol";

library ReaderPricingUtils {
    struct ExecutionPriceResult {
        int256 priceImpactUsd;
        uint256 priceImpactDiffUsd;
        uint256 executionPrice;
    }

    struct PositionInfo {
        Position.Props position;
        PositionPricingUtils.PositionFees fees;
        ExecutionPriceResult executionPriceResult;
        int256 basePnlUsd;
        int256 pnlAfterPriceImpactUsd;
    }

    struct GetPositionInfoCache {
        Market.Props market;
        Price.Props collateralTokenPrice;
        uint256 pendingBorrowingFeeUsd;
        int256 latestLongTokenFundingAmountPerSize;
        int256 latestShortTokenFundingAmountPerSize;
    }
}
