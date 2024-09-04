// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {LSXPool} from "../../src/LSXPool.sol";

/// @dev this contract exposes the internal functions for testing
contract LSXPoolInternals is LSXPool {

    constructor(
        uint256 _targetUtilization,
        uint256 _baseFee,
        uint256 _dynamicLPFee,
        address _stakedToken,
        address _nativeToken,
        string memory _name,
        string memory _symbol
    ) LSXPool(_targetUtilization, _baseFee, _dynamicLPFee, _stakedToken, _nativeToken, _name, _symbol) {
    }

    function _recalculateDynamicFeePercentageInternal() public {
        super._recalculateDynamicFeePercentage();
    }

}