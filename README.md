# Ethereum Exchange Contract

This repository contains the Solidity smart contract for an Ethereum-based decentralized exchange platform. The `Exchange` contract is designed to handle the trading of ERC20 tokens, manage ownership, and facilitate user requests for buying and selling tokens efficiently and securely.

## Features

- **Dynamic Ownership Management**: Facilitates the transfer of contract ownership securely.
- **Request Handling**: Manages user requests for buying and selling tokens.
- **Token Transactions**: Supports secure and efficient transactions of ERC20 tokens.
- **Reentrancy Protection**: Implements checks to prevent reentrancy attacks, enhancing security in contract operations.

## Contract Structure

The `Exchange` contract incorporates several key elements:

- **Ownership Transfer**: Allows the current owner to propose and execute ownership transfers.
- **Request Management**: Users can initiate buy and sell requests which are managed and matched by the contract.
- **Security Modifiers**: Includes several modifiers to ensure operations are performed by authorized users and under correct conditions.

### Core Functions

The `Exchange` contract provides several functions that users can interact with to manage and execute token transactions:

- **`initiateOwnershipTransfer(address _nextContractOwner)`**: Allows the current contract owner to initiate a transfer of ownership to a new owner. This function sets the `nextContractOwner` who will then need to accept the ownership.

- **`claimTokenOwnership()`**: Used by the new owner to accept ownership of the contract. This function transfers the contract's ownership from the current owner to the new owner set by `initiateOwnershipTransfer`.

- **`sellRequest(address tokenAddress, uint256 amount, uint256 coinPrice)`**: Allows users to create a request to sell a specified amount of tokens at a given price. This function registers the sell request and tries to match it with existing buy requests.

- **`buyRequest(address tokenAddress, uint256 amount, uint256 coinPrice)`**: Similar to `sellRequest`, this function lets users place a request to buy tokens. It takes the token address, the amount of tokens to buy, and the price offered per token. The function locks in the Ether sent with the request and attempts to match with existing sell requests.

- **`cancelRequest()`**: Enables users to cancel their outstanding buy or sell requests. This function checks the type of request and returns the locked tokens or Ether to the user if the request is still unfulfilled.


## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/en/download/) and npm installed.
- [Truffle Suite](https://www.trufflesuite.com/truffle) for compiling and deploying the contract.
- [Ganache](https://www.trufflesuite.com/ganache) for a personal Ethereum blockchain to run tests.

### Installation

Clone this repository and install the necessary dependencies:

```bash
git clone https://github.com/yourusername/exchange-contract.git
cd exchange-contract
npm install
