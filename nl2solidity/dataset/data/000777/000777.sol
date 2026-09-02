// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Test.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {Math} from "../../lib/Math.sol";
import {IStrategy} from "../../lib/app/IStrategy.sol";
import {IVault} from "../../lib/app/IVault.sol";
import {Auth} from "../../lib/app/Auth.sol";
import "../../Constants.sol";

contract Vault is Auth {
    uint256 private constant DECIMAL_OFFSET = 6;

    IERC20 public constant weth = IERC20(WETH);
    IStrategy public strategy;
    address public withdrawCallback;

    bool private locked;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => IVault.WithdrawOrder) public withdrawOrders;

    modifier guard() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    function setStrategy(address _strategy) external auth {
        strategy = IStrategy(_strategy);
    }

    function setWithdrawCallback(address _withdrawCallback) external auth {
        withdrawCallback = _withdrawCallback;
    }

    // Task 1: Calculate the total value managed by this contract
    function totalValueInToken() public view returns (uint256) {
        uint256 val = weth.balanceOf(address(this));
        if (address(strategy) != address(0)) {
            val += strategy.totalValueInToken();
        }
        return val;
    }

    function getWithdrawOrder(bytes32 key)
        external
        view
        returns (IVault.WithdrawOrder memory)
    {
        return withdrawOrders[key];
    }

    // Task 2: Deposit WETH and mint shares
    function deposit(uint256 wethAmount)
        external
        guard
        returns (uint256 shares)
    {
        if (address(strategy) != address(0)) {
            strategy.claim();
        }

        uint256 totalVal = totalValueInToken();
        shares = _convertToShares(totalSupply, totalVal, wethAmount);

        weth.transferFrom(msg.sender, address(this), wethAmount);

        _mint(msg.sender, shares);
    }

    // NOTE: Withdrawal delay or gradual profit distribution should be implemented
    // to prevent users from depositing before profit is claimed by the strategy and then
    // immediately withdrawing after.

    // Task 3: Burn shares and withdraw WETH
    function withdraw(uint256 shares)
        external
        payable
        guard
        returns (uint256 wethSent, bytes32 withdrawOrderKey)
    {
        if (address(strategy) != address(0)) {
            strategy.claim();
        }

        uint256 totalVal = totalValueInToken();
        uint256 wethAmount = _convertToWeth(totalSupply, totalVal, shares);
        require(wethAmount > 0, "weth amount = 0");

        uint256 wethRemaining = wethAmount;

        uint256 wethInVault = weth.balanceOf(address(this));
        wethRemaining -= Math.min(wethInVault, wethRemaining);

        if (wethRemaining > 0 && address(strategy) != address(0)) {
            uint256 wethInStrategy = weth.balanceOf(address(strategy));
            if (wethInStrategy > 0) {
                uint256 wethToTransfer = Math.min(wethInStrategy, wethRemaining);
                wethRemaining -= wethToTransfer;
                strategy.transfer(address(this), wethToTransfer);
            }
        }

        if (wethRemaining == 0) {
            _burn(msg.sender, shares);
            wethSent = wethAmount;
            weth.transfer(msg.sender, wethSent);

            if (msg.value > 0) {
                (bool ok,) = msg.sender.call{value: msg.value}("");
                require(ok, "Send ETH failed");
            }
        } else {
            uint256 sharesRemaining = shares * wethRemaining / wethAmount;
            _burn(msg.sender, shares - sharesRemaining);
            _lock(msg.sender, sharesRemaining);
            wethSent = wethAmount - wethRemaining;
            weth.transfer(msg.sender, wethSent);

            if (sharesRemaining > 0) {
                require(
                    withdrawCallback.code.length > 0,
                    "withdraw callback is not a contract"
                );

                require(msg.value > 0, "execution fee = 0");
                withdrawOrderKey = strategy.decrease{value: msg.value}(
                    wethRemaining, withdrawCallback
                );

                require(
                    withdrawOrderKey != bytes32(uint256(0)), "invalid order key"
                );
                require(
                    withdrawOrders[withdrawOrderKey].account == address(0),
                    "order is not empty"
                );
                withdrawOrders[withdrawOrderKey] = IVault.WithdrawOrder({
                    account: msg.sender,
                    shares: sharesRemaining,
                    weth: wethRemaining
                });
            }
        }
    }

    // Task 4: Cancel withdraw order
    function cancelWithdrawOrder(bytes32 key) external guard {
        require(msg.sender == withdrawOrders[key].account, "not owner of order");
        require(
            withdrawCallback.code.length > 0,
            "withdraw callback is not a contract"
        );
        strategy.cancel(key);
    }

    // Task 5: Delete withdraw order. This function is called from WithdrawCallback
    function removeWithdrawOrder(bytes32 key, bool ok) external auth {
        IVault.WithdrawOrder memory withdrawOrder = withdrawOrders[key];

        _unlock(withdrawOrder.account, withdrawOrder.shares);
        if (ok) {
            _burn(withdrawOrder.account, withdrawOrder.shares);
        }

        delete withdrawOrders[key];
    }

    // OpenZeppelin vault inflation protection
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1873ecb38e0833fa3552f58e639eeeb134b82135/contracts/token/ERC20/extensions/ERC4626.sol#L225-L234
    function _convertToShares(
        uint256 totalShares,
        uint256 totalWethInPool,
        uint256 wethAmount
    ) internal pure returns (uint256) {
        if (totalShares == 0 || totalWethInPool == 0) {
            return wethAmount;
        }

        return
            (totalShares + 10 ** DECIMAL_OFFSET) * wethAmount / totalWethInPool;
    }

    function _convertToWeth(
        uint256 totalShares,
        uint256 totalWethInPool,
        uint256 shares
    ) internal pure returns (uint256) {
        return totalWethInPool * shares / (totalShares + 10 ** DECIMAL_OFFSET);
    }

    function _mint(address dst, uint256 shares) internal {
        totalSupply += shares;
        balanceOf[dst] += shares;
    }

    function _burn(address src, uint256 shares) internal {
        totalSupply -= shares;
        balanceOf[src] -= shares;
    }

    function _lock(address src, uint256 shares) internal {
        balanceOf[src] -= shares;
        balanceOf[address(this)] += shares;
    }

    function _unlock(address dst, uint256 shares) internal {
        balanceOf[dst] += shares;
        balanceOf[address(this)] -= shares;
    }

    function transfer(address dst, uint256 amount) external auth {
        weth.transfer(dst, amount);
    }
}
