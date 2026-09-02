// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {Math} from "../../lib/Math.sol";
import {Auth} from "../../lib/app/Auth.sol";
import "../../Constants.sol";
import {GmxHelper} from "./GmxHelper.sol";

contract Strategy is Auth, GmxHelper {
    IERC20 public constant weth = IERC20(WETH);

    constructor(address oracle)
        GmxHelper(
            GM_TOKEN_ETH_WETH_USDC,
            WETH,
            USDC,
            CHAINLINK_ETH_USD,
            CHAINLINK_USDC_USD,
            oracle
        )
    {}

    receive() external payable {}

    // Task 1: Calculate total vaule managed by this contract in terms of WETH
    function totalValueInToken() external view returns (uint256) {
        uint256 val = weth.balanceOf(address(this));
        int256 remainingCollateral = getPositionWithPnlInToken();

        if (remainingCollateral >= 0) {
            val += uint256(remainingCollateral);
        } else {
            val -= Math.min(val, uint256(-remainingCollateral));
        }

        return val;
    }

    // Task 2: Create market increase order
    function increase(uint256 wethAmount)
        external
        payable
        auth
        returns (bytes32 orderKey)
    {
        orderKey = createIncreaseShortPositionOrder({
            executionFee: msg.value,
            longTokenAmount: wethAmount
        });
    }

    // Task 3: Create market decrease order
    // Function call is from the vault when the callback contract is not address(0).
    function decrease(uint256 wethAmount, address callbackContract)
        external
        payable
        auth
        returns (bytes32 orderKey)
    {
        if (callbackContract == address(0)) {
            orderKey = createDecreaseShortPositionOrder({
                executionFee: msg.value,
                longTokenAmount: wethAmount,
                receiver: address(this),
                callbackContract: address(0),
                callbackGasLimit: 0
            });
        } else {
            // Called from the vault
            require(
                callbackContract.code.length > 0, "callback is not a contract"
            );
            uint256 maxCallbackGasLimit = getMaxCallbackGasLimit();
            require(
                msg.value > maxCallbackGasLimit,
                "callback gas limit < execution fee"
            );

            int256 total = getPositionWithPnlInToken();
            require(total > 0, "position with pnl <= 0");

            orderKey = createDecreaseShortPositionOrder({
                executionFee: msg.value,
                // Calculate collateral to withdraw
                longTokenAmount: getPositionCollateralAmount() * wethAmount
                    / uint256(total),
                receiver: callbackContract,
                callbackContract: callbackContract,
                callbackGasLimit: maxCallbackGasLimit
            });
        }
    }

    // Task 4: Cancel an order
    function cancel(bytes32 orderKey) external payable auth {
        cancelOrder(orderKey);
    }

    // Task 5: Claim funding fees
    function claim() external {
        claimFundingFees();
    }

    function transfer(address dst, uint256 amount) external auth {
        weth.transfer(dst, amount);
    }

    function withdraw(address token) external auth {
        if (token == address(0)) {
            (bool ok,) = msg.sender.call{value: address(this).balance}("");
            require(ok, "Send ETH failed");
        } else {
            IERC20(token).transfer(
                msg.sender, IERC20(token).balanceOf(address(this))
            );
        }
    }
}
