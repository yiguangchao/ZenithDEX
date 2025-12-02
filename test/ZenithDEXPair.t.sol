// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/ZenithDEXFactory.sol";
import "../src/core/ZenithDEXPair.sol";
import "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Simulated tokens for testing purposes
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol, 18) {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract ZenithDEXPairTest is Test {
    ZenithDEXFactory factory;
    ZenithDEXPair pair;
    MockERC20 tokenA;
    MockERC20 tokenB;

    function setUp() public {
        // 1. build Factory
        factory = new ZenithDEXFactory();
        
        // 2. build two token
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        
        // 3. Ensure tokenA<tokenB (as Factory will sort)
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // 4. crete Pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = ZenithDEXPair(pairAddress);

        // 5. send some money to the testing account
        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);
    }

    function testMintBootstrap() public {
        // test adding liquidity for the first time
        uint amount0 = 1 ether;
        uint amount1 = 4 ether; // 价格 1:4

        // 1. transfer to Pair Contract
        tokenA.transfer(address(pair), amount0);
        tokenB.transfer(address(pair), amount1);

        // 2. call mint
        uint liquidity = pair.mint(address(this));

        // 3. verification result
        // expected liquidity = sqrt(1 * 4) - 1000 = 2 ether - 1000
        uint expectedLiquidity = 2 ether - 1000;
        
        assertEq(liquidity, expectedLiquidity);
        assertEq(pair.totalSupply(), expectedLiquidity + 1000);
        assertEq(pair.balanceOf(address(this)), expectedLiquidity);
        
        console.log("Liquidity Minted:", liquidity);
    }
}