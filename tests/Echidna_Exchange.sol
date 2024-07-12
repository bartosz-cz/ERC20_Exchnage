// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;


import "../src/Exchange.sol";
import {ERC20} from "ERC20.sol";

/**
 * @title External Tests for Exchange and ERC20 interactions
 * @dev This contract tests the non-reversion of sell and buy requests through an Exchange contract with an ERC20 token
 */
contract ExternalTests {
    ERC20 token;
    Exchange _Exchange;

    /**
     * @dev Constructor that deploys a new ERC20 token, sets up an Exchange, and mints ERC20 tokens to this contract
     */
    constructor() {
        token = new ERC20(address(this), "test", "sym", 8, 1000000);
        _Exchange = new Exchange(address(this));
        token.mint(address(this), 500000);
    }

    // Fallback function to accept ether
    fallback() external payable {}

    // Receive function to accept ether
    receive() external payable {}

    /**
     * @notice Test that ensures 'sellRequest' and 'cancelRequest' on the Exchange do not revert unexpectedly
     * @param amount The amount of tokens to sell
     * @param tokenPrice The price of the token in Ether
     */
    function sellRequest_cancel_never_reverts(uint256 amount, uint256 tokenPrice) public {
        uint256 balance = token.balanceOf(address(this));
        
        // Ensure there is a valid amount of tokens to sell and balance suffices
        if (amount > 0 && balance >= amount) {
            // Approve the exchange to handle `amount` tokens
            try token.approve(address(_Exchange), amount) {
                // Approval did not revert
            } catch {
                assert(false); // Should never fail
            }

            // Check the allowance is set correctly
            assert(token.allowance(address(this), address(_Exchange)) >= amount);

            // Ensure no existing request is active
            (,,,,Exchange.RequestTypes TYPE) = _Exchange.Requests(address(this));
            if (TYPE == Exchange.RequestTypes.NONE && tokenPrice > 0) {
                // Try to create a sell request
                try _Exchange.sellRequest(address(token), amount, tokenPrice) {
                    // Request did not revert
                } catch {
                    assert(false); // Should never fail
                }

                // Validate the state of the new request
                (address tokenAddress,,uint256 _amount,uint256 _tokenPrice,Exchange.RequestTypes newTYPE) = _Exchange.Requests(address(this));
                assert(tokenAddress == address(token));
                assert(_amount == amount);
                assert(_tokenPrice == tokenPrice);
                assert(newTYPE == Exchange.RequestTypes.SELL);

                // Check balance adjustment after sale
                uint256 tmp = balance;
                balance = token.balanceOf(address(this));
                assert(tmp - balance == amount);

                // Attempt to cancel the request
                try _Exchange.cancelRequest() {
                    // Cancel did not revert
                } catch {
                    assert(false); // Should never fail
                }

                // Verify request cancellation
                (,,,,Exchange.RequestTypes afterTYPE) = _Exchange.Requests(address(this));
                assert(afterTYPE == Exchange.RequestTypes.NONE);
                assert(tmp == token.balanceOf(address(this))); // Balance should revert to original after cancellation
            }
        }
    }

    /**
     * @notice Test that ensures 'buyRequest' and 'cancelRequest' on the Exchange do not revert unexpectedly
     * @param amount The amount of tokens to buy
     * @param tokenPrice The price of the token in Ether
     */
    function buyRequest_cancel_never_reverts(uint256 amount, uint256 tokenPrice) public payable {
        // Ensure no existing request is active
        (,,,,Exchange.RequestTypes TYPE) = _Exchange.Requests(address(this));
        
        // Conditions to initiate a buy request
        if (amount > 0 && tokenPrice > 0 && msg.value >= tokenPrice * amount && TYPE == Exchange.RequestTypes.NONE) {
            // Try to create a buy request
            try _Exchange.buyRequest{value: tokenPrice * amount}(address(token), amount, tokenPrice) {
                // Request did not revert
            } catch {
                assert(false); // Should never fail
            }

            // Validate the state of the new request
            (address tokenAddress,,uint256 _amount,uint256 _tokenPrice,Exchange.RequestTypes newTYPE) = _Exchange.Requests(address(this));
            assert(tokenAddress == address(token));
            assert(_amount == amount);
            assert(_tokenPrice == tokenPrice);
            assert(newTYPE == Exchange.RequestTypes.BUY);

            // Check Ether balance in the Exchange after purchase
            uint256 ethBalance = address(_Exchange).balance;
            assert(ethBalance == tokenPrice * amount);

            // Attempt to cancel the request
            try _Exchange.cancelRequest() {
                // Cancel did not revert
            } catch {
                assert(false); // Should never fail
            }

            // Verify request cancellation
            (,,,,Exchange.RequestTypes afterTYPE) = _Exchange.Requests(address(this));
            assert(afterTYPE == Exchange.RequestTypes.NONE);
            assert(address(_Exchange).balance == 0); // Balance should revert to zero after cancellation
        }
    }
}

    



/*
contract TestExchangeExternal is Exchange{
    ERC20 private Token;
    constructor() Exchange(msg.sender){
    }
    //tests for initiateOwnershipTransfer 
    function echidna_test_initiateOwnershipTransfer() public view returns (bool) {
        if(contractOwner == address(0)){
            return false;
        }
        return true;
    }

    function echidna_test_reentrancy() public returns (bool) {
        address tokenAddress = address(1); // Dummy address for testing
        uint256 amount = 1 ether;
        uint256 price = 100;

        // Trying to invoke reentrant calls
        try this.sellRequest(tokenAddress, amount, price) {
            return false; // Should not allow reentrant calls
        } catch {
            return duringOperation[tokenAddress] == false; // State should remain secure
        }
    }
    /*function echidna_initiateOwnershipTransfer(address nextContractOwner) public returns (bool) {
        if (nextContractOwner != address(0)) {
            try _Exchange.initiateOwnershipTransfer(nextContractOwner) {
                address _nextContractOwner =  _Exchange.nextContractOwner();
                if(_nextContractOwner == nextContractOwner){
                    return true; 
                }else{
                    return false; 
                }
            } catch {
                return false; 
            }
        }else{
            try _Exchange.initiateOwnershipTransfer(nextContractOwner) {
                return false; 
            } catch {
                return true; 
            }
        }
    }

    //tests for claimTokenOwnership

    function echidna_sellRequest(uint256 tradeAmount,uint256 coinPrice, string memory _name, string memory _symbol, uint8 _decimals, uint256 _maxSupply) public returns (bool) {
        Token = new ERC20(msg.sender, _name, _symbol, _decimals, _maxSupply);
        Token.mint(msg.sender, tradeAmount);
        Token.approve(address(_Exchange), tradeAmount);
        (,,,,Exchange.RequestTypes TYPE) = _Exchange.Requests(msg.sender);
        if(tradeAmount == 0 || coinPrice == 0 || (TYPE != Exchange.RequestTypes.NONE)){
            try _Exchange.sellRequest(address(Token),tradeAmount,coinPrice) {
                return false;
            } catch {
                return true; 
            }
        }else{
            try _Exchange.sellRequest(address(Token),tradeAmount,coinPrice) {
                (address tokenAddress,, uint256 amount, uint256 tokenPrice, Exchange.RequestTypes newTYPE) = _Exchange.Requests(msg.sender);
                echidna_cancelRequest();
                if(tokenAddress == address(Token) && amount == tradeAmount && tokenPrice == coinPrice && newTYPE == Exchange.RequestTypes.SELL){
                    return true;
                }else{
                    return false;
                }
            } catch {
                return false; 
            }
        }
    }

    function echidna_cancelRequest() public returns (bool){
        _Exchange.cancelRequest();
        (,,,,Exchange.RequestTypes TYPE) = _Exchange.Requests(msg.sender);
        if(TYPE != Exchange.RequestTypes.NONE){
            try  _Exchange.cancelRequest() {
                (,,,,Exchange.RequestTypes newTYPE) = _Exchange.Requests(msg.sender);
                if(newTYPE == Exchange.RequestTypes.NONE){
                    return true;
                }else{
                    return false;
                }
            } catch {
                return false; 
            }
        }else{
            try  _Exchange.cancelRequest() {
                return false;
            } catch {
                return true; 
            }
        }
    }*/

