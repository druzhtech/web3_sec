// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

/**
 * Welcome to a cool trader contract
 * that simplifies your trading experience
 *
 * Come up with a strategy of token swaps:
 * the contract will check if it is profitable
 * and execute it
 */
contract Trader is Ownable {
    // Uniswap v3
    ISwapRouter public immutable swapRouter;
    IQuoter public immutable quoter;

    constructor(ISwapRouter _swapRouter, IQuoter _quoter) {
        swapRouter = _swapRouter;
        quoter = _quoter;
    }

    /**
     * Run a profitable strategy to increase the Trader balance
     * @param path uniswap v3 multi-hop path of the swap, i.e. each token pair and the pool fee
     * @param amountIn how much to swap
     * 
     * The start token in the path must be equal to the end token
     * The profit must be positive: the amount out must be greater than the amount in
     * 
     * For example:
     * ```
     * uint24 fee = 3000;
     * address WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
     * address DAI = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
     * 
     * runProfitableStrategy(abi.encodePacked(WETH, fee, DAI, fee, WETH), 100)
     * ```
     */
    function runProfitableStrategy(bytes memory path, uint256 amountIn) public {
        address start = toAddress(path, 0);
        address finish = toAddress(path, path.length - 20);
        require(start == finish, "the path must start and end with the same token");

        uint256 amountOut = quoter.quoteExactInput(path, amountIn);
        require(amountOut > amountIn, "not profitable");

        IERC20(start).approve(address(swapRouter), type(uint256).max);

        swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                amountIn: amountIn,
                recipient: address(this),
                deadline: block.timestamp,
                amountOutMinimum: 0
            })
        );
    }

    function sweep(IERC20 token) onlyOwner external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address result) {
        assembly {
            result := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }
    }
}
