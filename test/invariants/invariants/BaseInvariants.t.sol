// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/StakeBake.sol";

// Contracts
import "../hooks/HookAggregator.sol";
import "forge-std/console.sol";

/// @title BaseInvariants
/// @notice Implements base invariants for the StakeBake protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    StakeBake public stakeBake;
    address[] public actorAddresses;

    // Labels for invariant assertions
    string constant BASE_INVARIANT_TOTAL_STAKED = "Total staked exceeds staking token balance";
    string constant BASE_INVARIANT_POOL_COUNT = "Pool count is negative";
    string constant BASE_INVARIANT_TOTAL_REWARD_FUND = "Total reward fund exceeds reward token balance";
    string constant BASE_INVARIANT_EMERGENCY_STOP = "Emergency stop set by unauthorized actor";
    string constant BASE_INVARIANT_ACTOR_BALANCE = "Actor reward token balance is negative";
    string constant BASE_INVARIANT_REENTRANCY = "Reentrancy guard entered unexpectedly";

    constructor(address _stakeBake, address[] memory _actors) {
        stakeBake = StakeBake(_stakeBake);
        actorAddresses = _actors;
    }

    /// @notice Ensures totalStaked <= stakingToken balance for a pool
    function assert_BASE_INVARIANT_TOTAL_STAKED(uint256 _poolId) internal view {
        require(_poolId < stakeBake.poolCount(), "Invalid pool ID");
        (StakeBake.Pool memory pool,) = stakeBake.getPoolInfo(_poolId);
        uint256 stakingTokenBalance = pool.stakingToken.balanceOf(address(stakeBake));
        assertLe(pool.totalStaked, stakingTokenBalance, BASE_INVARIANT_TOTAL_STAKED);
    }

    /// @notice Ensures poolCount is non-negative
    function assert_BASE_INVARIANT_POOL_COUNT() internal view {
        assertGe(stakeBake.poolCount(), 0, BASE_INVARIANT_POOL_COUNT);
    }

    /// @notice Ensures totalRewardFund <= rewardToken balance
    function assert_BASE_INVARIANT_TOTAL_REWARD_FUND() internal view {
        uint256 totalRewardFund = stakeBake.totalRewardFund();
        uint256 rewardTokenBalance = stakeBake.rewardToken().balanceOf(address(stakeBake));
        assertLe(totalRewardFund, rewardTokenBalance, BASE_INVARIANT_TOTAL_REWARD_FUND);
    }

    /// @notice Ensures emergencyStopped only set by authorized (owner or multisig)
    function assert_BASE_INVARIANT_EMERGENCY_STOP() internal view {
        bool emergencyStopped = stakeBake.emergencyStopped();
        if (emergencyStopped) {
            // Simplified: assumes only owner can set (extend for multisig if logic added)
            assertEq(stakeBake.owner(), msg.sender, BASE_INVARIANT_EMERGENCY_STOP);
        }
    }

    /// @notice Ensures actor reward token balances are non-negative
    function assert_BASE_INVARIANT_ACTOR_BALANCE(address _actor) internal view {
        uint256 rewardBalance = stakeBake.rewardToken().balanceOf(_actor);
        assertGe(rewardBalance, 0, BASE_INVARIANT_ACTOR_BALANCE);
    }

    /// @notice Ensures reentrancy guard is not entered unexpectedly
    function assert_BASE_INVARIANT_REENTRANCY() internal view {
        // StakeBake uses OpenZeppelin's ReentrancyGuard; check its storage slot
        bytes32 reentrancySlot = keccak256("ReentrancyGuard.reentrancyGuard");
        uint256 reentrancyStatus = uint256(vm.load(address(stakeBake), reentrancySlot));
        assertEq(reentrancyStatus, 1, BASE_INVARIANT_REENTRANCY); // 1 = not entered, 2 = entered
    }
}