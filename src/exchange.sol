// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./IERC20.sol";

// Base contract for SOLT token
contract exchange{
    
    address public contractOwner;
    address public nextContractOwner;

    event ContractOwnershipTransferStarted(address indexed from, address indexed to);
    event ContractOwnershipTransferFinished(address indexed newContractOwner);
    //event ContractOwnershipTransferStarted(address indexed from, address indexed to);

    // Mapping from user addresses to their information
    mapping(address => User) public users;

    // Arrays of addresses with active sell and buy requests
    mapping(address => address[]) public sellRequestants;
    mapping(address => address[]) public buyRequestants;
     
    // Enum for different types of user requests
    enum RequestTypes{
        NONE,
        SELL, 
        BUY
    }

    // Structure to hold information about a user's request
    struct UserRequest{
        address tokenAddress;
        uint256 amount;
        uint256 coinPrice;
        uint256 time;
        RequestTypes Type;
    }
    
    // Structure to hold information about a user
    struct User{
        UserRequest Request;
    }

    // Modifier to restrict function access to a specific address

    modifier allowOnly(address _authorized){
        require(msg.sender == _authorized, "Caller is not authorized");
        _;
    }
    modifier enoughEther(uint256 _amount){
        require(msg.value >= _amount);
        _;
    }
    modifier sufficientAllowance(address tokenAddress,uint256 _amount){
        require(IERC20(tokenAddress).allowance(msg.sender, address(this)) >= _amount);
        _;
    }
    modifier sufficientBalance(address tokenAddress,uint256 _amount){
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= _amount);
        _;
    }
    modifier noOtherRequests(){
         require(users[msg.sender].Request.Type == RequestTypes.NONE);
         _;
    }
    modifier nonZeroAddress(address _to){
        require(address(0) != _to, "Transfer to the zero address is not allowed");
        _;
    }
    modifier nonZeroAmount(uint256 _amount){
        require(_amount != 0, "Amount must be greater than zero");
        _;
    }


    // Constructor sets the initial owner and assigns the max supply to them
    constructor(address _owner){
        contractOwner = _owner;
    }

    // Function to initiate token ownership transfer, can only be called by current token owner.
    function transferContractOwnership(address _nextContractOwner) external 
        allowOnly(contractOwner)
        nonZeroAddress(_nextContractOwner)
        returns(bool)
    {
        nextContractOwner = _nextContractOwner;
        emit ContractOwnershipTransferStarted(contractOwner, nextContractOwner);
        return true;
    }

    // Function to finalize token ownership transfer, can only be called by the new owner
    function claimTokenOwnership() external 
        allowOnly(nextContractOwner) 
        returns(bool)
    {
        contractOwner = nextContractOwner;
        nextContractOwner = address(0);
        emit ContractOwnershipTransferFinished(contractOwner);
        return true;
    }

    // Public functions to place sell and buy requests
    function sellRequest(address tokenAddress, uint256 amount, uint256 coinPrice) external 
        noOtherRequests()
        sufficientAllowance(tokenAddress, amount)
        sufficientBalance(tokenAddress, amount)
    {
        users[msg.sender].Request.Type = RequestTypes.SELL;
        if(!IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert("Token transfer to exchange failed");
        matchRequests(tokenAddress, amount, coinPrice, RequestTypes.SELL); 
    }

    function buyRequest(address coinAddress, uint256 amount, uint256 coinPrice) public payable 
        noOtherRequests()
        enoughEther(amount*coinPrice)
    {
        //emit RequestAccepted(msg.sender, amount, coinPrice, RequestTypes.BUY);
        users[msg.sender].Request.Type = RequestTypes.BUY;
        matchRequests(coinAddress, amount, coinPrice, RequestTypes.BUY);
    }

    // Finds requests that fulfill each other and calls executeRequests function for them
    function matchRequests(address tokenAddress, uint256 amount, uint256 coinPrice, RequestTypes TYPE) private{
        address[] storage requestants = (TYPE==RequestTypes.SELL ? buyRequestants[tokenAddress] : sellRequestants[tokenAddress]);
        uint256 amountLeft = amount;
        for (uint256 i = requestants.length; i > 0; i--){
            UserRequest storage Request = users[requestants[i-1]].Request;
            if (Request.coinPrice >= coinPrice) {
                amountLeft = executeRequests(tokenAddress,requestants[i-1], amountLeft, TYPE, i-1);
                if (amountLeft == 0) break;
            }
        }
        if(amountLeft > 0){
            //emit RequestPartiallyFulfilled(msg.sender, amount-amountLeft, coinPrice, block.timestamp);
            addRequest(tokenAddress, amountLeft, coinPrice, TYPE);
        }else{
            users[msg.sender].Request.Type = RequestTypes.NONE;   
        }
    }

    // Executes matched requests between users
    function executeRequests(address tokenAddress, address counterparty, uint256 amount, RequestTypes TYPE, uint256 requestIndex) private returns(uint256){
        UserRequest storage Request = users[counterparty].Request;
        uint256 tradeAmount = amount < Request.amount ? amount : Request.amount;
        if (TYPE == RequestTypes.SELL) {
            if(!IERC20(tokenAddress).transfer(counterparty, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(msg.sender),tradeAmount*Request.coinPrice);
        }else{
            if(!IERC20(tokenAddress).transfer(msg.sender, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(counterparty),tradeAmount*Request.coinPrice);
        }
        Request.amount -= tradeAmount;
        if (Request.amount == 0) removeRequest(tokenAddress, Request, requestIndex);
        return amount-=tradeAmount;
    }

    // Adds a new request to the respective requestants list
    function addRequest(address tokenAddress, uint256 amount, uint256 coinPrice, RequestTypes TYPE) private {
        address[] storage requestants = (TYPE!=RequestTypes.SELL ? buyRequestants[tokenAddress] : sellRequestants[tokenAddress]);
        requestants.push(msg.sender);
        UserRequest storage Request = users[msg.sender].Request;
        Request.tokenAddress = tokenAddress;
        Request.amount = amount;
        Request.coinPrice = coinPrice;
        Request.time = block.timestamp;
        //emit PendingRequestOpened(msg.sender, amount, coinPrice, block.timestamp, TYPE);
    }

    // Function to send Ether from the contract balance to a user
    function sendEther(address payable reciver, uint256 amount) private{
        (bool sent,) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    // Removes a request after it's been fully fulfilled or cancelled
    function removeRequest(address tokenAddress, UserRequest storage request, uint256 requestIndex) private {
        address[] storage requestants = (request.Type==RequestTypes.SELL ? sellRequestants[tokenAddress] : buyRequestants[tokenAddress]);
        //emit RequestFulfilled(requestants[requestIndex], request.amount, request.coinPrice, block.timestamp, request.Type);
        for (uint256 i = requestIndex; i < requestants.length - 1; i++) {
            requestants[i] = requestants[i + 1];
        }
        requestants.pop();
        request.Type = RequestTypes.NONE;
    }

}



