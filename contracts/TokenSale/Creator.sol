pragma solidity >=0.5.16;

import '../Token/REVToken.sol';
import './PeriodicAllocation.sol';

contract Creator {
    REVToken public token = new REVToken('REV');
    PeriodicAllocation public periodicAllocation;

    function createToken() external returns (REVToken) {
        token.setOwner(msg.sender);

        return token;
    }

    function createPeriodicAllocation() external returns (PeriodicAllocation) {
        periodicAllocation = new PeriodicAllocation(token);
        periodicAllocation.setOwner(msg.sender);

        return periodicAllocation;
    }
}
