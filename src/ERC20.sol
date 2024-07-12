// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;

// Importing the IERC20 interface which defines standard methods for ERC20 tokens.
import "./IERC20.sol";

contract ERC20 is IERC20{
    
    string public name;
    string public symbol;
    uint8 immutable public decimals;
    uint256 public totalSupply;
    uint256 immutable public maxSupply;
    address public tokenOwner;
    address public nextTokenOwner;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenOwnershipTransferStarted(address indexed from, address indexed to);
    event TokenOwnershipTransferFinished(address indexed newTokenOwner);

    modifier sufficientBalance(address _sender, uint256 _amount){
        require(balanceOf[_sender] >= _amount, "Caller does not have sufficient balance");
        _;
    }
    modifier sufficientAllowance(address _sender, uint256 _amount){
        require(allowance[_sender][msg.sender] >= _amount, "Caller does not have sufficient allowance");
        _;
    }
    modifier allowOnly(address _authorized){
        require(msg.sender == _authorized, "Caller is not authorized");
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


    constructor(address _owner, string memory _name, string memory _symbol, uint8 _decimals, uint256 _maxSupply) nonZeroAddress(_owner){
        
        tokenOwner = _owner;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        maxSupply = _maxSupply;
        totalSupply = 0;
    }

    // Function to initiate token ownership transfer, can only be called by current token owner.
    function transferTokenOwnership(address _nextTokenOwner) external 
        allowOnly(tokenOwner)
        nonZeroAddress(_nextTokenOwner)
        returns(bool)
    {
        nextTokenOwner = _nextTokenOwner;
        emit TokenOwnershipTransferStarted(tokenOwner, nextTokenOwner);
        return true;
    }

    // Function to finalize token ownership transfer, can only be called by the new owner
    function claimTokenOwnership() external 
        allowOnly(nextTokenOwner) 
        returns(bool)
    {
        tokenOwner = nextTokenOwner;
        nextTokenOwner = address(0);
        emit TokenOwnershipTransferFinished(tokenOwner);
        return true;
    }

    // Transfer function to move tokens between addresses
    function transfer(address recipient, uint256 amount) external returns(bool) 
    {
        if (amount == 0 || recipient == address(0) || balanceOf[msg.sender] < amount) return false;
        balanceOf[msg.sender]-=amount;
        balanceOf[recipient]+=amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    } 
    
    // TransferFrom function allowing a spender to transfer tokens, subject to approval and balance checks
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool)
    {
        if (amount == 0 || recipient == address(0) || balanceOf[sender] < amount || allowance[sender][msg.sender] < amount) return false;
        allowance[sender][msg.sender]-=amount;
        balanceOf[sender]-=amount;
        balanceOf[recipient]+=amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
    // Approve function enabling an owner to allow another address to spend a specific amount of tokens.
    function approve(address spender, uint256 amount) external returns(bool)
    {
        if (amount == 0 || spender == address(0) || balanceOf[msg.sender] < amount) return false;
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // External mint function accessible only by the token owner, used for creating new tokens
    function mint(address to, uint256 amount) external 
        allowOnly(tokenOwner)
        nonZeroAmount(amount)
        nonZeroAddress(to)
    {
        require(totalSupply+amount <= maxSupply);
        _mint(to, amount);
    }

    // External burn function allowing the token owner to destroy tokens, reducing the total supply
    function burn(address from, uint256 amount) external 
        allowOnly(tokenOwner) 
        nonZeroAmount(amount)
        sufficientBalance(from, amount) 
    {
        _burn(from, amount);
    }

    // Internal mint function to increase token supply by creating new tokens.
    function _mint(address to, uint256 amount) internal{
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    // Internal burn function to decrease token supply by destroying existing tokens
    function _burn(address from, uint256 amount) internal{
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}