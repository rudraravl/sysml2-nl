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
    function totalValueInToken() external view returns (uint256) {}

    // Task 2: Create market increase order
    function increase(uint256 wethAmount)
        external
        payable
        auth
        returns (bytes32 orderKey)
    {}

    // Task 3: Create market decrease order
    // Function call is from the vault when the callback contract is not address(0).
    function decrease(uint256 wethAmount, address callbackContract)
        external
        payable
        auth
        returns (bytes32 orderKey)
    {
        if (callbackContract == address(0)) {
            // Write your code here
        } else {
            // Write your code here
        }
    }

    // Task 4: Cancel an order
    function cancel(bytes32 orderKey) external payable auth {}

    // Task 5: Claim funding fees
    function claim() external {}

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
