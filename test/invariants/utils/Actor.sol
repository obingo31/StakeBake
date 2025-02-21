// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../src/StakeBake.sol";

/// @notice Base proxy contract for invariant suite actors to simulate user/admin interactions with StakeBake
contract Actor {
    /// @notice Last targeted contract address
    address public lastTarget;

    /// @notice StakeBake contract instance
    StakeBake public stakeBake;

    /// @notice List of tokens to approve (e.g., rewardToken and stakingTokens)
    address[] internal tokens;

    /// @notice List of contracts to approve tokens to (e.g., StakeBake)
    address[] internal contracts;

    /// @notice Constructor to initialize tokens and contracts, and set max approvals
    /// @param _stakeBake Address of the deployed StakeBake contract
    /// @param _tokens Array of token addresses (rewardToken and stakingTokens)
    /// @param _contracts Array of contracts to approve tokens to (typically just StakeBake)
    constructor(address _stakeBake, address[] memory _tokens, address[] memory _contracts) payable {
        stakeBake = StakeBake(_stakeBake);
        tokens = _tokens;
        contracts = _contracts;

        // Approve all tokens to all contracts with max allowance
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < contracts.length; j++) {
                IERC20(tokens[i]).approve(contracts[j], type(uint256).max);
            }
        }
    }

    /// @notice Proxy a call to a target contract
    /// @param _target Address of the contract to call (typically StakeBake)
    /// @param _calldata Encoded function call data
    /// @return success Whether the call succeeded
    /// @return returnData Data returned from the call
    function proxy(address _target, bytes memory _calldata)
        public
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = _target.call(_calldata);
        lastTarget = _target;
        handleAssertionError(success, returnData);
    }

    /// @notice Proxy a call with value to a target contract
    /// @param _target Address of the contract to call
    /// @param _calldata Encoded function call data
    /// @param _value Ether value to send with the call
    /// @return success Whether the call succeeded
    /// @return returnData Data returned from the call
    function proxy(address _target, bytes memory _calldata, uint256 _value)
        public
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = _target.call{value: _value}(_calldata);
        lastTarget = _target;
        handleAssertionError(success, returnData);
    }

    /// @notice Handle assertion errors from low-level calls
    /// @param _success Whether the call succeeded
    /// @param _returnData Returned data to check for assertion errors
    function handleAssertionError(bool _success, bytes memory _returnData) internal pure {
        if (!_success && _returnData.length == 36) {
            bytes4 selector;
            uint256 code;
            assembly {
                selector := mload(add(_returnData, 0x20))
                code := mload(add(_returnData, 0x24))
            }
            // Check for Solidity assertion error (Panic(0x01))
            if (selector == bytes4(0x4e487b71) && code == 1) {
                assert(false);
            }
        }
    }

    /// @notice Allow the contract to receive Ether
    receive() external payable {}
}