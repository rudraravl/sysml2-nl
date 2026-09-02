// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Market} from "./Market.sol";
import {MarketUtils} from "./MarketUtils.sol";

library ReaderUtils {
    struct VirtualInventory {
        uint256 virtualPoolAmountForLongToken;
        uint256 virtualPoolAmountForShortToken;
        int256 virtualInventoryForPositions;
    }

    struct MarketInfo {
        Market.Props market;
        uint256 borrowingFactorPerSecondForLongs;
        uint256 borrowingFactorPerSecondForShorts;
        BaseFundingValues baseFunding;
        MarketUtils.GetNextFundingAmountPerSizeResult nextFunding;
        VirtualInventory virtualInventory;
        bool isDisabled;
    }

    struct BaseFundingValues {
        MarketUtils.PositionType fundingFeeAmountPerSize;
        MarketUtils.PositionType claimableFundingAmountPerSize;
    }
}
