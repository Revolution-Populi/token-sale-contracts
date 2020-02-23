pragma solidity ^0.6.0;

import "./Pausable.sol";
import "./Ownable.sol";

contract PausableWithException is Pausable, Ownable {
    mapping(address => bool) public exceptions;

    modifier whenNotPaused() override {
        require(!paused() || hasException(_msgSender()), "Pausable: paused");

        _;
    }

    modifier whenNotPausedWithoutException() {
        require(!paused() || hasException(_msgSender()), "Pausable: paused");

        _;
    }

    function hasException(address _account) public view returns (bool) {
        return exceptions[_account] == true;
    }

    function setPausableException(address _account, bool _status) external whenNotPaused onlyOwner {
        exceptions[_account] = _status;
    }
}
