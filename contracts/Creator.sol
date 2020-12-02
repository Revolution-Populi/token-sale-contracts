// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.6.0;

import './REVToken.sol';
import './PeriodicAllocation.sol';

contract Creator {
    REVToken public token = new REVToken('REV');
    PeriodicAllocation public periodicAllocation;

    function createToken() external returns (REVToken) {
        token.transferOwnership(msg.sender);

        return token;
    }

    function createPeriodicAllocation() external returns (PeriodicAllocation) {
        periodicAllocation = new PeriodicAllocation(token);
        periodicAllocation.transferOwnership(msg.sender);

        return periodicAllocation;
    }
}
