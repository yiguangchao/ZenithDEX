// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "./interfaces/ISimpleSwapPair.sol";
import "@solmate/tokens/ERC20.sol"; // It inherits from ERC20, because LP Token is itself a token
import "./libraries/Math.sol";
// import "./libraries/UQ112x112.sol"; // A library for handling price accuracy
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    // Core, add liquidity （Mint) ---
    // The user first transfers TokenA and TokenB to this contract, and then calls mint()
    // Return value: The number of LP Tokens generated this time
    function mint(address to) external lock returns (uint liquidity) {
        // 1. get the balance in the current contract 
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        // 2. calculate how much money the user just transferred in
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        // 3. calculate how much LP Token should be send to him
        uint _totalSupply = totalSupply;

        if(_totalSupply == 0) {
            // first casting: geometric mean minimum flowability
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // permanently lock the top 100 positions
            _mint(address(0), MINIMUM_LIQUIDITY);
        }else {
            // follow-up casting
            // liquidity - min( (amount0 * total / reserve0))
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        // 4. send LP Token to user
        _mint(to, liquidity);

        // 5. Update reserve records
        _update(balance0, balance1, _reserve0, _reserve1);

        emit Mint(msg.sender, amount0, amount1);
    }
}