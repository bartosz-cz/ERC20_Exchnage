// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;

import "./IERC20.sol";

// The main contract for the exchange, which defines transaction logic, user data storage, and contract ownership management
contract Exchange{
    
    // Variables to store the current and future owner's addresses of the contract
    address public contractOwner;
    address public nextContractOwner;

    // Mapping to store information about exchange users
    mapping(address => UserRequest) public Requests;

    // Mappings to store lists of users who have expressed interest in selling or buying tokens
    mapping(address => address[]) public sellRequestants;
    mapping(address => address[]) public buyRequestants; 
    mapping(address => bool) private freeForOperation;
  
    // Enumeration defining types of user requests
    enum RequestTypes{NONE,SELL, BUY}

    // Structure storing detailed information about a user's request
    struct UserRequest{
        address tokenAddress;
        uint256 index;
        uint256 amount;
        uint256 tokenPrice;
        RequestTypes TYPE;
    }

    // Events emitted by the contract, used to notify about state changes and actions within the contract
    event InitiatedOwnershipTransfer(address indexed from, address indexed to);
    event ContractOwnershipTransferFinished(address indexed newContractOwner);
    event RequestCreated(address indexed tokenAddress, address indexed requestor, RequestTypes Type, uint256 amount, uint256 tokenPrice);
    event RequestExecuted(address indexed tokenAddress, address indexed requestor, address indexed counterparty, RequestTypes Type, uint256 amount, uint256 tokenPrice);

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
         require(Requests[msg.sender].TYPE == RequestTypes.NONE);
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
    modifier nonZeroPrice(uint256 _amount){
        require(_amount != 0, "Price must be greater than zero");
        _;
    }
    modifier noReentrancy(address tokenAddress){
        require(freeForOperation[tokenAddress], "Operation on token in progress");
        freeForOperation[tokenAddress] = false;
        _;
        freeForOperation[tokenAddress] = true;
    }


    // Constructor initializes the contract owner and sets initial fees.
    constructor(address _owner) nonZeroAddress(_owner){
        contractOwner = _owner;
    }

    // Function to initiate token ownership transfer, can only be called by current token owner.
    function initiateOwnershipTransfer(address _nextContractOwner) external 
        allowOnly(contractOwner)
        nonZeroAddress(_nextContractOwner)
        returns(bool)
    {
        nextContractOwner = _nextContractOwner;
        emit InitiatedOwnershipTransfer(contractOwner, nextContractOwner);
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
  
    // External functions to place sell and buy requests
    function sellRequest(address tokenAddress, uint256 amount, uint256 coinPrice) external 
        noReentrancy(tokenAddress)
        noOtherRequests()
        nonZeroAmount(amount)
        nonZeroPrice(coinPrice)
        sufficientAllowance(tokenAddress, amount)
        sufficientBalance(tokenAddress, amount)
    {
        Requests[msg.sender].TYPE = RequestTypes.SELL;
        if(!IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert("Token transfer to exchange failed");
        matchRequests(tokenAddress, amount, coinPrice, RequestTypes.SELL); 
    }

    function buyRequest(address tokenAddress, uint256 amount, uint256 coinPrice) external payable 
        noReentrancy(tokenAddress)
        noOtherRequests()
        nonZeroAmount(amount)
        nonZeroPrice(coinPrice)
        enoughEther(amount*coinPrice)
    {
        Requests[msg.sender].TYPE = RequestTypes.BUY;
        if(msg.value > amount*coinPrice) sendEther(payable(msg.sender), msg.value - amount*coinPrice);
        matchRequests(tokenAddress, amount, coinPrice, RequestTypes.BUY);
    }

    function cancelRequest() external 
          noReentrancy(Requests[msg.sender].tokenAddress)
    {
        require(Requests[msg.sender].TYPE != RequestTypes.NONE,"No requests to cancel");
        require(Requests[msg.sender].amount != 0,"You cannot cancel multiple times");
        UserRequest memory Request = Requests[msg.sender];
        uint256 _amount = Request.amount;
        Requests[msg.sender].amount = 0;
        if(Request.TYPE == RequestTypes.SELL){
            if(!IERC20(Request.tokenAddress).transfer(msg.sender,_amount)) revert("Token transfer back to requestor failed");
        }else{
            sendEther(payable(msg.sender), _amount*Request.tokenPrice);
        }
        removeRequest(msg.sender);
    }
    
    // Finds requests that fulfill each other and calls executeRequests function for them
    function matchRequests(address tokenAddress, uint256 amount, uint256 tokenPrice, RequestTypes TYPE) private{
        address[] memory requestants = (TYPE==RequestTypes.SELL ? buyRequestants[tokenAddress] : sellRequestants[tokenAddress]);
        uint256 amountLeft = amount;
        for (uint256 i = requestants.length; i > 0; i--){
            UserRequest memory Request = Requests[requestants[i-1]];
            if(priceCheck(Request, tokenPrice)){
                amountLeft = executeRequests(tokenAddress,requestants[i-1], amountLeft, tokenPrice);
                if (amountLeft == 0) break;
            }
        }
        if(amountLeft > 0){
            addRequest(tokenAddress, amountLeft, tokenPrice, TYPE);
        }else{
            Requests[msg.sender].TYPE = RequestTypes.NONE;   
        }
    }

    function priceCheck(UserRequest memory Request, uint256 tokenPrice) private pure returns(bool){
        if(Request.TYPE == RequestTypes.SELL){
            if(Request.tokenPrice <= tokenPrice) return true;
        }else{
            if(Request.tokenPrice >= tokenPrice) return true;
        }
        return false;
    }

    // Executes matched requests between users
    function executeRequests(address tokenAddress, address counterparty, uint256 amount, uint256 tokenPrice) private returns(uint256){
        UserRequest memory Request = Requests[counterparty];
        uint256 tradeAmount = amount < Request.amount ? amount : Request.amount;
        if (Request.TYPE == RequestTypes.BUY) {
            if(!IERC20(tokenAddress).transfer(counterparty, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(msg.sender),tradeAmount*Request.tokenPrice);
            if(Request.tokenPrice > tokenPrice) sendEther(payable(counterparty), (Request.tokenPrice-tokenPrice)*tradeAmount);
        }else{
            if(!IERC20(tokenAddress).transfer(msg.sender, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(counterparty),tradeAmount*Request.tokenPrice);
            if(Request.tokenPrice < tokenPrice) sendEther(payable(msg.sender), (tokenPrice-Request.tokenPrice)*tradeAmount);
        }
        Request.amount -= tradeAmount;
        if (Request.amount == 0){
            removeRequest(counterparty);
        }else{
            Requests[counterparty].amount = Request.amount;
        }
        emit RequestExecuted(tokenAddress, msg.sender, counterparty, Request.TYPE, tradeAmount, Request.tokenPrice);
        return amount-=tradeAmount;
    }

    // Adds a new request to the respective requestants list
    function addRequest(address _tokenAddress, uint256 _amount, uint256 _tokenPrice, RequestTypes _TYPE) private {
        address[] storage requestants = (_TYPE!=RequestTypes.SELL ? buyRequestants[_tokenAddress] : sellRequestants[_tokenAddress]);
        requestants.push(msg.sender);
        Requests[msg.sender] = UserRequest({
            tokenAddress : _tokenAddress,
            index : requestants.length-1,
            amount : _amount,
            tokenPrice : _tokenPrice,
            TYPE : _TYPE
        });
        emit RequestCreated(_tokenAddress, msg.sender, _TYPE, _amount, _tokenPrice);
    }

    // Removes a request after it's been fully fulfilled or cancelled
    function removeRequest(address requestor) private {
        UserRequest memory Request = Requests[requestor];
        address[] storage requestants = (Request.TYPE==RequestTypes.SELL ? sellRequestants[Request.tokenAddress] : buyRequestants[Request.tokenAddress]);
        Requests[requestants[requestants.length - 1]].index = Request.index;
        requestants[Request.index] = requestants[requestants.length - 1];
        requestants.pop();
        Requests[requestor].TYPE = RequestTypes.NONE;
    }

    // Function to send Ether from the contract balance to a user
    function sendEther(address payable reciver, uint256 amount) private{
        (bool sent,) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}



