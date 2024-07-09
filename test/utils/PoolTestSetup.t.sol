// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {LSXPool, ERC20, Math} from "../../src/LSXPool.sol";
import {MockToken} from "./MockToken.sol";
import {LSXPoolInternals} from "./LSXPoolInternals.sol";

contract PoolTestSetup is Test {
    LSXPool public pool;
    LSXPoolInternals public poolInternals;
    address public user1;
    address public user2;
    // these are just mocks
    MockToken public nativeToken;
    MockToken public stakedToken;

    function setUp() public virtual {
        user1 = address(1);
        user2 = address(2);
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

        poolInternals = new LSXPoolInternals({
            _targetUtilization: 9000,
            _baseFee: 100,
            _dynamicLPFee: 100,
            _stakedToken: address(stakedToken),
            _nativeToken: address(nativeToken),
            _name: "LSXPool",
            _symbol: "LSX"
        });
    }
}
