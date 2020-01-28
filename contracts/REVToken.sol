pragma solidity >=0.5.16;

import './ERC20.sol';
import './DSStop.sol';

contract REVToken is ERC20, DSStop {
    bytes32  public  symbol;
    bytes32  public  name = '';
    uint256  public  decimals = 18;

    constructor(bytes32 symbol_) public {
        symbol = symbol_;
    }

    function setName(bytes32 name_) public auth {
        name = name_;
    }

    function approve(address spender) public stoppable returns (bool) {
        return super.approve(spender, uint(-1));
    }

    function approve(address spender, uint amount) public stoppable returns (bool) {
        return super.approve(spender, amount);
    }

    function transferFrom(address sender, address recipient, uint amount) public stoppable returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address account, uint amount) public auth stoppable {
        _mint(account, amount);
    }

    function burn(address account, uint amount) public auth stoppable {
        _burn(account, amount);
    }
}
