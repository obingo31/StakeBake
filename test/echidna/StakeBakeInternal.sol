// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "./Actor.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {StakeBakeInternal} from "./StakeBakeInternal.sol"; // Updated import
import {Invariants} from "./Invariants.sol";
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";
import {StakeBakeBaseTest} from "./StakeBakeBaseTest.t.sol";

contract EchidnaStakeBakeTest is StakeBakeBaseTest, Invariants, DefaultBeforeAfterHooks {
    Actor public actor;

    constructor() {
        rewardToken = new TestERC20("Reward", "RWD", 1_000_000e18);
        recipeNFT = new TestERC721("Recipe", "RNFT");
        address[] memory multiSigSigners = new address[](2);
        multiSigSigners[0] = address(0x1);
        multiSigSigners[1] = address(0x2);

        stakeBake = new StakeBakeInternal( // Updated to StakeBakeInternal
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
        poolIds.push(0);

        actor = new Actor(stakeBake, rewardToken, recipeNFT);
        actors[address(actor)] = actor;
        actorAddresses.push(address(actor));

        setContracts(stakeBake, rewardToken, recipeNFT);
    }

    function lockTokens(uint256 tokenId, uint256 lockingPeriod, uint256 poolId) public setup {
        _before();
        actor.lockTokens(tokenId, lockingPeriod, poolId);
        _after();
    }

    function unlockTokens(uint256 tokenId, uint256 poolId) public setup {
        _before();
        actor.unlockTokens(tokenId, poolId);
        _after();
    }

    function claimRewards(uint256 poolId) public setup {
        _before();
        actor.claimRewards(poolId);
        _after();
    }

    function recognizeProfit(uint256 profit) public {
        _before();
        StakeBakeInternal(address(stakeBake)).recognizeProfit(profit);
        _after();
    }

    function recognizeLoss(uint256 loss) public {
        _before();
        StakeBakeInternal(address(stakeBake)).recognizeLoss(loss);
        _after();
    }

    function simulateStake(uint256 poolId, uint256 tokenId, uint256 lockingPeriod) public {
        _before();
        StakeBakeInternal(address(stakeBake)).simulateStake(poolId, tokenId, lockingPeriod);
        _after();
    }

    function echidna_check_invariants() public returns (bool) {
        assert_STAKING_INVARIANT_A();
        assert_STAKING_INVARIANT_B();
        assert_STAKING_INVARIANT_G();
        return true;
    }
}