pragma solidity >=0.5.16;

import './DSAuth.sol';
import './DSExec.sol';
import './REVToken.sol';
import './SafeMath.sol';
import './Creator.sol';

contract REVSale is DSAuth, DSExec {
    using SafeMath for uint256;

    uint constant MIN_ETH = 1 ether;
    uint constant FIRST_WINDOW_MULTIPLIER = 3; // 3 times more tokens are sold during window 1
    uint constant WINDOW_DURATION = 24 hours; // @TODO: 23 hours?

    REVToken public REV;                   // The REV token itself
    uint     public totalSupply;           // Total REV amount created

    uint     public firstWindowStartTime;  // Time of window 1 opening
    uint     public createPerFirstWindow;  // Tokens sold in window 1

    uint     public otherWindowsStartTime; // Time of other windows opening
    uint     public numberOfOtherWindows;  // Number of other windows
    uint     public createPerOtherWindow;  // Tokens sold in each window after window 1

    uint     public totalBoughtTokens;
    uint     public totalRaisedETH;

    mapping(uint => uint)                      public  dailyTotals;
    mapping(uint => mapping(address => uint))  public  userBuys;
    mapping(uint => mapping(address => bool))  public  claimed;

    event LogInit (
        uint tokensToSell,
        uint checksum,
        uint firstWindowDuration,
        uint otherWindowDuration,
        uint totalWindowDuration,
        uint createPerFirstWindow,
        uint createPerOtherWindow
    );

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
        uint _totalSupply,
        uint _firstWindowStartTime,
        uint _otherWindowsStartTime,
        uint _numberOfOtherWindows,
        uint _bulkPurchaseTokens,
        address _bulkPurchaseAddress
    ) public auth {
        require(_totalSupply > 0, "_totalSupply should be > 0");
        require(_firstWindowStartTime < _otherWindowsStartTime, "_firstWindowStartTime should be < _otherWindowsStartTime");
        require(_numberOfOtherWindows > 0, "_numberOfOtherWindows should be > 0");
        require(_bulkPurchaseTokens <= _totalSupply, "_bulkPurchaseTokens should be <= _totalSupply");
        require(_bulkPurchaseAddress != address(0x0), "_bulkPurchaseAddress is invalid");

        numberOfOtherWindows = _numberOfOtherWindows;
        totalSupply = _totalSupply;
        firstWindowStartTime = _firstWindowStartTime;
        otherWindowsStartTime = _otherWindowsStartTime;

        REV.mint(address(this), totalSupply);

        uint tokensToSell = totalSupply.sub(_bulkPurchaseTokens);
        uint firstWindowDuration = otherWindowsStartTime.sub(firstWindowStartTime);
        uint otherWindowDuration = numberOfOtherWindows.mul(WINDOW_DURATION);
        uint totalWindowDuration = otherWindowDuration.add(firstWindowDuration);

        createPerFirstWindow = tokensToSell.div(totalWindowDuration).mul(FIRST_WINDOW_MULTIPLIER).mul(firstWindowDuration);
        createPerOtherWindow = tokensToSell.sub(createPerFirstWindow).div(otherWindowDuration);

        uint checksum = createPerOtherWindow.mul(otherWindowDuration).add(createPerFirstWindow).add(_bulkPurchaseTokens);

        // require(checksum == totalSupply, "Checksum failed");

        if (_bulkPurchaseTokens > 0) {
            REV.transfer(_bulkPurchaseAddress, _bulkPurchaseTokens);
        }

        emit LogInit(
            tokensToSell,
            checksum,
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

    function collectUnsoldTokens(uint window, address recepient) public auth {
        require(today() > 0, "today() should be > 0");
        require(window > 0, "window should be > 0");
        require(window < today(), "window should be < today()");

        uint unsoldTokens = unsoldTokensBeforeWindow(window);

        if (unsoldTokens > 0) {
            REV.transfer(recepient, unsoldTokens);
        }
    }
}
