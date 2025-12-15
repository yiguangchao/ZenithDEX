// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "../../core/interfaces/ISimpleSwapPair.sol";
import "../../core/ZenithDEXPair.sol";

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
                hex'5f9258599943e5152a23f7bfb8b8ca9f715f65550ed1347206d6a96c8837d30a' 
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

    // 5. Chain computing: Given the input amount In and path path, calculate the output of each step
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "ZenithDEXLibrary: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
}