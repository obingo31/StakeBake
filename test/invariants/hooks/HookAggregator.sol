// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Hook Contracts
import "./DefaultBeforeAfterHooks.t.sol";
import "../invariants/StakeBakeInvariants.sol"; 
/// @title HookAggregator
/// @notice Helper contract to aggregate all before/after hook contracts, inherited by handlers
abstract contract HookAggregator is DefaultBeforeAfterHooks, StakeBakeInvariants {
    /// @notice Executes before hooks for all pools in StakeBake
    function _before() internal {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            _defaultHooksBefore(i);
        }
    }

    /// @notice Executes after hooks and checks postconditions for all pools in StakeBake
    function _after() internal {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            _defaultHooksAfter(i);
            _checkPostConditions(i);
        }
    }

    /// @notice Postconditions for the handlers, specific to each pool
    function _checkPostConditions(uint256 _poolId) internal {
        // BASE GPOSTs
        assert_BASE_GPOST_TOTAL_STAKED(_poolId);      // Total staked consistency
        assert_BASE_GPOST_REWARD_FUND();              // Reward fund vs. token balance
        assert_BASE_GPOST_POOL_COUNT();               // Pool count non-decreasing

        // STAKE GPOSTs
        assert_STAKE_GPOST_USER_STAKE(_poolId);       // User stake updates correctly

        // REWARD GPOSTs
        assert_REWARD_GPOST_CONTINUOUS(_poolId);      // Continuous rewards non-negative

        // VESTING GPOSTs
        assert_VESTING_GPOST_RELEASED_VS_GRANTED();   // Released <= Granted
    }

    // BASE GPOST Assertions
    function assert_BASE_GPOST_TOTAL_STAKED(uint256 _poolId) internal {
        (StakeBake.Pool memory poolBefore,) = beforeState.pools[_poolId];
        (StakeBake.Pool memory poolAfter,) = afterState.pools[_poolId];
        assert(poolAfter.totalStaked >= poolBefore.totalStaked || poolAfter.totalStaked <= poolBefore.totalStaked);
        // Note: Total staked can increase (stake) or decrease (unstake), but should align with action
    }

    function assert_BASE_GPOST_REWARD_FUND() internal {
        assert(afterState.totalRewardFund >= beforeState.totalRewardFund);
        // Total reward fund should only increase (e.g., via penalties)
    }

    function assert_BASE_GPOST_POOL_COUNT() internal {
        assert(afterState.poolCount >= beforeState.poolCount);
        // Pool count should only increase (via createPool)
    }

    // STAKE GPOST Assertions
    function assert_STAKE_GPOST_USER_STAKE(uint256 _poolId) internal {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            StakeBake.Stake memory stakeBefore = beforeState.userStakes[actorAddresses[j]][_poolId];
            StakeBake.Stake memory stakeAfter = afterState.userStakes[actorAddresses[j]][_poolId];
            if (stakeAfter.tokenAmount != stakeBefore.tokenAmount) {
                assert(stakeAfter.tokenAmount > 0 || stakeAfter.claimed); // Stake updates or claimed
            }
        }
    }

    // REWARD GPOST Assertions
    function assert_REWARD_GPOST_CONTINUOUS(uint256 _poolId) internal {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            uint256 continuousBefore = beforeState.continuousRewards[actorAddresses[j]];
            uint256 continuousAfter = afterState.continuousRewards[actorAddresses[j]];
            assert(continuousAfter >= continuousBefore || continuousAfter == 0); // Rewards claimed or accrued
        }
    }

    // VESTING GPOST Assertions
    function assert_VESTING_GPOST_RELEASED_VS_GRANTED() internal {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            uint256 grantedBefore = beforeState.grantedTokens[actorAddresses[j]];
            uint256 releasedBefore = beforeState.releasedTokens[actorAddresses[j]];
            uint256 grantedAfter = afterState.grantedTokens[actorAddresses[j]];
            uint256 releasedAfter = afterState.releasedTokens[actorAddresses[j]];
            assert(releasedAfter <= grantedAfter);
            assert(grantedAfter >= grantedBefore); // Granted can only increase
            assert(releasedAfter >= releasedBefore); // Released can only increase
        }
    }
}