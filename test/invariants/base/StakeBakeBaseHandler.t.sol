// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// Libraries
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";

// Contracts
import {StakeBakeActor} from "../utils/StakeBakeActor.sol";
import {StakeBakeHookAggregator} from "../hooks/StakeBakeHookAggregator.t.sol";

/// @title StakeBakeBaseHandler
/// @notice Contains common logic for all StakeBake handlers
/// @dev Inherits StakeBakeHookAggregator to check actions in assertion testing mode
contract StakeBakeBaseHandler is StakeBakeHookAggregator {
    // StakeBake-specific state (no direct contract reference)
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
        uint256 vestingDuration
    ) StakeBakeHookAggregator(
        stakeBakeAddress,
        rewardTokenAddress,
        recipeNFTAddress,
        owner,
        multiSigSigners,
        multiSigRequiredSignatures,
        stakingDurationInBlocks,
        vestingDuration
    ) {
        rewardToken = IERC20(rewardTokenAddress);
        recipeNFT = IERC721(recipeNFTAddress);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HELPERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to get a random pool ID
    function _getRandomPool(uint256 i) internal view returns (uint256) {
        require(poolIds.length > 0, "No pools available");
        return poolIds[i % poolIds.length];
    }

    /// @notice Helper function to randomize a uint256 seed with a string salt
    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    /// @notice Helper function to get a random value within a modulus
    function _getRandomValue(uint256 modulus) internal view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encode(block.timestamp, block.prevrandao, msg.sender))
        );
        return randomNumber % modulus;
    }

    /// @notice Helper function to approve an ERC20 amount to a spender via Actor
    function _approveERC20(
        address token,
        StakeBakeActor actor_,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory returnData) = actor_.proxy(
            token,
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(success, string(returnData));
    }

    /// @notice Helper function to approve an ERC721 token to a spender via Actor
    function _approveERC721(
        address token,
        StakeBakeActor actor_,
        address spender,
        uint256 tokenId
    ) internal {
        (bool success, bytes memory returnData) = actor_.proxy(
            token,
            abi.encodeWithSelector(IERC721.approve.selector, spender, tokenId)
        );
        require(success, string(returnData));
    }

    /// @notice Helper function to safely approve an ERC20 amount to a spender
    function _approveERC20(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        vm.prank(owner);
        _safeApproveERC20(token, spender, 0);
        vm.prank(owner);
        _safeApproveERC20(token, spender, amount);
    }

    /// @notice Helper function to safely approve an ERC20 amount to a spender
    function _safeApproveERC20(
        address token,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory retdata) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        assert(success);
        if (retdata.length > 0) assert(abi.decode(retdata, (bool)));
    }

    /// @notice Helper function to approve all ERC721 tokens to a spender
    function _approveAllERC721(
        address token,
        address owner,
        address spender,
        bool approved
    ) internal {
        vm.prank(owner);
        (bool success, bytes memory retdata) = token.call(
            abi.encodeWithSelector(IERC721.setApprovalForAll.selector, spender, approved)
        );
        assert(success);
        if (retdata.length > 0) assert(abi.decode(retdata, (bool)));
    }

    /// @notice Helper function to mint an ERC20 amount to an address
    function _mintERC20(address token, address receiver, uint256 amount) internal {
        TestERC20(token).mint(receiver, amount);
    }

    /// @notice Helper function to mint an ERC721 token to an address
    function _mintERC721(address token, address receiver, uint256 tokenId) internal {
        TestERC721(token).mint(receiver, tokenId);
    }

    /// @notice Helper function to mint and approve ERC20 tokens
    function _mintAndApproveERC20(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _mintERC20(token, owner, amount);
        _approveERC20(token, owner, spender, amount);
    }

    /// @notice Helper function to mint and approve an ERC721 token
    function _mintAndApproveERC721(
        address token,
        address owner,
        address spender,
        uint256 tokenId
    ) internal {
        _mintERC721(token, owner, tokenId);
        vm.prank(owner);
        IERC721(token).approve(spender, tokenId);
    }
}