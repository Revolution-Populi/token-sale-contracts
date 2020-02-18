pragma solidity ^0.6.0;

import './ERC20.sol';
import './Pausable.sol';

contract REVToken is ERC20, Pausable {
    bytes32  public  symbol;
    bytes32  public  name = '';
    uint256  public  decimals = 18;

    constructor(bytes32 symbol_) public {
        symbol = symbol_;
    }

    function setName(bytes32 name_) public onlyOwner {
        name = name_;
    }

    function transfer(address recipient, uint amount) public override whenNotPaused returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint amount) public override whenNotPaused returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address account, uint amount) public onlyOwner whenNotPaused {
        _mint(account, amount);
    }

    function burn(address account, uint amount) public onlyOwner whenNotPaused {
        _burn(account, amount);
    }
}
