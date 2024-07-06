// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ILSXPool} from "./interfaces/ILSXPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
        _calculateDynamicFee();
        return amount * dynamicLPFee + baseFee;
    }

    /// @notice Calculate the shares for a given amount of LP
    /// @dev this is Sshares in the whitepaper, Anative / Ttotal
    /// @param amount The amount to calculate the shares for
    /// @return shares
    function calculateShares(uint256 amount) public returns (uint256) {
        return amount / total();
    }

    /// @notice return the total value of the pool
    /// @dev this is Ttotal in the whitepaper
    /// @return total
    function total() public returns (uint256) {
        _calculateDynamicFee();
        uint256 total = (nativeTokenBalance *
            (1 + dynamicLPFee) +
            ((stakedTokenBalance + bondedTokenBalance) *
                (1 - dynamicLPFee)));
        return total;
    }

    /*///////////////////////////////////////////////////////////////
                                BUY/SELL
    ///////////////////////////////////////////////////////////////*/

    /// @notice Buy staked tokens with native tokens
    function buy(uint256 amount) public {
        // give native tokens and get staked tokens back (LST)
    }

    /// @notice Sell staked tokens for native tokens
    /// @notice there is a dynamic fee
    function sell(uint256 amount) public {
        if (amount == 0) revert AmountZero();

        uint256 fee = calculateTotalFee(amount);
        uint256 nativeTokenTransferAmount = amount - fee;
        if (nativeTokenTransferAmount == 0) revert NativeTokenTransferAmountZero();    

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
    function provideLiquidity(uint256 amount) public {
        nativeToken.transferFrom(msg.sender, address(this), amount);
        nativeTokenBalance += amount;

        // todo math

        /// @dev mint the LP tokens
        uint256 shares = calculateShares(amount);
        _mint(msg.sender, shares);
    }

    /// @notice Remove liquidity
    function removeLiquidity(uint256 amount) public {
        //return lp tokens and get native tokens back (more in return)
    }

    /*///////////////////////////////////////////////////////////////
                                INTERNAL
    ///////////////////////////////////////////////////////////////*/

    //note: this may eventually be a view function if we remove dynamicLPFee from state and dont put in constructor
    //todo: make these fractions work
    function _calculateDynamicFee() internal {
        uint256 fee;
        uint256 utilization = calculateUtilization();
        if (utilization < targetUtilization) {
            /// @dev this is slope 1
            fee = utilization / targetUtilization * 100;
        } else {
            /// @dev this is slope 2
            fee = (utilization - targetUtilization) / (1 - targetUtilization) * 100;
        }
        /// @dev set state
        dynamicLPFee = fee;
    }

}
