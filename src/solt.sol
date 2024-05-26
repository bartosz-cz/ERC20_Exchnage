// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract solt{
    address onwer;
    address nextOwner;
    uint32 coinCount = 1000000000;
    mapping(address => uint32) public balances;

    constructor(){
        onwer = msg.sender;
        balances[msg.sender] = coinCount;
    }

    //only allow specified address to use function
    modifier OnlyChosen(address chosen){
        require(msg.sender == chosen);
        _;
    }

    //only allow users with enough coins to use this feature
    modifier isBalaceSufficient(uint32 amount){
         require(balances[msg.sender] >= amount);
         _;
    }

    //select new solt owner address (old owner still owns)
    function chooseNewOwner(address newOwner) public OnlyChosen(onwer){
        nextOwner = newOwner;
    }  

    //transfer ownership to the new address (old owner lost access)
    function  ClaimOwnership() public OnlyChosen(nextOwner){
        onwer = nextOwner;
        delete nextOwner;
    }

    //send solt coins between addresses
    function send(address reciver, uint32 amount) public isBalaceSufficient(amount){
        balances[msg.sender] -= amount;
        balances[reciver] += amount;
        assert(balances[reciver] <= coinCount);
    }
}
