// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/core/interfaces/ISimpleSwapPair.sol";

contract ActionSwap is Script {
    function run() external {
        //trigger event
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(deployerPrivateKey);

        address pairAddress = C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; 

    }
}