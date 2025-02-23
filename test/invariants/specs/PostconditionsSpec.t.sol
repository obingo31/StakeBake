// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title StakeBakePostconditionsSpec
/// @notice Postconditions specification for the StakeBake protocol
/// @dev Contains pseudo code and description for the postcondition properties in StakeBake
abstract contract StakeBakePostconditionsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.

    ///   - There are two types of POSTCONDITIONS:

    ///     - GLOBAL POSTCONDITIONS (GPOST): 
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the StakeBakeHookAggregator contract.

    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST): 
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BASE_GPOST_A = "BASE_GPOST_A: pool.updatedAt changes only on lockTokens, reward claims, or pool management functions";
    string constant BASE_GPOST_B = "BASE_GPOST_B: pool.totalStaked > 0 and updatedAt changed => rewardPerTokenStored increased";
    string constant BASE_GPOST_C = "BASE_GPOST_C: totalRewardFund decreases only on successful reward claims or granted token releases";
    string constant BASE_GPOST_D = "BASE_GPOST_D: No staking operations succeed when isEmergencyStopped == true";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STAKING POOLS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant POOL_HSPOST_A = "POOL_HSPOST_A: createPool() increases poolCount by 1";
    string constant POOL_HSPOST_B = "POOL_HSPOST_B: createPool() sets pool.active to true";
    string constant POOL_GPOST_C = "POOL_GPOST_C: pool.totalStaked increases only on successful lockTokens calls";
    string constant POOL_HSPOST_D = "POOL_HSPOST_D: executeCreatePool() with enough signatures creates a new pool";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STAKING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant STAKING_HSPOST_A = "STAKING_HSPOST_A: after lockTokens, pool.totalStaked increases by token weight";
    string constant STAKING_HSPOST_B = "STAKING_HSPOST_B: after lockTokens, userStakedTokenIds[user].length increases by 1";
    string constant STAKING_HSPOST_C = "STAKING_HSPOST_C: after lockTokens, userRewardPoints increases by expectedStakingRewardPoints";
    string constant STAKING_GPOST_D = "STAKING_GPOST_D: lockTokens transfers NFT from user to contract";
    string constant STAKING_HSPOST_E = "STAKING_HSPOST_E: lockTokens with booster active increases reward points by booster multiplier";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          REWARDS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant REWARDS_HSPOST_A = "REWARDS_HSPOST_A: after reward claim, continuousRewards[user] decreases by claimed amount";
    string constant REWARDS_HSPOST_B = "REWARDS_HSPOST_B: after reward claim, rewardToken.balanceOf(user) increases by claimed amount";
    string constant REWARDS_GPOST_C = "REWARDS_GPOST_C: totalRewardFund never increases except via addRewardFund";
    string constant REWARDS_HSPOST_D = "REWARDS_HSPOST_D: addRewardFund increases totalRewardFund by amount";
    string constant REWARDS_HSPOST_E = "REWARDS_HSPOST_E: claim cannot reduce userRewardPoints below 0";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        GOVERNANCE                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GOVERNANCE_HSPOST_A = "GOVERNANCE_HSPOST_A: emergencyStop toggles isEmergencyStopped state";
    string constant GOVERNANCE_HSPOST_B = "GOVERNANCE_HSPOST_B: submitSignature adds signature to multiSig.signatures";
    string constant GOVERNANCE_GPOST_C = "GOVERNANCE_GPOST_C: executeCreatePool clears signatures after success";
    string constant GOVERNANCE_HSPOST_D = "GOVERNANCE_HSPOST_D: grantTokens increases grantedTokens[user] by amount";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        VESTING                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant VESTING_HSPOST_A = "VESTING_HSPOST_A: createVestingSchedule sets totalAmount correctly";
    string constant VESTING_HSPOST_B = "VESTING_HSPOST_B: releaseGrantedTokens decreases grantedTokens by amount";
    string constant VESTING_GPOST_C = "VESTING_GPOST_C: releasedTokens[user] never exceeds grantedTokens[user]";
    string constant VESTING_HSPOST_D = "VESTING_HSPOST_D: releaseGrantedTokens transfers reward tokens to user";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      IN PROGRESS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant STAKING_HSPOST_F = "STAKING_HSPOST_F: unlock prematurely applies earlyWithdrawalPenalty";
    string constant STAKING_HSPOST_G = "STAKING_HSPOST_G: unlock after lock period distributes full reward points";
    string constant REWARDS_HSPOST_F = "REWARDS_HSPOST_F: booster activation increases reward points for new stakes";
}