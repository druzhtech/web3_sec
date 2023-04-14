pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Split{
    function getAddrAndAmountToSplit() view external returns(address, uint);
}

contract SmartBank {

    mapping (IERC20 => mapping(address => uint)) public userBalance;
    
    mapping (address => Split) splits;


    function getWholeNumberAmount(IERC20 token, address user) external view returns(uint) {
        return userBalance[token][user] / 10**18;
    }

    function addToBalance(IERC20 token, uint amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        userBalance[token][msg.sender] += amount; 
        
    }

    function withdrawBalance(IERC20 token) external  {
        token.transfer(msg.sender, userBalance[token][msg.sender]);
        userBalance[token][msg.sender] = 0;
    }
    
    function registerSplit(Split split) external {
        splits[msg.sender] = split;
    }

    function splitBalance(IERC20 token) external  {
        Split split = splits[msg.sender];
        require(address(split) != address(0x0));
        uint balance = userBalance[token][msg.sender];
        
        (address dest, uint amount) = split.getAddrAndAmountToSplit();
   
        userBalance[token][dest] = amount;
        userBalance[token][msg.sender] = balance - amount; 
    }
}
