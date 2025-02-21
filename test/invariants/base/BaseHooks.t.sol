// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Contracts
import "./ProtocolAssertions.t.sol";
import "src/StakeBake.sol";

// Test Contracts
import "../specs/SpecAggregator.t.sol";
/// @title BaseHooks
/// @notice Contains common logic for all hooks in the StakeBake test suite
/// @dev Inherits ProtocolAssertions for suite-wide assertions and SpecAggregator for specifications
contract BaseHooks is ProtocolAssertions, SpecAggregator {
    StakeBake public stakeBake;
    address[] public actorAddresses;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(address _stakeBake, address[] memory _actors) {
        stakeBake = StakeBake(_stakeBake);
        actorAddresses = _actors;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HELPERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Get the total staked amount across all actors for a pool
    function getTotalStakedForPool(uint256 _poolId) internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            StakeBake.Stake memory stake = stakeBake.userStakes(actorAddresses[i], _poolId);
            total += stake.tokenAmount;
        }
        return total;
    }

    /// @notice Check if an actor has an active stake in a pool
    function hasActiveStake(address _actor, uint256 _poolId) internal view returns (bool) {
        StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
        return stake.tokenAmount > 0 && !stake.claimed;
    }

    /// @notice Calculate the expected reward points for a stake
    function calculateExpectedRewardPoints(
        uint72 _amount,
        uint24 _period,
        uint256 _rate,
        uint256 _poolId
    ) internal view returns (uint128) {
        (,, uint256 booster,) = stakeBake.poolBoosters(_poolId); // Booster struct
        uint256 multiplier = block.number < booster ? stakeBake.poolBoosters(_poolId).multiplier : 1e18;
        return uint128((uint256(_amount) * _period * _rate * multiplier) / 1e18);
    }

    /// @notice Get the total granted tokens across all actors
    function getTotalGrantedTokens() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            total += stakeBake.grantedTokens(actorAddresses[i]);
        }
        return total;
    }

    /// @notice Get the total released tokens across all actors
    function getTotalReleasedTokens() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            total += stakeBake.releasedTokens(actorAddresses[i]);
        }
        return total;
    }

    /// @notice Check if the contract is in an emergency stop state
    function isEmergencyStopped() internal view returns (bool) {
        return stakeBake.emergencyStopped();
    }

    /// @notice Advance block number for testing vesting/rewards (Foundry-specific)
    function advanceBlocks(uint256 _blocks) internal {
        vm.roll(block.number + _blocks);
    }

    // Placeholder implementations for hook methods (to be overridden)
    function cacheBefore() internal virtual {}
    function cacheAfter() internal virtual {}
    function checkPostConditions() internal virtual {}
}