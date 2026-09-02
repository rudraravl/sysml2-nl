// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IWeth} from "../../interfaces/IWeth.sol";
import {Order} from "../../types/Order.sol";
import {EventUtils} from "../../types/EventUtils.sol";
import {Math} from "../../lib/Math.sol";
import {IStrategy} from "../../lib/app/IStrategy.sol";
import {IVault} from "../../lib/app/IVault.sol";
import {Auth} from "../../lib/app/Auth.sol";
import "../../Constants.sol";

contract WithdrawCallback is Auth {
    IWeth public constant weth = IWeth(WETH);
    IVault public immutable vault;

    mapping(bytes32 => address) public refunds;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    modifier onlyGmx() {
        require(msg.sender == ORDER_HANDLER, "not authorized");
        _;
    }

    function setRefundAccount(bytes32 key, address account) private {
        require(refunds[key] == address(0), "refund account already set");
        refunds[key] = account;
    }

    // Task 1: Refund execution fee callback
    function refundExecutionFee(
        // Order key
        bytes32 key,
        EventUtils.EventLogData memory eventData
    ) external payable onlyGmx {
        address account = refunds[key];
        require(account != address(0), "refund address = 0");

        delete refunds[key];

        uint256 bal = address(this).balance;
        if (bal > 0) {
            (bool ok,) = account.call{value: bal}("");
            require(ok, "refund failed");
        }
    }

    // Task 2: Order execution callback
    function afterOrderExecution(
        // Order key
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external onlyGmx {
        IVault.WithdrawOrder memory withdrawOrder = vault.getWithdrawOrder(key);
        require(withdrawOrder.account != address(0), "invalid order key");
        require(
            order.numbers.orderType == Order.OrderType.MarketDecrease,
            "invalid order type"
        );

        setRefundAccount(key, withdrawOrder.account);
        vault.removeWithdrawOrder(key, true);

        uint256 bal = weth.balanceOf(address(this));
        if (withdrawOrder.weth >= bal) {
            weth.transfer(withdrawOrder.account, bal);
        } else {
            weth.transfer(withdrawOrder.account, withdrawOrder.weth);
            weth.transfer(address(vault), bal - withdrawOrder.weth);
        }
    }

    // Task 3: Order cancellation callback
    function afterOrderCancellation(
        // Order key
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external onlyGmx {
        IVault.WithdrawOrder memory withdrawOrder = vault.getWithdrawOrder(key);
        require(withdrawOrder.account != address(0), "invalid order key");
        require(
            order.numbers.orderType == Order.OrderType.MarketDecrease,
            "invalid order type"
        );

        setRefundAccount(key, withdrawOrder.account);
        vault.removeWithdrawOrder(key, false);
    }

    // Task 4: Order frozen callback
    function afterOrderFrozen(
        // Order key
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external onlyGmx {
        IVault.WithdrawOrder memory withdrawOrder = vault.getWithdrawOrder(key);
        require(withdrawOrder.account != address(0), "invalid order key");
        require(
            order.numbers.orderType == Order.OrderType.MarketDecrease,
            "invalid order type"
        );

        setRefundAccount(key, withdrawOrder.account);
        vault.removeWithdrawOrder(key, false);
    }

    function transfer(address dst, uint256 amount) external auth {
        weth.transfer(dst, amount);
    }
}
