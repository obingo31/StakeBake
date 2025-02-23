// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Utils
import {Actor} from "./utils/Actor.sol";

// Contracts
import {StakeBake} from "src/StakeBake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Test Contracts
import {BaseTest} from "./base/BaseTest.t.sol";

// Mock Contracts
import {TestERC20} from "./utils/mocks/TestERC20.sol";

// Interfaces
// import {IStakeBake} from "src/interfaces/IStakeBake.sol";

import "forge-std/console.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    StakeBake public stakeBake;
    IERC20 public rewardToken;
    TestERC20 public stakingToken;
    address public admin;
    address[] public users;
    uint256 public constant INIT_BALANCE = 1_000_000 ether;
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 500_000 ether;

    function _setUp() internal {
        // Deploy protocol contracts and protocol actors
        _deployProtocolCore();
        _setUpActors();
    }

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        // Deploy reward and staking tokens
        rewardToken = new TestERC20("Reward Token", "RWD", 18);
        stakingToken = new TestERC20("Staking Token", "STK", 18);

        // Deploy StakeBake
        address[] memory multiSigSigners = new address[](1);
        multiSigSigners[0] = admin;
        stakeBake = new StakeBake(
            address(rewardToken), 
            100_000, // staking duration in blocks
            50_000,  // vesting duration in blocks
            admin,
            multiSigSigners,
            1
        );

        // Mint tokens and distribute them
        rewardToken.mint(address(stakeBake), REWARD_AMOUNT);
        stakingToken.mint(admin, INIT_BALANCE);
    }

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = address(uint160(1)); // USER1
        addresses[1] = address(uint160(2)); // USER2
        addresses[2] = address(uint160(3)); // USER3

        // Initialize the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(rewardToken);
        tokens[1] = address(stakingToken);

        address[] memory contracts = new address[](1);
        contracts[0] = address(stakeBake);

        for (uint256 i = 0; i < addresses.length; i++) {
            // Deploy actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, contracts);

            // Mint initial balances to actors
            stakingToken.mint(_actor, INIT_BALANCE);
            users.push(_actor);
        }
    }

    /// @notice Deploy an actor proxy contract for a user address
    /// @param userAddress Address of the user
    /// @param tokens Array of token addresses
    /// @param contracts Array of contract addresses to approve tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(address userAddress, address[] memory tokens, address[] memory contracts)
        internal
        returns (address actorAddress)
    {
        bool success;
        Actor _actor = new Actor(tokens, contracts);
        (success,) = address(_actor).call{value: INIT_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }

    /// @notice Create a staking pool
    function createPool() public {
        stakeBake.createPool(
            address(stakingToken), 
            10, // Reward rate points
            1,  // Reward rate per second
            5   // Early withdrawal penalty
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  INVARIANTS                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function invariant_RewardFundCannotGoNegative() public view {
        assert(stakeBake.totalRewardFund() >= 0);
    }

    function invariant_StakedAmountsMatchPoolTotal() public view {
        uint256 totalStaked;
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < stakeBake.poolCount(); j++) {
                (uint72 tokenAmount,,,,) = stakeBake.userStakes(users[i], j);
                totalStaked += tokenAmount;
            }
        }
        uint256 expectedTotalStaked;
        for (uint256 j = 0; j < stakeBake.poolCount(); j++) {
            (,, uint256 poolTotalStaked,,,) = stakeBake.pools(j);
            expectedTotalStaked += poolTotalStaked;
        }
        assertEq(totalStaked, expectedTotalStaked);
    }

    function invariant_RewardPointsMatchTotalPool() public view {
        uint256 totalUserPoints;
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < stakeBake.poolCount(); j++) {
                totalUserPoints += stakeBake.userRewardPoints(users[i], j);
            }
        }
        uint256 totalPoolPoints;
        for (uint256 j = 0; j < stakeBake.poolCount(); j++) {
            totalPoolPoints += stakeBake.poolTotalRewardPoints(j);
        }
        assertEq(totalUserPoints, totalPoolPoints);
    }

    function invariant_UserBalancesNeverExceedTotalSupply() public view {
        uint256 totalTokenBalance;
        for (uint256 i = 0; i < users.length; i++) {
            totalTokenBalance += rewardToken.balanceOf(users[i]);
        }
        assertLe(totalTokenBalance, rewardToken.totalSupply());
    }
}