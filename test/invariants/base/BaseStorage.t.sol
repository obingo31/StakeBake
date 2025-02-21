// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Contracts
import "src/StakeBake.sol";

// Mock Contracts
import {TestERC20} from "../utils/mocks/TestERC20.sol"; 

// Utils
import {Actor} from "../utils/Actor.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice BaseStorage contract for all StakeBake test contracts, works with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29; // Max token amount for staking/rewards

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3; // Number of test actors
    uint256 internal constant INITIAL_TOKEN_BALANCE = 1e26; // Initial balance for actors

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The pool admin is set to this contract (Tester contract)
    address internal poolAdmin = address(this);

    /// @notice The actor to which hooks are applied
    address internal targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // PROTOCOL CONTRACTS

    /// @notice The StakeBake contract instance
    StakeBake internal stakeBake;

    // ASSETS

    /// @notice Reward token for staking rewards
    TestERC20 internal rewardToken;

    /// @notice Array of staking tokens for each pool
    TestERC20[] internal stakingTokens;

    // CONFIGURATION

    /// @notice Staking program duration in blocks
    uint256 internal stakingDurationInBlocks;

    /// @notice Vesting duration in blocks
    uint256 internal vestingDuration;

    /// @notice Owner of the StakeBake contract
    address internal owner;

    /// @notice Multi-signature signers
    address[] internal multiSigSigners;

    /// @notice Required signatures for multi-sig actions
    uint256 internal multiSigRequiredSignatures;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Array of pool IDs for the suite (for iteration)
    uint256[] internal poolIds;

    /// @notice Mapping of pool ID to its staking token
    mapping(uint256 => IERC20) internal poolStakingTokens;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SETUP                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(
        address _stakeBake,
        address _rewardToken,
        uint256 _stakingDurationInBlocks,
        uint256 _vestingDuration,
        address _owner,
        address[] memory _multiSigSigners,
        uint256 _multiSigRequiredSignatures,
        address[] memory _actors
    ) {
        stakeBake = StakeBake(_stakeBake);
        rewardToken = TestERC20(_rewardToken);
        stakingDurationInBlocks = _stakingDurationInBlocks;
        vestingDuration = _vestingDuration;
        owner = _owner;
        multiSigSigners = _multiSigSigners;
        multiSigRequiredSignatures = _multiSigRequiredSignatures;
        actorAddresses = _actors;

        // Initialize actors
        for (uint256 i = 0; i < _actors.length; i++) {
            actors[_actors[i]] = new Actor(_stakeBake, new address[](1), new address[](1));
            actors[_actors[i]].proxy(_stakeBake, abi.encodeWithSignature("")); // Placeholder setup
        }
    }

    /// @notice Add a staking token for a newly created pool
    function addStakingToken(uint256 _poolId, address _stakingToken) internal {
        stakingTokens.push(TestERC20(_stakingToken));
        poolStakingTokens[_poolId] = IERC20(_stakingToken);
        poolIds.push(_poolId);
    }
}