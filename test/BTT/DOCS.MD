# This spec uses conditions (when/given) and actions (it) to describe expected behaviors.

*Root*: StakeBakeTest becomes the contract name in the Solidity file.
*Conditions*: Phrases like "When the user has staked an NFT" define preconditions.
*Actions*: Phrases like "It should allow staking an NFT" define test assertions.


```js
StakeBakeTest
├── It should allow staking an NFT.
├── It should allow unstaking an NFT after the lock period.
├── It should allow claiming rewards.
├── When the user has staked an NFT
│   └── It should increase the user's staked balance.
├── When the user unstakes an NFT
│   └── It should decrease the user's staked balance.
├── When the user claims rewards
│   └── It should transfer rewards to the user.
└── When the emergency stop is active
    └── It should prevent staking and unstaking.
```

BTT/StakeBakeRewards.tree
```js
StakeBakeTest::claimRewards
├── It should allow claiming rewards.
├── When the user has no staked NFTs
│   └── It should revert with "No rewards to claim".
└── When the rewards are already claimed
    └── It should revert with "No rewards to claim".
```    
This scenario verifies that users can claim rewards only when they have staked NFTs and haven’t already claimed them.


BTT/StakeBakeEmergencyStop.tree

```js
StakeBakeTest::emergencyStop
├── It should allow the owner to trigger emergency stop.
├── When emergency stop is active
│   ├── It should prevent staking.
│   └── It should prevent unstaking.
└── When emergency stop is not active
    ├── It should allow staking.
    └── It should allow unstaking.
```    
This tests the protocol’s emergency stop mechanism, ensuring it restricts operations when activated and allows them when inactive.

Scenario 4: Reentrancy Protection
File: BTT/StakeBakeReentrancy.tree

```js
Copy
StakeBakeTest::unlockTokens
├── It should prevent reentrancy during unstaking.
└── It should prevent reentrancy during reward claiming.
This scenario ensures the contract is secure against reentrancy attacks during critical operations like unstaking and reward claiming.
```

BTT/StakeBakeEdgeCases.tree

```js
StakeBakeTest::lockTokens
├── When the NFT ID is invalid
│   └── It should revert with "Invalid NFT ID".
└── When the lock period is zero
    └── It should revert with "Invalid locking period".

StakeBakeTest::unlockTokens
├── When trying to unstake before lock period ends
│   └── It should revert with "Lock period not ended".
└── When trying to unstake an unstaked NFT
    └── It should revert with "Token not staked".

StakeBakeTest::claimRewards
├── When claiming with no staked NFTs
│   └── It should revert with "No rewards to claim".
└── When claiming after unstaking
    └── It should revert with "No rewards to claim".
```    

This scenario tests edge cases and invalid inputs to ensure the contract handles unexpected conditions gracefully.


After creating the .tree files, use Bulloak to scaffold Solidity test files from them. Run the following commands in your terminal:

```bash
bulloak scaffold BTT/StakeBakeBasic.tree
bulloak scaffold BTT/StakeBakeRewards.tree
bulloak scaffold BTT/StakeBakeEmergencyStop.tree
bulloak scaffold BTT/StakeBakeReentrancy.tree
bulloak scaffold BTT/StakeBakeEdgeCases.tree
```
This will generate files like StakeBakeBasic.t.sol, StakeBakeRewards.t.sol, and so on, each containing test functions corresponding to the scenarios defined in the .tree files.

Step 4: Next Steps
To complete the process:

Implement the Tests: Open the generated .t.sol files and add the necessary Solidity code to test StakeBake’s behavior. For example:
In StakeBakeBasic.t.sol, implement test_ItShouldAllowStakingAnNFT by minting an NFT, approving it, and calling lockTokens.
In StakeBakeRewards.t.sol, implement test_ItShouldAllowClaimingRewards by staking an NFT, advancing the block number, and calling claimRewards.
Verify Consistency: After implementation, run Bulloak’s check command to ensure the tests match the .tree specifications:
```bash
bulloak check BTT/StakeBakeBasic.tree
bulloak check BTT/StakeBakeRewards.tree
bulloak check BTT/StakeBakeEmergencyStop.tree
bulloak check BTT/StakeBakeReentrancy.tree
bulloak check BTT/StakeBakeEdgeCases.tree
```




