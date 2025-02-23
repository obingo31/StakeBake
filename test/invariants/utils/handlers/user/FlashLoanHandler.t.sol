// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC3156FlashLender} from "../../src/interfaces/IERC3156FlashLender.sol";
import {StakeBake} from "src/StakeBake.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "./invariants/base/BaseHandler.t.sol";

/// @title FlashLoanHandler
/// @notice Handler test contract for flash loan actions
contract FlashLoanHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Address of the flash loan receiver contract
    address public flashLoanReceiver;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Simulate a flash loan
    /// @param _amount The amount of tokens to borrow
    /// @param _amountToRepay The amount of tokens to repay (including fees)
    /// @param i Index for selecting a random pool
    /// @param j Index for selecting a random staking token
    function flashLoan(uint256 _amount, uint256 _amountToRepay, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Select a random pool and staking token
        address target = address(stakeBake);
        address token = _getRandomStakingToken(j);

        // Get the maximum flash loan amount for the token
        uint256 maxFlashLoanAmount = IERC3156FlashLender(target).maxFlashLoan(token);

        // Clamp the repayment amount to avoid overflow
        _amountToRepay = clampBetween(_amountToRepay, 0, type(uint256).max - IERC20(token).totalSupply());

        _before();

        // Execute the flash loan
        (success, returnData) = actor.proxy(
            target,
            abi.encodeWithSelector(
                IERC3156FlashLender.flashLoan.selector,
                flashLoanReceiver,
                token,
                _amount,
                abi.encode(_amountToRepay, address(actor))
            )
        );

        // Calculate the flash fee
        uint256 flashFee = IERC3156FlashLender(target).flashFee(token, _amount);

        // POST-CONDITIONS

        // Validate success/failure based on repayment amount and max loan amount
        if (_amountToRepay > _amount + flashFee && maxFlashLoanAmount >= _amount) {
            assertTrue(success, "FLASHLOAN_HSPOST_U1: Flash loan should succeed");
        } else {
            assertFalse(success, "FLASHLOAN_HSPOST_U2: Flash loan should fail");
        }

        // Validate state after a successful flash loan
        if (success) {
            _after();

            assertEq(
                IERC20(token).balanceOf(target),
                IERC20(token).balanceOf(target) + flashFee,
                "FLASHLOAN_HSPOST_T: Flash fee should be added to the pool"
            );
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to clamp a value between a minimum and maximum
    function clampBetween(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        return value < min ? min : (value > max ? max : value);
    }
}