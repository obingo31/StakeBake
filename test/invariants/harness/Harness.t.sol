// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {StakeBakeInternal} from "./StakeBakeInternal.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {StakeBakePropertiesAsserts} from "../StakeBakePropertiesAsserts.sol";

/// @title StakeBakeActionsHarness_Test
/// @notice Fuzzing test contract for StakeBake actions, adapted from Uniswap’s ActionsHarness_Test
/// @dev Tests StakeBake’s staking, unstaking, and reward claiming for regressions
contract StakeBakeActionsHarness_Test is Test, StakeBakePropertiesAsserts {
    StakeBakeInternal public stakeBake;
    TestERC20 public rewardToken;
    TestERC721 public recipeNFT;

    uint256 public poolId = 0;
    address public actor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   SETUP                                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Set up the StakeBake environment for testing
    function setUp() public {
        // Deploy mock reward ERC20 token and recipe NFT
        rewardToken = new TestERC20("Reward", "RWD", 1_000_000e18);
        recipeNFT = new TestERC721("Recipe", "RNFT");

        // Set up multisig signers for StakeBake
        address[] memory multiSigSigners = new address[](2);
        multiSigSigners[0] = address(0x1);
        multiSigSigners[1] = address(0x2);

        // Deploy StakeBake contract
        stakeBake = new StakeBakeInternal(
            address(rewardToken),
            1000, // Max staking amount
            500,  // Min staking amount
            multiSigSigners,
            2     // Required signatures
        );

        // Mint reward tokens and fund the StakeBake contract
        rewardToken.mint(address(this), 500_000e18);
        rewardToken.approve(address(stakeBake), 500_000e18);
        stakeBake.addRewardFund(500_000e18);

        // Create a staking pool
        stakeBake.createPool(address(recipeNFT), 1e18, 1e15, 50);

        // Set the actor for testing
        actor = address(this);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                             ACTION TESTS                                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Test staking an NFT
    function test_lockTokens() public {
        uint256 tokenId = 1;
        uint256 lockingPeriod = 100;
        recipeNFT.mint(actor, tokenId);
        recipeNFT.approve(address(stakeBake), tokenId);
        stakeBake.lockTokens(poolId, tokenId, lockingPeriod);
    }

    /// @notice Test unstaking an NFT
    function test_unlockTokens() public {
        uint256 tokenId = 1;
        stakeBake.unlockTokens(poolId, tokenId);
    }

    /// @notice Test claiming rewards
    function test_claimRewards() public {
        stakeBake.claimRewards(poolId);
    }

    /// @notice Test staking and then unstaking an NFT
    function test_lock_and_unlock() public {
        uint256 tokenId = 2;
        uint256 lockingPeriod = 100;
        recipeNFT.mint(actor, tokenId);
        recipeNFT.approve(address(stakeBake), tokenId);
        stakeBake.lockTokens(poolId, tokenId, lockingPeriod);
        vm.roll(block.number + lockingPeriod); // Simulate block passage
        stakeBake.unlockTokens(poolId, tokenId);
    }

    /// @notice Test staking and then claiming rewards
    function test_lock_and_claim() public {
        uint256 tokenId = 3;
        uint256 lockingPeriod = 100;
        recipeNFT.mint(actor, tokenId);
        recipeNFT.approve(address(stakeBake), tokenId);
        stakeBake.lockTokens(poolId, tokenId, lockingPeriod);
        vm.roll(block.number + 50); // Partial lock period
        stakeBake.claimRewards(poolId);
    }

    /// @notice Test staking multiple NFTs
    function test_multiple_locks() public {
        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = i + 4;
            recipeNFT.mint(actor, tokenIds[i]);
            recipeNFT.approve(address(stakeBake), tokenIds[i]);
            stakeBake.lockTokens(poolId, tokenIds[i], 100);
        }
    }

    /// @notice Test unstaking after the lock period
    function test_unlock_after_lock() public {
        uint256 tokenId = 7;
        recipeNFT.mint(actor, tokenId);
        recipeNFT.approve(address(stakeBake), tokenId);
        stakeBake.lockTokens(poolId, tokenId, 100);
        vm.roll(block.number + 100);
        stakeBake.unlockTokens(poolId, tokenId);
    }

    /// @notice Test claiming rewards after multiple staking and unstaking actions
    function test_claim_after_multiple_actions() public {
        uint256 tokenId1 = 8;
        uint256 tokenId2 = 9;
        recipeNFT.mint(actor, tokenId1);
        recipeNFT.approve(address(stakeBake), tokenId1);
        stakeBake.lockTokens(poolId, tokenId1, 100);

        recipeNFT.mint(actor, tokenId2);
        recipeNFT.approve(address(stakeBake), tokenId2);
        stakeBake.lockTokens(poolId, tokenId2, 150);

        vm.roll(block.number + 50);
        stakeBake.claimRewards(poolId);

        vm.roll(block.number + 100);
        stakeBake.unlockTokens(poolId, tokenId1);
        stakeBake.unlockTokens(poolId, tokenId2);
    }

    /// @notice Test simulating profit and loss in the reward fund
    function test_simulate_profit_and_loss() public {
        stakeBake.recognizeProfit(1e18);
        stakeBake.recognizeLoss(0.5e18);
    }

    /// @notice Test emergency stop functionality
    function test_emergency_stop() public {
        stakeBake.emergencyStop();
        vm.expectRevert("Emergency stop is active");
        stakeBake.lockTokens(poolId, 10, 100);
    }
}