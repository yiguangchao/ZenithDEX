// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/ZenithDEXPair.sol";

contract GetInitCodeHash is Script {
    function run() public pure {
        // 获取 ZenithDEXPair 的创建字节码
        bytes memory bytecode = type(ZenithDEXPair).creationCode;
        // 计算哈希
        bytes32 hash = keccak256(bytecode);
        // 打印出来
        console.log("INIT_CODE_HASH:");
        console.logBytes32(hash);
    }
}