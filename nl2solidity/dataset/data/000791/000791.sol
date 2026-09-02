// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Position} from "./Position.sol";
import {PositionPricingUtils} from "./PositionPricingUtils.sol";
import {ReaderPricingUtils} from "./ReaderPricingUtils.sol";
import {Market} from "./Market.sol";
import {Price} from "./Price.sol";

library ReaderPositionUtils {
    struct PositionInfo {
        Position.Props position;
        PositionPricingUtils.PositionFees fees;
        ReaderPricingUtils.ExecutionPriceResult executionPriceResult;
        int256 basePnlUsd;
        int256 uncappedBasePnlUsd;
        int256 pnlAfterPriceImpactUsd;
    }

    struct GetPositionInfoCache {
        Market.Props market;
        Price.Props collateralTokenPrice;
        uint256 pendingBorrowingFeeUsd;
    }
}
