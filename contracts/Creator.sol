pragma solidity >=0.5.16;

import './REVToken.sol';

contract Creator {
    REVToken public token = new REVToken('REV');

    function createToken() external returns (REVToken) {
        token.setOwner(msg.sender);

        return token;
    }
}
