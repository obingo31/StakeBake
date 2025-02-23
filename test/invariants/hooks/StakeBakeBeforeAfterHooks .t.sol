// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Pretty, Strings} from "../utils/Pretty.sol";
import "forge-std/console.sol";

// Interfaces
import {StakeBake} from "./StakeBake.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";
import {Actor} from "../utils/Actor.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";

/// @title StakeBake Before After Hooks
/// @notice Helper contract for StakeBake-specific before and after hooks
/// @dev This contract is inherited by handlers
abstract contract StakeBakeBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct StakeBakeVars {
        // Pool State
        uint256 totalStaked;
        uint256 rewardPerTokenStored;
        uint256 poolTotalRewardPoints;
        uint256 updatedAt;
        // User State
        uint256 userRewardPoints;
        uint256 userStakedCount;
        uint256 userContinuousRewards;
        uint256 userRewardPerTokenPaid;
        // Contract State
        uint256 totalRewardFund;
        uint256 grantedTokens;
        uint256 releasedTokens;
        bool isEmergencyStopped;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(uint256 => mapping(address => StakeBakeVars)) varsBefore; // poolId => actor => vars
    mapping(uint256 => mapping(address => StakeBakeVars)) varsAfter;  // poolId => actor => vars

    StakeBake public stakeBake;
    IERC20 public rewardToken;
    TestERC721 public recipeNFT;

    // Error messages
    string constant STAKE_GPOST_A = "Total staked decreased unexpectedly";
    string constant STAKE_GPOST_B = "Reward points decreased";
    string constant STAKE_GPOST_C = "Continuous rewards decreased unexpectedly";
    string constant STAKE_GPOST_D = "Operations allowed during emergency stop";

    constructor(
        address stakeBakeAddress,
        address rewardTokenAddress,
        address recipeNFTAddress,
        address owner,
        address[] memory multiSigSigners,
        uint256 multiSigRequiredSignatures,
        uint256 stakingDurationInBlocks,
        uint256 vestingDuration
    ) BaseHooks(stakeBakeAddress, rewardTokenAddress, owner, multiSigSigners, multiSigRequiredSignatures, stakingDurationInBlocks, vestingDuration) {
        stakeBake = StakeBake(stakeBakeAddress);
        rewardToken = IERC20(rewardTokenAddress);
        recipeNFT = TestERC721(recipeNFTAddress);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice StakeBake-specific hooks setup
    function _setUpStakeBakeHooks() internal virtual {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _stakeBakeHooksBefore(uint256 poolId, address actor) internal {
        _setPoolValues(poolId, actor, varsBefore[poolId][actor]);
        _setUserValues(poolId, actor, varsBefore[poolId][actor]);
    }

    function _stakeBakeHooksAfter(uint256 poolId, address actor) internal {
        _setPoolValues(poolId, actor, varsAfter[poolId][actor]);
        _setUserValues(poolId, actor, varsAfter[poolId][actor]);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETTERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setPoolValues(uint256 poolId, address actor, StakeBakeVars storage _vars) internal {
        StakeBake.Pool memory pool = stakeBake.pools(poolId);
        _vars.totalStaked = pool.totalStaked;
        _vars.rewardPerTokenStored = pool.rewardPerTokenStored;
        _vars.poolTotalRewardPoints = stakeBake.poolTotalRewardPoints(poolId);
        _vars.updatedAt = pool.updatedAt;
        _vars.totalRewardFund = stakeBake.totalRewardFund();
        _vars.isEmergencyStopped = stakeBake.isEmergencyStopped();
    }

    function _setUserValues(uint256 poolId, address actor, StakeBakeVars storage _vars) internal {
        bytes32 userPoolKey = stakeBake.getUserPoolKey(actor, poolId);
        _vars.userRewardPoints = stakeBake.userRewardPoints(actor, poolId);
        _vars.userStakedCount = stakeBake.userStakedTokenIds(actor, poolId).length;
        _vars.userContinuousRewards = stakeBake.continuousRewards(userPoolKey);
        _vars.userRewardPerTokenPaid = stakeBake.userRewardPerTokenPaid(actor, poolId);
        _vars.grantedTokens = stakeBake.grantedTokens(actor);
        _vars.releasedTokens = stakeBake.releasedTokens(actor);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _isRewardUpdated(uint256 poolId, address actor) internal view returns (bool) {
        return varsBefore[poolId][actor].updatedAt != varsAfter[poolId][actor].updatedAt;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GLOBAL POST CONDITIONS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_STAKE_GPOST_A(uint256 poolId, address actor) internal {
        // Total staked should never decrease unless emergency stop is active
        if (!varsAfter[poolId][actor].isEmergencyStopped) {
            assertGe(
                varsAfter[poolId][actor].totalStaked,
                varsBefore[poolId][actor].totalStaked,
                STAKE_GPOST_A
            );
        }
    }

    function assert_STAKE_GPOST_B(uint256 poolId, address actor) internal {
        // User reward points should never decrease
        assertGe(
            varsAfter[poolId][actor].userRewardPoints,
            varsBefore[poolId][actor].userRewardPoints,
            STAKE_GPOST_B
        );
        
        // Pool total reward points should never decrease
        assertGe(
            varsAfter[poolId][actor].poolTotalRewardPoints,
            varsBefore[poolId][actor].poolTotalRewardPoints,
            STAKE_GPOST_B
        );
    }

    function assert_STAKE_GPOST_C(uint256 poolId, address actor) internal {
        // Continuous rewards should never decrease when rewards are updated
        if (_isRewardUpdated(poolId, actor)) {
            assertGe(
                varsAfter[poolId][actor].userContinuousRewards,
                varsBefore[poolId][actor].userContinuousRewards,
                STAKE_GPOST_C
            );
        }
    }

    function assert_STAKE_GPOST_D(uint256 poolId, address actor) internal {
        // No staking operations should succeed during emergency stop
        if (varsBefore[poolId][actor].isEmergencyStopped &&
            varsAfter[poolId][actor].isEmergencyStopped) {
            assertEq(
                varsAfter[poolId][actor].userStakedCount,
                varsBefore[poolId][actor].userStakedCount,
                STAKE_GPOST_D
            );
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STAKING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_STAKING_GPOST_E(uint256 poolId, address actor) internal {
        // If staking occurred, staked count should increase
        if (msg.sig == bytes4(keccak256("lockTokens(uint256,uint256,uint256)"))) {
            assertGt(
                varsAfter[poolId][actor].userStakedCount,
                varsBefore[poolId][actor].userStakedCount,
                "Staking didn't increase staked count"
            );
        }
    }
}

/// @title StakeBake Handler
/// @notice Handler for testing StakeBake operations
contract StakeBakeHandler is StakeBakeBeforeAfterHooks {
    constructor(
        address stakeBakeAddress,
        address rewardTokenAddress,
        address recipeNFTAddress,
        address owner,
        address[] memory multiSigSigners,
        uint256 multiSigRequiredSignatures,
        uint256 stakingDurationInBlocks,
        uint256 vestingDuration
    ) StakeBakeBeforeAfterHooks(
        stakeBakeAddress,
        rewardTokenAddress,
        recipeNFTAddress,
        owner,
        multiSigSigners,
        multiSigRequiredSignatures,
        stakingDurationInBlocks,
        vestingDuration
    ) {}

    function lockTokens(uint256 poolId, uint256 tokenId, uint256 lockingPeriod) public {
        vm.assume(lockingPeriod <= stakingDurationInBlocks);
        vm.assume(poolId < stakeBake.poolCount());
        
        recipeNFT.mint(targetActor, tokenId);
        vm.prank(targetActor);
        recipeNFT.approve(address(stakeBake), tokenId);
        
        _stakeBakeHooksBefore(poolId, targetActor);
        vm.prank(targetActor);
        stakeBake.lockTokens(poolId, tokenId, lockingPeriod);
        _stakeBakeHooksAfter(poolId, targetActor);
        
        // Check invariants
        assert_STAKE_GPOST_A(poolId, targetActor);
        assert_STAKE_GPOST_B(poolId, targetActor);
        assert_STAKE_GPOST_C(poolId, targetActor);
        assert_STAKE_GPOST_D(poolId, targetActor);
        assert_STAKING_GPOST_E(poolId, targetActor);
    }
}        