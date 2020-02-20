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

const BULK_PURCHASE_EXAMPLE = '100000000000000000000000'; // 100k * 10^18

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

let getRevTokenFromRevSale = async (revSale) => {
    return REVToken.at(await revSale.REV());
};

let getBalanceByRevSale = async (revSale, account) => {
    let revToken = await REVToken.at(await revSale.REV());
    
    return revToken.balanceOf(account);
};

contract('REVSale', accounts => {
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
    });

    it("should have proper total supply and create per first/other window values after calling distributeShares (without bulk purchasers)", async () => {
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

    it("should have proper total supply and create per first/other window values after calling distributeShares (with bulk purchasers)", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.setBulkPurchasers(
            [accounts[1], accounts[2]],
            [BULK_PURCHASE_EXAMPLE, BULK_PURCHASE_EXAMPLE],
            { from: accounts[0] }
        );

        let totalBulkPurchaseAmount = new BigNumber(BULK_PURCHASE_EXAMPLE).multipliedBy(2);

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

    if ("should have proper distribution of tokens after calling distributeShares", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await revSale.distributeShares({ from: accounts[0] });

        let periodicAllocation = await PeriodicAllocation.at(await revSale.periodicAllocation());
        let periodicAllocationAddress = new String(periodicAllocation.address).valueOf();

        assert.equal(
            new BigNumber(REVPOP_COMPANY_SHARE).plus(REVPOP_FOUNDATION_SHARE).toString(10),
            (await getBalanceByRevSale(revSale, periodicAllocationAddress)).toString(10)
        );

        assert.equal(RESERVE_SHARE, await revToken.balanceOf(RESERVE_ACCOUNT));
        assert.equal(MARKETING_SHARE, await revToken.balanceOf(MARKETING_ACCOUNT));
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
                [BULK_PURCHASE_EXAMPLE, BULK_PURCHASE_EXAMPLE],
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
            [BULK_PURCHASE_EXAMPLE, BULK_PURCHASE_EXAMPLE],
            { from: accounts[0] }
        );

        // @TODO: Also check that bulk purchasers receive correct amount of tokens.
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
});
