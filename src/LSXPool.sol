// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ILSXPool} from "./interfaces/ILSXPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "../test/utils/MockToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title LSX Pool
/// @notice Pool for Liquid Staking AMM
/// @author andrewcmonte (andrew@definative.xyz)
contract LSXPool is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice error when user tries to buy/sell/lp 0 tokens
    error AmountZero();

    /// @notice error when user tries to transfer 0 native tokens
    error NativeTokenTransferAmountZero();

    /// @notice error when the fee is too low
    error FeeTooLow();

    /*///////////////////////////////////////////////////////////////
                        CONSTANTS/IMMUTABLES
    ///////////////////////////////////////////////////////////////*/

    /// @notice The target ratio of staked to unstaked tokens in the pool
    /// @dev this is in basis points
    uint256 public immutable targetUtilization;

    /// @notice The base fee that a liquidity
    /// provider must get on every trade
    uint256 public immutable baseFee;

    /// @notice The staked token in the pool
    MockToken public immutable stakedToken;

    /// @notice The native token in the pool
    ERC20 public immutable nativeToken;

    /// @notice The maximum amount of basis points
    uint256 public constant MAX_BASIS_POINTS = 10_000;

    /*///////////////////////////////////////////////////////////////
                                STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice The percentage that
    /// a liquidity provider will get on every trade
    /// @dev this is in basis points
    uint256 public dynamicLPFee;

    /// @notice The amount of native tokens in the pool
    /// @dev this is T in the whitepaper
    uint256 public nativeTokenBalance;

    /// @notice The amount of staked tokens in the pool
    /// @dev this is Ts in the whitepaper
    uint256 public stakedTokenBalance;

    /// @notice The amount of bonded tokens in the pool
    /// @dev this is Tu in the whitepaper
    uint256 public bondedTokenBalance;

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /// @param _targetUtilization The target ratio of staked to unstaked tokens in the pool
    /// @param _baseFee The base fee that a liquidity provider will get on every trade
    /// @param _dynamicLPFee The percentage that a liquidity provider will get on every trade
    /// @param _stakedToken The staked token in the pool
    constructor(
        uint256 _targetUtilization,
        uint256 _baseFee,
        uint256 _dynamicLPFee,
        address _stakedToken,
        address _nativeToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        targetUtilization = _targetUtilization;
        baseFee = _baseFee;
        dynamicLPFee = _dynamicLPFee;
        stakedToken = MockToken(_stakedToken); // just going to make it a MockERC20 for now but can change
        nativeToken = ERC20(_nativeToken); // just going to make it an ERC20 for now but can change
    }

    /*///////////////////////////////////////////////////////////////
                                HELPERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Calculate the utilization ratio of the pool
    /// @dev this is U in the whitepaper, (Ts + Tu) / T
    /// @return utilization
    function calculateUtilization() public view returns (uint256) {
        /// @dev return the ratio in basis points
        return
            Math.mulDiv(
                stakedTokenBalance + bondedTokenBalance,
                MAX_BASIS_POINTS,
                nativeTokenBalance
            );
    }

    /// @notice Calculate the total fee (base + dynamic)
    /// @param amount The amount to calculate the fee for
    /// @return fee
    function calculateTotalFee(uint256 amount) public returns (uint256) {
        uint256 dynamicFee = calculateDynamicFee(amount);
        if (dynamicFee == 0) revert FeeTooLow();
        return dynamicFee + baseFee;
    }

    function calculateDynamicFee(uint256 amount) public returns (uint256) {
        //_recalculateDynamicFeePercentage();
        return Math.mulDiv(amount, dynamicLPFee, MAX_BASIS_POINTS);
    }

    /// @notice return the total value of the pool
    /// @dev this is Ttotal in the whitepaper
    /// @return total
    function total() public returns (uint256) {
        uint256 total = (nativeTokenBalance +
            calculateDynamicFee(nativeTokenBalance) +
            (stakedTokenBalance + bondedTokenBalance) -
            calculateDynamicFee(stakedTokenBalance + bondedTokenBalance));
        return total;
    }

    /*///////////////////////////////////////////////////////////////
                                BUY/SELL
    ///////////////////////////////////////////////////////////////*/

    /// @notice Buy staked tokens with native tokens
    function buy(uint256 amount) public {
        if (amount == 0) revert AmountZero();

        /// @dev this is the formula for buying
        /// Astaked(1 + (F-2Fb))
        uint256 stakedTokenTransferAmount = amount +
            calculateDynamicFee(amount) -
            baseFee;

        /// @dev if we run out of staked tokens then mint more
        if (stakedTokenBalance < stakedTokenTransferAmount) {
            _mintLST(stakedTokenTransferAmount - stakedTokenBalance);
        }

        // update state
        stakedTokenBalance -= stakedTokenTransferAmount;
        nativeTokenBalance += amount;

        // do token transfers
        stakedToken.transfer(msg.sender, stakedTokenTransferAmount);
        nativeToken.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Sell staked tokens for native tokens
    /// @notice there is a dynamic fee
    function sell(uint256 amount) public {
        if (amount == 0) revert AmountZero();

        uint256 fee = calculateTotalFee(amount);
        uint256 nativeTokenTransferAmount = amount - fee;
        if (nativeTokenTransferAmount == 0)
            revert NativeTokenTransferAmountZero();

        // update state
        stakedTokenBalance += amount;
        nativeTokenBalance -= nativeTokenTransferAmount;

        // do token transfers
        stakedToken.transferFrom(msg.sender, address(this), amount);
        nativeToken.transfer(msg.sender, nativeTokenTransferAmount);
    }

    /*///////////////////////////////////////////////////////////////
                                LIQUIDITY
    ///////////////////////////////////////////////////////////////*/

    /// @notice Provide single sided liquidity
    function provideLiquidity(uint256 amountToDeposit) public {
        if (amountToDeposit == 0) revert AmountZero();

        uint256 sharesToMint;
        if (totalSupply() == 0) {
            sharesToMint = amountToDeposit;
        } else {
            /// @dev (amount to deposit * total shares before mint) / balance of pool before deposit
            sharesToMint = Math.mulDiv(amountToDeposit, totalSupply(), total());
        }

        nativeTokenBalance += amountToDeposit;
        _mint(msg.sender, sharesToMint);
        nativeToken.transferFrom(msg.sender, address(this), amountToDeposit);
    }

    /// @notice Remove liquidity
    function removeLiquidity(uint256 sharesToBurn) public {
        if (sharesToBurn == 0) revert AmountZero();

        /// @dev (shares to burn * balance of pool before withdraw) / total shares before burn
        uint256 amountToWithdraw = Math.mulDiv(
            sharesToBurn,
            total(),
            totalSupply()
        );

        //todo fix underflow case: unequal math when removing liquidity
        if (amountToWithdraw > nativeTokenBalance) {
            amountToWithdraw = nativeTokenBalance;
        }

        nativeTokenBalance -= amountToWithdraw;
        _burn(msg.sender, sharesToBurn);
        nativeToken.transfer(msg.sender, amountToWithdraw);
    }

    /*///////////////////////////////////////////////////////////////
                                INTERNAL
    ///////////////////////////////////////////////////////////////*/

    //note: this may eventually be a view function if we remove dynamicLPFee from state and dont put in constructor
    function _recalculateDynamicFeePercentage() internal {
        //todo test this function and fix math. not sure if Ut is expected to be < 1 or > 1
        uint256 dynamicFee;
        uint256 utilization = calculateUtilization();
        uint256 slope1 = Math.mulDiv(
            utilization,
            MAX_BASIS_POINTS,
            targetUtilization
        );
        if (utilization < targetUtilization) {
            /// @dev this is slope 1
            dynamicFee = slope1;
        } else {
            /// @dev this is slope 1 + slope 2
            uint256 slope2 = ((utilization - targetUtilization) *
                MAX_BASIS_POINTS) / (MAX_BASIS_POINTS - targetUtilization);
            dynamicFee = slope1 + slope2;
        }
        /// @dev set state
        dynamicLPFee = dynamicFee;
    }

    /// @dev mint more LST at a rate of 1:1 at the minter contract
    function _mintLST(uint256 amount) internal {
        uint256 stakedTokenBalanceBefore = stakedToken.balanceOf(address(this));

        // todo integrate minter contract. this is temporary for testing
        stakedToken.mint(address(this), amount);

        uint256 stakedTokenBalanceAfter = stakedToken.balanceOf(address(this));
        require(
            stakedTokenBalanceAfter > stakedTokenBalanceBefore,
            "LSXPool: minting failed"
        );

        stakedTokenBalance += amount;
    }

    //todo add skim/sync to make sure balances are correct

    function sync() public {
        //wip
        nativeTokenBalance = nativeToken.balanceOf(address(this));
        stakedTokenBalance = stakedToken.balanceOf(address(this));
    }
}
