// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {PoolTestHelpers} from "./utils/PoolTestHelpers.t.sol";
import {PoolId} from "../src/LSXPool.sol";
import {IAmAmm} from "biddog/interfaces/IAmAmm.sol";

contract BidDogTest is PoolTestHelpers {

    PoolId constant POOL_0 = PoolId.wrap(bytes32(0));

    uint128 internal constant K = 24; // 24 windows (hours)
    uint256 internal constant EPOCH_SIZE = 1 hours;
    uint256 internal constant MIN_BID_MULTIPLIER = 1.1e18; // 10%

    function setUp() public override {
        super.setUp();
    }

    function _swapFeeToPayload(uint24 swapFee) internal pure returns (bytes7) {
        return bytes7(bytes3(swapFee));
    }

    function test1Bid() external {
        // mint bid tokens
        pool.nativeToken().mint(address(this), K * 1e18);

        // make bid
        pool.bid({
            id: POOL_0,
            manager: address(this),
            payload: _swapFeeToPayload(0.01e6),
            rent: 1e18,
            deposit: K * 1e18
        });

        // get bid
        IAmAmm.Bid memory bid = pool.getNextBid(POOL_0);
        assertEq(bid.manager, address(this), "top bid manager incorrect");
        assertEq(bid.payload, _swapFeeToPayload(0.01e6), "top bid swapFee incorrect");
        assertEq(bid.rent, 1e18, "top bid rent incorrect");
        assertEq(bid.deposit, K * 1e18, "top bid deposit incorrect");
        assertEq(bid.epoch, _getEpoch(vm.getBlockTimestamp()), "top bid epoch incorrect");
    }

    function _getEpoch(uint256 timestamp) internal pure returns (uint40) {
        return uint40(timestamp / EPOCH_SIZE);
    }

}