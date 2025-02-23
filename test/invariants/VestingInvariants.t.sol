// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "./base/BaseInvariants.t.sol";
import "./specs/InvariantsSpec.t.sol";

/// @title VestingInvariants
/// @notice Implements vesting-specific invariant checks for the StakeBake protocol
abstract contract VestingInvariants is BaseInvariants, InvariantsSpec {
    constructor(
        address _stakeBake,
        address _rewardToken,
        uint256 _stakingDurationInBlocks,
        uint256 _vestingDuration,
        address _owner,
        address[] memory _multiSigSigners,
        uint256 _multiSigRequiredSignatures,
        address[] memory _actors
    ) BaseInvariants(_stakeBake, _rewardToken, _stakingDurationInBlocks, _vestingDuration, _owner, _multiSigSigners, _multiSigRequiredSignatures, _actors) {}

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
}