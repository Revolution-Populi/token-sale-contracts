pragma solidity ^0.6.0;

import './ERC20.sol';
import './PausableWithException.sol';

contract REVToken is ERC20, PausableWithException {
    bytes32  public  symbol;
    bytes32  public  name = '';
    uint256  public  decimals = 18;

    constructor(bytes32 symbol_) public {
        symbol = symbol_;
    }

    function setName(bytes32 name_) public onlyOwner {
        name = name_;
    }

    function pause() public onlyOwner {
        super._pause();
    }

    function unpause() public onlyOwner {
        super._unpause();
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused withPausableException returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address account, uint amount) public onlyOwner whenNotPaused {
        _mint(account, amount);
    }

    function burn(address account, uint amount) public onlyOwner {
        _burn(account, amount);
    }
}
