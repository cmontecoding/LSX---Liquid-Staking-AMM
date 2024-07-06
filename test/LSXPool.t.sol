// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {LSXPool, ERC20} from "../src/LSXPool.sol";
import {MockToken} from "./MockToken.sol";

contract LSXPoolTest is Test {
    LSXPool public pool;
    address public user1;
    // these are just mocks
    MockToken public nativeToken;
    MockToken public stakedToken;

    function setUp() public {
        user1 = address(1);
        nativeToken = new MockToken("native", "NAT");
        stakedToken = new MockToken("staked", "STK");

        pool = new LSXPool({
            _targetUtilization: 9000,
            _baseFee: 100,
            _dynamicLPFee: 100,
            _stakedToken: address(stakedToken),
            _nativeToken: address(nativeToken),
            _name: "LSXPool",
            _symbol: "LSX"
        });


    }

    function testConstructor() public {
        assertEq(pool.targetUtilization(), 9000);
        assertEq(pool.baseFee(), 100);
        assertEq(pool.dynamicLPFee(), 100);
        assertEq(address(pool.stakedToken()), address(stakedToken));
        assertEq(address(pool.nativeToken()), address(nativeToken));
        assertEq(pool.name(), "LSXPool");
        assertEq(pool.symbol(), "LSX");
    }

    function testCalculateTotalFee() public {
        // assertEq(pool.calculateTotalFee(1000), 100);
    }


}
