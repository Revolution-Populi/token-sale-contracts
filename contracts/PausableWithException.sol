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

import './Pausable.sol';
import './Ownable.sol';

contract PausableWithException is Pausable, Ownable {
    mapping(address => bool) public exceptions;

    modifier whenNotPaused() override {
        require(!paused() || hasException(_msgSender()), "Pausable: paused (and no exception)");

        _;
    }

    modifier whenNotPausedWithoutException() {
        require(!paused(), "Pausable: paused");

        _;
    }

    function hasException(address _account) public view returns (bool) {
        return exceptions[_account];
    }

    function setPausableException(address _account, bool _status) external whenNotPaused onlyOwner {
        exceptions[_account] = _status;
    }
}
