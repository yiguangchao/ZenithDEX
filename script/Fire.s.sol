// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/ZenithDEXFactory.sol";
import "../src/periphery/ZenithDEXRouter.sol";
import "@solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol, 18) {
        _mint(msg.sender, 1000000 ether);
    }
}

contract Fire is Script {
    function run() external {
        uint256 key = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(key);

        // 1. Retrieve existing Factory and Router addresses
        ZenithDEXFactory factory = new ZenithDEXFactory();
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        ZenithDEXRouter router = new ZenithDEXRouter(address(factory), weth);

        // 2. Issue two new coins (Gold and Silver)
        MockERC20 tokenA = new MockERC20("Gold", "GLD");
        MockERC20 tokenB = new MockERC20("Silver", "SLV");

        // 3. Authorize the Router
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);

        // 4.Add liquidity (this will create pairs and trigger Sync events!!!)
        // 100 GLD : 400 SLV
        console.log(unicode"🔥 FIRING! Adding Liquidity...");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            400 ether,
            0,
            0,
            msg.sender,
            block.timestamp + 1000
        );
        console.log(unicode"🔥 FIRE COMPLETE! Check your Bot.");

        vm.stopBroadcast();
    }
}