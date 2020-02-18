pragma solidity ^0.6.0;

import './Ownable.sol';

contract DSStop is Ownable {
    bool public stopped;

    modifier stoppable {
        require(!stopped, "ds-stop-is-stopped");
        _;
    }

    function stop() public onlyOwner {
        stopped = true;
    }

    function start() public onlyOwner {
        stopped = false;
    }
}
