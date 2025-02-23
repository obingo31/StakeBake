// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakeBake} from "src/StakeBake.sol";

// Invariant Contracts
import {BaseInvariants} from "./invariants/base/BaseInvariants.t.sol";
import {StakingInvariants} from "./invariants/StakingInvariants.t.sol";
import {RewardInvariants} from "./invariants/RewardInvariants.t.sol";

import "forge-std/console.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev Recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants, StakingInvariants, and RewardInvariants
abstract contract Invariants is BaseInvariants, StakingInvariants, RewardInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_BASE_INVARIANT() public returns (bool) {
        // Ensure the total reward fund never goes negative
        assert(stakeBake.totalRewardFund() >= 0);

        // Ensure the total staked amount across users matches the total staked amount in the pool
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            uint256 totalStaked;
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                (uint72 tokenAmount,,,,) = stakeBake.userStakes(actorAddresses[j], i);
                totalStaked += tokenAmount;
            }
            (,, uint256 poolTotalStaked,,,) = stakeBake.pools(i);
            assertEq(totalStaked, poolTotalStaked);
        }

        // Ensure the total balance of reward tokens across users never exceeds the total supply
        uint256 totalTokenBalance;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalTokenBalance += rewardToken.balanceOf(actorAddresses[i]);
        }
        assertLe(totalTokenBalance, rewardToken.totalSupply());

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     STAKING INVARIANTS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_STAKING_INVARIANT() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            // Ensure the total reward points across users match the total reward points in the pool
            uint256 totalUserPoints;
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                totalUserPoints += stakeBake.userRewardPoints(actorAddresses[j], i);
            }
            uint256 totalPoolPoints = stakeBake.poolTotalRewardPoints(i);
            assertEq(totalUserPoints, totalPoolPoints);

            // Ensure the locking period of a stake never exceeds the staking program duration
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                (,, uint24 lockingPeriod,,) = stakeBake.userStakes(actorAddresses[j], i);
                assertLe(lockingPeriod, stakeBake.stakingProgramEndsBlock() - block.number);
            }

            // Ensure the total staked amount in a pool never exceeds the total supply of the staking token
            (,, uint256 poolTotalStaked,,,) = stakeBake.pools(i);
            assertLe(poolTotalStaked, stakingTokens[i].totalSupply());
        }

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     REWARD INVARIANTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_REWARD_INVARIANT() public returns (bool) {
        // Ensure no user can have a negative balance of staking tokens
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            for (uint256 j = 0; j < stakingTokens.length; j++) {
                assertGe(stakingTokens[j].balanceOf(actorAddresses[i]), 0);
            }
        }

        // Ensure no user can have a negative balance of reward tokens
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            assertGe(rewardToken.balanceOf(actorAddresses[i]), 0);
        }

        // Ensure the total granted tokens never exceed the total reward fund
        uint256 totalGranted;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalGranted += stakeBake.grantedTokens(actorAddresses[i]);
        }
        assertLe(totalGranted, stakeBake.totalRewardFund());

        // Ensure the total released tokens never exceed the total granted tokens
        uint256 totalReleased;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalReleased += stakeBake.releasedTokens(actorAddresses[i]);
        }
        assertLe(totalReleased, totalGranted);

        return true;
    }
}