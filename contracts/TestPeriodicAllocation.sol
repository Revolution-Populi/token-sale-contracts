// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import './PeriodicAllocation.sol';
import './REVToken.sol';

contract TestPeriodicAllocation is PeriodicAllocation {
    constructor(REVToken _token) public PeriodicAllocation(_token) { }

    function setUnlockStart(uint256 _unlockStart) external override onlyOwner {
        unlockStart = _unlockStart;
    }
}
