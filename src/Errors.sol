// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Errors {
    error UnauthorizedAccess();
    error InvalidNFTAddress();
    error EarlyWithdrawalPenaltyTooHigh();
    error InvalidPoolId();
    error PoolNotActive();
    error ExcessiveLockingPeriod();
    error EmergencyStopActive();
    error NoActiveStake();
    error StakeAlreadyClaimed();
    error TokenTransferFailed();
    error NoTokensToRelease();
    error InvalidMultiSignatureConfiguration();
    error NotMultiSignatureSigner();
    error InsufficientSignatures();
    error AlreadyVoted();
    error CannotVoteForOwnRecipe();
    error MultiSignatureTransactionFailed();
}
