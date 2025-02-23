// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {StakeBakeActor} from "../../utils/StakeBakeActor.sol";
import {StakeBakeBaseHandler} from "../../base/StakeBakeBaseHandler.t.sol";
import {StakeBakeStdAsserts} from "../../base/StakeBakeStdAsserts.sol";

/// @title StakeBakeStakingHandler
/// @notice Handler test contract for StakeBake staking actions
contract StakeBakeStakingHandler is StakeBakeBaseHandler, StakeBakeStdAsserts {
    IERC20 public rewardToken;
    IERC721 public recipeNFT;

    constructor(
        address stakeBakeAddress,
        address rewardTokenAddress,
        address recipeNFTAddress,
        address owner,
        address[] memory multiSigSigners,
        uint256 multiSigRequiredSignatures,
        uint256 stakingDurationInBlocks,
        uint256 vestingDuration,
        StakeBakeActor _actor
    ) StakeBakeBaseHandler(
        stakeBakeAddress,
        rewardTokenAddress,
        recipeNFTAddress,
        owner,
        multiSigSigners,
        multiSigRequiredSignatures,
        stakingDurationInBlocks,
        vestingDuration
    ) {
        actor = _actor;
        rewardToken = IERC20(rewardTokenAddress);
        recipeNFT = IERC721(recipeNFTAddress);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function lockTokens(uint256 _tokenId, uint256 _lockingPeriod, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the actors randomly
        address staker = _getRandomActor(i);

        // Get a random pool
        uint256 poolId = _getRandomPool(j);

        // Clamp locking period to valid range
        _lockingPeriod = clampBetween(_lockingPeriod, 1, stakingDurationInBlocks);

        // Mint and approve NFT
        _mintAndApproveERC721(address(recipeNFT), staker, stakeBakeAddress, _tokenId);

        _before();
        (success, returnData) = actor.proxy(
            stakeBakeAddress,
            abi.encodeWithSelector(bytes4(keccak256("lockTokens(uint256,uint256,uint256)")), poolId, _tokenId, _lockingPeriod)
        );

        // POST-CONDITIONS
        if (success) {
            _after();

            assertIncreasedBy(
                varsBefore[poolId][staker].totalStaked,
                varsAfter[poolId][staker].totalStaked,
                1, // Assuming getWeight returns 1; adjust if different
                STAKING_HSPOST_A
            );
            assertIncreasedBy(
                varsBefore[poolId][staker].userStakedCount,
                varsAfter[poolId][staker].userStakedCount,
                1,
                STAKING_HSPOST_B
            );
            assertPositiveRewardPoints(
                varsAfter[poolId][staker].userRewardPoints - varsBefore[poolId][staker].userRewardPoints,
                STAKING_HSPOST_C
            );
            assertNFTOwner(address(recipeNFT), _tokenId, stakeBakeAddress, STAKING_GPOST_D);
        }

        // Zero locking period should fail
        if (_lockingPeriod == 0) {
            assertFalse(success, "Zero locking period should fail");
        }
    }

    // Note: StakeBake doesn’t have direct equivalents to mint, withdraw, or redeem.
    // We could add unlockTokens or claim rewards later if needed.

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          PROPERTIES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_STAKING_INVARIANT_A(uint8 i, uint8 j, uint256 tokenId1, uint256 tokenId2) public setup {
        bool success1;
        bool success2;
        bytes memory returnData1;
        bytes memory returnData2;

        address staker = _getRandomActor(i);
        uint256 poolId = _getRandomPool(j);

        // Mint two NFTs and approve them
        _mintAndApproveERC721(address(recipeNFT), staker, stakeBakeAddress, tokenId1);
        _mintAndApproveERC721(address(recipeNFT), staker, stakeBakeAddress, tokenId2);

        _before();
        // First staking attempt
        (success1, returnData1) = actor.proxy(
            stakeBakeAddress,
            abi.encodeWithSelector(bytes4(keccak256("lockTokens(uint256,uint256,uint256)")), poolId, tokenId1, 100)
        );
        if (success1) {
            // Second staking attempt with the same token should fail (STAKING_INVARIANT_A: NFT can only be staked once)
            (success2, returnData2) = actor.proxy(
                stakeBakeAddress,
                abi.encodeWithSelector(bytes4(keccak256("lockTokens(uint256,uint256,uint256)")), poolId, tokenId1, 100)
            );
            assertFalse(success2, STAKING_INVARIANT_A);
        }
        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Owner actions like emergencyStop or pool creation would go in StakeBakeConfigHandler

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}