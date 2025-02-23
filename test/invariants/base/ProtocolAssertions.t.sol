// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Base
import {StakeBakeBaseTest} from "./StakeBakeBaseTest.t.sol";
import {StakeBakeStdAsserts} from "./StakeBakeStdAsserts.sol";

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/// @title StakeBakeProtocolAssertions
/// @notice Helper contract for StakeBake protocol-specific assertions
contract StakeBakeProtocolAssertions is StakeBakeStdAsserts, StakeBakeBaseTest {
    IERC20 public rewardToken;
    IERC721 public recipeNFT;

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
    ) {
        stakeBakeAddress = _stakeBakeAddress;
        rewardToken = IERC20(_rewardTokenAddress);
        recipeNFT = IERC721(_recipeNFTAddress);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assertBaseInvariantA(uint256 poolId) public {
        (bool success, bytes memory poolData) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("pools(uint256)")), poolId)
        );
        require(success, "Failed to fetch pool data");
        (, uint256 totalStaked, , , , , , bool active, ) = abi.decode(
            poolData,
            (address, uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256)
        );
        uint256 nftBalance = recipeNFT.balanceOf(stakeBakeAddress);
        bool condition = (totalStaked == 0) == (!active || nftBalance == 0);
        assertTrue(condition, BASE_INVARIANT_A);
    }

    function assertBaseInvariantB() public {
        uint256 contractBalance = rewardToken.balanceOf(stakeBakeAddress);
        (bool success, bytes memory totalRewardFundData) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("totalRewardFund()")))
        );
        require(success, "Failed to fetch totalRewardFund");
        uint256 totalRewardFund = abi.decode(totalRewardFundData, (uint256));
        assertGe(contractBalance, totalRewardFund, BASE_INVARIANT_B);
    }

    function assertBaseInvariantD(uint256 poolId, address user) public {
        (bool success, bytes memory stakedCountData) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("userStakedTokenIds(address,uint256)")), user, poolId)
        );
        require(success, "Failed to fetch userStakedTokenIds");
        uint256[] memory stakedTokenIds = abi.decode(stakedCountData, (uint256[]));
        uint256 stakedCount = stakedTokenIds.length;

        (success, bytes memory rewardPointsData) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("userRewardPoints(address,uint256)")), user, poolId)
        );
        require(success, "Failed to fetch userRewardPoints");
        uint256 rewardPoints = abi.decode(rewardPointsData, (uint256));

        if (stakedCount > 0) {
            assertGt(rewardPoints, 0, BASE_INVARIANT_D);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   STAKING POSTCONDITIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assertStakingHSPostA(uint256 poolId, uint256 beforeTotalStaked, uint256 afterTotalStaked, uint256 tokenId) public {
        (bool success, bytes memory weightData) = address(recipeNFT).staticcall(
            abi.encodeWithSelector(bytes4(keccak256("getWeight(uint256)")), tokenId)
        );
        require(success, "Failed to fetch token weight");
        uint256 tokenWeight = abi.decode(weightData, (uint256));
        assertIncreasedBy(beforeTotalStaked, afterTotalStaked, tokenWeight, STAKING_HSPOST_A);
    }

    function assertStakingHSPostB(uint256 poolId, address user, uint256 beforeCount, uint256 afterCount) public {
        assertIncreasedBy(beforeCount, afterCount, 1, STAKING_HSPOST_B);
    }

    function assertStakingGPostD(address user, uint256 tokenId) public {
        assertNFTOwner(address(recipeNFT), tokenId, stakeBakeAddress, STAKING_GPOST_D);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   GOVERNANCE POSTCONDITIONS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assertGovernanceHSPostA(bool beforeState, bool afterState) public {
        assertEq(afterState, !beforeState, GOVERNANCE_HSPOST_A);
    }
}