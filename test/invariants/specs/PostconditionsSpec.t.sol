// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title PostconditionsSpec
/// @notice Postconditions specification for the StakeBake protocol
/// @dev Contains pseudo code and description for the postcondition properties in the protocol
abstract contract PostconditionsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.

    ///   - There are two types of POSTCONDITIONS:

    ///     - GLOBAL POSTCONDITIONS (GPOST):
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the HookAggregator contract.

    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST):
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Reward updates only occur on specific actions
    string constant BASE_GPOST_A = "BASE_GPOST_A: rewardPerToken updates only on lockTokens, unlockTokens, claimRewards, compoundRewards, release";

    /// @notice Total reward fund only increases (e.g., via penalties)
    string constant BASE_GPOST_B = "BASE_GPOST_B: totalRewardFund after >= totalRewardFund before after any action";

    /// @notice Pool count only increases (via createPool)
    string constant BASE_GPOST_C = "BASE_GPOST_C: poolCount after >= poolCount before after any action";

    /// @notice Actions requiring active stakes or solvency checks
    string constant BASE_GPOST_D = "BASE_GPOST_D: unlockTokens, adjustLockingPeriod should revert if user has no active stake";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STAKE MANAGEMENT                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice lockTokens increases totalStaked
    string constant STAKE_HSPOST_A = "STAKE_HSPOST_A: after lockTokens, pool.totalStaked increases by amount staked";

    /// @notice unlockTokens decreases totalStaked
    string constant STAKE_HSPOST_B = "STAKE_HSPOST_B: after unlockTokens, pool.totalStaked decreases by staked amount (minus penalty if applicable)";

    /// @notice adjustLockingPeriod updates stake period
    string constant STAKE_HSPOST_C = "STAKE_HSPOST_C: after adjustLockingPeriod, userStakes.lockingPeriodInBlocks updates to new value";

    /// @notice lockTokens creates a new stake
    string constant STAKE_HSPOST_D = "STAKE_HSPOST_D: after lockTokens, userStakes[user][poolId].tokenAmount > 0 and !claimed";

    /// @notice unlockTokens marks stake as claimed
    string constant STAKE_HSPOST_E = "STAKE_HSPOST_E: after unlockTokens, userStakes[user][poolId].claimed == true";

    /// @notice createPool increases poolCount
    string constant STAKE_HSPOST_F = "STAKE_HSPOST_F: after createPool, poolCount increases by 1";

    /// @notice activateBooster updates booster state
    string constant STAKE_HSPOST_G = "STAKE_HSPOST_G: after activateBooster, poolBoosters[poolId].multiplier and endBlock are set correctly";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       REWARD DISTRIBUTION                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice claimRewards resets continuous rewards
    string constant REWARD_HSPOST_A = "REWARD_HSPOST_A: after claimRewards, continuousRewards[user] == 0 for claimed pools";

    /// @notice compoundRewards increases stake amount
    string constant REWARD_HSPOST_B = "REWARD_HSPOST_B: after compoundRewards, userStakes[user][poolId].tokenAmount increases by compounded amount";

    /// @notice claimRewards increases granted tokens
    string constant REWARD_HSPOST_C = "REWARD_HSPOST_C: after claimRewards with locked rewards, grantedTokens[user] increases";

    /// @notice rewardPerToken updates on state-changing actions
    string constant REWARD_GPOST_D = "REWARD_GPOST_D: after lockTokens, unlockTokens, claimRewards, compoundRewards, pool.rewardPerTokenStored updates";

    /// @notice totalRewardFund increases with penalties
    string constant REWARD_HSPOST_E = "REWARD_HSPOST_E: after unlockTokens with early withdrawal, totalRewardFund increases by penalty amount";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       VESTING                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice release increases released tokens
    string constant VESTING_HSPOST_A = "VESTING_HSPOST_A: after release, releasedTokens[user] increases by releasable amount";

    /// @notice release does not exceed granted tokens
    string constant VESTING_GPOST_B = "VESTING_GPOST_B: after release, releasedTokens[user] <= grantedTokens[user]";

    /// @notice release reduces contract reward token balance
    string constant VESTING_HSPOST_C = "VESTING_HSPOST_C: after release, rewardToken.balanceOf(address(this)) decreases by released amount";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SECURITY                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Emergency stop prevents staking actions
    string constant SECURITY_GPOST_A = "SECURITY_GPOST_A: if emergencyStopped, lockTokens and compoundRewards should revert";

    /// @notice Only owner or multisig can trigger emergency stop
    string constant SECURITY_HSPOST_B = "SECURITY_HSPOST_B: after setting emergencyStopped, caller must be owner or multisig";
}