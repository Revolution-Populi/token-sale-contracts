pragma solidity >=0.5.16;

import './DSAuth.sol';
import './DSExec.sol';
import './REVToken.sol';
import './SafeMath.sol';
import './Creator.sol';

contract REVSale is DSAuth, DSExec {
    using SafeMath for uint256;

    REVToken public  REV;                  // The REV token itself
    uint     public  totalSupply;          // Total REV amount created
    uint     public  foundersAllocation;   // Amount given to founders
    string   public  foundersKey;          // Public key of founders

    uint     public  openTime;             // Time of window 0 opening
    uint     public  createFirstDay;       // Tokens sold in window 0

    uint     public  startTime;            // Time of window 1 opening
    uint     public  numberOfDays;         // Number of windows after 0
    uint     public  createPerDay;         // Tokens sold in each window

    uint     public  totalBoughtTokens;
    uint     public  totalRaisedETH;

    mapping(uint => uint)                      public  dailyTotals;
    mapping(uint => mapping(address => uint))  public  userBuys;
    mapping(uint => mapping(address => bool))  public  claimed;

    event LogBuy      (uint window, address user, uint amount);
    event LogClaim    (uint window, address user, uint amount);
    event LogCollect  (uint amount);
    event LogFreeze   ();

    constructor(Creator creator) public {
        REV = creator.createToken();

        require(REV.owner() == address(this), "Invalid owner of the REVToken");
        require(REV.authority() == DSAuthority(0), "Invalid authority of the REVToken");
        require(REV.totalSupply() == 0, "Total supply of REVToken should be 0");
    }

    function initialize(
        uint _numberOfDays,
        uint _totalSupply,
        uint _openTime,
        uint _startTime,
        uint _foundersAllocation,
        string memory _foundersKey
    ) public auth {
        require(numberOfDays > 0, "numberOfDays should be > 0");
        require(totalSupply > foundersAllocation, "totalSupply should be > foundersAllocation");
        require(openTime < startTime, "openTime should be < startTime");

        numberOfDays = _numberOfDays;
        totalSupply = _totalSupply;
        openTime = _openTime;
        startTime = _startTime;
        foundersAllocation = _foundersAllocation;
        foundersKey = _foundersKey;

        createFirstDay = totalSupply.mul(0.2 ether);
        createPerDay = (totalSupply.sub(foundersAllocation).sub(createFirstDay)).div(numberOfDays);

        REV.mint(address(this), totalSupply);
    }

    function time() public view returns (uint) {
        return block.timestamp;
    }

    function today() public view returns (uint) {
        return dayFor(time());
    }

    // Each window is 23 hours long so that end-of-window rotates
    // around the clock for all timezones.
    function dayFor(uint timestamp) public view returns (uint) {
        return timestamp < startTime
        ? 0
        : timestamp.sub(startTime) / 23 hours + 1;
    }

    function createOnDay(uint day) public view returns (uint) {
        return day == 0 ? createFirstDay : createPerDay;
    }

    // This method provides the buyer some protections regarding which
    // day the buy order is submitted and the maximum price prior to
    // applying this payment that will be allowed.
    function buyWithLimit(uint day, uint limit) public payable {
        assert(time() >= openTime && today() <= numberOfDays);
        assert(msg.value >= 0.01 ether);

        assert(day >= today());
        assert(day <= numberOfDays);

        userBuys[day][msg.sender] += msg.value;
        dailyTotals[day] += msg.value;

        if (limit != 0) {
            assert(dailyTotals[day] <= limit);
        }

        emit LogBuy(day, msg.sender, msg.value);
    }

    function buy() public payable {
        buyWithLimit(today(), 0);
    }

    function() external payable {
        buy();
    }

    function claim(uint day) public {
        assert(today() > day);

        if (claimed[day][msg.sender] || dailyTotals[day] == 0) {
            return;
        }

        uint256 dailyTotal = dailyTotals[day];
        uint256 userTotal = userBuys[day][msg.sender];
        uint256 price = createOnDay(day).div(dailyTotal);
        uint256 reward = price.mul(userTotal);

        claimed[day][msg.sender] = true;

        REV.transfer(msg.sender, reward);

        emit LogClaim(day, msg.sender, reward);
    }

    function claimAll() public {
        for (uint i = 0; i < today(); i++) {
            claim(i);
        }
    }

    // Crowdsale owners can collect ETH any number of times
    function collect() public auth {
        assert(today() > 0);
        // Prevent recycling during window 0
        exec(msg.sender, address(this).balance);
        emit LogCollect(address(this).balance);
    }
}
