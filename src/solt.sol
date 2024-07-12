// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;

import "./ERC20.sol";

// Base contract for SOLT token
contract solt is ERC20 {
   
    constructor(address _owner, string memory _name, string memory _symbol, uint8 _decimals, uint256 _maxSupply)
        ERC20(_owner, _name, _symbol, _decimals, _maxSupply)
    {
        _mint(_owner, 100*10**_decimals);
    }
}



