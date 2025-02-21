// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/StakeBake.sol";

// Libraries
import {Vm} from "forge-std/Vm.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "forge-std/console.sol";

// Utils
import {Actor} from "../utils/Actor.sol";
import {PropertiesConstants} from "../utils/PropertiesConstants.sol"; 
import {StdAsserts} from "../utils/StdAsserts.sol"; 

// Base
import {BaseStorage} from "./BaseStorage.t.sol"; 

/// @title BaseTest
/// @notice Base contract for all StakeBake test contracts, extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev Inherits BaseStorage, PropertiesConstants, StdAsserts, and StdUtils
abstract contract BaseTest is BaseStorage, PropertiesConstants, StdAsserts, StdUtils {
    bool internal IS_TEST = true;

    // Actor proxy instance
    Actor public actor;
    address public targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   ACTOR PROXY MECHANISM                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Actor proxy mechanism to select a random actor for each test call
    modifier setup() virtual {
        // Select a random actor from actorAddresses
        uint256 actorIndex = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % actorAddresses.length;
        targetActor = actorAddresses[actorIndex];
        actor = Actor(payable(targetActor));
        _;
        actor = Actor(payable(address(0)));
        targetActor = address(0);
    }

    /// @dev Ensures monotonic timestamp progression (optional for Echidna)
    modifier monotonicTimestamp() virtual {
        uint256 prevTimestamp = block.timestamp;
        _;
        assertGe(block.timestamp, prevTimestamp, "Timestamp decreased");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     CHEAT CODE SETUP                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    /// @dev Virtual machine instance
    Vm internal constant vm = Vm(VM_ADDRESS);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Get the maximum releasable amount for a user (simulates release logic)
    function _maxReleasable(address _user) internal view returns (uint256) {
        try stakeBake._releasableAmount(_user) returns (uint256 amount) { // Note: private, needs accessor
            return amount;
        } catch {
            return 0;
        }
    }

    /// @notice Get the total staked amount for a pool by a user
    function _totalStaked(address _user, uint256 _poolId) internal view returns (uint256) {
        StakeBake.Stake memory stake = stakeBake.userStakes(_user, _poolId);
        return stake.tokenAmount;
    }

    /// @notice Check if a user has an active stake in any pool
    function _hasActiveStake(address _user) internal view returns (bool) {
        for (uint256 i = 0; i < stakeBake.poolCount(); i++) {
            StakeBake.Stake memory stake = stakeBake.userStakes(_user, i);
            if (stake.tokenAmount > 0 && !stake.claimed) {
                return true;
            }
        }
        return false;
    }

    /// @notice Get a user's total continuous rewards across all pools
    function _getUserContinuousRewards(address _user) internal view returns (uint256) {
        return stakeBake.continuousRewards(_user);
    }

    /// @notice Set the target actor explicitly
    function _setTargetActor(address _user) internal {
        targetActor = _user;
        actor = Actor(payable(_user));
    }

    /// @notice Get a random address
    function _makeAddr(string memory _name) internal pure returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(_name)));
        addr = vm.addr(privateKey);
    }

    /// @notice Get a random actor proxy address
    function _getRandomActor(uint256 _i) internal view returns (address) {
        uint256 actorIndex = _i % actorAddresses.length;
        return actorAddresses[actorIndex];
    }

    /// @notice Advance block number for testing vesting/rewards
    function _advanceBlocks(uint256 _blocks) internal {
        vm.roll(block.number + _blocks);
    }
}