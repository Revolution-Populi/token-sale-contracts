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

import './Ownable.sol';
import './Token.sol';
import './SafeMath.sol';
import './SafeERC20.sol';

contract TokenEscrow is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for Token;

    struct Share {
        uint256 proportion;
        uint256 periods;
        uint256 periodLength;
    }

    uint256 public unlockStart;
    uint256 public totalShare;

    mapping(address => Share) public shares;
    mapping(address => uint256) public unlocked;

    Token public token;

    constructor(Token _token) {
        token = _token;
    }

    function setUnlockStart(uint256 _unlockStart) external virtual onlyOwner {
        require(unlockStart == 0, "unlockStart should be == 0");
        require(_unlockStart >= block.timestamp, "_unlockStart should be >= block.timestamp");

        unlockStart = _unlockStart;
    }

    function addShare(address _beneficiary, uint256 _proportion, uint256 _periods, uint256 _periodLength) external onlyOwner {
        shares[_beneficiary] = Share(shares[_beneficiary].proportion.add(_proportion),_periods,_periodLength);
        totalShare = totalShare.add(_proportion);
    }

    // If the time of freezing expired will return the funds to the owner.
    function unlockFor(address _beneficiary) public {
        require(unlockStart > 0, "unlockStart should be > 0");
        require(
            block.timestamp >= (unlockStart.add(shares[_beneficiary].periodLength)),
            "block.timestamp should be >= (unlockStart.add(shares[_beneficiary].periodLength))"
        );

        uint256 share = shares[_beneficiary].proportion;
        uint256 periodsSinceUnlockStart = ((block.timestamp).sub(unlockStart)).div(shares[_beneficiary].periodLength);

        if (periodsSinceUnlockStart < shares[_beneficiary].periods) {
            share = share.mul(periodsSinceUnlockStart).div(shares[_beneficiary].periods);
        }

        share = share.sub(unlocked[_beneficiary]);

        if (share > 0) {
            unlocked[_beneficiary] = unlocked[_beneficiary].add(share);
            uint256 unlockedToken = token.balanceOf(address(this)).mul(share).div(totalShare);
            totalShare = totalShare.sub(share);
            token.safeTransfer(_beneficiary,unlockedToken);
        }
    }
}
