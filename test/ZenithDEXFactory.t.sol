// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/ZenithDEXFactory.sol";
import "../src/core/ZenithDEXPair.sol";

// Simulated ERC20 Token
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MTK";
    uint8 public decimals = 18;
}

contract ZenithDEXFactoryTest is Test {
    ZenithDEXFactory factory;
    
    // Define two simulated token addresses
    address tokenA;
    address tokenB;

    // Redefine events for testing capture (Event definition)
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);

    function setUp() public {
        // 1. Deploy factory contract
        factory = new ZenithDEXFactory();

        // 2. Deploy two simulated tokens and obtain addresses
        address t1 = address(new MockERC20());
        address t2 = address(new MockERC20());
        
        if (t1 < t2) {
            tokenA = t1;
            tokenB = t2;
        } else {
            tokenA = t2;
            tokenB = t1;
        }
    }

    // --- Normal Process Testing (Happy Path)---

    // Test 1: Successfully created a trading pair
    function testCreatePair() public {
        // Call the create function
        address pair = factory.createPair(tokenA, tokenB);

        // Assumption 1: The generated pair address should not be a 0 address
        assertTrue(pair != address(0));

        // Assumption 2: This address should be able to be found through getPair mapping
        assertEq(factory.getPair(tokenA, tokenB), pair);
        
        // Assumption 3: Reverse queries should also find the same address (because the factory has sorted it internally)
        assertEq(factory.getPair(tokenB, tokenA), pair);

        // Assumption 4: The length of the allPairs array should be 1
        assertEq(factory.allPairs(0), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    // Test 2: Verify if the Event event is correctly thrown
    function testEmitPairCreated() public {
        vm.expectEmit(true, true, false, false);
        
        emit PairCreated(tokenA, tokenB, address(0), 1); 

        factory.createPair(tokenA, tokenB);
    }

    // ---Abnormal Process Testing (Sad Path/Revert)---

    // Test 3: Prohibit using the same token address
    function testCannotCreatePairWithIdenticalTokens() public {
        vm.expectRevert("IDENTICAL_ADDRESSES");
        factory.createPair(tokenA, tokenA);
    }

    // Test 4: Prohibit the use of 0 addresses
    function testCannotCreatePairWithZeroAddress() public {
        vm.expectRevert("ZERO_ADDRESS");
        factory.createPair(address(0), tokenB);
    }

    // Test 5: Prohibit duplicate creation of existing transaction pairs
    function testCannotCreateExistingPair() public {
        factory.createPair(tokenA, tokenB);

        vm.expectRevert("PAIR_EXISTS");
        factory.createPair(tokenA, tokenB);
    }

    // Test 6: Prohibit duplicate creation (even in reverse order)
    function testCannotCreateExistingPairReverse() public {
        factory.createPair(tokenA, tokenB);

        vm.expectRevert("PAIR_EXISTS");
        factory.createPair(tokenB, tokenA);
    }
}