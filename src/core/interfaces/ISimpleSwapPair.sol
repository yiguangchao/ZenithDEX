// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISimpleSwapPair {
    function mint(address to) external returns (uint liquidity);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    
    // Because Pair is ERC20, Router sometimes needs to call transfer/apply
    function transferFrom(address from, address to, uint value) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}