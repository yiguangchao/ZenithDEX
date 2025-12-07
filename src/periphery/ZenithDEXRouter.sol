// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./libraries/ZenithDEXLibrary.sol";
import "../core/interfaces/ISimpleSwapFactory.sol";
import "../core/interfaces/ISimpleSwapPair.sol"; 
import "@solmate/tokens/ERC20.sol";
// Introduce WETH interface 
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract ZenithDEXRouter {
    address public immutable factory;
    address public immutable WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    // --- Internal logic: Calculate the optimal number of additions ---
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) {
        // 1. If Pair does not exist, create it first
        if (ISimpleSwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ISimpleSwapFactory(factory).createPair(tokenA, tokenB);
        }

        // 2. Obtain the current reserve quantity
        (uint reserveA, uint reserveB) = ZenithDEXLibrary.getReserves(factory, tokenA, tokenB);

        // 3. Calculate the optimal ratio
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // The old pond must be proportionally arranged
            // Calculation: How much B do I need if I save an amount of ADesired?
            uint amountBOptimal = (amountADesired * reserveB) / reserveA;
            
            if (amountBOptimal <= amountBDesired) {
                // The calculated B is small enough (I have enough B)
                require(amountBOptimal >= amountBMin, "INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // There are too many calculated B's, my B's are not enough. Then calculate the opposite, based on my B, how much A is needed
                uint amountAOptimal = (amountBDesired * reserveA) / reserveB;
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    // --- External interface: Add liquidity ---
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // 1. Calculate the optimal quantity
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
        // 2. Transfer: Transfer tokens from the user to Pair
        address pair = ZenithDEXLibrary.pairFor(factory, tokenA, tokenB);
        
        // Attention: Users must first approve the Router contract!
        ERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        ERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        
        // 3. Casting LP
        liquidity = ISimpleSwapPair(pair).mint(to);
    }

    // --- Internal core: Perform chain exchange ---
    // Extremely optimized implementation of Gas
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ZenithDEXLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            
            // Determine Amount0Out and Amount1Out
            // If input==token0, it means we want to swap out token1 (amont1Out)
            (uint amount0Out, uint amount1Out) = input == token0 
                ? (uint(0), amountOut) 
                : (amountOut, uint(0));
            
            // Determine the recipient (to)
            // If the destination of the path has not been reached yet, the receiver should be the next Pair address
            // If the destination is reached, the receiver is the user specified _to
            address to = i < path.length - 2 
                ? ZenithDEXLibrary.pairFor(factory, output, path[i + 2]) 
                : _to;
            
            // Trigger Pair's Swap
            ISimpleSwapPair(ZenithDEXLibrary.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    // --- External interface: precise input exchange (swapExactTokensForTokens) ---
    // Scenario: I have 1 ETH and want to exchange as much USDT as possible
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // 1. Calculate the amount for all steps
        amounts = ZenithDEXLibrary.getAmountsOut(factory, amountIn, path);
        
        // 2. Calculate the amount for all steps
        // The final amount calculated must be greater than or equal to the minimum value 
        // accepted by the user, otherwise rollback will occur
        require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        
        // 3. Collection: Transfer the user's Token A to the first pair
        // Note: Just turn to the first one, the rest are internal transfers between pairs
        address pair = ZenithDEXLibrary.pairFor(factory, path[0], path[1]);
        ERC20(path[0]).transferFrom(msg.sender, pair, amounts[0]);
        
        // 4. Start exchanging
        _swap(amounts, path, to);
    }
}