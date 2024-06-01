// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

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
    
    // Variable storing the ETH fees collected for price mismatches in transactions
    uint256 public priceMismatchEthFees;

    // Enumeration defining types of user requests
    enum RequestTypes{NONE,SELL, BUY}

    // Structure storing detailed information about a user's request
    struct UserRequest{
        address tokenAddress;
        uint256 amount;
        uint256 coinPrice;
        RequestTypes Type;
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
         require(Requests[msg.sender].Type == RequestTypes.NONE);
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


    // Constructor initializes the contract owner and sets initial fees.
    constructor(address _owner){
        contractOwner = _owner;
        priceMismatchEthFees = 0;
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

    function claimPriceMismatchEthFees() external 
        allowOnly(contractOwner) 
    {
        uint256 fees = priceMismatchEthFees;
        priceMismatchEthFees = 0;
        sendEther(payable(msg.sender), fees);
    }

    // External functions to place sell and buy requests
    function sellRequest(address tokenAddress, uint256 amount, uint256 coinPrice) external 
        noOtherRequests()
        nonZeroAmount(amount)
        nonZeroPrice(coinPrice)
        sufficientAllowance(tokenAddress, amount)
        sufficientBalance(tokenAddress, amount)
    {
        Requests[msg.sender].Type = RequestTypes.SELL;
        if(!IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert("Token transfer to exchange failed");
        matchRequests(tokenAddress, amount, coinPrice, RequestTypes.SELL); 
    }

    function buyRequest(address coinAddress, uint256 amount, uint256 coinPrice) external payable 
        noOtherRequests()
        nonZeroAmount(amount)
        nonZeroPrice(coinPrice)
        enoughEther(amount*coinPrice)
    {
        if(msg.value > amount*coinPrice) sendEther(payable(msg.sender), msg.value - amount*coinPrice);
        Requests[msg.sender].Type = RequestTypes.BUY;
        matchRequests(coinAddress, amount, coinPrice, RequestTypes.BUY);
    }
    
    // Finds requests that fulfill each other and calls executeRequests function for them
    function matchRequests(address tokenAddress, uint256 amount, uint256 tokenPrice, RequestTypes TYPE) private{
        address[] memory requestants = (TYPE==RequestTypes.SELL ? buyRequestants[tokenAddress] : sellRequestants[tokenAddress]);
        uint256 amountLeft = amount;
        for (uint256 i = requestants.length; i > 0; i--){
            UserRequest memory _Request = Requests[requestants[i-1]];
            if(priceCheck(_Request, tokenPrice)){
                amountLeft = executeRequests(tokenAddress,requestants[i-1], amountLeft, i-1, tokenPrice);
                if (amountLeft == 0) break;
            }
        }
        if(amountLeft > 0){
            addRequest(tokenAddress, amountLeft, tokenPrice, TYPE);
        }else{
            Requests[msg.sender].Type = RequestTypes.NONE;   
        }
    }

    function priceCheck(UserRequest memory _Request, uint256 tokenPrice) private pure returns(bool){
        if(_Request.Type == RequestTypes.SELL){
            if(_Request.coinPrice <= tokenPrice) return true;
        }else{
            if(_Request.coinPrice >= tokenPrice) return true;
        }
        return false;
    }

    // Executes matched requests between users
    function executeRequests(address tokenAddress, address counterparty, uint256 amount, uint256 requestIndex, uint256 tokenPrice) private returns(uint256){
        UserRequest storage _Request = Requests[counterparty];
        uint256 tradeAmount = amount < _Request.amount ? amount : _Request.amount;
        if (_Request.Type == RequestTypes.BUY) {
            if(!IERC20(tokenAddress).transfer(counterparty, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(msg.sender),tradeAmount*_Request.coinPrice);
            if(_Request.coinPrice > tokenPrice) priceMismatchEthFees+=((_Request.coinPrice-tokenPrice)*tradeAmount);
        }else{
            if(!IERC20(tokenAddress).transfer(msg.sender, tradeAmount)) revert("Token transfer to buyer failed");
            sendEther(payable(counterparty),tradeAmount*_Request.coinPrice);
            if(_Request.coinPrice < tokenPrice) priceMismatchEthFees+=((tokenPrice-_Request.coinPrice)*tradeAmount);
        }
        _Request.amount -= tradeAmount;
        emit RequestExecuted(tokenAddress, counterparty, msg.sender, _Request.Type, tradeAmount, _Request.coinPrice);
        if (_Request.amount == 0) removeRequest(tokenAddress, _Request, requestIndex);
        return amount-=tradeAmount;
    }

    // Adds a new request to the respective requestants list
    function addRequest(address tokenAddress, uint256 amount, uint256 tokenPrice, RequestTypes TYPE) private {
        address[] storage requestants = (TYPE!=RequestTypes.SELL ? buyRequestants[tokenAddress] : sellRequestants[tokenAddress]);
        requestants.push(msg.sender);
        UserRequest storage _Request = Requests[msg.sender];
        _Request.tokenAddress = tokenAddress;
        _Request.amount = amount;
        _Request.coinPrice = tokenPrice;
        emit RequestCreated(tokenAddress, msg.sender, TYPE, amount, tokenPrice);
    }

    // Removes a request after it's been fully fulfilled or cancelled
    function removeRequest(address tokenAddress, UserRequest storage request, uint256 requestIndex) private {
        address[] storage requestants = (request.Type==RequestTypes.SELL ? sellRequestants[tokenAddress] : buyRequestants[tokenAddress]);
        requestants[requestIndex] = requestants[requestants.length - 1];
        requestants.pop();
        request.Type = RequestTypes.NONE;
    }

    // Function to send Ether from the contract balance to a user
    function sendEther(address payable reciver, uint256 amount) private{
        (bool sent,) = reciver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}



