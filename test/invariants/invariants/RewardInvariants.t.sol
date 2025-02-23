// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakeBake} from "src/StakeBake.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

import "forge-std/console.sol";

/// @title StakingRewardInvariants
/// @notice Implements Invariants for the StakeBake protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract StakingRewardInvariants is HandlerAggregator {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STAKING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensure the total staked amount in a pool never exceeds the total supply of the staking token
    function assert_STAKING_INVARIANT_A(uint256 poolId) internal view {
        (,, uint256 poolTotalStaked,,,) = stakeBake.pools(poolId);
        assertLe(poolTotalStaked, stakingTokens[poolId].totalSupply(), "STAKING_INVARIANT_A: Staked amount exceeds token supply");
    }

    /// @notice Ensure the total staked amount across users matches the total staked amount in the pool
    function assert_STAKING_INVARIANT_B(uint256 poolId) internal view {
        uint256 totalStaked;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            (uint72 tokenAmount,,,,) = stakeBake.userStakes(actorAddresses[i], poolId);
            totalStaked += tokenAmount;
        }
        (,, uint256 poolTotalStaked,,,) = stakeBake.pools(poolId);
        assertEq(totalStaked, poolTotalStaked, "STAKING_INVARIANT_B: Total staked amount mismatch");
    }

    /// @notice Ensure the locking period of a stake never exceeds the staking program duration
    function assert_STAKING_INVARIANT_C(uint256 poolId) internal view {
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            (,, uint24 lockingPeriod,,) = stakeBake.userStakes(actorAddresses[i], poolId);
            assertLe(lockingPeriod, stakeBake.stakingProgramEndsBlock() - block.number, "STAKING_INVARIANT_C: Locking period exceeds staking duration");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          REWARDS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensure the total reward fund never goes negative
    function assert_REWARD_INVARIANT_A() internal view {
        assertGe(stakeBake.totalRewardFund(), 0, "REWARD_INVARIANT_A: Total reward fund cannot be negative");
    }

    /// @notice Ensure the total reward points across users match the total reward points in the pool
    function assert_REWARD_INVARIANT_B(uint256 poolId) internal view {
        uint256 totalUserPoints;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalUserPoints += stakeBake.userRewardPoints(actorAddresses[i], poolId);
        }
        uint256 totalPoolPoints = stakeBake.poolTotalRewardPoints(poolId);
        assertEq(totalUserPoints, totalPoolPoints, "REWARD_INVARIANT_B: Total reward points mismatch");
    }

    /// @notice Ensure the total granted tokens never exceed the total reward fund
    function assert_REWARD_INVARIANT_C() internal view {
        uint256 totalGranted;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalGranted += stakeBake.grantedTokens(actorAddresses[i]);
        }
        assertLe(totalGranted, stakeBake.totalRewardFund(), "REWARD_INVARIANT_C: Granted tokens exceed reward fund");
    }

    /// @notice Ensure the total released tokens never exceed the total granted tokens
    function assert_REWARD_INVARIANT_D() internal view {
        uint256 totalReleased;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalReleased += stakeBake.releasedTokens(actorAddresses[i]);
        }
        uint256 totalGranted;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            totalGranted += stakeBake.grantedTokens(actorAddresses[i]);
        }
        assertLe(totalReleased, totalGranted, "REWARD_INVARIANT_D: Released tokens exceed granted tokens");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      MULTI-SIGNATURE                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensure multi-signature transactions require the correct number of signatures
    function assert_MULTISIG_INVARIANT_A(bytes32 txHash) internal view {
        uint256 requiredSignatures = stakeBake.multiSig().requiredSignatures;
        uint256 currentSignatures = stakeBake.multiSig().signatures[txHash];
        assertLe(currentSignatures, requiredSignatures, "MULTISIG_INVARIANT_A: Signatures exceed required");
    }

    /// @notice Ensure multi-signature transactions cannot be executed without enough signatures
    function assert_MULTISIG_INVARIANT_B(bytes32 txHash) internal {
        uint256 requiredSignatures = stakeBake.multiSig().requiredSignatures;
        uint256 currentSignatures = stakeBake.multiSig().signatures[txHash];
        if (currentSignatures < requiredSignatures) {
            vm.expectRevert("Not enough signatures");
            stakeBake.executeMultiSigTransaction(txHash, address(this), 0, "");
        }
    }

    /// @notice Ensure only multi-signature signers can add signatures
    function assert_MULTISIG_INVARIANT_C(address user) internal {
        if (!stakeBake.isMultiSigSigner(user)) {
            vm.expectRevert("Not authorized: Only multi-signature signers can call this function");
            stakeBake.addMultiSigSignature(keccak256("test"));
        }
    }
}