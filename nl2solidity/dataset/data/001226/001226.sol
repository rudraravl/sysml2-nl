// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {IAddressFinder} from "./interfaces/IAddressFinder.sol";
import {IBlast, YieldMode, GasMode} from "./interfaces/IBlast.sol";
import {BlastPoints} from "./BlastPoints.sol";

/**
 * @title BlastNativeYield
 * @notice This contract is a base contract for inheriting functions to claim native yield and for those that wish to recieve Blast points
 * @author predict.fun protocol team
 */
contract BlastNativeYield is BlastPoints {
    /**
     * @param addressFinder Blast address finder
     */
    constructor(address addressFinder) BlastPoints(addressFinder) {
        address blast = IAddressFinder(addressFinder).getImplementationAddress("Blast");
        address governor = IAddressFinder(addressFinder).getImplementationAddress("Governor");
        IBlast(blast).configure(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, governor);
    }
}
