// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title NegRiskIdLib
/// @notice Functions for the NegRiskAdapter Market and QuestionIds
/// @notice MarketIds are the keccak256 hash of the oracle, feeBips, and metadata, with the final 8 bits set to 0
/// @notice QuestionIds share the first 31 bytes with their corresponding MarketId, and the final byte consists of the
/// questionIndex
library NegRiskIdLib {
    bytes32 private constant MASK = bytes32(type(uint256).max) << 8;

    /// @notice Returns the MarketId for a given QuestionId
    /// @param _questionId - the questionId
    /// @return marketId   - the marketId
    function getMarketId(bytes32 _questionId) internal pure returns (bytes32) {
        return _questionId & MASK;
    }
}