// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title StakeBakeInvariantsSpec
/// @notice Invariants specification for the StakeBake protocol
/// @dev Contains pseudo code and description for the invariant properties in StakeBake
abstract contract StakeBakeInvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV): 
    ///   - Properties that should always hold true in the system. 
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BASE_INVARIANT_A = "BASE_INVARIANT_A: pool.totalStaked == 0 <=> pool.active == false || pool.recipeNFT.balanceOf(pool) == 0";
    string constant BASE_INVARIANT_B = "BASE_INVARIANT_B: rewardToken.balanceOf(stakeBake) >= totalRewardFund";
    string constant BASE_INVARIANT_C = "BASE_INVARIANT_C: pool.updatedAt == 0 => pool.rewardPerTokenStored == 0";
    string constant BASE_INVARIANT_D = "BASE_INVARIANT_D: user has staked tokens => userRewardPoints[user] > 0";
    string constant BASE_INVARIANT_E = "BASE_INVARIANT_E: isEmergencyStopped == true => no staking operations can modify state";
    string constant BASE_INVARIANT_F = "BASE_INVARIANT_F: sum of all userRewardPoints for a pool == poolTotalRewardPoints";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STAKING POOLS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant POOL_INVARIANT_A = "POOL_INVARIANT_A: rewardPerToken() should never revert";
    string constant POOL_INVARIANT_B = "POOL_INVARIANT_B: earnedContinuous(user) >= userContinuousRewards stored value";
    string constant POOL_INVARIANT_C = "POOL_INVARIANT_C: pool.totalStaked == sum of all user staked weights";
    string constant POOL_INVARIANT_D = "POOL_INVARIANT_D: pool.active == false => no new stakes can be added";
    string constant POOL_INVARIANT_E = "POOL_INVARIANT_E: booster.multiplier > 1 => block.number < booster.endBlock";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STAKING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant STAKING_INVARIANT_A = "STAKING_INVARIANT_A: NFT can only be staked in one pool at a time";
    string constant STAKING_INVARIANT_B = "STAKING_INVARIANT_B: userStakedTokenIds[user].length == number of user’s staked NFTs";
    string constant STAKING_INVARIANT_C = "STAKING_INVARIANT_C: stake.startBlock + stake.lockingPeriodInBlocks <= stakingProgramEndsBlock";
    string constant STAKING_INVARIANT_D = "STAKING_INVARIANT_D: stake.claimed == false => reward points not yet distributed";
    string constant STAKING_INVARIANT_E = "STAKING_INVARIANT_E: lockingPeriodInBlocks > 0 => expectedStakingRewardPoints > 0";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          REWARDS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant REWARDS_INVARIANT_A = "REWARDS_INVARIANT_A: continuousRewards[user] never decreases unless claimed";
    string constant REWARDS_INVARIANT_B = "REWARDS_INVARIANT_B: rewardPerToken() increases over time when totalStaked > 0";
    string constant REWARDS_INVARIANT_C = "REWARDS_INVARIANT_C: totalRewardFund >= sum of all grantedTokens - releasedTokens";
    string constant REWARDS_INVARIANT_D = "REWARDS_INVARIANT_D: userRewardPoints[user] == sum of expectedStakingRewardPoints for user’s stakes";
    string constant REWARDS_INVARIANT_E = "REWARDS_INVARIANT_E: grantedTokens[user] >= releasedTokens[user]";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        GOVERNANCE                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GOVERNANCE_INVARIANT_A = "GOVERNANCE_INVARIANT_A: multiSig.signatures cleared after successful execution";
    string constant GOVERNANCE_INVARIANT_B = "GOVERNANCE_INVARIANT_B: multiSig.requiredSignatures <= multiSig.signers.length";
    string constant GOVERNANCE_INVARIANT_C = "GOVERNANCE_INVARIANT_C: onlyOwner functions require multiSig approval";
    string constant GOVERNANCE_INVARIANT_D = "GOVERNANCE_INVARIANT_D: pool creation requires sufficient signatures";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        VESTING                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant VESTING_INVARIANT_A = "VESTING_INVARIANT_A: vestingSchedule.totalAmount >= amount released so far";
    string constant VESTING_INVARIANT_B = "VESTING_INVARIANT_B: vestingSchedule.cliff >= vestingSchedule.start";
    string constant VESTING_INVARIANT_C = "VESTING_INVARIANT_C: vestingSchedule.duration > 0 => totalAmount > 0";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STAKEBAKE ERC20                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice ASSETS
    string constant ERC20_ASSETS_INVARIANT_A = "ERC20_ASSETS_INVARIANT_A: rewardToken address must not revert";
    string constant ERC20_ASSETS_INVARIANT_B = "ERC20_ASSETS_INVARIANT_B: totalRewardFund must not revert";

    /// @notice REWARDS
    string constant ERC20_REWARDS_INVARIANT_A = "ERC20_REWARDS_INVARIANT_A: rewardToken.transfer must succeed for valid claims";
    string constant ERC20_REWARDS_INVARIANT_B = "ERC20_REWARDS_INVARIANT_B: rewardToken.balanceOf(stakeBake) decreases only on valid withdrawals";
}