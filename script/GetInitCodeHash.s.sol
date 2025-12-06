// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/ZenithDEXPair.sol";

contract GetInitCodeHash is Script {
    function run() public pure {
        // Obtain the bytecode for creating ZenithDEXPair
        bytes memory bytecode = type(ZenithDEXPair).creationCode;
        // Calculate hash
        bytes32 hash = keccak256(bytecode);
        // print
        console.log("INIT_CODE_HASH:");
        console.logBytes32(hash);
    }
}