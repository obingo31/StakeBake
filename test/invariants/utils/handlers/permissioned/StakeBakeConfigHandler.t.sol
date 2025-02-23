// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {StakeBakeActor} from "../../utils/StakeBakeActor.sol";
import {StakeBakeBaseHandler} from "./StakeBakeBaseHandler.t.sol";
import {StakeBake} from "./StakeBake.sol";

/// @title StakeBakeConfigHandler
/// @notice Handler test contract for StakeBake configuration and management actions
contract StakeBakeConfigHandler is StakeBakeBaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Simulates creating a new staking pool
    function createPool(
        uint256 rewardRatePoints,
        uint256 rewardRatePerSecond,
        uint256 earlyWithdrawalPenalty
    ) external {
        vm.assume(earlyWithdrawalPenalty <= 100);
        vm.assume(rewardRatePoints > 0);
        vm.assume(rewardRatePerSecond > 0);

        uint256 initialPoolCount = stakeBake.poolCount();

        _before();
        vm.prank(owner);
        stakeBake.createPool(address(recipeNFT), rewardRatePoints, rewardRatePerSecond, earlyWithdrawalPenalty);
        _after();

        // HANDLER-SPECIFIC POST-CONDITIONS
        assertEq(stakeBake.poolCount(), initialPoolCount + 1, POOL_HSPOST_A);
        assertTrue(stakeBake.pools(initialPoolCount).active, POOL_HSPOST_B);

        // Add new pool to tracking
        addPoolId(initialPoolCount);
    }

    /// @notice Simulates adding reward funds to the contract
    function addRewardFund(uint256 amount) external {
        vm.assume(amount > 0);
        vm.assume(amount <= rewardToken.balanceOf(owner));

        vm.prank(owner);
        rewardToken.approve(address(stakeBake), amount);

        uint256 initialTotalRewardFund = stakeBake.totalRewardFund();

        _before();
        vm.prank(owner);
        stakeBake.addRewardFund(amount);
        _after();

        // HANDLER-SPECIFIC POST-CONDITIONS
        assertEq(
            stakeBake.totalRewardFund(),
            initialTotalRewardFund + amount,
            REWARDS_HSPOST_D
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Simulates toggling the emergency stop
    function toggleEmergencyStop() external {
        bool initialState = stakeBake.isEmergencyStopped();

        _before();
        vm.prank(owner);
        stakeBake.emergencyStop();
        _after();

        // HANDLER-SPECIFIC POST-CONDITIONS
        assertEq(
            stakeBake.isEmergencyStopped(),
            !initialState,
            GOVERNANCE_HSPOST_A
        );
    }

    /// @notice Simulates granting tokens to a user
    function grantTokens(address user, uint256 amount) external {
        vm.assume(user != address(0));
        vm.assume(amount > 0);

        uint256 initialGranted = stakeBake.grantedTokens(user);

        _before();
        vm.prank(owner);
        stakeBake.grantTokens(user, amount);
        _after();

        // HANDLER-SPECIFIC POST-CONDITIONS
        assertEq(
            stakeBake.grantedTokens(user),
            initialGranted + amount,
            GOVERNANCE_HSPOST_D
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}