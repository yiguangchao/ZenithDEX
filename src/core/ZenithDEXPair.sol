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

    function _update(uint balance0, uint balance1, uint112 /*_reserve0*/, uint112 /*_reserve1*/) private {
        // ...
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

    // Core trading function
    // amount0Out: how much do users want to buy token0
    // amount1Out: how much do users want to buy token1
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        
        // 1. Obtain reserve quantity (provincial gas)
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");

        uint balance0;
        uint balance1;
        
        // 2. Optimistic Transfer
        // First, give the money to the user, and then check if the corresponding input token has been received.
        // This sequence allows for "lightning loans" - users can use the money to arbitrage elsewhere after receiving it,
        // and finally repay it back.
        { 
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "INVALID_TO");
            
            // Transfer to user
            if (amount0Out > 0) IERC20(_token0).transfer(to, amount0Out); 
            if (amount1Out > 0) IERC20(_token1).transfer(to, amount1Out);
            
            // If there is data in the data, this will trigger a callback for lightning loans (callee. zenithCall)
            // if (data.length > 0) IZenithCallee(to).zenithCall(msg.sender, amount0Out, amount1Out, data);

            // Obtain the balance after transfer
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // 3. Calculate how much money the user actually deposited (Input Amount)
        // Balance - (Reserve - Transferred)=Actual Input
        uint amount0In = balance0 > (_reserve0 - amount0Out) ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > (_reserve1 - amount1Out) ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        // 4. K-value verification (core formula verification)
        // (x + dx * 0.997) * (y + dy * 0.997) >= x * y
        // That is to say, the adjusted balance product is greater than or equal to the old reserve product
        {
            uint balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            uint balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            
            // To prevent overflow, higher precision calculations may be required here, but in Solidity 0.8, 
            // there is no need to worry about overflow bypassing, only revert
            require(
                balance0Adjusted * balance1Adjusted >= uint(_reserve0) * uint(_reserve1) * (1000**2), 
                "K"
            );
        }

        // 5. Update reserve quantity
        _update(balance0, balance1, _reserve0, _reserve1);
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // destruction of liquidity: Users need to transfer LP tokens to this contract first, and then call this function
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        // 1. get current status
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1); 
        address _token0 = token0;
        address _token1 = token1;
        
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        
        // 2. core: Check how many LP tokens users have transferred in and need to be destroyed
        uint liquidity = balanceOf[address(this)];

        // 3. calculate the amount to be refunded
        // amount0 = (liquidity * balance0) / totalSupply
        uint _totalSupply = totalSupply; 
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        // 4. destroy LP Token
        _burn(address(this), liquidity);

        // 5. transfer money to the user
        IERC20(_token0).transfer(to, amount0);
        IERC20(_token1).transfer(to, amount1);

        // 6. update reserve quantity
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
}