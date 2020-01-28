pragma solidity >=0.5.16;

import './ERC20.sol';
import './DSStop.sol';

contract DSToken is ERC20, DSStop {

    bytes32  public  symbol;
    uint256  public  decimals = 18; // standard token precision. override to customize

    constructor(bytes32 symbol_) public {
        symbol = symbol_;
    }

    function approve(address guy) public stoppable returns (bool) {
        return super.approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        return super.approve(guy, wad);
    }

    function transferFrom(address src, address dst, uint wad)
    public
    stoppable
    returns (bool)
    {
        return super.transferFrom(src, dst, wad);
    }

    function push(address dst, uint wad) public {
        transferFrom(msg.sender, dst, wad);
    }

    function pull(address src, uint wad) public {
        transferFrom(src, msg.sender, wad);
    }

    function move(address src, address dst, uint wad) public {
        transferFrom(src, dst, wad);
    }

    function mint(uint wad) public {
        mint(msg.sender, wad);
    }

    function burn(uint wad) public {
        burn(msg.sender, wad);
    }

    function mint(address guy, uint wad) public auth stoppable {
        _mint(guy, wad);
    }

    function burn(address guy, uint wad) public auth stoppable {
        _burn(guy, wad);
    }

    // Optional token name
    bytes32   public  name = "";

    function setName(bytes32 name_) public auth {
        name = name_;
    }
}
