// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Utils
import {Actor} from "../utils/Actor.sol";

// Contracts
import "../StakeBake.sol";

// Test Contracts
import {BaseTest} from "./BaseTest.t.sol";

// Mock Contracts
import {TestERC20} from "../utils/mocks/TestERC20.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

/// @notice Setup contract for the StakeBake invariant test suite, inherited by Tester
/// @dev Deploys and configures the full StakeBake protocol for fuzzing
contract Setup is BaseTest {
    // StakeBake protocol contracts
    StakeBake internal stakeBake;

    // Assets
    TestERC20 internal rewardToken;
    TestERC20[] internal stakingTokens; // staking tokens for each pool

    // Configuration constants
    uint256 constant STAKING_DURATION_IN_BLOCKS = 100000; // ~2 weeks at 13s/block
    uint256 constant VESTING_DURATION = 10000; // ~2 days at 13s/block
    uint256 constant INITIAL_TOKEN_BALANCE = 1e26; // 10^26 tokens for actors
    uint256 constant NUMBER_OF_POOLS = 2; // Number of staking pools
    uint256 constant DAO_FEE = 0.05e18; // 5% fee for penalty distribution
    uint256 constant MAX_TOKEN_AMOUNT = 1e29; // Max token amount for fuzzing

    // Actor addresses
    address constant DAO_ADMIN = address(0x1111);
    address constant USER1 = address(0x2222);
    address constant USER2 = address(0x3333);
    address constant USER3 = address(0x4444);

    // Multisig configuration
    address[] internal multiSigSigners;
    uint256 internal multiSigRequiredSignatures = 2;

    function _setUp() internal {
        // Deploy protocol contracts and actors
        _deployProtocolCore();
        _setUpActors();
    }

    /// @notice Deploy StakeBake core protocol components
    function _deployProtocolCore() internal {
        // Deploy core protocol contracts
        core_setUp(DAO_ADMIN);

        // Deploy assets
        _deployAssets();

        // Create staking pools
        _initPools();
    }

    /// @notice Deploy StakeBake core contracts
    function core_setUp(address daoAdmin) internal {
        // Deploy reward token
        rewardToken = new TestERC20("Reward Token", "RWD", 18);

        // Setup multisig signers
        multiSigSigners = new address[](3);
        multiSigSigners[0] = daoAdmin;
        multiSigSigners[1] = USER1;
        multiSigSigners[2] = USER2;

        // Deploy StakeBake contract
        stakeBake = new StakeBake(
            address(rewardToken),
            STAKING_DURATION_IN_BLOCKS,
            VESTING_DURATION,
            daoAdmin, // Owner
            multiSigSigners,
            multiSigRequiredSignatures
        );

        // Fund StakeBake with reward tokens for distribution
        rewardToken.mint(address(this), INITIAL_TOKEN_BALANCE * 10); // Extra for contract
        rewardToken.approve(address(stakeBake), type(uint256).max);
        rewardToken.transfer(address(stakeBake), INITIAL_TOKEN_BALANCE * 5); // 5x actor initial balance
    }

    /// @notice Deploy assets (staking tokens for pools)
    function _deployAssets() internal {
        for (uint256 i = 0; i < NUMBER_OF_POOLS; i++) {
            TestERC20 stakingToken = new TestERC20(
                string(abi.encodePacked("Stake Token ", uint8(i + 48))),
                string(abi.encodePacked("STK", uint8(i + 48))),
                18
            );
            stakingTokens.push(stakingToken);
        }
    }

    /// @notice Initialize staking pools
    function _initPools() internal {
        for (uint256 i = 0; i < NUMBER_OF_POOLS; i++) {
            stakeBake.createPool(
                address(stakingTokens[i]),
                1e18, // rewardRatePoints (1x multiplier)
                1e12, // rewardRatePerSecond (1 trillion wei/sec)
                50    // earlyWithdrawalPenalty (50%)
            );
        }
    }

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize actor addresses
        address[] memory addresses = new address[](4);
        addresses[0] = DAO_ADMIN;
        addresses[1] = USER1;
        addresses[2] = USER2;
        addresses[3] = USER3;

        // Initialize tokens array (reward + staking tokens)
        address[] memory tokens = new address[](stakingTokens.length + 1);
        tokens[0] = address(rewardToken);
        for (uint256 i = 0; i < stakingTokens.length; i++) {
            tokens[i + 1] = address(stakingTokens[i]);
        }

        // Contracts to approve tokens to
        address[] memory contracts = new address[](1);
        contracts[0] = address(stakeBake);

        for (uint256 i = 0; i < addresses.length; i++) {
            // Deploy actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, contracts);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                TestERC20 _token = TestERC20(tokens[j]);
                _token.mint(_actor, INITIAL_TOKEN_BALANCE);
            }
            actorAddresses.push(_actor);
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
        Actor _actor = new Actor(address(stakeBake), tokens, contracts);
        actors[userAddress] = _actor;
        vm.deal(address(_actor), INITIAL_TOKEN_BALANCE); // Provide ETH for gas
        actorAddress = address(_actor);
    }
}