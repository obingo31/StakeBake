// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/StakeBake.sol";

// Invariant Contracts
import "./invariants/BaseInvariants.t.sol";
import "./StakeInvariants.t.sol";
import "./RewardInvariants.t.sol";
import "./VestingInvariants.t.sol";

import "forge-std/console.sol";

/// @title StakeBakeInvariants
/// @notice Wrappers for the StakeBake protocol invariants implemented in each invariants contract
/// @dev Recognized by Echidna when property mode is activated
/// @dev Inherits BaseInvariants, StakeInvariants, RewardInvariants, and VestingInvariants
abstract contract StakeBakeInvariants is BaseInvariants, StakeInvariants, RewardInvariants, VestingInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_BASE_INVARIANT() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            // Base invariants from BaseInvariants.t.sol
            assert_BASE_INVARIANT_TOTAL_STAKED(i);
            assert_BASE_INVARIANT_POOL_ACTIVE(i);
            assert_BASE_INVARIANT_TOTAL_REWARD_FUND();
            assert_BASE_INVARIANT_EMERGENCY_STOP();
            assert_BASE_INVARIANT_REENTRANCY();

            // ERC721-like base invariants
            assert_ERC721_BASE_INVARIANT_001(i); // Zero address has no stakes
            assert_ERC721_BASE_INVARIANT_002(i); // Invalid pool ID handling
            
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                address user = actorAddresses[j];
                assert_BASE_INVARIANT_ACTOR_BALANCE(user);
            }
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   STAKE INVARIANTS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_STAKE_INVARIANT() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            assert_STAKE_INVARIANT_TOTAL_STAKED(i);
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                address user = actorAddresses[j];
                assert_STAKE_INVARIANT_USER_STAKE(user, i);
                assert_STAKE_INVARIANT_REWARD_POINTS(user, i);

                // ERC721-like stake invariants
                assert_ERC721_BASE_INVARIANT_004(user, i); // Ownership check
                assert_ERC721_BASE_INVARIANT_005(user, i); // Reset on claim
                assert_ERC721_BASE_INVARIANT_006(user, i); // Claimed update
                assert_ERC721_BASE_INVARIANT_009(user, i); // Self-unstake accounting
                assert_ERC721_MINTABLE_INVARIANT_001(i);  // Staking increases total
                assert_ERC721_MINTABLE_INVARIANT_002(user, i); // Fresh stake
                assert_ERC721_BURNABLE_INVARIANT_001(i);  // Unstaking reduces total
                assert_ERC721_BURNABLE_INVARIANT_002(user, i); // No reuse after claim
            }
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   REWARD INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_REWARD_INVARIANT() public returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            assert_REWARD_INVARIANT_CONTINUOUS(i);
            for (uint256 j = 0; j < actorAddresses.length; j++) {
                address user = actorAddresses[j];
                assert_REWARD_INVARIANT_EARNED(user, i);
            }
        }
        assert_REWARD_INVARIANT_FUND_BALANCE();
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   VESTING INVARIANTS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_VESTING_INVARIANT() public returns (bool) {
        for (uint256 j = 0; j < actorAddresses.length; j++) {
            address user = actorAddresses[j];
            assert_VESTING_INVARIANT_RELEASED_VS_GRANTED(user);
            assert_VESTING_INVARIANT_RELEASABLE(user);
        }
        assert_VESTING_INVARIANT_DURATION();
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   ERC20 INVARIANTS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC20_INVARIANT() public returns (bool) {
        // ERC20_INVARIANT_A implicitly tested via Echidna actions
        assert_ERC20_INVARIANT_B();
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   SECURITY INVARIANTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_SECURITY_INVARIANT() public returns (bool) {
        assert_SECURITY_INVARIANT_A();
        return true;
    }
}