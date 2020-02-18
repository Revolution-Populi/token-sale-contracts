pragma solidity ^0.6.0;

import './Ownable.sol';
import './DSNote.sol';

contract DSStop is DSNote, Ownable {
    bool public stopped;

    modifier stoppable {
        require(!stopped, "ds-stop-is-stopped");
        _;
    }

    function stop() public auth note {
        stopped = true;
    }

    function start() public auth note {
        stopped = false;
    }
}
