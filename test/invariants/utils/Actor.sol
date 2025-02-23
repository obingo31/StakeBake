// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/// @notice Proxy contract for StakeBake invariant suite actors to avoid Tester calling contracts directly
contract StakeBakeActor {
    /// @notice Last targeted contract
    address public lastTarget;
    /// @notice List of ERC20 tokens to approve (e.g., reward token)
    address[] internal erc20Tokens;
    /// @notice List of ERC721 tokens to approve (e.g., recipe NFTs)
    address[] internal erc721Tokens;
    /// @notice List of contracts to approve tokens to (e.g., StakeBake contract)
    address[] internal contracts;

    constructor(
        address[] memory _erc20Tokens,
        address[] memory _erc721Tokens,
        address[] memory _contracts
    ) payable {
        erc20Tokens = _erc20Tokens;
        erc721Tokens = _erc721Tokens;
        contracts = _contracts;

        // Approve ERC20 tokens to contracts
        for (uint256 i = 0; i < erc20Tokens.length; i++) {
            for (uint256 j = 0; j < contracts.length; j++) {
                IERC20(erc20Tokens[i]).approve(contracts[j], type(uint256).max);
            }
        }

        // Approve ERC721 tokens to contracts
        for (uint256 i = 0; i < erc721Tokens.length; i++) {
            for (uint256 j = 0; j < contracts.length; j++) {
                IERC721(erc721Tokens[i]).setApprovalForAll(contracts[j], true);
            }
        }
    }

    /// @notice Helper function to proxy a call to a target contract
    /// @dev Used to avoid Tester calling contracts directly
    function proxy(address _target, bytes memory _calldata) 
        public 
        returns (bool success, bytes memory returnData) 
    {
        (success, returnData) = address(_target).call(_calldata);
        lastTarget = _target;
        handleAssertionError(success, returnData);
    }

    /// @notice Helper function to proxy a call with value to a target contract
    /// @dev Used for operations that might require ETH (though unlikely in StakeBake)
    function proxy(address _target, bytes memory _calldata, uint256 value)
        public
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = address(_target).call{value: value}(_calldata);
        lastTarget = _target;
        handleAssertionError(success, returnData);
    }

    /// @notice Checks if a call failed due to an assertion error and propagates it
    /// @param success Indicates whether the call was successful
    /// @param returnData The data returned from the call
    function handleAssertionError(bool success, bytes memory returnData) internal pure {
        if (!success && returnData.length == 36) {
            bytes4 selector;
            uint256 code;
            assembly {
                selector := mload(add(returnData, 0x20))
                code := mload(add(returnData, 0x24))
            }

            if (selector == bytes4(0x4e487b71) && code == 1) { // Panic code for assertion failure
                assert(false);
            }
        }
    }

    /// @notice Helper to update ERC721 approvals if needed
    function updateERC721Approval(address erc721Token, address contractAddr, bool approved) external {
        IERC721(erc721Token).setApprovalForAll(contractAddr, approved);
    }

    /// @notice Helper to update ERC20 approvals if needed
    function updateERC20Approval(address erc20Token, address contractAddr, uint256 amount) external {
        IERC20(erc20Token).approve(contractAddr, amount);
    }

    receive() external payable {}
}