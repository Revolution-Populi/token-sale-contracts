// Copyright (c) 2019-2020 revolutionpopuli.com

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// SPDX-License-Identifier: GPL-3.0-only

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

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPausedWithoutException returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address account, uint amount) public onlyOwner whenNotPaused {
        _mint(account, amount);
    }

    function burn(address account, uint amount) public onlyOwner {
        _burn(account, amount);
    }
}
