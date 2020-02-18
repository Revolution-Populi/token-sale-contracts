pragma solidity ^0.6.0;

import './Ownable.sol';
import './REVToken.sol';
import './SafeMath.sol';

contract PeriodicAllocation is Ownable {
    using SafeMath for uint256;

    struct Share {
        uint256 proportion;
        uint256 periods;
        uint256 periodLength;
    }

    uint256 public unlockStart;
    uint256 public totalShare;

    mapping(address => Share) public shares;
    mapping(address => uint256) public unlocked;

    REVToken public token;

    constructor(REVToken _token) public {
        token = _token;
    }

    function setUnlockStart(uint256 _unlockStart) onlyOwner external {
        require(unlockStart == 0, "unlockStart should be == 0");
        require(_unlockStart >= now, "_unlockStart should be >= now");

        unlockStart = _unlockStart;
    }

    function addShare(address _beneficiary, uint256 _proportion, uint256 _periods, uint256 _periodLength) onlyOwner external {
        shares[_beneficiary] = Share(shares[_beneficiary].proportion.add(_proportion),_periods,_periodLength);
        totalShare = totalShare.add(_proportion);
    }

    // If the time of freezing expired will return the funds to the owner.
    function unlockFor(address _owner) public {
        require(unlockStart > 0, "unlockStart should be > 0");
        require(
            now >= (unlockStart.add(shares[_owner].periodLength)),
            "block.timestamp should be >= (unlockStart.add(shares[_owner].periodLength))"
        );

        uint256 share = shares[_owner].proportion;
        uint256 periodsSinceUnlockStart = (now.sub(unlockStart)).div(shares[_owner].periodLength);

        if (periodsSinceUnlockStart < shares[_owner].periods) {
            share = share.div(shares[_owner].periods).mul(periodsSinceUnlockStart);
        }

        share = share.sub(unlocked[_owner]);

        if (share > 0) {
            uint256 unlockedToken = token.balanceOf(address(this)).mul(share).div(totalShare);
            totalShare = totalShare.sub(share);
            unlocked[_owner] += share;
            token.transfer(_owner,unlockedToken);
        }
    }
}