// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import {TestERC20} from "../utils/mocks/TestERC20.sol"; // Adjust the path as necessary
import {StakeBake} from "../../src/StakeBake.sol"; // Adjust the path as necessary
import {IRecipeNFT} from "../../src/StakeBake.sol";

import "forge-std/console.sol";
// import {VmSafe} from "forge-std/src/VmSafe.sol";

/// @title BaseHandler
/// @notice Contains common logic for all StakeBake handlers
/// @dev Inherits HookAggregator and provides helper functions for StakeBake interaction
contract BaseHandler {
    using VmSafe for vm;

    StakeBake public stakeBake;
    IRecipeNFT public recipeNFT;
    IERC20 public rewardToken;

    address[] public actorAddresses; // List of actor addresses for invariants

    constructor(address _stakeBake, address _recipeNFT, address _rewardToken) {
        stakeBake = StakeBake(_stakeBake);
        recipeNFT = IRecipeNFT(_recipeNFT);
        rewardToken = IERC20(_rewardToken);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HELPERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to get a random value
    function _getRandomValue(uint256 modulus) internal view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encode(block.timestamp, block.prevrandao, msg.sender))
        );
        return randomNumber % modulus; // Adjust the modulus to the desired range
    }

    /// @notice Helper function to create a pool
    function _createPool(
        address recipeNFTAddress,
        uint256 rewardRatePoints,
        uint256 rewardRatePerSecond,
        uint256 earlyWithdrawalPenalty
    ) internal {
        stakeBake.createPool(
            recipeNFTAddress,
            rewardRatePoints,
            rewardRatePerSecond,
            earlyWithdrawalPenalty
        );
    }

    /// @notice Helper function to lock tokens
    function _lockTokens(
        uint256 poolId,
        uint256 tokenId,
        uint24 lockingPeriodInBlocks
    ) internal {
        stakeBake.lockTokens(poolId, tokenId, lockingPeriodInBlocks);
    }

    /// @notice Helper function to adjust the locking period
    function _adjustLockingPeriod(
        uint256 poolId,
        uint256 tokenId,
        uint24 newLockingPeriod
    ) internal {
        stakeBake.adjustLockingPeriod(poolId, tokenId, newLockingPeriod);
    }

    /// @notice Helper function to unlock tokens
    function _unlockTokens(uint256 poolId, uint256 tokenId) internal {
        stakeBake.unlockTokens(poolId, tokenId);
    }

    /// @notice Helper function to claim rewards
    function _claimRewards(uint256[] memory poolIds) internal {
        stakeBake.claimRewards(poolIds);
    }

    /// @notice Helper function to release tokens
    function _release() internal {
        stakeBake.release();
    }

    /// @notice Helper function to add a multi-sig signature
    function _addMultiSigSignature(bytes32 txHash) internal {
        stakeBake.addMultiSigSignature(txHash);
    }

    /// @notice Helper function to execute a multi-sig transaction
    function _executeMultiSigTransaction(
        bytes32 txHash,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        stakeBake.executeMultiSigTransaction(txHash, to, value, data);
    }

    /// @notice Helper function to approve an amount of tokens to a spender
    function _approve(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        vm.prank(owner);
        _safeApprove(token, spender, 0);
        vm.prank(owner);
        _safeApprove(token, spender, amount);
    }

    /// @notice Helper function to safely approve an amount of tokens to a spender
    /// @dev This function is used to revert on failed approvals
    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        vm.startPrank(msg.sender);
        (bool success, bytes memory retdata) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        vm.stopPrank();

        assert(success);
        if (retdata.length > 0) assert(abi.decode(retdata, (bool)));
    }

    /// @notice Helper function to mint an amount of tokens to an address
    function _mint(address token, address receiver, uint256 amount) internal {
        TestERC20(token).mint(receiver, amount);
    }

    /// @notice Helper function to mint an amount of tokens to an address and approve them to a spender
    /// @param token Address of the token to mint
    /// @param owner Address of the new owner of the tokens
    /// @param spender Address of the spender to approve the tokens to
    /// @param amount Amount of tokens to mint and approve
    function _mintAndApprove(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _mint(token, owner, amount);
        _approve(token, owner, spender, amount);
    }

    // Helper functions for setting state (testing purposes)
    function _setTotalRewardFund(uint256 amount) internal {
        stakeBake._setTotalRewardFund(amount);
    }

    function _setGrantedTokens(address account, uint256 amount) internal {
        stakeBake._setGrantedTokens(account, amount);
    }

    function _setReleasedTokens(address account, uint256 amount) internal {
        stakeBake._setReleasedTokens(account, amount);
    }
}
