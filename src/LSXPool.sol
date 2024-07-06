// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ILSXPool} from "./interfaces/ILSXPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LSX Pool
/// @notice Pool for Liquid Staking AMM
/// @author andrewcmonte (andrew@definative.xyz)
contract LSXPool is ERC20 {

    /*///////////////////////////////////////////////////////////////
                        CONSTANTS/IMMUTABLES
    ///////////////////////////////////////////////////////////////*/

    /// @notice The target ratio of staked to unstaked tokens in the pool
    uint256 public immutable targetUtilization;

    /// @notice The base fee that a liquidity 
    /// provider must get on every trade
    uint256 public immutable baseFee;

    /// @notice The staked token in the pool
    IERC20 public immutable stakedToken;

    /// @notice The native token in the pool
    ERC20 public immutable nativeToken;

    /*///////////////////////////////////////////////////////////////
                                STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice The percentage that
    /// a liquidity provider will get on every trade
    uint256 public dynamicLPFee;

    /// @notice The amount of native tokens in the pool
    uint256 public nativeTokenBalance; 

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
    ) ERC20(_name, _symbol){
        targetUtilization = _targetUtilization;
        baseFee = _baseFee;
        dynamicLPFee = _dynamicLPFee;
        stakedToken = IERC20(_stakedToken); // just going to make it an IERC20 for now but can change
        nativeToken = ERC20(_nativeToken); // just going to make it an ERC20 for now but can change
    }

    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Calculate the utilization ratio of the pool
    /// @dev this is U in the whitepaper, (Ts + Tu) / T
    /// @return utilization
    function calculateUtilization() public view returns (uint256) {
        // math
    }

    /// @notice Calculate the total fee (base + dynamic)
    /// @param amount The amount to calculate the fee for
    /// @return fee
    function calculateTotalFee(uint256 amount) public view returns (uint256) {
        return amount * dynamicLPFee + baseFee;
    }

    /// @notice Calculate the shares for a given amount of LP
    /// @dev this is Sshares in the whitepaper, Anative / Ttotal
    /// @param amount The amount to calculate the shares for
    /// @return shares
    function calculateShares(uint256 amount) public view returns (uint256) {
        // math
    }

    /// @notice return the total value of the pool
    /// @dev this is Ttotal in the whitepaper
    /// @return total
    function total() public view returns (uint256) {
        // math
    }

    /*///////////////////////////////////////////////////////////////
                                BUY/SELL
    ///////////////////////////////////////////////////////////////*/

    /// @notice Buy staked tokens with native tokens
    function buy(uint256 amount) public {
        
        // give native tokens and get staked tokens back (LST)

    }

    /// @notice Sell staked tokens for unstaked tokens
    /// @notice there is a dynamic fee
    function sell(uint256 amount) public {
        
        // give staked tokens (LST) and get native tokens back

    }

    /*///////////////////////////////////////////////////////////////
                                LIQUIDITY
    ///////////////////////////////////////////////////////////////*/

    /// @notice Provide single sided liquidity
    function provideLiquidity(uint256 amount) public {
        nativeToken.transferFrom(msg.sender, address(this), amount);
        // note: if NT is ETH then this can prob be removed
        // and we can look at .balance instead 
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
}
