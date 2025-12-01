// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "./interfaces/ISimpleSwapPair.sol";
import "@solmate/tokens/ERC20.sol"; // It inherits from ERC20, because LP Token is itself a token
// import "./libraries/Math.sol";
// import "./libraries/UQ112x112.sol"; // A library for handling price accuracy

contract ZenithDEXPair is ERC20 {
    // 1. state variable
    uint256 public constant MINIMUM_LIQUIDITY = 10**3; // Minimum liquidity, anti-attack
    
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0; // Using uint112 is for packing storage and saving gas
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    // 2. Lock mechanism (prevent reentrance)
    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // 3. event
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() ERC20("SimpleSwap LPs", "SS-LP", 18) {
        factory = msg.sender;
    }

    // Initialization (called by Factory)
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }
}