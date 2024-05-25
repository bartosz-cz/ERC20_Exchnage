// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract solt{
    address onwer;
    address nextOwner;
    uint32 coinCount = 1000000000;
    mapping(address => uint32) balances;

    constructor(){
        onwer = msg.sender;
        balances[msg.sender] = coinCount;
    }

    modifier OnlyChosen(address chosen){
        require(msg.sender == chosen);
        _;
    }

    modifier isBalaceSufficient(uint32 amount){
         require(balances[msg.sender] >= amount);
         _;
    }

    function chooseNewOwner(address newOwner) public OnlyChosen(onwer){
        nextOwner = newOwner;
    }  

    function  ClaimOwnership() public OnlyChosen(nextOwner){
        onwer = nextOwner;
        delete nextOwner;
    }

    function send(address reciver, uint32 amount) public isBalaceSufficient(amount){
        balances[msg.sender] -= amount;
        balances[reciver] += amount;
        assert(balances[reciver] <= coinCount);
    }
}