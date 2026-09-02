// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseOrderUtils} from "./BaseOrderUtils.sol";
import {Market} from "./Market.sol";
import {MarketUtils} from "./MarketUtils.sol";
import {Order} from "./Order.sol";
import {Position} from "./Position.sol";
import {Price} from "./Price.sol";

library PositionUtils {
    struct UpdatePositionParams {
        BaseOrderUtils.ExecuteOrderParamsContracts contracts;
        Market.Props market;
        Order.Props order;
        bytes32 orderKey;
        Position.Props position;
        bytes32 positionKey;
        Order.SecondaryOrderType secondaryOrderType;
    }

    struct UpdatePositionParamsContracts {
        address dataStore;
        address eventEmitter;
        address oracle;
        address swapHandler;
        address referralStorage;
    }

    struct WillPositionCollateralBeSufficientValues {
        uint256 positionSizeInUsd;
        uint256 positionCollateralAmount;
        int256 realizedPnlUsd;
        int256 openInterestDelta;
    }

    struct DecreasePositionCollateralValuesOutput {
        address outputToken;
        uint256 outputAmount;
        address secondaryOutputToken;
        uint256 secondaryOutputAmount;
    }

    struct DecreasePositionCollateralValues {
        uint256 executionPrice;
        uint256 remainingCollateralAmount;
        int256 basePnlUsd;
        int256 uncappedBasePnlUsd;
        uint256 sizeDeltaInTokens;
        int256 priceImpactUsd;
        uint256 priceImpactDiffUsd;
        DecreasePositionCollateralValuesOutput output;
    }

    struct DecreasePositionCache {
        MarketUtils.MarketPrices prices;
        int256 estimatedPositionPnlUsd;
        int256 estimatedRealizedPnlUsd;
        int256 estimatedRemainingPnlUsd;
        address pnlToken;
        Price.Props pnlTokenPrice;
        Price.Props collateralTokenPrice;
        uint256 initialCollateralAmount;
        uint256 nextPositionSizeInUsd;
        uint256 nextPositionBorrowingFactor;
    }

    struct GetPositionPnlUsdCache {
        int256 positionValue;
        int256 totalPositionPnl;
        int256 uncappedTotalPositionPnl;
        address pnlToken;
        uint256 poolTokenAmount;
        uint256 poolTokenPrice;
        uint256 poolTokenUsd;
        int256 poolPnl;
        int256 cappedPoolPnl;
        uint256 sizeDeltaInTokens;
        int256 positionPnlUsd;
        int256 uncappedPositionPnlUsd;
    }

    struct IsPositionLiquidatableInfo {
        int256 remainingCollateralUsd;
        int256 minCollateralUsd;
        int256 minCollateralUsdForLeverage;
    }

    struct IsPositionLiquidatableCache {
        int256 positionPnlUsd;
        uint256 minCollateralFactor;
        Price.Props collateralTokenPrice;
        uint256 collateralUsd;
        int256 usdDeltaForPriceImpact;
        int256 priceImpactUsd;
        bool hasPositiveImpact;
    }

    struct GetExecutionPriceForDecreaseCache {
        int256 priceImpactUsd;
        uint256 priceImpactDiffUsd;
        uint256 executionPrice;
    }
}
