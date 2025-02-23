// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "./BaseStorage.t.sol";
import {StakeBake, IRecipeNFT} from "./StakeBake.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";

contract BaseHooks is Test, BaseStorage {

    StakeBake public stakeBake;
    TestERC20 public rewardToken;
    uint256 public stakingDurationInBlocks;
    uint256 public vestingDuration;

    struct MultiSig {
        address[] signers;
        uint256 requiredSignatures;
        mapping(address => bool) isSigner;
    }

    MultiSig public multiSig;

    constructor(
        address stakeBakeAddress,
        address rewardTokenAddress,
        address owner,
        address[] memory multiSigSigners,
        uint256 multiSigRequiredSignatures,
        uint256 stakingDurationInBlocks_,
        uint256 vestingDuration_
    ) {
        _stakeBake = stakeBakeAddress;
        _rewardToken = rewardTokenAddress;

        stakingDurationInBlocks = stakingDurationInBlocks_;
        vestingDuration = vestingDuration_;

        stakeBake = StakeBake(rewardTokenAddress, stakingDurationInBlocks, vestingDuration, multiSigSigners, multiSigRequiredSignatures); // Using deployed contract
        rewardToken = TestERC20(rewardTokenAddress); 

        // Initialize multisig signers
        multiSig.signers = multiSigSigners;
        multiSig.requiredSignatures = multiSigRequiredSignatures;

        // Set the signers to the StakeBake contract's multisig
        for (uint256 i = 0; i < multiSigSigners.length; i++) {
            stakeBake.multiSig().isSigner[multiSigSigners[i]] = true;
        }

        // Transfer ownership to the specified owner
        stakeBake.transferOwnership(owner);
    }

    function cacheBefore() internal virtual {}
    function cacheAfter() internal virtual {}
    function checkPostConditions() internal virtual {}
}
