pragma solidity >=0.4.21 <0.7.0;

import './DSAuth.sol';
import './DSNote.sol';

contract DSStop is DSAuth, DSNote {

    bool public stopped;

    modifier stoppable {
        assert (!stopped);
        _;
    }
    function stop() auth note {
        stopped = true;
    }
    function start() auth note {
        stopped = false;
    }

}
