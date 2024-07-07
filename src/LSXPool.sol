// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ILSXPool} from "./interfaces/ILSXPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    ERC20 public immutable stakedToken;

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
        stakedToken = ERC20(_stakedToken); // just going to make it an ERC20 for now but can change
        nativeToken = ERC20(_nativeToken); // just going to make it an ERC20 for now but can change
    }

    /*///////////////////////////////////////////////////////////////
                                HELPERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Calculate the utilization ratio of the pool
    /// @dev this is U in the whitepaper, (Ts + Tu) / T
    /// @return utilization
    function calculateUtilization() public view returns (uint256) {
        return (stakedTokenBalance + bondedTokenBalance) / nativeTokenBalance;
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
        // give native tokens and get staked tokens back (LST)

        // if we run out of staked tokens then mint more
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
        uint256 amountToWithdraw = Math.mulDiv(sharesToBurn, total(), totalSupply());
        
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
    //todo: make these fractions work
    function _recalculateDynamicFeePercentage() internal {
        uint256 fee;
        uint256 utilization = calculateUtilization();
        if (utilization < targetUtilization) {
            /// @dev this is slope 1
            fee = (utilization / targetUtilization) * 100;
        } else {
            /// @dev this is slope 2
            fee =
                ((utilization - targetUtilization) / (1 - targetUtilization)) *
                100;
        }
        /// @dev set state
        dynamicLPFee = fee;
    }

    //todo add skim/sync to make sure balances are correct

    function sync() public {
        //wip
        nativeTokenBalance = nativeToken.balanceOf(address(this));
        stakedTokenBalance = stakedToken.balanceOf(address(this));
    }
}
