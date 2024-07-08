// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {PoolTestSetup} from "./PoolTestSetup.t.sol";

contract PoolTestHelpers is PoolTestSetup {
    function setUp() public virtual override {
        super.setUp();
    }

    function mintToUserAndLP(address user, uint256 amount) public {
        nativeToken.mint(user, amount);
        vm.startPrank(user);
        nativeToken.approve(address(pool), amount);
        pool.provideLiquidity(amount);
        vm.stopPrank();
    }

    function assertBalancesAreZero() public {
        assertEq(nativeToken.balanceOf(address(pool)), 0);
        assertEq(stakedToken.balanceOf(address(pool)), 0);
        assertEq(pool.nativeTokenBalance(), 0);
        assertEq(pool.stakedTokenBalance(), 0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.balanceOf(user2), 0);
    }
    
}
