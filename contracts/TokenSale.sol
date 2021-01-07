// Copyright (c) 2019-2020 revolutionpopuli.com

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0 <0.8.0;

import './Ownable.sol';
import './Token.sol';
import './SafeERC20.sol';
import './SafeMath.sol';
import './Creator.sol';

contract TokenSale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for Token;

    uint constant public MIN_ETH = 1 ether; // !!! for real ICO change to 1 ether
    uint constant public WINDOW_DURATION = 23 hours; // !!! for real ICO change to 23 hours

    uint constant public MARKETING_SHARE = 200000000 ether;
    uint constant public TEAM_MEMBER_1_SHARE = 45000000 ether;
    uint constant public TEAM_MEMBER_2_SHARE = 45000000 ether;
    uint constant public TEAM_MEMBER_3_SHARE = 45000000 ether;
    uint constant public TEAM_MEMBER_4_SHARE = 45000000 ether;
    uint constant public TEAM_MEMBER_5_SHARE = 20000000 ether;
    uint constant public REVPOP_FOUNDATION_SHARE = 200000000 ether;
    uint constant public REVPOP_FOUNDATION_PERIOD_LENGTH = 365 days; // !!! for real ICO change to 365 days
    uint constant public REVPOP_FOUNDATION_PERIODS = 10; // 10 days (!!! for real ICO it would be 10 years)
    uint constant public REVPOP_COMPANY_SHARE = 200000000 ether;
    uint constant public REVPOP_COMPANY_PERIOD_LENGTH = 365 days; // !!! for real ICO change to 365 days
    uint constant public REVPOP_COMPANY_PERIODS = 10; // 10 days (!!! for real ICO it would be 10 years)

    address[10] public wallets = [
        // RevPop.org foundation
        0x26be1e82026BB50742bBF765c8b1665bCB763c4c,

        // RevPop the company
        0x4A2d3b4475dA7E634154F1868e689705bDCEEF4c,

        // Marketing
        0x73d3F88BF15EB48e94E6583968041cC850d61D62,

        // Team member 1
        0x1F3eFCe792f9744d919eee34d23e054631351eBc,

        // Team member 2
        0xEB7bb38D821219aE20d3Df7A80A161563CDe5f1b,

        // Team member 3
        0x9F3868cF5FEdb90Df9D9974A131dE6B56B3aA7Ca,

        // Team member 4
        0xE7320724CA4C20aEb193472D3082593f6c58A3C5,

        // Team member 5
        0xCde8311aa7AAbECDEf84179D93a04005C8C549c0,

        // Unsold tokens taker
        0x8B104136F8c1FC63fBA34cb46c42c7af5532f80e,

        // Beneficiarry
        0x8B104136F8c1FC63fBA34cb46c42c7af5532f80e
    ];

    Token public token;                   // The Token token itself
    TokenEscrow public tokenEscrow;

    uint public totalSupply;           // Total Token amount created

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
    bool public tokensPerPeriodAreSet = false;
    bool public distributedShares = false;
    bool public began = false;

    mapping(uint => uint) public dailyTotals;
    mapping(uint => mapping(address => uint)) public userBuys;
    mapping(uint => mapping(address => bool)) public claimed;

    event LogBuy           (uint window, address user, uint amount);
    event LogClaim         (uint window, address user, uint amount);
    event LogCollect       (uint amount);
    event LogCollectUnsold (uint amount);
    event LogFreeze        ();

    constructor(Creator creator) {
        token = creator.createToken();

        require(token.owner() == address(this), "Invalid owner of the Token");
        require(token.totalSupply() == 0, "Total supply of Token should be 0");

        tokenEscrow = creator.createTokenEscrow();

        require(tokenEscrow.owner() == address(this), "Invalid owner of the TokenEscrow");
        require(tokenEscrow.unlockStart() == 0, "TokenEscrow.unlockStart should be 0");

        token.setPausableException(address(tokenEscrow), true);
        token.setPausableException(address(this), true);
        token.setPausableException(wallets[2], true);
    }

    function renounceOwnership() public override onlyOwner {
        require(address(this).balance == 0, "address(this).balance should be == 0");

        super.renounceOwnership();
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
        require(_totalSupply > totalReservedTokens(), "_totalSupply should be more than totalReservedTokens()");

        numberOfOtherWindows = _numberOfOtherWindows;
        totalSupply = _totalSupply;
        firstWindowStartTime = _firstWindowStartTime;
        otherWindowsStartTime = _otherWindowsStartTime;

        initialized = true;

        token.mint(address(this), totalSupply);
    }

    function addBulkPurchasers(address[] memory _purchasers, uint[] memory _tokens) public onlyOwner {
        require(initialized == true, "initialized should be == true");
        require(tokensPerPeriodAreSet == false, "tokensPerPeriodAreSet should be == false");

        uint count = _purchasers.length;

        require(count > 0, "count should be > 0");
        require(count == _tokens.length, "count should be == _tokens.length");

        uint needTokens = 0;

        for (uint i = 0; i < count; i++) {
            require(_tokens[i] > 0, "_tokens[i] should be > 0");

            needTokens = needTokens.add(_tokens[i]);
        }

        require(
            token.balanceOf(address(this)).sub(totalReservedTokens()) > needTokens,
            "token.balanceOf(address(this)).sub(totalReservedTokens()) should be > needTokens"
        );

        for (uint i = 0; i < count; i++) {
            token.safeTransfer(_purchasers[i], _tokens[i]);
            totalBulkPurchasedTokens = totalBulkPurchasedTokens.add(_tokens[i]);
        }
    }

    function setTokensPerPeriods(uint _firstPeriodTokens, uint _otherPeriodTokens) public onlyOwner {
        require(initialized == true, "initialized should be == true");

        tokensPerPeriodAreSet = true;

        uint totalTokens = _firstPeriodTokens.add(_otherPeriodTokens.mul(numberOfOtherWindows));

        require(
            totalSupply.sub(totalReservedTokens()).sub(totalBulkPurchasedTokens) == totalTokens,
            "totalSupply.sub(totalReservedTokens()).sub(totalBulkPurchasedTokens) should be == totalTokens"
        );

        createPerFirstWindow = _firstPeriodTokens;
        createPerOtherWindow = _otherPeriodTokens;
    }

    function distributeShares() public onlyOwner {
        require(tokensPerPeriodAreSet == true, "tokensPerPeriodAreSet should be == true");
        require(distributedShares == false, "distributedShares should be == false");

        distributedShares = true;

        token.safeTransfer(address(tokenEscrow), REVPOP_COMPANY_SHARE.add(REVPOP_FOUNDATION_SHARE));
        token.safeTransfer(wallets[2], MARKETING_SHARE);
        token.safeTransfer(wallets[3], TEAM_MEMBER_1_SHARE);
        token.safeTransfer(wallets[4], TEAM_MEMBER_2_SHARE);
        token.safeTransfer(wallets[5], TEAM_MEMBER_3_SHARE);
        token.safeTransfer(wallets[6], TEAM_MEMBER_4_SHARE);
        token.safeTransfer(wallets[7], TEAM_MEMBER_5_SHARE);

        tokenEscrow.addShare(wallets[0], 50, REVPOP_FOUNDATION_PERIODS, REVPOP_FOUNDATION_PERIOD_LENGTH);
        tokenEscrow.addShare(wallets[1], 50, REVPOP_COMPANY_PERIODS, REVPOP_COMPANY_PERIOD_LENGTH);
        tokenEscrow.setUnlockStart(time());

        // We pause all transfers and minting.
        // We allow to use transfer() function ONLY for tokenEscrow contract,
        // because it is an escrow and it should allow to transfer tokens to a certain party.
        pauseTokenTransfer();
    }

    function totalReservedTokens() internal pure returns (uint) {
        return MARKETING_SHARE
            .add(TEAM_MEMBER_1_SHARE)
            .add(TEAM_MEMBER_2_SHARE)
            .add(TEAM_MEMBER_3_SHARE)
            .add(TEAM_MEMBER_4_SHARE)
            .add(TEAM_MEMBER_5_SHARE)
            .add(REVPOP_COMPANY_SHARE)
            .add(REVPOP_FOUNDATION_SHARE);
    }

    function begin() public onlyOwner {
        require(distributedShares == true, "distributedShares should be == true");
        require(began == false, "began should be == false");

        began = true;
    }

    function pauseTokenTransfer() public onlyOwner {
        token.pause();
    }

    function unpauseTokenTransfer() public onlyOwner {
        token.unpause();
    }

    function burnTokens(address account, uint amount) public onlyOwner {
        token.burn(account, amount);
    }

    function removePausableException(address _address) public onlyOwner {
        token.setPausableException(_address, false);
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

        userBuys[window][msg.sender] = userBuys[window][msg.sender].add(msg.value);
        dailyTotals[window] = dailyTotals[window].add(msg.value);
        totalRaisedETH = totalRaisedETH.add(msg.value);

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

        // 100 ether below is 100% * 10^18
        uint256 userEthShare = userBuys[window][msg.sender].mul(100 ether).div(dailyTotals[window]);
        uint256 reward = (createOnWindow(window)).mul(userEthShare).div(100 ether);

        totalBoughtTokens = totalBoughtTokens.add(reward);
        claimed[window][msg.sender] = true;
        token.safeTransfer(msg.sender, reward);

        emit LogClaim(window, msg.sender, reward);
    }

    function claimAll() public {
        require(began == true, "began should be == true");

        for (uint i = 0; i < today(); i++) {
            claim(i);
        }
    }

    // Crowdsale owners can collect ETH  number of times
    function collect() public {
        require(began == true, "began should be == true");
        require(today() > 0, "today() should be > 0");
        // Prevent recycling during window 0

        uint balance = address(this).balance;
        payable(wallets[9]).transfer(address(this).balance);

        emit LogCollect(balance);
    }

    function collectUnsoldTokens(uint window) public {
        require(began == true, "began should be == true");
        require(today() > 0, "today() should be > 0");
        require(window <= today(), "window should be <= today()");
        require(window > collectedUnsoldTokensBeforeWindow, "window should be > collectedUnsoldTokensBeforeWindow");

        uint unsoldTokens = 0;

        for (uint i = collectedUnsoldTokensBeforeWindow; i < window; i++) {
            uint dailyTotal = dailyTotals[i];

            if (dailyTotal == 0) {
                unsoldTokens = unsoldTokens.add(i == 0 ? createPerFirstWindow : createPerOtherWindow);
            }
        }

        collectedUnsoldTokensBeforeWindow = window;

        if (unsoldTokens > 0) {
            token.safeTransfer(wallets[8], unsoldTokens);
        }

        emit LogCollectUnsold(unsoldTokens);
    }
}
