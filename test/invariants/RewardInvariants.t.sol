// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./invariants/BaseInvariants.t.sol";

abstract contract RewardInvariants is BaseInvariants {
    function assert_REWARD_INVARIANT_CONTINUOUS(uint256 _poolId) internal view {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            assertGe(stakeBake.continuousRewards(actorAddresses[j]), 0, REWARD_INVARIANT_A);
        }
    }

    function assert_REWARD_INVARIANT_EARNED(address _actor, uint256 _poolId) internal view {
        uint256 earned = stakeBake.earnedContinuous(_actor, _poolId);
        assertGe(earned, 0, REWARD_INVARIANT_B);
    }

    function assert_REWARD_INVARIANT_FUND_BALANCE() internal view {
        uint256 totalGranted = 0;
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            totalGranted += stakeBake.grantedTokens(actorAddresses[j]);
        }
        assertGe(stakeBake.rewardToken().balanceOf(address(stakeBake)), totalGranted, REWARD_INVARIANT_C);
    }
}