// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice StakeBakePropertiesAsserts is a library that provides assertions for properties of StakeBake contracts.
/// @dev Adapted from PropertiesAsserts with StakeBake-specific enhancements
abstract contract StakeBakePropertiesAsserts {
    event LogUint256(string, uint256);
    event LogAddress(string, address);
    event LogString(string);

    event AssertFail(string);
    event AssertEqFail(string);
    event AssertNeqFail(string);
    event AssertGeFail(string);
    event AssertGtFail(string);
    event AssertLeFail(string);
    event AssertLtFail(string);

    function assertWithMsg(bool b, string memory reason) internal {
        if (!b) {
            emit AssertFail(reason);
            assert(false);
        }
    }

    /// @notice asserts that a is equal to b
    function assertEq(uint256 a, uint256 b) internal pure {
        if (a != b) {
            assert(false);
        }
    }

    function assertEq(int256 a, int256 b) internal pure {
        if (a != b) {
            assert(false);
        }
    }

    function assertEq(address a, address b) internal pure {
        if (a != b) {
            assert(false);
        }
    }

    function assertEq(address a, address b, string memory reason) internal {
        if (a != b) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "!=", bStr, ", reason: ", reason);
            emit AssertEqFail(string(assertMsg));
            assert(false);
        }
    }

    function assertEq(uint256 a, uint256 b, string memory reason) internal {
        if (a != b) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "!=", bStr, ", reason: ", reason);
            emit AssertEqFail(string(assertMsg));
            assert(false);
        }
    }

    function assertEq(int256 a, int256 b, string memory reason) internal {
        if (a != b) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "!=", bStr, ", reason: ", reason);
            emit AssertEqFail(string(assertMsg));
            assert(false);
        }
    }

    function assertNeq(uint256 a, uint256 b, string memory reason) internal {
        if (a == b) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "==", bStr, ", reason: ", reason);
            emit AssertNeqFail(string(assertMsg));
            assert(false);
        }
    }

    function assertNeq(int256 a, int256 b, string memory reason) internal {
        if (a == b) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "==", bStr, ", reason: ", reason);
            emit AssertNeqFail(string(assertMsg));
            assert(false);
        }
    }

    function assertGe(uint256 a, uint256 b, string memory reason) internal {
        if (!(a >= b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "<", bStr, " failed, reason: ", reason);
            emit AssertGeFail(string(assertMsg));
            assert(false);
        }
    }

    function assertGe(int256 a, int256 b, string memory reason) internal {
        if (!(a >= b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "<", bStr, " failed, reason: ", reason);
            emit AssertGeFail(string(assertMsg));
            assert(false);
        }
    }

    function assertGt(uint256 a, uint256 b, string memory reason) internal {
        if (!(a > b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "<=", bStr, " failed, reason: ", reason);
            emit AssertGtFail(string(assertMsg));
            assert(false);
        }
    }

    function assertGt(int256 a, int256 b, string memory reason) internal {
        if (!(a > b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, "<=", bStr, " failed, reason: ", reason);
            emit AssertGtFail(string(assertMsg));
            assert(false);
        }
    }

    function assertLe(uint256 a, uint256 b, string memory reason) internal {
        if (!(a <= b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, ">", bStr, " failed, reason: ", reason);
            emit AssertLeFail(string(assertMsg));
            assert(false);
        }
    }

    function assertLe(int256 a, int256 b, string memory reason) internal {
        if (!(a <= b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, ">", bStr, " failed, reason: ", reason);
            emit AssertLeFail(string(assertMsg));
            assert(false);
        }
    }

    function assertLt(uint256 a, uint256 b, string memory reason) internal {
        if (!(a < b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, ">=", bStr, " failed, reason: ", reason);
            emit AssertLtFail(string(assertMsg));
            assert(false);
        }
    }

    function assertLt(int256 a, int256 b, string memory reason) internal {
        if (!(a < b)) {
            string memory aStr = PropertiesLibString.toString(a);
            string memory bStr = PropertiesLibString.toString(b);
            bytes memory assertMsg = abi.encodePacked("Invalid: ", aStr, ">=", bStr, " failed, reason: ", reason);
            emit AssertLtFail(string(assertMsg));
            assert(false);
        }
    }

    // StakeBake-specific clamping functions

    /// @notice Clamps locking period to be within staking program bounds
    function clampWithinStakingPeriod(uint256 lockingPeriod, uint256 stakingDurationInBlocks) internal returns (uint256) {
        if (lockingPeriod > stakingDurationInBlocks) {
            uint256 clamped = lockingPeriod % (stakingDurationInBlocks + 1);
            string memory periodStr = PropertiesLibString.toString(lockingPeriod);
            string memory clampedStr = PropertiesLibString.toString(clamped);
            emit LogString(string(abi.encodePacked("Clamping locking period ", periodStr, " to ", clampedStr)));
            return clamped;
        }
        return lockingPeriod;
    }

    // Keep existing clamp functions with minor StakeBake-specific tweaks if needed
    function clampBetween(uint256 value, uint256 low, uint256 high) internal returns (uint256) {
        if (value < low || value > high) {
            uint256 ans = low + (value % (high - low + 1));
            string memory valueStr = PropertiesLibString.toString(value);
            string memory ansStr = PropertiesLibString.toString(ans);
            emit LogString(string(abi.encodePacked("Clamping value ", valueStr, " to ", ansStr)));
            return ans;
        }
        return value;
    }

    function clampBetween(int256 value, int256 low, int256 high) internal returns (int256) {
        if (value < low || value > high) {
            int256 range = high - low + 1;
            int256 clamped = (value - low) % (range);
            if (clamped < 0) clamped += range;
            int256 ans = low + clamped;
            string memory valueStr = PropertiesLibString.toString(value);
            string memory ansStr = PropertiesLibString.toString(ans);
            emit LogString(string(abi.encodePacked("Clamping value ", valueStr, " to ", ansStr)));
            return ans;
        }
        return value;
    }

    function clampLt(uint256 a, uint256 b) internal returns (uint256) {
        if (!(a < b)) {
            assertNeq(b, 0, "clampLt cannot clamp value a to be less than zero. Check your inputs/assumptions.");
            uint256 value = a % b;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampLt(int256 a, int256 b) internal returns (int256) {
        if (!(a < b)) {
            int256 value = b - 1;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampLe(uint256 a, uint256 b) internal returns (uint256) {
        if (!(a <= b)) {
            uint256 value = a % (b + 1);
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampLe(int256 a, int256 b) internal returns (int256) {
        if (!(a <= b)) {
            int256 value = b;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampGt(uint256 a, uint256 b) internal returns (uint256) {
        if (!(a > b)) {
            assertNeq(
                b,
                type(uint256).max,
                "clampGt cannot clamp value a to be larger than uint256.max. Check your inputs/assumptions."
            );
            uint256 value = b + 1;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampGt(int256 a, int256 b) internal returns (int256) {
        if (!(a > b)) {
            int256 value = b + 1;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampGe(uint256 a, uint256 b) internal returns (uint256) {
        if (!(a >= b)) {
            uint256 value = b;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }

    function clampGe(int256 a, int256 b) internal returns (int256) {
        if (!(a >= b)) {
            int256 value = b;
            string memory aStr = PropertiesLibString.toString(a);
            string memory valueStr = PropertiesLibString.toString(value);
            emit LogString(string(abi.encodePacked("Clamping value ", aStr, " to ", valueStr)));
            return value;
        }
        return a;
    }
}

/// @notice Efficient library for creating string representations of integers and addresses
/// @dev Adapted from Solmate and Solady, renamed to avoid naming conflicts
library PropertiesLibString {
    function toString(int256 value) internal pure returns (string memory str) {
        uint256 absValue = value >= 0 ? uint256(value) : uint256(-value);
        str = toString(absValue);

        if (value < 0) {
            str = string(abi.encodePacked("-", str));
        }
    }

    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            let newFreeMemoryPointer := add(mload(0x40), 160)
            mstore(0x40, newFreeMemoryPointer)
            str := sub(newFreeMemoryPointer, 32)
            mstore(str, 0)
            let end := str
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let length := sub(end, str)
            str := sub(str, 32)
            mstore(str, length)
        }
    }

    function toString(address value) internal pure returns (string memory str) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(value)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}