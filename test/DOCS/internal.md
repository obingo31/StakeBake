1. Echidna Configuration (echidna_config.yaml)
The configuration file defines how Echidna will run the tests.

2. Property Formats
Echidna supports two types of properties:

Invariants: Properties that must hold true across all states of the system.

Postconditions: Properties that must hold true after specific function calls.

3. Writing Invariants
Invariants are implemented as public functions prefixed with echidna_. These functions should contain assertions that check the invariants.

Example Invariants for StakeBake
```bash
Total Staked Tokens Should Not Exceed Contract Balance:
```

```js
function echidna_total_staked_leq_balance() public view returns (bool) {
    uint256 totalStaked = 0;
    for (uint256 i = 0; i < poolCount; i++) {
        totalStaked += pools[i].totalStaked;
    }
    return totalStaked <= rewardToken.balanceOf(address(this));
}
```
No Negative Rewards:

```js
function echidna_no_negative_rewards() public view returns (bool) {
    for (uint256 i = 0; i < poolCount; i++) {
        if (pools[i].rewardPerTokenStored < 0 || poolTotalRewardPoints[i] < 0) {
            return false;
        }
    }
    return true;
}
```