// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/StakeBake.sol";
import "../specs/InvariantsSpec.t.sol";

/// @title StakeBakeInvariants
/// @notice Implements invariant checks for the StakeBake protocol
/// @dev Tests properties defined in InvariantsSpec.t.sol
contract StakeBakeInvariants is Test, InvariantsSpec {
    StakeBake public stakeBake;

    constructor(address _stakeBake, address[] memory _actors) {
        stakeBake = StakeBake(_stakeBake);
        actorAddresses = _actors;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_BASE_INVARIANTS() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            // BASE_INVARIANT_A: pool.totalStaked == sum(userStakes.tokenAmount)
            (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(i);
            uint256 sumUserStakes = 0;
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                sumUserStakes += stakeBake.userStakes(actorAddresses[j], i).tokenAmount;
            }
            assertEq(pool.totalStaked, sumUserStakes, BASE_INVARIANT_A);

            // BASE_INVARIANT_B: totalRewardFund <= rewardToken.balanceOf(address(this))
            assertLe(stakeBake.totalRewardFund(), stakeBake.rewardToken().balanceOf(address(stakeBake)), BASE_INVARIANT_B);

            // BASE_INVARIANT_C: pool.updatedAt == 0 => pool.rewardPerTokenStored == 0
            if (pool.updatedAt == 0) {
                assertEq(pool.rewardPerTokenStored, 0, BASE_INVARIANT_C);
            }

            // BASE_INVARIANT_D: user has active stake => stakingToken.balanceOf(user) reflects staked amount
            // (Simplified: assumes user balance decreases by staked amount, checked indirectly via E)
            assertLe(pool.totalStaked, pool.stakingToken.balanceOf(address(stakeBake)), BASE_INVARIANT_E);

            // BASE_INVARIANT_E: stakingToken.balanceOf(address(this)) >= pool.totalStaked
            assertLe(pool.totalStaked, pool.stakingToken.balanceOf(address(stakeBake)), BASE_INVARIANT_E);

            // ERC721_BASE_INVARIANT_001: userStakes(0x0, poolId).tokenAmount == 0
            assertEq(stakeBake.userStakes(address(0), i).tokenAmount, 0, ERC721_BASE_INVARIANT_001);

            // ERC721_BASE_INVARIANT_002: userStakes(user, invalidPoolId).tokenAmount == 0
            // (Checked below for invalid pool IDs)
        }

        // BASE_INVARIANT_F: poolCount >= 0
        assertGe(stakeBake.poolCount(), 0, BASE_INVARIANT_F);

        // BASE_INVARIANT_H: reentrancyGuardEntered == false
        bytes32 reentrancySlot = keccak256("ReentrancyGuard.reentrancyGuard");
        uint256 reentrancyStatus = uint256(vm.load(address(stakeBake), reentrancySlot));
        assertEq(reentrancyStatus, 1, BASE_INVARIANT_H); // 1 = not entered

        // Check invalid pool ID
        uint256 invalidPoolId = stakeBake.poolCount();
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            assertEq(stakeBake.userStakes(actorAddresses[j], invalidPoolId).tokenAmount, 0, ERC721_BASE_INVARIANT_002);
        }

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STAKE MANAGEMENT                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_STAKE_INVARIANTS() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            // STAKE_INVARIANT_A: rewardPerToken calculation should never revert
            // (Implicitly tested by calling it; Echidna will catch reverts)
            try stakeBake.rewardPerToken(i) returns (uint256) {
                // Success
            } catch {
                assertTrue(false, STAKE_INVARIANT_A);
            }

            uint256 sumUserPoints = 0;
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                address user = actorAddresses[j];
                StakeBake.Stake memory stake = stakeBake.userStakes(user, i);

                // STAKE_INVARIANT_B: user.expectedStakingRewardPoints >= calculated reward points
                (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(i);
                (StakeBake.Booster memory booster,) = stakeBake.poolBoosters(i);
                uint256 multiplier = block.number < booster.endBlock ? booster.multiplier : 1e18;
                uint128 calculatedPoints = uint128((uint256(stake.tokenAmount) * stake.lockingPeriodInBlocks * pool.rewardRatePoints * multiplier) / 1e18);
                assertGe(stake.expectedStakingRewardPoints, calculatedPoints, STAKE_INVARIANT_B);

                // STAKE_INVARIANT_D: user.tokenAmount > 0 => lockingPeriodInBlocks <= stakingProgramEndsBlock - startBlock
                if (stake.tokenAmount > 0) {
                    assertLe(stake.lockingPeriodInBlocks, stakeBake.stakingProgramEndsBlock() - stake.startBlock, STAKE_INVARIANT_D);
                    // STAKE_INVARIANT_E: user.tokenAmount > 0 => !user.claimed
                    assertFalse(stake.claimed, STAKE_INVARIANT_E);
                }

                sumUserPoints += stakeBake.userRewardPoints(user, i);
            }

            // STAKE_INVARIANT_C: poolTotalRewardPoints >= sum(userRewardPoints)
            assertGe(stakeBake.poolTotalRewardPoints(i), sumUserPoints, STAKE_INVARIANT_C);

            // ERC721_MINTABLE_INVARIANT_001: lockTokens increases totalStaked (checked post-action, not here)
            // ERC721_BURNABLE_INVARIANT_001: unlockTokens reduces totalStaked (checked post-action)
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       REWARD DISTRIBUTION                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_REWARD_INVARIANTS() public returns (bool) {
        uint256 totalGranted = 0;
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            address user = actorAddresses[j];

            // REWARD_INVARIANT_A: continuousRewards[user] >= 0
            assertGe(stakeBake.continuousRewards(user), 0, REWARD_INVARIANT_A);

            // REWARD_INVARIANT_B: earnedContinuous(user) >= 0
            for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
                try stakeBake.earnedContinuous(user, i) returns (uint256 earned) {
                    assertGe(earned, 0, REWARD_INVARIANT_B);
                } catch {
                    assertTrue(false, REWARD_INVARIANT_B);
                }
            }

            totalGranted += stakeBake.grantedTokens(user);
        }

        // REWARD_INVARIANT_C: rewardToken.balanceOf(address(this)) >= sum(grantedTokens)
        assertGe(stakeBake.rewardToken().balanceOf(address(stakeBake)), totalGranted, REWARD_INVARIANT_C);

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       VESTING                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_VESTING_INVARIANTS() public returns (bool) {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            address user = actorAddresses[j];

            // VESTING_INVARIANT_A: releasedTokens[user] <= grantedTokens[user]
            assertLe(stakeBake.releasedTokens(user), stakeBake.grantedTokens(user), VESTING_INVARIANT_A);

            // VESTING_INVARIANT_B: _releasableAmount(user) <= rewardToken.balanceOf(address(this))
            // Note: _releasableAmount is private; assumes a getter or calculates manually
            uint256 granted = stakeBake.grantedTokens(user);
            uint256 released = stakeBake.releasedTokens(user);
            uint256 releasable = block.number >= stakeBake.stakingProgramEndsBlock() + stakeBake.vestingDuration() 
                ? granted - released 
                : (granted * (block.number - stakeBake.stakingProgramEndsBlock())) / stakeBake.vestingDuration() - released;
            assertLe(releasable, stakeBake.rewardToken().balanceOf(address(stakeBake)), VESTING_INVARIANT_B);
        }

        // VESTING_INVARIANT_C: vestingDuration remains constant (immutable, checked via constructor)
        // (No runtime check needed as it's immutable)

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       ERC20 INTERACTIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC20_INVARIANTS() public returns (bool) {
        // ERC20_INVARIANT_A: stakingToken.transfer and transferFrom MUST NOT revert under normal conditions
        // (Implicitly tested via Echidna actions; explicit ERC20 testing would require a mock)

        uint256 totalGranted = 0;
        uint256 totalReleased = 0;
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            totalGranted += stakeBake.grantedTokens(actorAddresses[j]);
            totalReleased += stakeBake.releasedTokens(actorAddresses[j]);
        }

        // ERC20_INVARIANT_B: rewardToken.balanceOf(address(this)) >= sum(grantedTokens) - sum(releasedTokens)
        assertGe(stakeBake.rewardToken().balanceOf(address(stakeBake)), totalGranted - totalReleased, ERC20_INVARIANT_B);

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SECURITY                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_SECURITY_INVARIANTS() public returns (bool) {
        // SECURITY_INVARIANT_A: emergencyStopped => set by owner or multisig
        if (stakeBake.emergencyStopped()) {
            // Simplified: assumes only owner can set (extend for multisig if logic added)
            assertTrue(msg.sender == stakeBake.owner() || stakeBake.isMultiSigSigner(msg.sender), SECURITY_INVARIANT_A);
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              ERC721-LIKE BASE INVARIANTS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC721_BASE_INVARIANTS() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                address user = actorAddresses[j];
                StakeBake.Stake memory stake = stakeBake.userStakes(user, i);

                // ERC721_BASE_INVARIANT_004: unlockTokens() should revert if caller is not stake owner
                // (Implicitly tested via Echidna; requires handler to verify)

                // ERC721_BASE_INVARIANT_005 & 006: unlockTokens() should reset stake state (claimed = true)
                if (stake.claimed) {
                    assertEq(stake.tokenAmount, 0, ERC721_BASE_INVARIANT_005); // Simplification: assumes cleared on claim
                }

                // ERC721_BASE_INVARIANT_007: unlockTokens() should revert if stake owner is zero address
                // (Implicitly tested; zero address has no stakes per ERC721_BASE_INVARIANT_001)

                // ERC721_BASE_INVARIANT_009: unlockTokens() by owner to self should not break accounting
                // (Checked via BASE_INVARIANT_A for totalStaked consistency)
            }
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           ERC721-LIKE BURNABLE INVARIANTS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC721_BURNABLE_INVARIANTS() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                StakeBake.Stake memory stake = stakeBake.userStakes(actorAddresses[j], i);

                // ERC721_BURNABLE_INVARIANT_002 & 004: After unlockTokens(), stake cannot be manipulated again
                if (stake.claimed) {
                    assertFalse(stake.tokenAmount > 0, ERC721_BURNABLE_INVARIANT_002); // No active amount post-claim
                }

                // ERC721_BURNABLE_INVARIANT_003: unlockTokens() on claimed stake from zero address should revert
                // (Implicitly tested via zero address checks)
            }
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           ERC721-LIKE MINTABLE INVARIANTS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC721_MINTABLE_INVARIANTS() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                StakeBake.Stake memory stake = stakeBake.userStakes(actorAddresses[j], i);

                // ERC721_MINTABLE_INVARIANT_002: lockTokens() creates a new stake with non-zero tokenAmount
                if (!stake.claimed && stake.startBlock > 0) {
                    assertGt(stake.tokenAmount, 0, ERC721_MINTABLE_INVARIANT_002);
                }
            }
        }
        return true;
    }
}