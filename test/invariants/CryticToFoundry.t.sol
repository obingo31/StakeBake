// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {StakeBakeInvariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";
import {StakeBake} from "src/StakeBake.sol";

/*
 * Test suite that converts from "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is Invariants, Setup {
    CryticToFoundry Tester = this;
    uint256 constant DEFAULT_TIMESTAMP = 337812;

    modifier setup() override {
        targetActor = address(actor);
        _;
        targetActor = address(0);
    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(DEFAULT_TIMESTAMP);
    }

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                FAILING INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replayechidna_BASE_INVARIANT() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.unlockTokens(1);
        echidna_BASE_INVARIANT();
    }

    function test_replayechidna_LENDING_INVARIANT() public {
        Tester.lockTokens(1, 1000, 10000);
        echidna_LENDING_INVARIANT();
    }

    function test_replayechidna_BORROWING_INVARIANT2() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.unlockTokens(1);
        echidna_BORROWING_INVARIANT();
    }

    function test_replayechidna_BASE_INVARIANT2() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.unlockTokens(1);
        echidna_BASE_INVARIANT();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replaylockTokens() public {
        Tester.lockTokens(1, 1000, 10000);
    }

    function test_replayunlockTokens() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.unlockTokens(1);
    }

    function test_replayclaimRewards() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.claimRewards(1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 POSTCONDITIONS: FINAL REVISION                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replaylockTokens2() public {
        Tester.lockTokens(1, 1000, 10000);
    }

    function test_replayunlockTokens2() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.unlockTokens(1);
    }

    function test_replayclaimRewards2() public {
        Tester.lockTokens(1, 1000, 10000);
        Tester.claimRewards(1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}