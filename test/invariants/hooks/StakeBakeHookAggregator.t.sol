// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {StakeBakeBeforeAfterHooks} from "./StakeBakeBeforeAfterHooks.t.sol";

/// @title StakeBakeHookAggregator
/// @notice Helper contract to aggregate all before/after hooks for StakeBake, inherited by handlers
abstract contract StakeBakeHookAggregator is StakeBakeBeforeAfterHooks {
    /// @notice List of pool IDs to track
    uint256[] public poolIds;

    constructor(
        address stakeBakeAddress,
        address rewardTokenAddress,
        address recipeNFTAddress,
        address owner,
        address[] memory multiSigSigners,
        uint256 multiSigRequiredSignatures,
        uint256 stakingDurationInBlocks,
        uint256 vestingDuration
    ) StakeBakeBeforeAfterHooks(
        stakeBakeAddress,
        rewardTokenAddress,
        recipeNFTAddress,
        owner,
        multiSigSigners,
        multiSigRequiredSignatures,
        stakingDurationInBlocks,
        vestingDuration
    ) {
        // Initialize with pool 0 by default; can be extended
        poolIds.push(0);
    }

    /// @notice Modular hook selector for StakeBake pools before execution
    function _before() internal {
        for (uint256 i = 0; i < poolIds.length; i++) {
            _stakeBakeHooksBefore(poolIds[i], targetActor);
        }
    }

    /// @notice Modular hook selector for StakeBake pools after execution
    function _after() internal {
        for (uint256 i = 0; i < poolIds.length; i++) {
            _stakeBakeHooksAfter(poolIds[i], targetActor);
            _checkPostConditions(poolIds[i], targetActor);
        }
    }

    /// @notice Postconditions for the StakeBake handlers
    function _checkPostConditions(uint256 poolId, address actor) internal {
        // STAKE invariants
        assert_STAKE_GPOST_A(poolId, actor);
        assert_STAKE_GPOST_B(poolId, actor);
        assert_STAKE_GPOST_C(poolId, actor);
        assert_STAKE_GPOST_D(poolId, actor);
        
        // STAKING specific invariants
        assert_STAKING_GPOST_E(poolId, actor);
    }

    /// @notice Add a pool ID to track
    function addPoolId(uint256 poolId) internal {
        poolIds.push(poolId);
    }
}