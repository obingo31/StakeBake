// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {StakeBakeBaseTest} from "./StakeBakeBaseTest.t.sol";
import {StakeBakeBaseStorage} from "./StakeBakeBaseStorage.t.sol";
import {StakeBakeStdAsserts} from "./StakeBakeStdAsserts.sol";
import {StakeBakeProtocolAssertions} from "./StakeBakeProtocolAssertions.t.sol";
import {StakeBakeHookAggregator} from "./StakeBakeHookAggregator.t.sol";
import {StakeBakeStakingHandler} from "./StakeBakeStakingHandler.t.sol";
import {StakeBakeRewardHandler} from "./StakeBakeRewardHandler.t.sol";
import {StakeBakeConfigHandler} from "./StakeBakeConfigHandler.t.sol";
import {StakeBakeActor} from "../utils/StakeBakeActor.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {StakeBake} from "./StakeBake.sol"; // Only for setup

contract StakeBakeInvariantTest is StakeBakeBaseTest, StakeBakeStdAsserts {
    StakeBakeProtocolAssertions assertions;
    StakeBakeStakingHandler stakingHandler;
    StakeBakeRewardHandler rewardHandler;
    StakeBakeConfigHandler configHandler;
    StakeBakeActor actor;

    TestERC20 rewardToken;
    TestERC721 recipeNFT;
    StakeBake stakeBake;

    constructor(
        address _stakeBakeAddress,
        address _rewardTokenAddress,
        address _recipeNFTAddress,
        address _owner,
        address[] memory _multiSigSigners,
        uint256 _multiSigRequiredSignatures,
        uint256 _stakingDurationInBlocks,
        uint256 _vestingDuration
    ) StakeBakeBaseTest(
        _stakeBakeAddress,
        _rewardTokenAddress,
        _recipeNFTAddress,
        _owner,
        _multiSigSigners,
        _multiSigRequiredSignatures,
        _stakingDurationInBlocks,
        _vestingDuration
    ) {}

    function setUp() public {
        rewardToken = new TestERC20("Reward", "RWD", 1_000_000e18);
        recipeNFT = new TestERC721("Recipe", "RNFT");
        address[] memory multiSigSigners = new address[](2);
        multiSigSigners[0] = address(0x1);
        multiSigSigners[1] = address(0x2);

        vm.startPrank(address(0x3)); // Owner
        stakeBake = new StakeBake(
            address(rewardToken),
            1000,
            500,
            multiSigSigners,
            2
        );
        stakeBakeAddress = address(stakeBake);
        rewardToken.transfer(stakeBakeAddress, 500_000e18);
        stakeBake.addRewardFund(500_000e18);
        vm.stopPrank();

        address[] memory erc20Tokens = new address[](1);
        erc20Tokens[0] = address(rewardToken);
        address[] memory erc721Tokens = new address[](1);
        erc721Tokens[0] = address(recipeNFT);
        address[] memory contracts = new address[](1);
        contracts[0] = stakeBakeAddress;

        actor = new StakeBakeActor(erc20Tokens, erc721Tokens, contracts);
        actors[address(0x4)] = actor;
        actorAddresses.push(address(0x4));

        assertions = new StakeBakeProtocolAssertions(
            stakeBakeAddress,
            address(rewardToken),
            address(recipeNFT),
            address(0x3),
            multiSigSigners,
            2,
            1000,
            500
        );

        stakingHandler = new StakeBakeStakingHandler(
            stakeBakeAddress,
            address(rewardToken),
            address(recipeNFT),
            address(0x3),
            multiSigSigners,
            2,
            1000,
            500,
            actor
        );

        rewardHandler = new StakeBakeRewardHandler(
            stakeBakeAddress,
            address(rewardToken),
            address(recipeNFT),
            address(0x3),
            multiSigSigners,
            2,
            1000,
            500,
            actor
        );

        configHandler = new StakeBakeConfigHandler(
            stakeBakeAddress,
            address(rewardToken),
            address(recipeNFT),
            address(0x3),
            multiSigSigners,
            2,
            1000,
            500,
            actor
        );

        // Create an initial pool
        vm.prank(address(0x3));
        configHandler.createPool(1e18, 1e15, 50);
    }

    function test_invariant_baseA() public {
        assertions.assertBaseInvariantA(0);
    }

    function test_invariant_baseB() public {
        assertions.assertBaseInvariantB();
    }

    function test_staking_and_unlocking() public {
        stakingHandler.lockTokens(0, 1, 100, 0, 0);
        vm.roll(block.number + 50); // Halfway through lock period
        (bool success, ) = actor.proxy(
            stakeBakeAddress,
            abi.encodeWithSelector(bytes4(keccak256("unlockTokens(uint256,uint256)")), 0, 1)
        );
        assertTrue(success, "Unlocking should succeed");

        // Test mature unlocking
        stakingHandler.lockTokens(0, 2, 100, 0, 0);
        vm.roll(block.number + 100); // Past lock period
        (success, ) = actor.proxy(
            stakeBakeAddress,
            abi.encodeWithSelector(bytes4(keccak256("unlockTokens(uint256,uint256)")), 0, 2)
        );
        assertTrue(success, "Mature unlocking should succeed");
    }

    function test_rewardClaim() public {
        stakingHandler.lockTokens(0, 1, 100, 0, 0);
        vm.roll(block.number + 50);
        rewardHandler.claimRewards(0, 0);
    }
}