// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

library GlvDeposit {
    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    struct Addresses {
        address glv;
        address account;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialLongToken;
        address initialShortToken;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
    }

    struct Numbers {
        uint256 marketTokenAmount;
        uint256 initialLongTokenAmount;
        uint256 initialShortTokenAmount;
        uint256 minGlvTokens;
        uint256 updatedAtTime;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    struct Flags {
        bool shouldUnwrapNativeToken;
        bool isMarketTokenDeposit;
    }
}
