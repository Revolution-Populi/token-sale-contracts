// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.6.0;

import './TestPeriodicAllocation.sol';
import './Creator.sol';
import './REVToken.sol';

contract TestCreator is Creator {
    function createPeriodicAllocation(REVToken _token) external returns (PeriodicAllocation) {
        PeriodicAllocation allocation = new TestPeriodicAllocation(_token);
        allocation.transferOwnership(msg.sender);

        return allocation;
    }
}
