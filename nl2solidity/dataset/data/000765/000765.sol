// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

library Role {
    bytes32 public constant ROLE_ADMIN = keccak256(abi.encode("ROLE_ADMIN"));
    bytes32 public constant TIMELOCK_ADMIN =
        keccak256(abi.encode("TIMELOCK_ADMIN"));
    bytes32 public constant TIMELOCK_MULTISIG =
        keccak256(abi.encode("TIMELOCK_MULTISIG"));
    bytes32 public constant CONFIG_KEEPER =
        keccak256(abi.encode("CONFIG_KEEPER"));
    bytes32 public constant LIMITED_CONFIG_KEEPER =
        keccak256(abi.encode("LIMITED_CONFIG_KEEPER"));
    bytes32 public constant CONTROLLER = keccak256(abi.encode("CONTROLLER"));
    bytes32 public constant GOV_TOKEN_CONTROLLER =
        keccak256(abi.encode("GOV_TOKEN_CONTROLLER"));
    bytes32 public constant ROUTER_PLUGIN =
        keccak256(abi.encode("ROUTER_PLUGIN"));
    bytes32 public constant MARKET_KEEPER =
        keccak256(abi.encode("MARKET_KEEPER"));
    bytes32 public constant FEE_KEEPER = keccak256(abi.encode("FEE_KEEPER"));
    bytes32 public constant FEE_DISTRIBUTION_KEEPER =
        keccak256(abi.encode("FEE_DISTRIBUTION_KEEPER"));
    bytes32 public constant ORDER_KEEPER = keccak256(abi.encode("ORDER_KEEPER"));
    bytes32 public constant FROZEN_ORDER_KEEPER =
        keccak256(abi.encode("FROZEN_ORDER_KEEPER"));
    bytes32 public constant PRICING_KEEPER =
        keccak256(abi.encode("PRICING_KEEPER"));
    bytes32 public constant LIQUIDATION_KEEPER =
        keccak256(abi.encode("LIQUIDATION_KEEPER"));
    bytes32 public constant ADL_KEEPER = keccak256(abi.encode("ADL_KEEPER"));
    bytes32 public constant CONTRIBUTOR_KEEPER =
        keccak256(abi.encode("CONTRIBUTOR_KEEPER"));
    bytes32 public constant CONTRIBUTOR_DISTRIBUTOR =
        keccak256(abi.encode("CONTRIBUTOR_DISTRIBUTOR"));
}
