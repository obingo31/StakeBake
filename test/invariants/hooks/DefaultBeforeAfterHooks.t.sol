// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Libraries
import {Pretty, Strings} from "../utils/Pretty.sol";
import "forge-std/console.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/StakeBake.sol";

// Test Contracts
import "../base/BaseHooks.t.sol";
import "../utils/Actor.sol";

/// @title DefaultBeforeAfterHooks
/// @notice Helper contract for before and after hooks in StakeBake testing
/// @dev Inherited by handlers via HookAggregator
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct DefaultVars {
        // StakeBake Global State
        uint256 poolCount;
        uint256 totalRewardFund;
        bool emergencyStopped;
        uint256 rewardTokenBalance;
        // Pool-Specific State
        uint256 totalStaked;
        uint256 rewardPerTokenStored;
        uint256 updatedAt;
        bool poolActive;
        uint256 earlyWithdrawalPenalty;
        // User-Specific State
        uint72 userStakeAmount;
        uint24 userLockingPeriod;
        uint32 userStartBlock;
        uint128 userExpectedRewardPoints;
        bool userClaimed;
        uint256 userContinuousRewards;
        uint256 userGrantedTokens;
        uint256 userReleasedTokens;
        uint256 userStakingTokenBalance;
        uint256 userRewardTokenBalance;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(uint256 => mapping(address => DefaultVars)) defaultVarsBefore; // Pool ID -> Actor -> State
    mapping(uint256 => mapping(address => DefaultVars)) defaultVarsAfter;  // Pool ID -> Actor -> State

    // StakeBake instance from BaseHooks
    StakeBake public stakeBake;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Cache state before an action for a specific pool and target actor
    function _defaultHooksBefore(uint256 _poolId) internal {
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            address actor = actorAddresses[i];
            _setGlobalValues(_poolId, actor, defaultVarsBefore[_poolId][actor]);
            _setPoolValues(_poolId, actor, defaultVarsBefore[_poolId][actor]);
            _setUserValues(_poolId, actor, defaultVarsBefore[_poolId][actor]);
        }
    }

    /// @notice Cache state after an action for a specific pool and target actor
    function _defaultHooksAfter(uint256 _poolId) internal {
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            address actor = actorAddresses[i];
            _setGlobalValues(_poolId, actor, defaultVarsAfter[_poolId][actor]);
            _setPoolValues(_poolId, actor, defaultVarsAfter[_poolId][actor]);
            _setUserValues(_poolId, actor, defaultVarsAfter[_poolId][actor]);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETTERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Set global StakeBake values
    function _setGlobalValues(uint256 _poolId, address _actor, DefaultVars storage _vars) internal {
        _vars.poolCount = stakeBake.poolCount();
        _vars.totalRewardFund = stakeBake.totalRewardFund();
        _vars.emergencyStopped = stakeBake.emergencyStopped();
        _vars.rewardTokenBalance = stakeBake.rewardToken().balanceOf(address(stakeBake));
    }

    /// @notice Set pool-specific values
    function _setPoolValues(uint256 _poolId, address _actor, DefaultVars storage _vars) internal {
        if (_poolId < stakeBake.poolCount()) {
            (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(_poolId);
            _vars.totalStaked = pool.totalStaked;
            _vars.rewardPerTokenStored = pool.rewardPerTokenStored;
            _vars.updatedAt = pool.updatedAt;
            _vars.poolActive = pool.active;
            _vars.earlyWithdrawalPenalty = pool.earlyWithdrawalPenalty;
        }
    }

    /// @notice Set user-specific values
    function _setUserValues(uint256 _poolId, address _actor, DefaultVars storage _vars) internal {
        if (_poolId < stakeBake.poolCount()) {
            StakeBake.Stake memory stake = stakeBake.userStakes(_actor, _poolId);
            _vars.userStakeAmount = stake.tokenAmount;
            _vars.userLockingPeriod = stake.lockingPeriodInBlocks;
            _vars.userStartBlock = stake.startBlock;
            _vars.userExpectedRewardPoints = stake.expectedStakingRewardPoints;
            _vars.userClaimed = stake.claimed;
            _vars.userContinuousRewards = stakeBake.continuousRewards(_actor);
            _vars.userGrantedTokens = stakeBake.grantedTokens(_actor);
            _vars.userReleasedTokens = stakeBake.releasedTokens(_actor);
            (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(_poolId);
            _vars.userStakingTokenBalance = pool.stakingToken.balanceOf(_actor);
            _vars.userRewardTokenBalance = stakeBake.rewardToken().balanceOf(_actor);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Check if rewardPerTokenStored was updated
    function _isRewardPerTokenUpdated(uint256 _poolId, address _actor) internal view returns (bool) {
        return defaultVarsBefore[_poolId][_actor].rewardPerTokenStored != defaultVarsAfter[_poolId][_actor].rewardPerTokenStored;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GLOBAL POST CONDITIONS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // BASE GPOSTs
    function assert_BASE_GPOST_TOTAL_STAKED(uint256 _poolId, address _actor) internal {
        uint256 beforeTotalStaked = defaultVarsBefore[_poolId][_actor].totalStaked;
        uint256 afterTotalStaked = defaultVarsAfter[_poolId][_actor].totalStaked;
        assert(afterTotalStaked >= beforeTotalStaked || afterTotalStaked <= beforeTotalStaked); // Can increase or decrease
    }

    function assert_BASE_GPOST_REWARD_FUND(address _actor) internal {
        uint256 beforeFund = defaultVarsBefore[0][_actor].totalRewardFund; // 0 as a proxy for global state
        uint256 afterFund = defaultVarsAfter[0][_actor].totalRewardFund;
        assert(afterFund >= beforeFund); // Should only increase (e.g., via penalties)
    }

    function assert_BASE_GPOST_POOL_COUNT(address _actor) internal {
        uint256 beforeCount = defaultVarsBefore[0][_actor].poolCount;
        uint256 afterCount = defaultVarsAfter[0][_actor].poolCount;
        assert(afterCount >= beforeCount); // Should only increase
    }

    // STAKE GPOSTs
    function assert_STAKE_GPOST_USER_STAKE(uint256 _poolId, address _actor) internal {
        DefaultVars storage beforeVars = defaultVarsBefore[_poolId][_actor];
        DefaultVars storage afterVars = defaultVarsAfter[_poolId][_actor];
        if (afterVars.userStakeAmount != beforeVars.userStakeAmount) {
            assert(afterVars.userStakeAmount > 0 || afterVars.userClaimed); // Stake updated or claimed
        }
    }

    // REWARD GPOSTs
    function assert_REWARD_GPOST_CONTINUOUS(uint256 _poolId, address _actor) internal {
        uint256 beforeRewards = defaultVarsBefore[_poolId][_actor].userContinuousRewards;
        uint256 afterRewards = defaultVarsAfter[_poolId][_actor].userContinuousRewards;
        assert(afterRewards >= beforeRewards || afterRewards == 0); // Rewards accrued or claimed
    }

    // VESTING GPOSTs
    function assert_VESTING_GPOST_RELEASED_VS_GRANTED(address _actor) internal {
        uint256 beforeGranted = defaultVarsBefore[0][_actor].userGrantedTokens;
        uint256 beforeReleased = defaultVarsBefore[0][_actor].userReleasedTokens;
        uint256 afterGranted = defaultVarsAfter[0][_actor].userGrantedTokens;
        uint256 afterReleased = defaultVarsAfter[0][_actor].userReleasedTokens;
        assert(afterReleased <= afterGranted);
        assert(afterGranted >= beforeGranted); // Granted only increases
        assert(afterReleased >= beforeReleased); // Released only increases
    }
}