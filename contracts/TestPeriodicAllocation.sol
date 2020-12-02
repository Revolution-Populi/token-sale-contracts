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

import './PeriodicAllocation.sol';
import './REVToken.sol';

contract TestPeriodicAllocation is PeriodicAllocation {
    constructor(REVToken _token) public PeriodicAllocation(_token) { }

    function setUnlockStart(uint256 _unlockStart) external override onlyOwner {
        unlockStart = _unlockStart;
    }
}
