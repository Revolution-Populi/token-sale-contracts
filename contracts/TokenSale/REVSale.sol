pragma solidity >=0.5.16;

import '../DS/DSAuth.sol';
import '../DS/DSExec.sol';
import '../Token/REVToken.sol';
import '../SafeMath.sol';
import './Creator.sol';

contract REVSale is DSAuth, DSExec {
    using SafeMath for uint256;

    uint constant MIN_ETH = 1 ether;
    uint constant FIRST_WINDOW_MULTIPLIER = 3; // 3 times more tokens are sold during window 1
    uint constant WINDOW_DURATION = 23 hours;

    uint constant MARKETING_SHARE = 250000000 ether;
    uint constant RESERVE_SHARE = 200000000 ether;
    uint constant REVPOP_FOUNDATION_SHARE = 200000000 ether;
    uint constant REVPOP_FOUNDATION_PERIOD_LENGTH = 365 days;
    uint constant REVPOP_FOUNDATION_PERIODS = 10; // 10 years
    uint constant REVPOP_COMPANY_SHARE = 200000000 ether;
    uint constant REVPOP_COMPANY_PERIOD_LENGTH = 365 days;
    uint constant REVPOP_COMPANY_PERIODS = 10; // 10 years

    address[6] public wallets = [
        // RevPop.org foundation
        0x049A9f8C12c23C0549b73960748645403DC443e3,

        // RevPop the company
        0x7bE0166D691fdDf4e5f0E50Cdd9Ab0666Ef8b41d,

        // Marketing
        0xF2fb97fBF0B2Ad0830F7C2B9C73F0648BB5340E4,

        // Reserve currency
        0x0f02A52EbeFcce7104fc82B68756f4edC640523C,

        // Bulk purchase account
        0x713F6b1C608784312974e6Fa4e03BdBac1748B01,

        // Unsold tokens taker
        0x97000D1a83E3cd519308B444a21eCE69f4414658
    ];

    REVToken public REV;                   // The REV token itself
    PeriodicAllocation public periodicAllocation;

    uint public totalSupply;           // Total REV amount created

    uint public firstWindowStartTime;  // Time of window 1 opening
    uint public createPerFirstWindow;  // Tokens sold in window 1

    uint public otherWindowsStartTime; // Time of other windows opening
    uint public numberOfOtherWindows;  // Number of other windows
    uint public createPerOtherWindow;  // Tokens sold in each window after window 1

    uint public totalBoughtTokens;
    uint public totalRaisedETH;

    mapping(uint => uint) public dailyTotals;
    mapping(uint => mapping(address => uint)) public userBuys;
    mapping(uint => mapping(address => bool)) public claimed;

    event LogInit (
        uint tokensToSell,
        uint firstWindowDuration,
        uint otherWindowDuration,
        uint totalWindowDuration,
        uint createPerFirstWindow,
        uint createPerOtherWindow
    );

    event LogBuy      (uint window, address indexed user, uint amount);
    event LogClaim    (uint window, address indexed user, uint amount);
    event LogCollect  (uint amount);
    event LogFreeze   ();

    constructor(Creator creator) public {
        REV = creator.createToken();

        require(REV.owner() == address(this), "Invalid owner of the REVToken");
        require(REV.authority() == DSAuthority(0), "Invalid authority of the REVToken");
        require(REV.totalSupply() == 0, "Total supply of REVToken should be 0");

        periodicAllocation = creator.createPeriodicAllocation();

        require(periodicAllocation.owner() == address(this), "Invalid owner of the PeriodicAllocation");
        require(periodicAllocation.authority() == DSAuthority(0), "Invalid authority of the PeriodicAllocation");
        require(periodicAllocation.unlockStart() == 0, "PeriodAllocation.unlockStart should be 0");
    }

    function initialize(
        uint _totalSupply,
        uint _firstWindowStartTime,
        uint _otherWindowsStartTime,
        uint _numberOfOtherWindows,
        uint _bulkPurchaseTokens
    ) public auth {
        require(_totalSupply > 0, "_totalSupply should be > 0");
        require(_firstWindowStartTime < _otherWindowsStartTime, "_firstWindowStartTime should be < _otherWindowsStartTime");
        require(_numberOfOtherWindows > 0, "_numberOfOtherWindows should be > 0");
        require(_bulkPurchaseTokens <= _totalSupply, "_bulkPurchaseTokens should be <= _totalSupply");

        numberOfOtherWindows = _numberOfOtherWindows;
        totalSupply = _totalSupply;
        firstWindowStartTime = _firstWindowStartTime;
        otherWindowsStartTime = _otherWindowsStartTime;

        REV.mint(address(this), totalSupply);

        uint tokensToSell = totalSupply
            .sub(_bulkPurchaseTokens)
            .sub(MARKETING_SHARE)
            .sub(RESERVE_SHARE)
            .sub(REVPOP_COMPANY_SHARE)
            .sub(REVPOP_FOUNDATION_SHARE);

        uint firstWindowDuration = otherWindowsStartTime.sub(firstWindowStartTime);
        uint otherWindowDuration = numberOfOtherWindows.mul(WINDOW_DURATION);
        uint totalWindowDuration = otherWindowDuration.add(firstWindowDuration);

        createPerFirstWindow = tokensToSell.div(totalWindowDuration).mul(FIRST_WINDOW_MULTIPLIER).mul(firstWindowDuration);
        createPerOtherWindow = tokensToSell.sub(createPerFirstWindow).div(otherWindowDuration);

        REV.transfer(address(periodicAllocation), REVPOP_COMPANY_SHARE.add(REVPOP_FOUNDATION_SHARE));
        REV.transfer(wallets[2], MARKETING_SHARE);
        REV.transfer(wallets[3], RESERVE_SHARE);

        if (_bulkPurchaseTokens > 0) {
            REV.transfer(wallets[4], _bulkPurchaseTokens);
        }

        periodicAllocation.addShare(wallets[0], 50, REVPOP_FOUNDATION_PERIODS, REVPOP_FOUNDATION_PERIOD_LENGTH);
        periodicAllocation.addShare(wallets[1], 50, REVPOP_COMPANY_PERIODS, REVPOP_COMPANY_PERIOD_LENGTH);
        periodicAllocation.setUnlockStart(time());

        emit LogInit(
            tokensToSell,
            firstWindowDuration,
            otherWindowDuration,
            totalWindowDuration,
            createPerFirstWindow,
            createPerOtherWindow
        );
    }

    function time() public view returns (uint) {
        return block.timestamp;
    }

    function today() public view returns (uint) {
        return windowFor(time());
    }

    // Each window is WINDOW_DURATION (23 hours) long so that end-of-window rotates
    // around the clock for all timezones.
    function windowFor(uint timestamp) public view returns (uint) {
        return timestamp < otherWindowsStartTime
        ? 0
        : timestamp.sub(otherWindowsStartTime).div(WINDOW_DURATION).add(1);
    }

    function createOnWindow(uint window) public view returns (uint) {
        return window == 0 ? createPerFirstWindow : createPerOtherWindow;
    }

    function shouldBeBoughtTotalTokensBeforeWindow(uint window) public view returns (uint) {
        require(window > 0, "window should be > 0");

        uint beforeWindow = window - 1;

        return beforeWindow == 0 ? createPerFirstWindow : createPerOtherWindow.mul(beforeWindow).add(createPerFirstWindow);
    }

    function unsoldTokensBeforeWindow(uint window) public view returns (uint) {
        return shouldBeBoughtTotalTokensBeforeWindow(window).sub(totalBoughtTokens);
    }

    // This method provides the buyer some protections regarding which
    // day the buy order is submitted and the maximum price prior to
    // applying this payment that will be allowed.
    function buyWithLimit(uint window, uint limit) public payable {
        require(time() >= firstWindowStartTime, "time() should be >= firstWindowStartTime");
        require(today() <= numberOfOtherWindows, "today() should be <= numberOfOtherWindows");
        require(msg.value >= MIN_ETH, "msg.value should be >= MIN_ETH");
        require(window >= today(), "window should be >= today()");
        require(window <= numberOfOtherWindows, "window should be <= numberOfOtherWindows");

        userBuys[window][msg.sender] += msg.value;
        dailyTotals[window] += msg.value;

        // @TODO: should this condition be performed before dailyTotals is updated?
        if (limit != 0) {
            require(dailyTotals[window] <= limit, "dailyTotals[window] should be <= limit");
        }

        emit LogBuy(window, msg.sender, msg.value);
    }

    function buy() public payable {
        buyWithLimit(today(), 0);
    }

    function() external payable {
        buy();
    }

    function claim(uint window) public {
        require(today() > window, "today() should be > window");

        if (claimed[window][msg.sender] || dailyTotals[window] == 0) {
            return;
        }

        uint256 dailyTotal = dailyTotals[window];
        uint256 userTotal = userBuys[window][msg.sender];
        uint256 price = createOnWindow(window).div(dailyTotal);
        uint256 reward = price.mul(userTotal);

        claimed[window][msg.sender] = true;

        REV.transfer(msg.sender, reward);

        emit LogClaim(window, msg.sender, reward);
    }

    function claimAll() public {
        for (uint i = 0; i < today(); i++) {
            claim(i);
        }
    }

    // Crowdsale owners can collect ETH any number of times
    function collect() public auth {
        require(today() > 0, "today() should be > 0");
        // Prevent recycling during window 0
        exec(msg.sender, address(this).balance);
        emit LogCollect(address(this).balance);
    }

    function collectUnsoldTokens(uint window) public auth {
        require(today() > 0, "today() should be > 0");
        require(window > 0, "window should be > 0");
        require(window < today(), "window should be < today()");

        uint unsoldTokens = unsoldTokensBeforeWindow(window);

        if (unsoldTokens > 0) {
            REV.transfer(wallets[5], unsoldTokens);
        }
    }
}
