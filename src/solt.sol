// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

//base solt contract
contract solt{
    address onwer;
    address nextOwner;
    uint32 coinCount = 1000000000;
    
    enum RequestTypes{
        none,
        sell, 
        buy
    }

    struct userRequest{
        address userAddress;
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

    address[] public sellRequests;
    address[] buyRequests;

    constructor(){
        onwer = msg.sender;
        users[msg.sender].balance = coinCount;
    }

    //only allow specified address to use function
    modifier OnlyChosen(address chosen){
        require(msg.sender == chosen);
        _;
    }

    //only allow users with enough coins to use this feature
    modifier isBalaceSufficient(uint32 amount){
        require(users[msg.sender].balance >= amount);
        _;
    }

    modifier noneRequest(){
         require(users[msg.sender].Request.Type == RequestTypes.none);
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
        users[msg.sender].balance -= amount;
        users[reciver].balance += amount;
        assert(users[reciver].balance <= coinCount);
    }

    
    
    
    
    
    function sendEther(address payable reciver, uint32 amount) private{
        (bool sent, bytes memory data) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }


    function sellRequest(uint32 amount, uint32 minCoinPrice) public noneRequest isBalaceSufficient(amount){
        users[msg.sender].Request.Type = RequestTypes.sell;
        uint32 amountToSell = amount;
        userRequest memory buyRequest;
        while(amountToSell > 0){
            
            if(buyRequests.length != 0 && users[buyRequests[buyRequests.length-1]].Request.coinPrice >= minCoinPrice){
                buyRequest = users[buyRequests[buyRequests.length-1]].Request;
                if(amount <= buyRequest.amount){
                    users[msg.sender].balance -= amount;
                    buyRequest.amount -= amount;
                    sendEther(payable(msg.sender),buyRequest.coinPrice * amount);
                    buyRequest.Type = RequestTypes.none;
                    users[buyRequests[buyRequests.length-1]].balance += amount;
                    amountToSell = 0;
                }else{
                    users[msg.sender].balance -= buyRequest.amount;
                    sendEther(payable(msg.sender),buyRequest.coinPrice * users[buyRequests[0]].Request.amount);
                    users[buyRequests[buyRequests.length-1]].balance += buyRequest.amount;
                    amountToSell -= buyRequest.amount;
                    delete buyRequest;
                    buyRequests.pop();
                }
            }else{
                users[msg.sender].Request.Type = RequestTypes.sell;
                users[msg.sender].Request.amount = amountToSell;
                users[msg.sender].Request.coinPrice = minCoinPrice;
                users[msg.sender].Request.time = block.timestamp;
                users[msg.sender].balance -= amountToSell;

                if(sellRequests.length != 0){
                    for(uint256 i = sellRequests.length-1; i > 0; i--){
                        if(users[sellRequests[buyRequests.length-1]].Request.coinPrice >= minCoinPrice){
                            sellRequests.push(sellRequests[sellRequests.length - 1]);
                            for (uint j = sellRequests.length - 1; j > i; j--) {
                                sellRequests[j] = sellRequests[j - 1];
                            }
                            sellRequests[i] = msg.sender;            
                        }
                    }
                }else{
                    sellRequests.push(msg.sender);
                }
                return;
            }
        }
        users[msg.sender].Request.Type = RequestTypes.none;
    }
}



