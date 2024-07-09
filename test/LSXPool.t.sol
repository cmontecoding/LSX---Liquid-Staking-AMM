// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {LSXPool, ERC20, Math} from "../src/LSXPool.sol";
import {MockToken} from "./utils/MockToken.sol";
import {PoolTestHelpers} from "./utils/PoolTestHelpers.t.sol";

contract LSXPoolTest is PoolTestHelpers {
    function setUp() public override {
        super.setUp();
    }

    function testConstructor() public  {
        assertEq(pool.targetUtilization(), 9000);
        assertEq(pool.baseFee(), 100);
        assertEq(pool.dynamicLPFee(), 100);
        assertEq(address(pool.stakedToken()), address(stakedToken));
        assertEq(address(pool.nativeToken()), address(nativeToken));
        assertEq(pool.name(), "LSXPool");
        assertEq(pool.symbol(), "LSX");
    }

    // total fee

    function testCalculateTotalFee() public {
        assertEq(pool.calculateTotalFee(20000), 300);
    }

    function testCalculateTotalFeeTooLow() public {
        vm.expectRevert(); //todo add error
        pool.calculateTotalFee(99);
    }

    function testFuzzCalculateTotalFee(uint256 amount) public {
        vm.assume(amount > 99);
        assertEq(pool.calculateTotalFee(amount), Math.mulDiv(amount, 100, 10000) + 100);
    }

    // total

    function testTotal() public {
        // setup
        assertEq(pool.nativeTokenBalance(), 0);
        assertEq(pool.stakedTokenBalance(), 0);
        nativeToken.mint(address(pool), 1000);
        stakedToken.mint(address(pool), 1000);
        pool.sync();
        assertEq(pool.nativeTokenBalance(), 1000);
        assertEq(pool.stakedTokenBalance(), 1000);

        // 1000 nativeTokenBalance
        // + 10 dynamicFee for nativeTokenBalance (1%)
        // + 1000 stakedTokenBalance + 0 bondedTokenBalance
        // - 10 dynamicFee for (stakedTokenBalance + bondedTokenBalance) (1%)
        assertEq(pool.total(), 2000);
    }

    // provide liquidity

    function testProvideLiquidity() public {
        assertBalancesAreZero();

        // provide liquidity
        mintToUserAndLP(user1, 1000);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 1000);
        assertEq(pool.nativeTokenBalance(), 1000);
        assertEq(pool.totalSupply(), 1000);
        assertEq(pool.balanceOf(user1), 1000);
    }

    function testProvideLiquidityMultipleActors() public {
        assertBalancesAreZero();

        // provide liquidity
        mintToUserAndLP(user1, 1000);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 1000);
        assertEq(pool.nativeTokenBalance(), 1000);
        assertEq(pool.totalSupply(), 1000);
        assertEq(pool.balanceOf(user1), 1000);

        // provide liquidity
        mintToUserAndLP(user2, 1000);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 2000);
        assertEq(pool.nativeTokenBalance(), 2000);
        assertEq(pool.totalSupply(), 1990);
        assertEq(pool.balanceOf(user1), 1000);
        // sharesToMint = (1000 * 1000) / 1010 = 990
        // the balance of the pool is 1010 because of the 1% dynamic fee
        assertEq(pool.balanceOf(user2), 990);

        // provide liquidity
        mintToUserAndLP(user1, 200);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 2200);
        assertEq(pool.nativeTokenBalance(), 2200);
        // sharesToMint = (200 * 1990) / 2020 = 197
        // the balance of the pool is 2020 because of the 1% dynamic fee
        assertEq(pool.totalSupply(), 2187);
        assertEq(pool.balanceOf(user1), 1197);
        assertEq(pool.balanceOf(user2), 990);

        assertEq(nativeToken.balanceOf(user1), 0);
        assertEq(nativeToken.balanceOf(user2), 0);
    }

    // remove liquidity

    function testRemoveLiquidity() public {
        assertBalancesAreZero();

        // provide liquidity
        mintToUserAndLP(user1, 1000);
        mintToUserAndLP(user2, 1000);
        mintToUserAndLP(user1, 200);
       
        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 2200);
        assertEq(pool.nativeTokenBalance(), 2200);
        assertEq(pool.totalSupply(), 2187);
        assertEq(pool.balanceOf(user1), 1197);
        assertEq(pool.balanceOf(user2), 990);
    

        // remove liquidity
        vm.prank(user1);
        pool.removeLiquidity(1197);

        // check balances
        // (1197 * 2222) / 2187 = 1216
        // 2200 - 1216 = 984
        assertEq(nativeToken.balanceOf(address(pool)), 984);
        assertEq(pool.nativeTokenBalance(), 984);
        assertEq(pool.totalSupply(), 990);
        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.balanceOf(user2), 990);
        assertEq(nativeToken.balanceOf(user1), 1216);

        // remove liquidity
        vm.prank(user2);
        pool.removeLiquidity(990);

        // check balances
        // (990 * 993) / 990 = 993
        // 984 - 993 = underflow. code is overriden to take all nativeTokenBalance
        assertEq(nativeToken.balanceOf(address(pool)), 0);
        assertEq(pool.nativeTokenBalance(), 0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.balanceOf(user2), 0);
        assertEq(nativeToken.balanceOf(user2), 984);

    }

    // buy

    function testBuy() public {
        // setup
        mintToUserAndLP(user1, 1000);
        mintToUserAndBuy(user2, 1000);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 2000);
        assertEq(pool.nativeTokenBalance(), 2000);
        assertEq(pool.totalSupply(), 1000);
        assertEq(pool.balanceOf(user1), 1000);
        assertEq(pool.balanceOf(user2), 0);
        assertEq(nativeToken.balanceOf(user2), 0);
        // 1000 + 10 (1% dynamic fee) - 100 (base fee)
        assertEq(stakedToken.balanceOf(user2), 910);
        assertEq(stakedToken.balanceOf(address(pool)), 0);
        assertEq(pool.stakedTokenBalance(), 0);
    }

    // sell

    function testSell() public {
        // setup
        mintToUserAndLP(user1, 1000);
        mintToUserAndBuy(user2, 1000);

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 2000);
        assertEq(pool.nativeTokenBalance(), 2000);
        assertEq(pool.totalSupply(), 1000);
        assertEq(pool.balanceOf(user1), 1000);
        assertEq(pool.balanceOf(user2), 0);
        assertEq(nativeToken.balanceOf(user2), 0);
        assertEq(stakedToken.balanceOf(user2), 910);
        assertEq(stakedToken.balanceOf(address(pool)), 0);
        assertEq(pool.stakedTokenBalance(), 0);

        // sell
        vm.startPrank(user2);
        stakedToken.approve(address(pool), 910);
        pool.sell(910);
        vm.stopPrank();

        // check balances
        assertEq(nativeToken.balanceOf(address(pool)), 1199);
        assertEq(pool.nativeTokenBalance(), 1199);
        assertEq(pool.totalSupply(), 1000);
        assertEq(pool.balanceOf(user1), 1000);
        assertEq(pool.balanceOf(user2), 0);
        assertEq(nativeToken.balanceOf(user2), 801);
        assertEq(stakedToken.balanceOf(user2), 0);
        assertEq(stakedToken.balanceOf(address(pool)), 910);
        assertEq(pool.stakedTokenBalance(), 910);
    }

    // dynamic fee

    function testRecalculateDynamicFee() public {
        //test dynamic fee
    }


}
