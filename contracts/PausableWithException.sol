pragma solidity ^0.6.0;

import "./Pausable.sol";
import "./Ownable.sol";

contract PausableWithException is Pausable, Ownable {
    mapping(address => bool) public exceptions;

    modifier withPausableException() {
        require(!hasException(_msgSender()), "exceptions[msg.sender] should be == true");

        _;
    }

    function hasException(address _account) public view returns (bool) {
        return exceptions[_account] == true;
    }

    function setPausableException(address _account, bool _status) external whenNotPaused onlyOwner {
        exceptions[_account] = _status;
    }
}
