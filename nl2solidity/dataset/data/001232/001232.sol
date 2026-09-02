// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title InterestLib
 * @notice A library to help calculate interest rates
 *
 * @dev The mean tropical year in seconds is used as the number of compounding periods in the equation for APY.
 *      The mean tropical year is approximately 365 days, 5 hours, 48 minutes and 45 seconds or 31,556,925 seconds.
 *      The APY equation is rearranged for the interest rate divided by number of compounding periods.
 *      The constant TEN_THOUSAND_APY is the interest rate divided by number of compounding periods for an APY of 10,000%.
 */
library InterestLib {
    uint256 public constant ONE = 10 ** 18;
    uint256 public constant TEN_THOUSAND_APY = 146_247_483_013;

    function pow(uint256 _base, uint256 _exponent) public pure returns (uint256) {
        if (_exponent == 0) {
            return ONE;
        } else if (_exponent % 2 == 0) {
            uint256 half = pow(_base, _exponent / 2);
            return half * half / ONE;
        } else {
            return _base * pow(_base, _exponent - 1) / ONE;
        }
    }
}