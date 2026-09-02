// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Math {
    function add(uint256 x, int256 y) internal pure returns (uint256) {
        return y >= 0 ? x + uint256(y) : x - uint256(-y);
    }

    function toInt256(uint256 x) internal pure returns (int256) {
        require(x <= uint256(type(int256).max), "value > max int256");
        return int256(x);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }
}
