// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Import User Actions Handler contracts
// import {StakingHandler} from './handlers/user/StakingHandler.t.sol';
// import {RewardHandler} from './handlers/user/RewardHandler.t.sol';
// import {VestingHandler} from './handlers/user/VestingHandler.t.sol';
// import {EmergencyHandler} from './handlers/user/EmergencyHandler.t.sol';

// Import Permissioned Actions Handler contracts
// import {PoolHandler} from './handlers/permissioned/PoolHandler.t.sol';
// import {BoosterHandler} from './handlers/permissioned/BoosterHandler.t.sol';
// import {MultiSigHandler} from './handlers/permissioned/MultiSigHandler.t.sol';

// Import Simulator Handler contracts
// import {FlashLoanHandler} from './handlers/simulators/FlashLoanHandler.t.sol';
// import {MockRewardHandler} from './handlers/simulators/MockRewardHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    StakingHandler,       // User Actions
    RewardHandler,
    VestingHandler,
    EmergencyHandler,
    PoolHandler,          // Permissioned Actions
    BoosterHandler,
    MultiSigHandler,
    FlashLoanHandler,     // Simulators
    MockRewardHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal virtual override {
        // Initialize all handlers if needed
        StakingHandler._setUpHandlers();
        RewardHandler._setUpHandlers();
        VestingHandler._setUpHandlers();
        EmergencyHandler._setUpHandlers();
        PoolHandler._setUpHandlers();
        BoosterHandler._setUpHandlers();
        MultiSigHandler._setUpHandlers();
        FlashLoanHandler._setUpHandlers();
        MockRewardHandler._setUpHandlers();
    }
}