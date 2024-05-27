// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

// Base contract for SOLT token
contract solt{
    address owner;
    address nextOwner;
    uint32 constant MAX_SUPPLY = 1000000000;
     
    // Enum for different types of user requests
    enum RequestTypes{
        NONE,
        SELL, 
        BUY
    }

    // Structure to hold information about a user's request
    struct UserRequest{
        uint32 amount;
        uint32 coinPrice;
        uint256 time;
        RequestTypes Type;
    }
    
    // Structure to hold information about a user
    struct User{
        uint32 balance;
        UserRequest Request;
    }

    // Mapping from user addresses to their information
    mapping(address => User) public users;

    // Arrays of addresses with active sell and buy requests
    address[] public sellRequestants;
    address[] public buyRequestants;

    // Events for various actions within the contract
    event NewOwnerChosed(address newOwner);
    event NewOwnerClaimedOwnership(address newOwner);
    event RequestAccepted(address requestor, uint32 amount, uint32 coinPrice, RequestTypes Type);
    event PendingRequestOpened(address requestor, uint32 amount, uint32 coinPrice, uint256 time, RequestTypes Type);
    event RequestPartiallyFulfilled(address requestor, uint32 amount, uint32 coinPrice, uint256 time);
    event RequestFulfilled(address requestor, uint32 amount, uint32 coinPrice, uint256 time, RequestTypes Type);

    // Constructor sets the initial owner and assigns the max supply to them
    constructor(){
        owner = msg.sender;
        users[msg.sender].balance = MAX_SUPPLY;
    }

    // Modifier to restrict function access to a specific address
    modifier allowOnly(address _authorized){
        require(msg.sender == _authorized, "Caller is not authorized");
        _;
    }

    //only allow users with enough coins to use this feature
    modifier balaceSufficient(uint32 _amount){
        require(users[msg.sender].balance >= _amount);
        _;
    }

    // Modifier to check if enough Ether has been sent with the request
    modifier enoughEther(uint32 _amount){
        require(msg.value >= _amount);
        _;
    }

    // Modifier to ensure the user has no active requests
    modifier noneRequest(){
         require(users[msg.sender].Request.Type == RequestTypes.NONE);
         _;
    }

    // Allows the current owner to choose a new owner
    function chooseNewOwner(address newOwner) public allowOnly(owner){
        require(newOwner != address(0), "Invalid new owner address");
        nextOwner = newOwner;
        emit NewOwnerChosed(newOwner);
    }  

    //transfer ownership to the new address (old owner lost access)
    function  ClaimOwnership() public allowOnly(nextOwner){
        owner = nextOwner;
        nextOwner = address(0);
        emit NewOwnerClaimedOwnership(owner);
    }

    //send solt coins between addresses
    function send(address reciver, uint32 amount) public balaceSufficient(amount){
        users[msg.sender].balance -= amount;
        users[reciver].balance += amount;
        assert(users[reciver].balance <= MAX_SUPPLY);
    }

    // Function to send Ether from the contract balance to a user
    function sendEther(address payable reciver, uint32 amount) private{
        (bool sent,) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    // Finds requests that fulfill each other and calls executeRequests function for them
    function matchRequests(uint32 amount, uint32 coinPrice, RequestTypes TYPE) private{
        users[msg.sender].Request.Type = TYPE;
        address[] storage requestants = (TYPE==RequestTypes.SELL ? buyRequestants : sellRequestants);
        uint32 amountLeft = amount;
        for (uint256 i = requestants.length; i > 0; i--) {
            UserRequest storage Request = users[requestants[i-1]].Request;
            if (Request.coinPrice >= coinPrice) {
                amountLeft = executeRequests(requestants[i-1], amountLeft, TYPE, i-1);
            if (amountLeft == 0) break;
        }
        }
        if(amountLeft > 0){
            emit RequestPartiallyFulfilled(msg.sender, amount-amountLeft, coinPrice, block.timestamp);
            addRequest(amountLeft, coinPrice, TYPE);
        }else{
            users[msg.sender].Request.Type = RequestTypes.NONE;   
        }
    }

    // Executes matched requests between users
    function executeRequests(address counterparty, uint32 amount, RequestTypes TYPE, uint256 requestIndex) private returns(uint32){
        UserRequest storage Request = users[counterparty].Request;
        uint32 tradeAmount = amount < Request.amount ? amount : Request.amount;
        if (TYPE == RequestTypes.SELL) {
            sendEther(payable(msg.sender),tradeAmount*Request.coinPrice);
            users[msg.sender].balance -= tradeAmount;
            users[counterparty].balance += tradeAmount;

        } else {
            sendEther(payable(counterparty),tradeAmount*Request.coinPrice);
            users[msg.sender].balance += tradeAmount;
            users[counterparty].balance -= tradeAmount;
        }
        Request.amount -= tradeAmount;
        if (Request.amount == 0) removeRequest(Request, requestIndex);
        return amount-=tradeAmount;
    }

    // Public functions to place sell and buy requests
    function sellRequest(uint32 amount, uint32 coinPrice) public noneRequest balaceSufficient(amount){
        emit RequestAccepted(msg.sender, amount, coinPrice, RequestTypes.SELL);
        matchRequests(amount, coinPrice, RequestTypes.SELL);
    }
    function buyRequest(uint32 amount, uint32 coinPrice) public payable noneRequest enoughEther(amount*coinPrice){
        emit RequestAccepted(msg.sender, amount, coinPrice, RequestTypes.BUY);
        matchRequests(amount, coinPrice, RequestTypes.BUY);
    }

    // Removes a request after it's been fully fulfilled or cancelled
    function removeRequest(UserRequest storage request, uint256 requestIndex) private {
        address[] storage requestants = (request.Type==RequestTypes.SELL ? sellRequestants : buyRequestants);
        emit RequestFulfilled(requestants[requestIndex], request.amount, request.coinPrice, block.timestamp, request.Type);
        for (uint256 i = requestIndex; i < requestants.length - 1; i++) {
            requestants[i] = requestants[i + 1];
        }
        requestants.pop();
        request.Type = RequestTypes.NONE;
    }

    // Adds a new request to the respective requestants list
    function addRequest(uint32 amount, uint32 coinPrice, RequestTypes TYPE) private {
        address[] storage requestants = (TYPE==RequestTypes.SELL ? sellRequestants : buyRequestants);
        users[msg.sender].balance -= amount;
        requestants.push(msg.sender);
        UserRequest storage Request = users[msg.sender].Request;
        Request.amount = amount;
        Request.coinPrice = coinPrice;
        Request.time = block.timestamp;
        emit PendingRequestOpened(msg.sender, amount, coinPrice, block.timestamp, TYPE);
    }
}



