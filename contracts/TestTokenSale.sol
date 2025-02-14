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

pragma solidity >=0.6.0 <0.8.0;

import './TokenSale.sol';
import './Creator.sol';

contract TestTokenSale is TokenSale {
    constructor (Creator creator) TokenSale(creator) {}

    function windowDuration() public override pure returns (uint) {
        return 10;
    }

    function setCreatePerFirstPeriod(uint _createPerFirstWindow) public onlyOwner {
        createPerFirstWindow = _createPerFirstWindow;
    }

    function setCreatePerOtherPeriod(uint _createPerOtherWindow) public onlyOwner {
        createPerOtherWindow = _createPerOtherWindow;
    }
}
