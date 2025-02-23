// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StakeBakePropertiesAsserts} from "../StakeBakePropertiesAsserts.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {StakeBakeInternal} from "./StakeBakeInternal.sol";
import {Actor} from "./Actor.sol";

/*
Command to run:
SOLC_VERSION=0.8.19 echidna ./echidna/EchidnaStakeBakeE2E.sol \
    --contract EchidnaStakeBakeE2E \
    --config ./echidna_config.yaml \
    --workers 10
*/
contract EchidnaStakeBakeE2E is StakeBakePropertiesAsserts {
    using Strings for uint256;

    address internal deployer;
    uint256 internal startTimestamp = 1706745600; // Consistent with Silo’s start
    uint256 internal startBlockHeight = 17336000;

    StakeBakeInternal internal stakeBake;
    TestERC20 internal rewardToken;
    TestERC721 internal recipeNFT;

    Actor[] internal actors;

    event ExactAmount(string msg, uint256 amount);

    constructor() payable {
        deployer = msg.sender;

        hevm.warp(startTimestamp);
        hevm.roll(startBlockHeight);

        rewardToken = new TestERC20("Reward", "RWD", 1_000_000e18);
        recipeNFT = new TestERC721("Recipe", "RNFT");
        address[] memory multiSigSigners = new address[](2);
        multiSigSigners[0] = address(0x1);
        multiSigSigners[1] = address(0x2);

        stakeBake = new StakeBakeInternal(
            address(rewardToken),
            1000,
            500,
            multiSigSigners,
            2
        );

        rewardToken.mint(address(this), 500_000e18);
        rewardToken.approve(address(stakeBake), 500_000e18);
        stakeBake.addRewardFund(500_000e18);

        stakeBake.createPool(address(recipeNFT), 1e18, 1e15, 50);

        // Set up actors
        for (uint256 i = 0; i < 3; i++) {
            actors.push(new Actor(stakeBake, rewardToken, recipeNFT));
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            ECHIDNA INVARIANTS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensures totalRewardFund matches contract balance
    function echidna_reward_fund_consistency() public view returns (bool success) {
        uint256 totalFund = stakeBake.totalRewardFund();
        uint256 contractBalance = rewardToken.balanceOf(address(stakeBake));
        assertEq(totalFund, contractBalance, "Reward fund inconsistent with balance");
        success = true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            SYSTEM INTERACTION FUNCTIONS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stakes an NFT into a pool
    function lockTokens(uint8 _actorIndex, uint256 poolId, uint256 tokenId, uint256 lockingPeriod) public {
        emit LogUint256("[lockTokens] block.timestamp:", block.timestamp);

        Actor actor = _selectActor(_actorIndex);
        poolId = clampBetween(poolId, 0, stakeBake.poolCount() - 1);
        lockingPeriod = clampBetween(lockingPeriod, 1, stakeBake.stakingProgramEndsBlock() - block.timestamp);

        uint256 shares = actor.lockTokens(tokenId, lockingPeriod, poolId);
        emit LogString(string.concat(
            "Staked token ID ", tokenId.toString(),
            " into pool ", poolId.toString(),
            " for ", lockingPeriod.toString(), " blocks"
        ));
    }

    /// @notice Unstakes an NFT from a pool
    function unlockTokens(uint8 _actorIndex, uint256 poolId, uint256 tokenId) public {
        emit LogUint256("[unlockTokens] block.timestamp:", block.timestamp);

        Actor actor = _selectActor(_actorIndex);
        poolId = clampBetween(poolId, 0, stakeBake.poolCount() - 1);

        actor.unlockTokens(tokenId, poolId);
        emit LogString(string.concat(
            "Unstaked token ID ", tokenId.toString(),
            " from pool ", poolId.toString()
        ));
    }

    /// @notice Claims rewards from a pool
    function claimRewards(uint8 _actorIndex, uint256 poolId) public {
        emit LogUint256("[claimRewards] block.timestamp:", block.timestamp);

        Actor actor = _selectActor(_actorIndex);
        poolId = clampBetween(poolId, 0, stakeBake.poolCount() - 1);

        uint256 rewards = actor.claimRewards(poolId);
        emit LogString(string.concat(
            "Claimed ", rewards.toString(),
            " rewards from pool ", poolId.toString()
        ));
    }

    /// @notice Simulates profit by adding reward tokens
    function recognizeProfit(uint256 profit) public {
        emit LogUint256("[recognizeProfit] block.timestamp:", block.timestamp);

        StakeBakeInternal(address(stakeBake)).recognizeProfit(profit);
        emit LogString(string.concat("Recognized profit of ", profit.toString(), " reward tokens"));
    }

    /// @notice Simulates loss by removing reward tokens
    function recognizeLoss(uint256 loss) public {
        emit LogUint256("[recognizeLoss] block.timestamp:", block.timestamp);

        StakeBakeInternal(address(stakeBake)).recognizeLoss(loss);
        emit LogString(string.concat("Recognized loss of ", loss.toString(), " reward tokens"));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            PROPERTY CHECKS                                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensures staking doesn’t mint zero rewards
    function lockTokens_never_generates_zero_rewards(uint8 _actorIndex, uint256 poolId, uint256 tokenId, uint256 lockingPeriod) public {
        emit LogUint256("[lockTokens_never_generates_zero_rewards] block.timestamp:", block.timestamp);

        Actor actor = _selectActor(_actorIndex);
        poolId = clampBetween(poolId, 0, stakeBake.poolCount() - 1);
        lockingPeriod = clampBetween(lockingPeriod, 1, stakeBake.stakingProgramEndsBlock() - block.timestamp);

        uint256 rewardPointsBefore = stakeBake.userRewardPoints(address(actor), poolId);
        lockTokens(_actorIndex, poolId, tokenId, lockingPeriod);
        uint256 rewardPointsAfter = stakeBake.userRewardPoints(address(actor), poolId);

        assertGt(rewardPointsAfter, rewardPointsBefore, "Staking generated zero reward points");
    }

    /// @notice Ensures claiming doesn’t exceed max claimable rewards
    function claimRewards_does_not_exceed_max(uint8 _actorIndex, uint256 poolId) public {
        emit LogUint256("[claimRewards_does_not_exceed_max] block.timestamp:", block.timestamp);

        Actor actor = _selectActor(_actorIndex);
        poolId = clampBetween(poolId, 0, stakeBake.poolCount() - 1);

        uint256 maxClaimable = _maxClaimableRewards(address(actor), poolId);
        uint256 balanceBefore = rewardToken.balanceOf(address(actor));
        claimRewards(_actorIndex, poolId);
        uint256 balanceAfter = rewardToken.balanceOf(address(actor));

        uint256 claimed = balanceAfter - balanceBefore;
        assertLe(claimed, maxClaimable, "Claimed rewards exceed max claimable");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            UTILITY FUNCTIONS                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _selectActor(uint8 index) internal returns (Actor actor) {
        uint256 actorIndex = clampBetween(uint256(index), 0, actors.length - 1);
        emit LogString(string.concat("Actor selected index:", actorIndex.toString()));
        return actors[actorIndex];
    }

    function _maxClaimableRewards(address user, uint256 poolId) internal view returns (uint256) {
        try stakeBake.earnedContinuous(user, poolId) returns (uint256 continuousRewards) {
            uint256 lockedRewards = 0;
            uint256[] memory tokenIds = stakeBake.userStakedTokenIds(user, poolId);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                (uint256 tokenId, , uint256 lockingPeriod, uint256 startBlock, uint256 expectedRewards, bool claimed) = stakeBake.userStakes(user, poolId, tokenIds[i]);
                if (!claimed && block.number >= startBlock + lockingPeriod) {
                    lockedRewards += expectedRewards;
                }
            }
            return continuousRewards + lockedRewards;
        } catch {
            return 0;
        }
    }
}