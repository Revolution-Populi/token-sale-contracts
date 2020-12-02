// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import './REVSale.sol';
import './Creator.sol';

contract TestREVSale is REVSale {
    constructor (Creator creator) REVSale(creator) public {

    }

    function windowDuration() public override pure returns (uint) {
        return 10;
    }

    function setCreatePerFirstPeriod(uint _createPerFirstWindow) public onlyOwner {
        createPerFirstWindow = _createPerFirstWindow;
    }

    function setCreatePerOtherPeriod(uint _createPerOtherWindow) public onlyOwner {
        createPerOtherWindow = _createPerOtherWindow;
    }
}
