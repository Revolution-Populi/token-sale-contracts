import BigNumber from 'bignumber.js';
import expectThrow from './helpers/expectThrow';

const REVSale = artifacts.require('REVSale');
const Creator = artifacts.require('Creator');
const REVToken = artifacts.require('REVToken');
const PeriodicAllocation = artifacts.require('PeriodicAllocation');

const DEFAULT_MARKETING_ACCOUNT = '0xF2fb97fBF0B2Ad0830F7C2B9C73F0648BB5340E4';
const DEFAULT_RESERVE_ACCOUNT = '0x0f02A52EbeFcce7104fc82B68756f4edC640523C';
const DEFAULT_REVPOP_FOUNDATION_ACCOUNT = '0x049A9f8C12c23C0549b73960748645403DC443e3';
const DEFAULT_REVPOP_COMPANY_ACCOUNT = '0x7bE0166D691fdDf4e5f0E50Cdd9Ab0666Ef8b41d';

const DEFAULT_TOTAL_SUPPLY = '2000000000000000000000000000'; // 2bn * 10^18
const DEFAULT_MARKETING_SHARE = '250000000000000000000000000'; // 250m * 10^18
const DEFAULT_RESERVE_SHARE = '200000000000000000000000000'; // 200m * 10^18
const DEFAULT_REVPOP_FOUNDATION_SHARE = '200000000000000000000000000'; // 200m * 10^18
const DEFAULT_REVPOP_COMPANY_SHARE = '200000000000000000000000000'; // 200m * 10^18

const DEFAULT_TOKENS_IN_FIRST_PERIOD = '49285714285714285713600000';
const DEFAULT_TOKENS_IN_OTHER_PERIOD = '36926807760141093474';

const DEFAULT_FIRST_PERIOD_DURATION_IN_SEC = 432000; // 5 days
const DEFAULT_NUMBER_OF_OTHER_WINDOWS = 360;
const DEFAULT_WINDOW_DURATION_IN_SEC = 82800; // 23 hours

let initializeRevSale = async (revSale, accounts, customProps) => {
    let startTime = new Date().getTime();

    let props = {
        totalSupply: DEFAULT_TOTAL_SUPPLY,
        startTime: startTime,
        otherStartTime: startTime + DEFAULT_FIRST_PERIOD_DURATION_IN_SEC,
        numberOfOtherWindows: DEFAULT_NUMBER_OF_OTHER_WINDOWS,
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

contract('REVSale', accounts => {
    it("should initialize with given values", async () => {
        let revSale = await createRevSale();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + DEFAULT_FIRST_PERIOD_DURATION_IN_SEC;

        await initializeRevSale(revSale, accounts, {
            startTime: startTime,
            otherStartTime: otherStartTime
        });

        // await revSale.setBulkPurchasers(
            // ['', ''],
            // [], []
        // );

        assert.equal(DEFAULT_NUMBER_OF_OTHER_WINDOWS, await revSale.numberOfOtherWindows());
        assert.equal(DEFAULT_TOTAL_SUPPLY, await revSale.totalSupply());
        assert.equal(startTime, await revSale.firstWindowStartTime());
        assert.equal(otherStartTime, await revSale.otherWindowsStartTime());

        // Check token transfers and total supply
        let revToken = await REVToken.at(await revSale.REV());
        let tokenAddress = new String(revSale.address).valueOf();

        assert.equal(DEFAULT_TOTAL_SUPPLY, await revToken.totalSupply.call());
        assert.equal(
            new BigNumber(DEFAULT_TOTAL_SUPPLY)
                .minus(new BigNumber(DEFAULT_REVPOP_FOUNDATION_SHARE))
                .minus(new BigNumber(DEFAULT_REVPOP_COMPANY_SHARE))
                .minus(new BigNumber(DEFAULT_MARKETING_SHARE))
                .minus(new BigNumber(DEFAULT_RESERVE_SHARE))
                .toString(10),
            (await revToken.balanceOf(tokenAddress)).toString(10)
        );

        let periodicAllocation = await PeriodicAllocation.at(await revSale.periodicAllocation());
        let periodicAllocationAddress = new String(periodicAllocation.address).valueOf();

        assert.equal(
            new BigNumber(DEFAULT_REVPOP_COMPANY_SHARE).plus(DEFAULT_REVPOP_FOUNDATION_SHARE).toString(10),
            (await revToken.balanceOf(periodicAllocationAddress)).toString(10)
        );
        
        // @TODO: check bulk purchasers

        assert.equal(DEFAULT_RESERVE_SHARE, await revToken.balanceOf(DEFAULT_RESERVE_ACCOUNT));
        assert.equal(DEFAULT_MARKETING_SHARE, await revToken.balanceOf(DEFAULT_MARKETING_ACCOUNT));

        // Check distribution per first and other windows
        assert.equal(DEFAULT_TOKENS_IN_FIRST_PERIOD, (await revSale.createPerFirstWindow()).toString(10));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, (await revSale.createPerOtherWindow()).toString(10));
    });

    it("should have correct wallets set up", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);

        assert.equal('0x049A9f8C12c23C0549b73960748645403DC443e3', await revSale.wallets(0));
        assert.equal('0x7bE0166D691fdDf4e5f0E50Cdd9Ab0666Ef8b41d', await revSale.wallets(1));
        assert.equal('0xF2fb97fBF0B2Ad0830F7C2B9C73F0648BB5340E4', await revSale.wallets(2));
        assert.equal('0x0f02A52EbeFcce7104fc82B68756f4edC640523C', await revSale.wallets(3));
        assert.equal('0x97000D1a83E3cd519308B444a21eCE69f4414658', await revSale.wallets(4));
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

        assert.equal(0, await revSale.windowFor(startTime));
        assert.equal(0, await revSale.windowFor(startTime + 50));
        assert.equal(0, await revSale.windowFor(startTime + 99));
        assert.equal(1, await revSale.windowFor(otherStartTime));
        assert.equal(2, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC));
        assert.equal(3, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC * 2));
        assert.equal(4, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC * 3));
    });

    it("should return correct token amount while calling shouldBeBoughtTotalTokensBeforeWindow()", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);

        let firstPeriodTokens = new BigNumber(DEFAULT_TOKENS_IN_FIRST_PERIOD);
        let otherPeriodTokens = new BigNumber(DEFAULT_TOKENS_IN_OTHER_PERIOD);

        assert.equal(
            firstPeriodTokens.toString(10),
            (await revSale.shouldBeBoughtTotalTokensBeforeWindow(1)).toString(10)
        );

        assert.equal(
            firstPeriodTokens.plus(otherPeriodTokens).toString(10),
            (await revSale.shouldBeBoughtTotalTokensBeforeWindow(2)).toString(10)
        );

        assert.equal(
            firstPeriodTokens.plus(otherPeriodTokens.multipliedBy(DEFAULT_NUMBER_OF_OTHER_WINDOWS - 1)).toString(10),
            (await revSale.shouldBeBoughtTotalTokensBeforeWindow(DEFAULT_NUMBER_OF_OTHER_WINDOWS)).toString(10)
        );
    });

    it("should throw an error while calling shouldBeBoughtTotalTokensBeforeWindow() with 0 value", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await expectThrow(revSale.shouldBeBoughtTotalTokensBeforeWindow(0), "window should be > 0");
    });

    it("should return 0 while calling unsoldTokensBeforeWindow() without any purchases", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);

        let firstPeriodTokens = new BigNumber(DEFAULT_TOKENS_IN_FIRST_PERIOD);
        let otherPeriodTokens = new BigNumber(DEFAULT_TOKENS_IN_OTHER_PERIOD);

        assert.equal(
            firstPeriodTokens.toString(10),
            (await revSale.shouldBeBoughtTotalTokensBeforeWindow(1)).toString(10)
        );

        assert.equal(
            firstPeriodTokens.plus(otherPeriodTokens.multipliedBy(DEFAULT_NUMBER_OF_OTHER_WINDOWS - 1)).toString(10),
            (await revSale.shouldBeBoughtTotalTokensBeforeWindow(DEFAULT_NUMBER_OF_OTHER_WINDOWS)).toString(10)
        );
    });

    it("should throw an error while calling unsoldTokensBeforeWindow() with 0 value", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);
        await expectThrow(revSale.shouldBeBoughtTotalTokensBeforeWindow(0), "window should be > 0");
    });

    it("should return 0 while calling today()", async () => {
        let revSale = await createRevSale();

        await initializeRevSale(revSale, accounts);

        assert.equal(0, (await revSale.today()).toString(10));
    });
});
