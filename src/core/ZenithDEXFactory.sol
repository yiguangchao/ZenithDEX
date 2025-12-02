// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./ZenithDEXPair.sol";
// import "./interfaces/IZenithDEXFactory.sol";

/**
 * @title ZenithDEX Factory
 * @author Guangchao Yi
 * @notice Create and manage trading pairs
 * @dev Using Create2, one can predict contract addresses off-chain, which is an advanced feature
 */
contract ZenithDEXFactory {
    // state variable: record all transaction pairs to addresses
    mapping(address => mapping(address => address)) public getPair;

    // an array that stores all pairs
    address[] public allPairs;

    // event: the key to FE indexing
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);

    constructor() {
        // set the rate controller here
    }

    /**
     * @dev create a new trading pair 
     * @param tokenA token A address
     * @param tokenB token B address
     */
    function createPair(address tokenA, address tokenB) external returns (address pair){
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        // sort: ensure that tokenA < tokenB to prevent duplicate creation of (A,B) and (B,A)
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), "ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PAIR_EXISTS");

        bytes memory bytecode = type(ZenithDEXPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //init Pair
        ZenithDEXPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev return trading total
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}