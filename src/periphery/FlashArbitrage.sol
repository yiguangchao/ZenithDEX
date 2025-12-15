// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@solmate/tokens/ERC20.sol";
import "../core/interfaces/ISimpleSwapPair.sol";
import "../core/interfaces/IZenithCallee.sol";

contract FlashArbitrage is IZenithCallee {
    address public immutable factory;
    
    constructor(address _factory) {
        factory = _factory;
    }

    // --- 1. Trigger: Called by Rust Bot---
    //TokenBorrow: What currency do you want to borrow (such as WETH)
    //Amount: How much to borrow
    function startArbitrage(address pairAddress, uint amount0Out, uint amount1Out) external {
        // As long as the data here is not empty, it will trigger Lightning Loan
        bytes memory data = abi.encode(msg.sender); 
        
        // Call Pair's swap to request a loan
        ISimpleSwapPair(pairAddress).swap(amount0Out, amount1Out, address(this), data);
    }

    // --- 2. callback logic: After Pair gives you the money, this function will be automatically called---
    function zenithCall(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        //Security check: Only Pair created by Factory can call me
        //For simplicity, it is omitted here. In actual projects, msg.sender must be checked

        address token0 = ISimpleSwapPair(msg.sender).token0();
        address token1 = ISimpleSwapPair(msg.sender).token1();
        
        // 1. Confirm that I have received the money
        uint fee = ((amount0 * 3) / 997) + 1;
        uint amountToRepay = amount0 + fee;

        // 2.  (Repay Loan)
        ERC20(token0).transfer(msg.sender, amountToRepay);
        
        // 3. Transfer the remaining money to the boss (Bot Owner)
        // uint profit = ...
        // ERC20(token0).transfer(owner, profit);
    }
}