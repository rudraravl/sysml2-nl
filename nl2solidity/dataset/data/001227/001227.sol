// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {IAddressFinder} from "./interfaces/IAddressFinder.sol";
import {IBlastPoints} from "./interfaces/IBlastPoints.sol";

/**
 * @title BlastPoints
 * @notice This contract is a base for future contracts that wish to be recipients of Blast points to inherit from
 * @author predict.fun protocol team
 */
contract BlastPoints {
    /**
     * @param addressFinder Blast address finder
     */
    constructor(address addressFinder) {
        address blastPoints = IAddressFinder(addressFinder).getImplementationAddress("BlastPoints");
        address blastPointsOperator = IAddressFinder(addressFinder).getImplementationAddress("BlastPointsOperator");
        IBlastPoints(blastPoints).configurePointsOperator(blastPointsOperator);
    }
}
