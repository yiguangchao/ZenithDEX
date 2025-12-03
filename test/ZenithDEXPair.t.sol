// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/ZenithDEXFactory.sol";
import "../src/core/ZenithDEXPair.sol";
import "@solmate/tokens/ERC20.sol";

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
        uint amount1 = 4 ether;

        // 1. transfer to Pair Contract
        tokenA.transfer(address(pair), amount0);
        tokenB.transfer(address(pair), amount1);

        // 2. call mint
        uint liquidity = pair.mint(address(this));

        // 3. verification result
        // Expected liquidity = sqrt(1 * 4) - 1000 = 2 ether - 1000
        uint expectedLiquidity = 2 ether - 1000;
        
        assertEq(liquidity, expectedLiquidity);
        assertEq(pair.totalSupply(), expectedLiquidity + 1000);
        assertEq(pair.balanceOf(address(this)), expectedLiquidity);
        
        console.log("Liquidity Minted:", liquidity);
    }

    function testBurn() public {
        // 1. Setup: first, mint some liquidity
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 4 ether);
        pair.mint(address(this));

        // 2. Action: remove liquidity
        // First, obtain the LP balance in my hand
        uint liquidity = pair.balanceOf(address(this));
        // We must first transfer the LP back to the Pair contract (Pull mode)
        pair.transfer(address(pair), liquidity);
        
        // call burn
        (uint amount0, uint amount1) = pair.burn(address(this));

        // 3. Assert: verify the money retrieved
        // Because MINIMUM-LIQUIDITY (1000 wei) is locked, the amount retrieved will be slightly less
        // 1 ether - 1000 wei * ratio... 
        // Simple verification: should be close to the original investment
        assertGt(amount0, 1 ether - 2000);
        assertGt(amount1, 4 ether - 5000);
        
        // Pair contract should be almost empty (except for a very small amount that is permanently locked)
        assertEq(pair.balanceOf(address(this)), 0);
    }

    // Simulate the logic of Library
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function testSwap() public {
        // 1. Setup:Inject initial liquidity (1 ETH : 4 ETH)
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 4 ether);
        pair.mint(address(this));

        // 2. Action: Preparing to purchase tokenB with 0.1 tokenA
        uint amountIn = 0.1 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(pair), amountIn); 

        // 3. Dynamically calculate expected results
        (uint reserve0, uint reserve1,) = pair.getReserves();
        uint expectedOut = getAmountOut(amountIn, 1 ether, 4 ether);
        
        console.log("Expected Out:", expectedOut);

        // 4. execute Swap
        // amount0Out = 0 
        // amount1Out = expectedOut
        pair.swap(0, expectedOut, address(this), "");

        // 5. Assert
        uint liquidityProvided = 4 ether;
        assertEq(
            tokenB.balanceOf(address(this)), 
            (10 ether - liquidityProvided) + expectedOut
        ); 
    }
}