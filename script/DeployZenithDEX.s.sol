// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/ZenithDEXFactory.sol";
import "../src/periphery/ZenithDEXRouter.sol";

contract DeployZenithDEX is Script {
    function run() external {
        // 1. Read the private key from the environment variable (simulate real deployment)
        // Default use of the testing account provided by Foundry on the local test network, no configuration required
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);

        // 2. Deploy Factory
        ZenithDEXFactory factory = new ZenithDEXFactory();
        console.log("Factory deployed at:", address(factory));

        // 3. Deploy WETH (for testing purposes, we will first deploy a fake WETH and use the real one for the actual main network)
        address wethAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); 
        console.log("Pair deployed at:", wethAddress);

        // 4. Deploy Router
        ZenithDEXRouter router = new ZenithDEXRouter(address(factory), wethAddress);
        console.log("Router deployed at:", address(router));

        vm.stopBroadcast();
    }
}