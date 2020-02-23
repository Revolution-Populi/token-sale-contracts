import BigNumber from 'bignumber.js';
import expectThrow from './helpers/expectThrow';

const REVSale = artifacts.require('REVSale');
const Creator = artifacts.require('Creator');
const REVToken = artifacts.require('REVToken');
const PeriodicAllocation = artifacts.require('PeriodicAllocation');

const UNSOLD_TOKENS_ACCOUNT = '0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E';
const MARKETING_ACCOUNT = '0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e';
const RESERVE_ACCOUNT = '0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0';
const REVPOP_FOUNDATION_ACCOUNT = '0xf0f5409ea22B14a20b12b330BD52a91597efBe8F';
const REVPOP_COMPANY_ACCOUNT = '0xb7D4Ac7FCe988DA56fEf5373A6596a0144aF9924';

// Indexes in ganache-cli
const UNSOLD_TOKENS_ACCOUNT_INDEX = 7;
const MARKETING_ACCOUNT_INDEX = 8;
const RESERVE_ACCOUNT_INDEX = 9;
const REVPOP_FOUNDATION_ACCOUNT_INDEX = 10;
const REVPOP_COMPANY_ACCOUNT_INDEX = 11;

const TOTAL_SUPPLY            = '2000000000000000000000000000'; // 2bn * 10^18
const MARKETING_SHARE         = '250000000000000000000000000'; // 250m * 10^18
const RESERVE_SHARE           = '200000000000000000000000000'; // 200m * 10^18
const REVPOP_FOUNDATION_SHARE = '200000000000000000000000000'; // 200m * 10^18
const REVPOP_COMPANY_SHARE    = '200000000000000000000000000'; // 200m * 10^18

const DEFAULT_TOKENS_IN_FIRST_PERIOD = '49285714285714285713600000';
const DEFAULT_TOKENS_IN_OTHER_PERIOD = '36926807760141093474';

const FIRST_PERIOD_DURATION_IN_SEC = 432000; // 5 days
const NUMBER_OF_OTHER_WINDOWS = 360;
const WINDOW_DURATION_IN_SEC = 82800; // 23 hours

let initializeRevSale = async (revSale, accounts, customProps) => {
    let startTime = new Date().getTime();

    let props = {
        totalSupply: TOTAL_SUPPLY,
        startTime: startTime,
        otherStartTime: startTime + FIRST_PERIOD_DURATION_IN_SEC,
        numberOfOtherWindows: NUMBER_OF_OTHER_WINDOWS,
        ...customProps
    };

    return revSale.initialize(
        props.totalSupply,
        props.startTime,
        props.otherStartTime,
        props.numberOfOtherWindows,
        { from: accounts[0] }
    );
};

let createRevSale = async () => {
    return REVSale.new((await Creator.new()).address);
};

let getEscrowFromRevSale = async (revSale) => {
    return PeriodicAllocation.at(await revSale.periodicAllocation());
};

let getRevTokenFromRevSale = async (revSale) => {
    return REVToken.at(await revSale.REV());
};

let getBalanceByRevSale = async (revSale, account) => {
    let revToken = await REVToken.at(await revSale.REV());
    
    return revToken.balanceOf(account);
};

contract('REVSale', accounts => {
    it("should have token with pausable exception for escrow contract", async () => {
        let revSale = await createRevSale();
        let escrow = await getEscrowFromRevSale(revSale);
        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(true, await token.hasException(escrow.address));
        assert.equal(false, await token.hasException(revSale.address));
        assert.equal(false, await token.hasException(accounts[0]));
        assert.equal(false, await token.hasException(accounts[1]));
        assert.equal(false, await token.hasException(accounts[2]));
    });

    it("should have token and escrow contracts with owner as REVSale", async () => {
        let revSale = await createRevSale();
        let escrow = await getEscrowFromRevSale(revSale);
        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(revSale.address, await token.owner());
        assert.equal(revSale.address, await escrow.owner());
    });

    it("should initialize with given values", async () => {
        let revSale = await createRevSale();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + FIRST_PERIOD_DURATION_IN_SEC;

        await initializeRevSale(revSale, accounts, {
            startTime: startTime,
            otherStartTime: otherStartTime
        });

        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        let revToken = await getRevTokenFromRevSale(revSale);

        assert.equal(TOTAL_SUPPLY, await revToken.totalSupply.call());
        assert.equal(NUMBER_OF_OTHER_WINDOWS, await revSale.numberOfOtherWindows());
        assert.equal(TOTAL_SUPPLY, await revSale.totalSupply());
        assert.equal(startTime, await revSale.firstWindowStartTime());
        assert.equal(otherStartTime, await revSale.otherWindowsStartTime());
        assert.equal(true, await revSale.initialized());
    });

    it("should have create per first/other window values after calling distributeShares (without bulk purchasers)", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });

        assert.equal(
            new BigNumber(TOTAL_SUPPLY)
                .minus(new BigNumber(REVPOP_FOUNDATION_SHARE))
                .minus(new BigNumber(REVPOP_COMPANY_SHARE))
                .minus(new BigNumber(MARKETING_SHARE))
                .minus(new BigNumber(RESERVE_SHARE))
                .toString(10),
            (await getBalanceByRevSale(revSale, revSale.address)).toString(10)
        );

        assert.equal(DEFAULT_TOKENS_IN_FIRST_PERIOD, (await revSale.createPerFirstWindow()).toString(10));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, (await revSale.createPerOtherWindow()).toString(10));
    });

    it("should have proper create per first/other window values after calling distributeShares (with bulk purchasers)", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.setBulkPurchasers(
            [accounts[1], accounts[2]],
            ['100000000000000000000000', '100000000000000000000000'], // 100k * 10^18
            { from: accounts[0] }
        );

        let totalBulkPurchaseAmount = new BigNumber('100000000000000000000000').plus(new BigNumber('100000000000000000000000'));

        await revSale.distributeShares({ from: accounts[0] });

        assert.equal(
            new BigNumber(TOTAL_SUPPLY)
                .minus(totalBulkPurchaseAmount)
                .minus(new BigNumber(REVPOP_FOUNDATION_SHARE))
                .minus(new BigNumber(REVPOP_COMPANY_SHARE))
                .minus(new BigNumber(MARKETING_SHARE))
                .minus(new BigNumber(RESERVE_SHARE))
                .toString(10),
            (await getBalanceByRevSale(revSale, revSale.address)).toString(10)
        );

        assert.equal('49277142857142857141856000', (await revSale.createPerFirstWindow()).toString(10));
        assert.equal('36920385706617590675', (await revSale.createPerOtherWindow()).toString(10));
    });

    it("should have proper distribution of tokens after calling distributeShares", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });

        assert.equal(true, await revSale.distributedShares());

        let escrow = await getEscrowFromRevSale(revSale);
        let escrowAddress = new String(escrow.address).valueOf();

        assert.equal(
            new BigNumber(REVPOP_COMPANY_SHARE).plus(REVPOP_FOUNDATION_SHARE).toString(10),
            (await getBalanceByRevSale(revSale, escrowAddress)).toString(10)
        );

        let escrowUnlockStart = (await escrow.unlockStart()).toNumber();
        let now = new Date().getTime() / 1000;

        assert.equal(true, now >= escrowUnlockStart);
        assert.equal(100, await escrow.totalShare());

        let companyShare = await escrow.shares(REVPOP_COMPANY_ACCOUNT);

        assert.equal(50, companyShare.proportion.toNumber());
        assert.equal(10, companyShare.periods.toNumber());
        assert.equal(31536000, companyShare.periodLength.toNumber());

        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(RESERVE_SHARE, await token.balanceOf(RESERVE_ACCOUNT));
        assert.equal(MARKETING_SHARE, await token.balanceOf(MARKETING_ACCOUNT));

        assert.equal(true, await token.paused());
    });

    it("initialize should be called only once", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await expectThrow(initializeRevSale(revSale, accounts), "initialized should be == false");
    });

    it("should allow to call setBulkPurchasers only after initialized", async () => {
        let revSale = await createRevSale();

        await expectThrow(
            revSale.setBulkPurchasers(
                [accounts[1], accounts[2]],
                ['100000000000000000000000', '100000000000000000000000'],
                { from: accounts[0] }
            ),
            "initialized should be == true"
        );
    });

    it("should transfer tokens to bulk purchasers when setBulkPurchasers is called", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.setBulkPurchasers(
            [accounts[1], accounts[2]],
            ['100000000000000000000000', '100000000000000000000000'],
            { from: accounts[0] }
        );

        let token = await getRevTokenFromRevSale(revSale);

        assert.equal('100000000000000000000000', (await token.balanceOf(accounts[1])).toString(10));
        assert.equal('100000000000000000000000', (await token.balanceOf(accounts[2])).toString(10));
    });

    it("begin should be called only after shares are distributed", async () => {
        let revSale = await createRevSale();

        await expectThrow(revSale.begin({ from: accounts[0] }), "distributedShares should be == true");
    });

    it("begin should be called only once", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        assert.equal(true, await revSale.began());

        await expectThrow(revSale.begin({ from: accounts[0] }), "began should be == false");
    });

    it("should have correct wallets set up", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        assert.equal(REVPOP_FOUNDATION_ACCOUNT, await revSale.wallets(0));
        assert.equal(REVPOP_COMPANY_ACCOUNT, await revSale.wallets(1));
        assert.equal(MARKETING_ACCOUNT, await revSale.wallets(2));
        assert.equal(RESERVE_ACCOUNT, await revSale.wallets(3));
        assert.equal(UNSOLD_TOKENS_ACCOUNT, await revSale.wallets(4));
    });

    it("should perform assertions while initializing", async () => {
        let revSale = await createRevSale();

        await expectThrow(initializeRevSale(revSale, accounts, { totalSupply: 0 }), '_totalSupply should be > 0');
        await expectThrow(initializeRevSale(revSale, accounts, { startTime: 10, otherStartTime: 9 }), '_firstWindowStartTime should be < _otherWindowsStartTime');
        await expectThrow(initializeRevSale(revSale, accounts, { numberOfOtherWindows: 0 }), '_numberOfOtherWindows should be > 0');
    });

    it("should return correct token amount while calling createOnWindow()", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        assert.equal(DEFAULT_TOKENS_IN_FIRST_PERIOD, await revSale.createOnWindow(0));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(1));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(180));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(360));
    });

    it("should return correct window while calling windowFor()", async () => {
        let revSale = await createRevSale();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + 100;

        await initializeRevSale(revSale, accounts, {
            startTime: startTime,
            otherStartTime: otherStartTime,
            numberOfOtherWindows: 100
        });

        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        assert.equal(0, await revSale.windowFor(startTime));
        assert.equal(0, await revSale.windowFor(startTime + 50));
        assert.equal(0, await revSale.windowFor(startTime + 99));
        assert.equal(1, await revSale.windowFor(otherStartTime));
        assert.equal(2, await revSale.windowFor(otherStartTime + WINDOW_DURATION_IN_SEC));
        assert.equal(3, await revSale.windowFor(otherStartTime + WINDOW_DURATION_IN_SEC * 2));
        assert.equal(4, await revSale.windowFor(otherStartTime + WINDOW_DURATION_IN_SEC * 3));
    });

    it("should return 0 while calling today()", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        assert.equal(0, (await revSale.today()).toString(10));
    });

    it("should be able to call pauseTokenTransfer() by the owner of revSale", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        // First, need to unpause transfer, because it is already paused. Otherwise we will get an error.
        await revSale.unpauseTokenTransfer({ from: accounts[0] });

        await revSale.pauseTokenTransfer({ from: accounts[0] });
        await expectThrow(revSale.pauseTokenTransfer({ from: accounts[1] }), 'Ownable: caller is not the owner');

        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(true, await token.paused());

        // Check that it is impossible to call pause on token contract directly
        await expectThrow(token.pause({ from: accounts[0] }), 'Ownable: caller is not the owner');
    });

    it("should be able to call unpauseTokenTransfer() by the owner of revSale", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        await revSale.unpauseTokenTransfer({ from: accounts[0] });
        await expectThrow(revSale.unpauseTokenTransfer({ from: accounts[1] }), 'Ownable: caller is not the owner');

        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(false, await token.paused());

        // Check that it is impossible to call unpause on token contract directly
        await expectThrow(token.unpause({ from: accounts[0] }), 'Ownable: caller is not the owner');
    });

    it("should be able to call burnTokens() by the owner of revSale", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        await revSale.burnTokens(MARKETING_ACCOUNT, '1000', { from: accounts[0] });
        await expectThrow(revSale.burnTokens(MARKETING_ACCOUNT, '1000', { from: accounts[1] }), 'Ownable: caller is not the owner');

        let token = await getRevTokenFromRevSale(revSale);

        assert.equal(
            new BigNumber(MARKETING_SHARE).minus(new BigNumber('1000')).toString(10),
            (await token.balanceOf(MARKETING_ACCOUNT)).toString(10)
        );

        // Check that it is impossible to call burn on token contract directly
        await expectThrow(token.burn(MARKETING_ACCOUNT, '1000', { from: accounts[0] }), 'Ownable: caller is not the owner');
    });

    it("should not be able to transfer tokens while pause", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        let token = await getRevTokenFromRevSale(revSale);

        await expectThrow(token.transfer(accounts[1], '1000'), 'Pausable: paused');

        // Check transferFrom
        await token.approve(accounts[1], '1000', { from: accounts[0] });
        await expectThrow(token.transferFrom(accounts[0], accounts[1], '1000', { from: accounts[0] }), 'Pausable: paused');
    });

    it("should not be able to call mint on token contract directly", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        let token = await getRevTokenFromRevSale(revSale);

        await expectThrow(token.mint(accounts[1], '1000'), 'Ownable: caller is not the owner');
    });

    it("should be able to call collect() by the owner of revSale", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        await expectThrow(revSale.collect({ from: accounts[0] }), 'today() should be > 0');
        await expectThrow(revSale.collect({ from: accounts[1] }), 'Ownable: caller is not the owner');
    });

    it("should be able to call collectUnsoldTokens() by the owner of revSale", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });
        await revSale.begin({ from: accounts[0] });

        await expectThrow(revSale.collectUnsoldTokens(1, { from: accounts[0] }), 'today() should be > 0');
        await expectThrow(revSale.collectUnsoldTokens(1, { from: accounts[1] }), 'Ownable: caller is not the owner');
    });
});
