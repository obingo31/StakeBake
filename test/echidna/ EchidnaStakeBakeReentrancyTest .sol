// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StakeBakeInternal} from "./StakeBakeInternal.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {StakeBakePropertiesAsserts} from "../StakeBakePropertiesAsserts.sol";

/// @title EchidnaStakeBakeReentrancyTest
/// @notice Tests StakeBake for reentrancy vulnerabilities inspired by the 
// Curve Hack @=> github.com/rappie/echidna-curve-reentrancy-hack
/// @dev Fuzzes lockTokens, unlockTokens, and claimRewards to detect profit via reentrancy
contract EchidnaStakeBakeReentrancyTest is StakeBakePropertiesAsserts {
    StakeBakeInternal public stakeBake;
    TestERC20 public rewardToken;
    TestERC721 public recipeNFT;

    uint256 public initialBalance;
    bool public reentrancyEnabled;
    uint8 public reentrancyFunction; // 0: lockTokens, 1: unlockTokens, 2: claimRewards
    uint128 public reentrancyAmount;

    uint256 constant INITIAL_POOL_ID = 0;

    event ProfitDetected(uint256 profit, string sourceFunction);
    event ReentrancyTriggered(uint8 functionId, uint128 amount);

    constructor() {
        rewardToken = new TestERC20("Reward", "RWD", 1_000_000e18);
        recipeNFT = new TestERC721("Recipe", "RNFT");
        address[] memory multiSigSigners = new address[](2);
        multiSigSigners[0] = address(0x1);
        multiSigSigners[1] = address(0x2);

        stakeBake = new StakeBakeInternal(
            address(rewardToken),
            1000,
            500,
            multiSigSigners,
            2
        );

        rewardToken.mint(address(this), 500_000e18);
        rewardToken.approve(address(stakeBake), 500_000e18);
        stakeBake.addRewardFund(500_000e18);

        stakeBake.createPool(address(recipeNFT), 1e18, 1e15, 50);

        initialBalance = rewardToken.balanceOf(address(this));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            ECHIDNA INVARIANTS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Ensures no profit is gained via reentrancy
    function echidna_no_profit() public returns (bool) {
        uint256 balance = rewardToken.balanceOf(address(this));
        if (balance > initialBalance) {
            emit ProfitDetected(balance - initialBalance, "echidna_no_profit");
        }
        return balance <= initialBalance; // Echidna fails if false
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            HANDLERS                                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stakes an NFT into the pool
    function lockTokens(uint128 tokenId, uint128 lockingPeriod) public {
        lockingPeriod = uint128(clampBetween(lockingPeriod, 1, stakeBake.stakingProgramEndsBlock() - block.number));
        recipeNFT.mint(address(this), tokenId);
        recipeNFT.approve(address(stakeBake), tokenId);
        stakeBake.lockTokens(INITIAL_POOL_ID, tokenId, lockingPeriod);
    }

    /// @notice Unstakes an NFT from the pool
    function unlockTokens(uint128 tokenId) public {
        stakeBake.unlockTokens(INITIAL_POOL_ID, tokenId);
    }

    /// @notice Claims rewards from the pool
    function claimRewards() public {
        stakeBake.claimRewards(INITIAL_POOL_ID);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            REENTRANCY CONTROL                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Triggers reentrancy to test vulnerability
    function triggerReentrancy(uint128 tokenId) public {
        if (reentrancyEnabled) {
            uint8 functionId = reentrancyFunction % 3;
            uint256 balanceBefore = rewardToken.balanceOf(address(this));
            emit ReentrancyTriggered(functionId, reentrancyAmount);

            // Simulate reentrant calls (up to 3 chained attempts)
            for (uint256 i = 0; i < 3; i++) {
                if (functionId == 0) {
                    lockTokens(tokenId, reentrancyAmount); // tokenId from input, period from reentrancyAmount
                } else if (functionId == 1) {
                    unlockTokens(tokenId);
                } else if (functionId == 2) {
                    claimRewards();
                }
                functionId = (functionId + 1) % 3; // Rotate to next function
            }

            uint256 balanceAfter = rewardToken.balanceOf(address(this));
            if (balanceAfter > balanceBefore) {
                emit ProfitDetected(balanceAfter - balanceBefore, "triggerReentrancy");
            }
        }
    }

    /// @notice Sets whether reentrancy is enabled
    function setReentrancyEnabled(bool _reentrancyEnabled) public {
        reentrancyEnabled = _reentrancyEnabled;
    }

    /// @notice Sets the reentrant function to call (0-2)
    function setReentrancyFunction(uint8 _reentrancyFunction) public {
        reentrancyFunction = _reentrancyFunction;
    }

    /// @notice Sets the amount used in reentrant calls
    function setReentrancyAmount(uint128 _reentrancyAmount) public {
        reentrancyAmount = _reentrancyAmount;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            UTILITY FUNCTIONS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns current profit, if any
    function getProfit() public view returns (uint256) {
        uint256 currentBalance = rewardToken.balanceOf(address(this));
        return currentBalance > initialBalance ? currentBalance - initialBalance : 0;
    }
}
