// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "../../core/interfaces/ISimpleSwapPair.sol";
import "../core/ZenithDEXPair.sol";

library ZenithDEXLibrary {
    // 1. sort Token
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "ZenithDEXLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZenithDEXLibrary: ZERO_ADDRESS");
    }

    // 2. Predicting Pair Address (No need to query on chain data, extremely gas efficient)
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'ace8a29bf09a29ec4c6c546400402450c88d35eb4ce5a27df614887ce4ab5d42' 
            )))));
    }

    // 3. Obtain the reserve amount of trading pairs
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        // Directly calculate the address and call
        (uint reserve0, uint reserve1,) = ZenithDEXPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // 4. Given input, calculate output
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, "ZenithDEXLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "ZenithDEXLibrary: INSUFFICIENT_LIQUIDITY");
        
        // 0.3% handling fee
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}