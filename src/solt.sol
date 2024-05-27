// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

//base solt contract
contract solt{
    address owner;
    address nextOwner;
    uint32 constant MAX_SUPPLY = 1000000000;
    
    enum RequestTypes{
        NONE,
        SELL, 
        BUY
    }

    struct userRequest{
        uint32 amount;
        uint32 coinPrice;
        uint256 time;
        RequestTypes Type;
    }
    
    struct User{
        uint32 balance;
        userRequest Request;
    }

    
    mapping(address => User) public users;

    address[] public sellRequestants;
    address[] public buyRequestants;

    constructor(){
        owner = msg.sender;
        users[msg.sender].balance = MAX_SUPPLY;
    }

    //only allow specified address to use function
    modifier allowOnly(address _authorized){
        require(msg.sender == _authorized, "Caller is not authorized");
        _;
    }

    //only allow users with enough coins to use this feature
    modifier balaceSufficient(uint32 _amount){
        require(users[msg.sender].balance >= _amount);
        _;
    }

    modifier enoughEther(uint32 _amount){
        require(msg.value >= _amount);
        _;
    }


    modifier noneRequest(){
         require(users[msg.sender].Request.Type == RequestTypes.NONE);
         _;
    }

    //select new solt owner address (old owner still owns)
    function chooseNewOwner(address newOwner) public allowOnly(owner){
        require(newOwner != address(0), "Invalid new owner address");
        nextOwner = newOwner;
    }  

    //transfer ownership to the new address (old owner lost access)
    function  ClaimOwnership() public allowOnly(nextOwner){
        owner = nextOwner;
        nextOwner = address(0);
    }

    //send solt coins between addresses
    function send(address reciver, uint32 amount) public balaceSufficient(amount){
        users[msg.sender].balance -= amount;
        users[reciver].balance += amount;
        assert(users[reciver].balance <= MAX_SUPPLY);
    }

    function sendEther(address payable reciver, uint32 amount) private{
        (bool sent,) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function matchRequests(uint32 amount, uint32 coinPrice, RequestTypes TYPE) private{
        users[msg.sender].Request.Type = TYPE;
        address[] storage requestants = (TYPE==RequestTypes.SELL ? buyRequestants : sellRequestants);
        uint32 amountLeft = amount;
        for (uint i = requestants.length; i > 0; i--) {
            userRequest storage request = users[requestants[i-1]].Request;
            if (request.coinPrice >= coinPrice) {
                amountLeft = executeRequests(requestants[i-1], amountLeft, TYPE, i-1);
            if (amountLeft == 0) break;
        }
        }
        if(amountLeft > 0){
            addRequest(amountLeft, coinPrice, TYPE);
        }else{
            users[msg.sender].Request.Type = RequestTypes.NONE;   
        }
    }

    function executeRequests(address counterparty, uint32 amount, RequestTypes TYPE, uint requestIndex) private returns(uint32){
        userRequest storage request = users[counterparty].Request;
        uint32 tradeAmount = amount < request.amount ? amount : request.amount;
        if (TYPE == RequestTypes.SELL) {
            sendEther(payable(msg.sender),tradeAmount*request.coinPrice);
            users[msg.sender].balance -= tradeAmount;
            users[counterparty].balance += tradeAmount;

        } else {
            sendEther(payable(counterparty),tradeAmount*request.coinPrice);
            users[msg.sender].balance += tradeAmount;
            users[counterparty].balance -= tradeAmount;
        }
        request.amount -= tradeAmount;
        if (request.amount == 0) removeRequest(request, requestIndex);
        return amount-=tradeAmount;
    }

    function sellRequest(uint32 amount, uint32 coinPrice) public noneRequest balaceSufficient(amount){
        matchRequests(amount, coinPrice, RequestTypes.SELL);
    }

    function buyRequest(uint32 amount, uint32 coinPrice) public payable noneRequest enoughEther(amount*coinPrice){
        matchRequests(amount, coinPrice, RequestTypes.BUY);
    }

    function removeRequest(userRequest storage request, uint requestIndex) private {
        address[] storage requestants = (request.Type==RequestTypes.SELL ? sellRequestants : buyRequestants);
        for (uint i = requestIndex; i < requestants.length - 1; i++) {
            requestants[i] = requestants[i + 1];
        }
        requestants.pop();
        request.Type = RequestTypes.NONE;
    }

    function addRequest(uint32 amount, uint32 coinPrice, RequestTypes TYPE) private {
        address[] storage requestants = (TYPE==RequestTypes.SELL ? sellRequestants : buyRequestants);
        users[msg.sender].balance -= amount;
        requestants.push(msg.sender);
        userRequest storage request = users[msg.sender].Request;
        request.amount = amount;
        request.coinPrice = coinPrice;
        request.time = block.timestamp;
    }
}



