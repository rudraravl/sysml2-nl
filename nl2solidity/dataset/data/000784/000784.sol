// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

library GlvWithdrawal {
    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    struct Addresses {
        address glv;
        address market;
        address account;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
    }

    struct Numbers {
        uint256 glvTokenAmount;
        uint256 minLongTokenAmount;
        uint256 minShortTokenAmount;
        uint256 updatedAtTime;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    struct Flags {
        bool shouldUnwrapNativeToken;
    }
}
