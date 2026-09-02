// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Price} from "./Price.sol";

library MarketUtils {
    enum FundingRateChangeType {
        NoChange,
        Increase,
        Decrease
    }

    struct MarketPrices {
        Price.Props indexTokenPrice;
        Price.Props longTokenPrice;
        Price.Props shortTokenPrice;
    }

    struct CollateralType {
        uint256 longToken;
        uint256 shortToken;
    }

    struct PositionType {
        CollateralType long;
        CollateralType short;
    }

    struct GetNextFundingAmountPerSizeResult {
        bool longsPayShorts;
        uint256 fundingFactorPerSecond;
        int256 nextSavedFundingFactorPerSecond;
        PositionType fundingFeeAmountPerSizeDelta;
        PositionType claimableFundingAmountPerSizeDelta;
    }

    struct GetNextFundingAmountPerSizeCache {
        PositionType openInterest;
        uint256 longOpenInterest;
        uint256 shortOpenInterest;
        uint256 durationInSeconds;
        uint256 sizeOfLargerSide;
        uint256 fundingUsd;
        uint256 fundingUsdForLongCollateral;
        uint256 fundingUsdForShortCollateral;
    }

    struct GetNextFundingFactorPerSecondCache {
        uint256 diffUsd;
        uint256 totalOpenInterest;
        uint256 fundingFactor;
        uint256 fundingExponentFactor;
        uint256 diffUsdAfterExponent;
        uint256 diffUsdToOpenInterestFactor;
        int256 savedFundingFactorPerSecond;
        uint256 savedFundingFactorPerSecondMagnitude;
        int256 nextSavedFundingFactorPerSecond;
        int256 nextSavedFundingFactorPerSecondWithMinBound;
    }

    struct FundingConfigCache {
        uint256 thresholdForStableFunding;
        uint256 thresholdForDecreaseFunding;
        uint256 fundingIncreaseFactorPerSecond;
        uint256 fundingDecreaseFactorPerSecond;
        uint256 minFundingFactorPerSecond;
        uint256 maxFundingFactorPerSecond;
    }

    struct GetExpectedMinTokenBalanceCache {
        uint256 poolAmount;
        uint256 swapImpactPoolAmount;
        uint256 claimableCollateralAmount;
        uint256 claimableFeeAmount;
        uint256 claimableUiFeeAmount;
        uint256 affiliateRewardAmount;
    }
}
