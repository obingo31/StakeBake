// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// Libraries
import {Vm} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "forge-std/console.sol";

// Utils
import {StakeBakeActor} from "../utils/StakeBakeActor.sol";
import {PropertiesConstants} from "../utils/PropertiesConstants.sol";
import {StdAsserts} from "../utils/StdAsserts.sol";

// Base
import {BaseStorage} from "./BaseStorage.t.sol";

/// @notice Base contract for all StakeBake test contracts extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev Inherits Storage, Testing constants, assertions, and utils needed for testing
abstract contract StakeBakeBaseTest is BaseStorage, PropertiesConstants, StdAsserts, StdUtils {
    bool internal IS_TEST = true;

    // StakeBake-specific state
    address public stakeBakeAddress;
    IERC20 public rewardToken;
    IERC721 public recipeNFT;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   ACTOR PROXY MECHANISM                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Actor proxy mechanism
    modifier setup() virtual {
        actor = actors[msg.sender];
        targetActor = address(actor);
        _;
        actor = StakeBakeActor(payable(address(0)));
        targetActor = address(0);
    }

    /// @dev Solves medusa backward time warp issue (if needed)
    modifier monotonicTimestamp() virtual {
        // Implement monotonic timestamp if needed
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     CHEAT CODE SETUP                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    /// @dev Virtual machine instance
    Vm internal constant vm = Vm(VM_ADDRESS);

    constructor(
        address _stakeBakeAddress,
        address _rewardTokenAddress,
        address _recipeNFTAddress,
        address _owner,
        address[] memory _multiSigSigners,
        uint256 _multiSigRequiredSignatures,
        uint256 _stakingDurationInBlocks,
        uint256 _vestingDuration
    ) BaseStorage(
        _stakeBakeAddress,
        _rewardTokenAddress,
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
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to get max staked tokens for a user in a pool
    function _maxStakedTokens(uint256 poolId, address user) internal view returns (uint256) {
        (bool success, bytes memory data) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("userStakedTokenIds(address,uint256)")), user, poolId)
        );
        if (!success) return 0;
        uint256[] memory tokenIds = abi.decode(data, (uint256[]));
        return tokenIds.length;
    }

    /// @notice Helper function to get total staked weight in a pool
    function _totalStakedWeight(uint256 poolId) internal view returns (uint256) {
        (bool success, bytes memory data) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("pools(uint256)")), poolId)
        );
        if (!success) return 0;
        (, uint256 totalStaked, , , , , , , ) = abi.decode(
            data,
            (address, uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256)
        );
        return totalStaked;
    }

    /// @notice Helper function to check if a user has staked tokens
    function _hasStaked(address user, uint256 poolId) internal returns (bool) {
        (bool success, bytes memory data) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("userStakedTokenIds(address,uint256)")), user, poolId)
        );
        if (!success) return false;
        uint256[] memory tokenIds = abi.decode(data, (uint256[]));
        return tokenIds.length > 0;
    }

    /// @notice Helper function to get a user’s reward points in a pool
    function _getUserRewardPoints(uint256 poolId, address user) internal view returns (uint256) {
        (bool success, bytes memory data) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("userRewardPoints(address,uint256)")), user, poolId)
        );
        if (!success) return 0;
        return abi.decode(data, (uint256));
    }

    /// @notice Set the target actor for testing
    function _setTargetActor(address user) internal {
        targetActor = user;
    }

    /// @notice Get total reward fund
    function _getTotalRewardFund() internal view returns (uint256) {
        (bool success, bytes memory data) = stakeBakeAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("totalRewardFund()")))
        );
        if (!success) return 0;
        return abi.decode(data, (uint256));
    }

    /// @notice Get a random address
    function _makeAddr(string memory name) internal pure returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
    }

    /// @notice Get a random actor proxy address
    function _getRandomActor(uint256 _i) internal view returns (address) {
        uint256 _actorIndex = _i % NUMBER_OF_ACTORS;
        return actorAddresses[_actorIndex];
    }
}