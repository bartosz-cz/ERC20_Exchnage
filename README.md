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

### Core Components

- `contractOwner` and `nextContractOwner`: Manage current and prospective contract ownership.
- `UserRequest`: Struct that stores details about user requests.
- `Requests`: A mapping to keep track of each user's requests.
- `sellRequestants` and `buyRequestants`: Track users interested in selling or buying tokens.

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
