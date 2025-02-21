// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "./BaseTest.sol";

// contract Setup is BaseTest {
//     function _setUp() internal {
//         // Deploy StakeBakePlusEnhanced contract
//         rewardToken = new MockERC20("Reward Token", "RWT");
//         staking = new StakeBakePlusEnhanced(
//             address(rewardToken),
//             10000, // stakingDurationInBlocks
//             1000,  // vestingDuration
//             address(this), // owner
//             new address[](0), // multiSigSigners
//             0 // multiSigRequiredSignatures
//         );

//         // Initialize pools
//         staking.createPool(address(rewardToken), 1000, 1e18, 10); // Pool 0
//         staking.createPool(address(rewardToken), 2000, 2e18, 20); // Pool 1
//     }

//     function _setUpActors() internal {
//         actors[USER1] = new Actor();
//         actors[USER2] = new Actor();
//         actors[USER3] = new Actor();
//     }

//     function _setUpHandlers() internal {
//         // Initialize handlers
//     }
// }