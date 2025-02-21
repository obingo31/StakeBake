// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title InvariantsSpec
/// @notice Invariants specification for the StakeBake protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV):
    ///   - Properties that should always hold true in the StakeBake system.
    ///   - Implemented in the /invariants folder (e.g., StakeBakeInvariants.t.sol).

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Total staked in each pool equals the sum of user stakes
    string constant BASE_INVARIANT_A = "BASE_INVARIANT_A: pool.totalStaked == sum(userStakes.tokenAmount) for each pool";

    /// @notice Total reward fund <= reward token balance in the contract
    string constant BASE_INVARIANT_B = "BASE_INVARIANT_B: totalRewardFund <= rewardToken.balanceOf(address(this))";

    /// @notice If pool.updatedAt == 0, then pool.rewardPerTokenStored == 0
    string constant BASE_INVARIANT_C = "BASE_INVARIANT_C: pool.updatedAt == 0 => pool.rewardPerTokenStored == 0";

    /// @notice If user has an active stake, their staking token balance reflects it
    string constant BASE_INVARIANT_D = "BASE_INVARIANT_D: user has active stake => stakingToken.balanceOf(user) reflects staked amount";

    /// @notice Contract’s staking token balance >= totalStaked for each pool
    string constant BASE_INVARIANT_E = "BASE_INVARIANT_E: stakingToken.balanceOf(address(this)) >= pool.totalStaked";

    /// @notice Pool count is non-negative
    string constant BASE_INVARIANT_F = "BASE_INVARIANT_F: poolCount >= 0";

    /// @notice Reentrancy guard is not entered
    string constant BASE_INVARIANT_H = "BASE_INVARIANT_H: reentrancyGuardEntered == false";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STAKE MANAGEMENT                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Updating reward per token should never revert
    string constant STAKE_INVARIANT_A = "STAKE_INVARIANT_A: rewardPerToken calculation should never revert";

    /// @notice User's expected reward points >= calculated points
    string constant STAKE_INVARIANT_B = "STAKE_INVARIANT_B: user.expectedStakingRewardPoints >= calculated reward points";

    /// @notice Total reward points in pool >= sum of user reward points
    string constant STAKE_INVARIANT_C = "STAKE_INVARIANT_C: poolTotalRewardPoints >= sum(userRewardPoints)";

    /// @notice If user has stake, their locking period <= stakingProgramEndsBlock - startBlock
    string constant STAKE_INVARIANT_D = "STAKE_INVARIANT_D: user.tokenAmount > 0 => lockingPeriodInBlocks <= stakingProgramEndsBlock - startBlock";

    /// @notice Active stakes are not claimed
    string constant STAKE_INVARIANT_E = "STAKE_INVARIANT_E: user.tokenAmount > 0 => !user.claimed";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       REWARD DISTRIBUTION                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Continuous rewards are non-negative
    string constant REWARD_INVARIANT_A = "REWARD_INVARIANT_A: continuousRewards[user] >= 0";

    /// @notice Earned continuous rewards >= 0
    string constant REWARD_INVARIANT_B = "REWARD_INVARIANT_B: earnedContinuous(user) >= 0";

    /// @notice Reward token balance covers granted tokens
    string constant REWARD_INVARIANT_C = "REWARD_INVARIANT_C: rewardToken.balanceOf(address(this)) >= sum(grantedTokens)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       VESTING                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Released tokens <= granted tokens for each user
    string constant VESTING_INVARIANT_A = "VESTING_INVARIANT_A: releasedTokens[user] <= grantedTokens[user]";

    /// @notice Releasable amount <= reward token balance
    string constant VESTING_INVARIANT_B = "VESTING_INVARIANT_B: _releasableAmount(user) <= rewardToken.balanceOf(address(this))";

    /// @notice Vesting duration is immutable
    string constant VESTING_INVARIANT_C = "VESTING_INVARIANT_C: vestingDuration remains constant after deployment";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       ERC20 INTERACTIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Staking token transfers do not revert
    string constant ERC20_INVARIANT_A = "ERC20_INVARIANT_A: stakingToken.transfer and transferFrom MUST NOT revert under normal conditions";

    /// @notice Reward token balance reflects granted and released amounts
    string constant ERC20_INVARIANT_B = "ERC20_INVARIANT_B: rewardToken.balanceOf(address(this)) >= sum(grantedTokens) - sum(releasedTokens)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SECURITY                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Emergency stop only active if set by owner or multisig
    string constant SECURITY_INVARIANT_A = "SECURITY_INVARIANT_A: emergencyStopped => set by owner or multisig";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              ERC721-LIKE BASE INVARIANTS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Adapted from ERC721-BASE-001: Querying stakes for zero address should be invalid
    string constant ERC721_BASE_INVARIANT_001 = "ERC721_BASE_INVARIANT_001: userStakes(0x0, poolId).tokenAmount == 0";

    /// @notice Adapted from ERC721-BASE-002: Querying invalid pool ID should return no valid stake
    string constant ERC721_BASE_INVARIANT_002 = "ERC721_BASE_INVARIANT_002: userStakes(user, invalidPoolId).tokenAmount == 0";

    /// @notice Adapted from ERC721-BASE-003: Actions on invalid pool IDs should revert
    string constant ERC721_BASE_INVARIANT_003 = "ERC721_BASE_INVARIANT_003: lockTokens() or unlockTokens() with invalid poolId should revert";

    /// @notice Adapted from ERC721-BASE-004: Unstaking requires ownership
    string constant ERC721_BASE_INVARIANT_004 = "ERC721_BASE_INVARIANT_004: unlockTokens() should revert if caller is not stake owner";

    /// @notice Adapted from ERC721-BASE-005: Claiming resets stake state
    string constant ERC721_BASE_INVARIANT_005 = "ERC721_BASE_INVARIANT_005: unlockTokens() should reset stake state (e.g., claimed = true)";

    /// @notice Adapted from ERC721-BASE-006: Unstaking updates stake ownership
    string constant ERC721_BASE_INVARIANT_006 = "ERC721_BASE_INVARIANT_006: unlockTokens() should update stake.claimed to true";

    /// @notice Adapted from ERC721-BASE-007: Unstaking from zero address is invalid
    string constant ERC721_BASE_INVARIANT_007 = "ERC721_BASE_INVARIANT_007: unlockTokens() should revert if stake owner is zero address";

    /// @notice Adapted from ERC721-BASE-008: Transferring stake to zero address is invalid
    string constant ERC721_BASE_INVARIANT_008 = "ERC721_BASE_INVARIANT_008: unlockTokens() should not allow transfer to zero address equivalent";

    /// @notice Adapted from ERC721-BASE-009: Unstaking self does not break accounting
    string constant ERC721_BASE_INVARIANT_009 = "ERC721_BASE_INVARIANT_009: unlockTokens() by owner to self should not break pool.totalStaked accounting";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           ERC721-LIKE BURNABLE INVARIANTS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Adapted from ERC721-BURNABLE-001: Unstaking reduces total staked
    string constant ERC721_BURNABLE_INVARIANT_001 = "ERC721_BURNABLE_INVARIANT_001: unlockTokens() reduces pool.totalStaked correctly";

    /// @notice Adapted from ERC721-BURNABLE-002: Claimed stake cannot be reused
    string constant ERC721_BURNABLE_INVARIANT_002 = "ERC721_BURNABLE_INVARIANT_002: After unlockTokens(), stake cannot be manipulated again";

    /// @notice Adapted from ERC721-BURNABLE-003: Claimed stake cannot be transferred from zero address
    string constant ERC721_BURNABLE_INVARIANT_003 = "ERC721_BURNABLE_INVARIANT_003: unlockTokens() on claimed stake from zero address should revert";

    /// @notice Adapted from ERC721-BURNABLE-004: Claimed stake has no valid state
    string constant ERC721_BURNABLE_INVARIANT_004 = "ERC721_BURNABLE_INVARIANT_004: After unlockTokens(), stake state should be reset (e.g., no valid actions)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           ERC721-LIKE MINTABLE INVARIANTS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Adapted from ERC721-MINTABLE-001: Staking increases total staked
    string constant ERC721_MINTABLE_INVARIANT_001 = "ERC721_MINTABLE_INVARIANT_001: lockTokens() increases pool.totalStaked correctly";

    /// @notice Adapted from ERC721-MINTABLE-002: Staking creates a fresh stake
    string constant ERC721_MINTABLE_INVARIANT_002 = "ERC721_MINTABLE_INVARIANT_002: lockTokens() creates a new stake with non-zero tokenAmount";
}