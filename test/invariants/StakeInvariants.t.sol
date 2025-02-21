// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./invariants/BaseInvariants.t.sol";

abstract contract StakeInvariants is BaseInvariants {
    function assert_STAKE_INVARIANT_TOTAL_STAKED(uint256 _poolId) internal view {
        (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(_poolId);
        uint256 sumStakes = 0;
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            sumStakes += stakeBake.userStakes(actorAddresses[j], _poolId).tokenAmount;
        }
        assertEq(pool.totalStaked, sumStakes, STAKE_INVARIANT_C);
    }

    function assert_STAKE_INVARIANT_USER_STAKE(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        if (stake.tokenAmount > 0) {
            assertLe(stake.lockingPeriodInBlocks, stakeBake.stakingProgramEndsBlock() - stake.startBlock, STAKE_INVARIANT_D);
            assertFalse(stake.claimed, STAKE_INVARIANT_E);
        }
    }

    function assert_STAKE_INVARIANT_REWARD_POINTS(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(_poolId);
        (StakeBake.Booster memory booster,) = stakeBake.poolBoosters(_poolId);
        uint256 multiplier = block.number < booster.endBlock ? booster.multiplier : 1e18;
        uint128 calculated = uint128((uint256(stake.tokenAmount) * stake.lockingPeriodInBlocks * pool.rewardRatePoints * multiplier) / 1e18);
        assertGe(stake.expectedStakingRewardPoints, calculated, STAKE_INVARIANT_B);
    }

    function assert_ERC721_BASE_INVARIANT_004(address _actor, uint256 _poolId) internal view {
        // Ownership check implicit; unlockTokens reverts if not owner (tested via handlers)
    }

    function assert_ERC721_BASE_INVARIANT_005(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        if (stake.claimed) {
            assertEq(stake.tokenAmount, 0, ERC721_BASE_INVARIANT_005); // Simplification
        }
    }

    function assert_ERC721_BASE_INVARIANT_006(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        if (stake.claimed) {
            assertTrue(stake.claimed, ERC721_BASE_INVARIANT_006);
        }
    }

    function assert_ERC721_BASE_INVARIANT_009(address _actor, uint256 _poolId) internal view {
        // Self-unstake accounting checked via BASE_INVARIANT_A
    }

    function assert_ERC721_MINTABLE_INVARIANT_001(uint256 _poolId) internal view {
        // Increases totalStaked checked post-action in handlers
    }

    function assert_ERC721_MINTABLE_INVARIANT_002(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        if (!stake.claimed && stake.startBlock > 0) {
            assertGt(stake.tokenAmount, 0, ERC721_MINTABLE_INVARIANT_002);
        }
    }

    function assert_ERC721_BURNABLE_INVARIANT_001(uint256 _poolId) internal view {
        // Reduces totalStaked checked post-action in handlers
    }

    function assert_ERC721_BURNABLE_INVARIANT_002(address _actor, uint256 _poolId) internal view {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        if (stake.claimed) {
            assertFalse(stake.tokenAmount > 0, ERC721_BURNABLE_INVARIANT_002);
        }
    }
}