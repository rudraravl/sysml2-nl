// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Market} from "./Market.sol";

library SwapPricingUtils {
    struct GetPriceImpactUsdParams {
        address dataStore;
        Market.Props market;
        address tokenA;
        address tokenB;
        uint256 priceForTokenA;
        uint256 priceForTokenB;
        int256 usdDeltaForTokenA;
        int256 usdDeltaForTokenB;
        bool includeVirtualInventoryImpact;
    }

    struct EmitSwapInfoParams {
        bytes32 orderKey;
        address market;
        address receiver;
        address tokenIn;
        address tokenOut;
        uint256 tokenInPrice;
        uint256 tokenOutPrice;
        uint256 amountIn;
        uint256 amountInAfterFees;
        uint256 amountOut;
        int256 priceImpactUsd;
        int256 priceImpactAmount;
        int256 tokenInPriceImpactAmount;
    }

    struct PoolParams {
        uint256 poolUsdForTokenA;
        uint256 poolUsdForTokenB;
        uint256 nextPoolUsdForTokenA;
        uint256 nextPoolUsdForTokenB;
    }

    struct SwapFees {
        uint256 feeReceiverAmount;
        uint256 feeAmountForPool;
        uint256 amountAfterFees;
        address uiFeeReceiver;
        uint256 uiFeeReceiverFactor;
        uint256 uiFeeAmount;
    }
}
