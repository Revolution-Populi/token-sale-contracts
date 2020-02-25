pragma solidity ^0.6.0;

import './Ownable.sol';
import './REVToken.sol';
import './SafeMath.sol';
import './Creator.sol';

contract REVSale is Ownable {
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

    address[5] public wallets = [
        // RevPop.org foundation
        0xf0f5409ea22B14a20b12b330BD52a91597efBe8F,

        // RevPop the company
        0xb7D4Ac7FCe988DA56fEf5373A6596a0144aF9924,

        // Marketing
        0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e,

        // Reserve currency
        0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0,

        // Unsold tokens taker
        0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E
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
    uint public totalBulkPurchasedTokens;

    uint public collectedUnsoldTokensBeforeWindow = 0;

    bool public initialized = false;
    bool public distributedShares = false;
    bool public began = false;

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

    event LogBuy           (uint window, address user, uint amount);
    event LogClaim         (uint window, address user, uint amount);
    event LogCollect       (uint amount);
    event LogCollectUnsold (uint amount);
    event LogFreeze        ();

    constructor(Creator creator) public {
        REV = creator.createToken();

        require(REV.owner() == address(this), "Invalid owner of the REVToken");
        require(REV.totalSupply() == 0, "Total supply of REVToken should be 0");

        periodicAllocation = creator.createPeriodicAllocation();

        require(periodicAllocation.owner() == address(this), "Invalid owner of the PeriodicAllocation");
        require(periodicAllocation.unlockStart() == 0, "PeriodAllocation.unlockStart should be 0");

        REV.setPausableException(address(periodicAllocation), true);
        REV.setPausableException(address(this), true);
    }

    function initialize(
        uint _totalSupply,
        uint _firstWindowStartTime,
        uint _otherWindowsStartTime,
        uint _numberOfOtherWindows
    ) public onlyOwner {
        require(initialized == false, "initialized should be == false");
        require(_totalSupply > 0, "_totalSupply should be > 0");
        require(_firstWindowStartTime < _otherWindowsStartTime, "_firstWindowStartTime should be < _otherWindowsStartTime");
        require(_numberOfOtherWindows > 0, "_numberOfOtherWindows should be > 0");

        numberOfOtherWindows = _numberOfOtherWindows;
        totalSupply = _totalSupply;
        firstWindowStartTime = _firstWindowStartTime;
        otherWindowsStartTime = _otherWindowsStartTime;

        REV.mint(address(this), totalSupply);

        initialized = true;
    }

    function distributeShares() public onlyOwner {
        require(initialized == true, "initialized should be == true");
        require(distributedShares == false, "distributedShares should be == false");

        uint tokensToSell = totalSupply
            .sub(totalBulkPurchasedTokens)
            .sub(MARKETING_SHARE)
            .sub(RESERVE_SHARE)
            .sub(REVPOP_COMPANY_SHARE)
            .sub(REVPOP_FOUNDATION_SHARE);

        uint firstWindowDuration = otherWindowsStartTime.sub(firstWindowStartTime);
        uint otherWindowDuration = numberOfOtherWindows.mul(windowDuration());
        uint totalWindowDuration = otherWindowDuration.add(firstWindowDuration);

        createPerFirstWindow = tokensToSell.div(totalWindowDuration).mul(FIRST_WINDOW_MULTIPLIER).mul(firstWindowDuration);
        createPerOtherWindow = tokensToSell.sub(createPerFirstWindow).div(otherWindowDuration);

        REV.transfer(address(periodicAllocation), REVPOP_COMPANY_SHARE.add(REVPOP_FOUNDATION_SHARE));
        REV.transfer(wallets[2], MARKETING_SHARE);
        REV.transfer(wallets[3], RESERVE_SHARE);

        periodicAllocation.addShare(wallets[0], 50, REVPOP_FOUNDATION_PERIODS, REVPOP_FOUNDATION_PERIOD_LENGTH);
        periodicAllocation.addShare(wallets[1], 50, REVPOP_COMPANY_PERIODS, REVPOP_COMPANY_PERIOD_LENGTH);
        periodicAllocation.setUnlockStart(time());

        // We pause all transfers and minting.
        // We allow to use transfer() function ONLY for periodicAllocation contract, 
        // because it is an escrow and it should allow to transfer tokens to a certain party.
        pauseTokenTransfer();

        emit LogInit(
            tokensToSell,
            firstWindowDuration,
            otherWindowDuration,
            totalWindowDuration,
            createPerFirstWindow,
            createPerOtherWindow
        );

        distributedShares = true;
    }

    function begin() public onlyOwner {
        require(distributedShares == true, "distributedShares should be == true");
        require(began == false, "began should be == false");

        began = true;
    }

    function pauseTokenTransfer() public onlyOwner {
        REV.pause();
    }

    function unpauseTokenTransfer() public onlyOwner {
        REV.unpause();
    }

    function burnTokens(address account, uint amount) public onlyOwner {
        REV.burn(account, amount);
    }

    function removePausableException(address _address) public onlyOwner {
        REV.setPausableException(_address, false);
    }

    function setBulkPurchasers(address[] memory _purchasers, uint[] memory _tokens) public onlyOwner {
        require(initialized == true, "initialized should be == true");
        require(distributedShares == false, "distributedShares should be == false");

        uint count = _purchasers.length;

        require(count > 0, "count should be > 0");
        require(count == _tokens.length, "count should be == _tokens.length");

        for (uint i = 0; i < count; i++) {
            require(REV.balanceOf(address(this)) > _tokens[i], "REV.balanceOf(address(this)) should be > _tokens[i]");

            REV.transfer(_purchasers[i], _tokens[i]);
            totalBulkPurchasedTokens = totalBulkPurchasedTokens.add(_tokens[i]);
        }
    }

    function time() internal view returns (uint) {
        return block.timestamp;
    }

    function today() public view returns (uint) {
        return windowFor(time());
    }

    function windowDuration() public virtual pure returns (uint) {
        return WINDOW_DURATION;
    }

    // Each window is windowDuration() (23 hours) long so that end-of-window rotates
    // around the clock for all timezones.
    function windowFor(uint timestamp) public view returns (uint) {
        return timestamp < otherWindowsStartTime
        ? 0
        : timestamp.sub(otherWindowsStartTime).div(windowDuration()).add(1);
    }

    function createOnWindow(uint window) public view returns (uint) {
        return window == 0 ? createPerFirstWindow : createPerOtherWindow;
    }

    // This method provides the buyer some protections regarding which
    // day the buy order is submitted and the maximum price prior to
    // applying this payment that will be allowed.
    function buyWithLimit(uint window, uint limit) public payable {
        require(began == true, "began should be == true");
        require(time() >= firstWindowStartTime, "time() should be >= firstWindowStartTime");
        require(today() <= numberOfOtherWindows, "today() should be <= numberOfOtherWindows");
        require(msg.value >= MIN_ETH, "msg.value should be >= MIN_ETH");
        require(window >= today(), "window should be >= today()");
        require(window <= numberOfOtherWindows, "window should be <= numberOfOtherWindows");

        if (limit != 0) {
            require(dailyTotals[window] <= limit, "dailyTotals[window] should be <= limit");
        }

        userBuys[window][msg.sender] += msg.value;
        dailyTotals[window] += msg.value;
        totalRaisedETH += msg.value;

        emit LogBuy(window, msg.sender, msg.value);
    }

    function buy() public payable {
        buyWithLimit(today(), 0);
    }

    fallback() external payable {
        buy();
    }

    receive() external payable {
        buy();
    }

    function claim(uint window) public {
        require(began == true, "began should be == true");
        require(today() > window, "today() should be > window");

        if (claimed[window][msg.sender] || dailyTotals[window] == 0) {
            return;
        }

        uint256 dailyTotal = dailyTotals[window];
        uint256 userTotal = userBuys[window][msg.sender];
        uint256 price = createOnWindow(window).div(dailyTotal);
        uint256 reward = price.mul(userTotal);

        totalBoughtTokens += reward;

        claimed[window][msg.sender] = true;

        REV.transfer(msg.sender, reward);

        emit LogClaim(window, msg.sender, reward);
    }

    function claimAll() public {
        require(began == true, "began should be == true");

        for (uint i = 0; i < today(); i++) {
            claim(i);
        }
    }

    // Crowdsale owners can collect ETH any number of times
    function collect() public onlyOwner {
        require(began == true, "began should be == true");
        require(today() > 0, "today() should be > 0");
        // Prevent recycling during window 0
        msg.sender.transfer(address(this).balance);

        emit LogCollect(address(this).balance);
    }

    function collectUnsoldTokens(uint window) public onlyOwner {
        require(began == true, "began should be == true");
        require(today() > 0, "today() should be > 0");
        require(window > 0, "window should be > 0");
        require(window <= today(), "window should be <= today()");
        require(window > collectedUnsoldTokensBeforeWindow, "window should be > collectedUnsoldTokensBeforeWindow");

        uint unsoldTokens = 0;

        for (uint i = collectedUnsoldTokensBeforeWindow; i < window; i++) {
            uint dailyTotal = dailyTotals[i];

            if (dailyTotal == 0) {
                unsoldTokens += i == 0 ? createPerFirstWindow : createPerOtherWindow;
            }
        }

        if (unsoldTokens > 0) {
            REV.transfer(wallets[4], unsoldTokens);
        }

        collectedUnsoldTokensBeforeWindow = window;

        emit LogCollectUnsold(unsoldTokens);
    }
}
