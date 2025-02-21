// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./invariants/BaseInvariants.t.sol";

abstract contract VestingInvariants is BaseInvariants {
    function assert_VESTING_INVARIANT_RELEASED_VS_GRANTED(address _actor) internal view {
        assertLe(stakeBake.releasedTokens(_actor), stakeBake.grantedTokens(_actor), VESTING_INVARIANT_A);
    }

    function assert_VESTING_INVARIANT_RELEASABLE(address _actor) internal view {
        uint256 granted = stakeBake.grantedTokens(_actor);
        uint256 released = stakeBake.releasedTokens(_actor);
        uint256 releasable = block.number >= stakeBake.stakingProgramEndsBlock() + stakeBake.vestingDuration()
            ? granted - released
            : (granted * (block.number - stakeBake.stakingProgramEndsBlock())) / stakeBake.vestingDuration() - released;
        assertLe(releasable, stakeBake.rewardToken().balanceOf(address(stakeBake)), VESTING_INVARIANT_B);
    }

    function assert_VESTING_INVARIANT_DURATION() internal view {
        // Immutable; no runtime check needed
    }
}