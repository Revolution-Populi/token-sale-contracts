import BigNumber from 'bignumber.js';
import expectThrow from './helpers/expectThrow';

const REVSale = artifacts.require('REVSale');
const REVToken = artifacts.require('REVToken');

const DEFAULT_TOTAL_SUPPLY = '2000000000000000000000000000'; // 2 000 000 000 * 10**18
const DEFAULT_BULK_PURCHASE_TOKENS = '1000000000000000000000'; // 1000 * 10**18
const DEFAULT_FIRST_PERIOD_DURATION_IN_SEC = 432000; // 5 days
const DEFAULT_NUMBER_OF_OTHER_WINDOWS = 360;
const DEFAULT_WINDOW_DURATION_IN_SEC = 82800; // 23 hours
const DEFAULT_TOKENS_IN_FIRST_PERIOD = '82191739726027397260224000';
const DEFAULT_TOKENS_IN_OTHER_PERIOD = '61657898028355600653';

let initializeRevSale = async (revSale, accounts, customProps) => {
    let startTime = new Date().getTime();

    let props = {
        totalSupply: DEFAULT_TOTAL_SUPPLY,
        startTime: startTime,
        otherStartTime: startTime + DEFAULT_FIRST_PERIOD_DURATION_IN_SEC,
        numberOfOtherWindows: DEFAULT_NUMBER_OF_OTHER_WINDOWS,
        bulkPurchaseTokens: DEFAULT_BULK_PURCHASE_TOKENS,
        bulkPurchaseAddress: accounts[1],
        ...customProps
    };

    return revSale.initialize(
        props.totalSupply,
        props.startTime,
        props.otherStartTime,
        props.numberOfOtherWindows,
        props.bulkPurchaseTokens,
        props.bulkPurchaseAddress,
        { from: accounts[0] }
    );
};

contract('REVSale', accounts => {
    it("should initialize with given values", async () => {
        let revSale = await REVSale.deployed();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + DEFAULT_FIRST_PERIOD_DURATION_IN_SEC;

        await initializeRevSale(revSale, accounts, {
            startTime: startTime,
            otherStartTime: otherStartTime
        });

        assert.equal(DEFAULT_NUMBER_OF_OTHER_WINDOWS, await revSale.numberOfOtherWindows());
        assert.equal(DEFAULT_TOTAL_SUPPLY, await revSale.totalSupply());
        assert.equal(startTime, await revSale.firstWindowStartTime());
        assert.equal(otherStartTime, await revSale.otherWindowsStartTime());

        // Check token transfers and total supply
        let revToken = await REVToken.at(await revSale.REV());

        assert.equal(DEFAULT_TOTAL_SUPPLY, await revToken.totalSupply.call());
        assert.equal(DEFAULT_TOTAL_SUPPLY - DEFAULT_BULK_PURCHASE_TOKENS, await revToken.balanceOf(new String(revSale.address).valueOf()));
        assert.equal(DEFAULT_BULK_PURCHASE_TOKENS, await revToken.balanceOf(accounts[1]));

        // Check distribution per first and other windows
        assert.equal(DEFAULT_TOKENS_IN_FIRST_PERIOD, (await revSale.createPerFirstWindow()).toString(10));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, (await revSale.createPerOtherWindow()).toString(10));
    });

    it("should return correct token amount while calling createOnWindow()", async () => {
        let revSale = await REVSale.deployed();

        await initializeRevSale(revSale, accounts);

        assert.equal(DEFAULT_TOKENS_IN_FIRST_PERIOD, await revSale.createOnWindow(0));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(1));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(180));
        assert.equal(DEFAULT_TOKENS_IN_OTHER_PERIOD, await revSale.createOnWindow(360));
    });

    it("should return correct window while calling windowFor()", async () => {
        let revSale = await REVSale.deployed();
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
        assert.equal(1, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC));
        assert.equal(2, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC * 2));
        assert.equal(3, await revSale.windowFor(otherStartTime + DEFAULT_WINDOW_DURATION_IN_SEC * 3));
    });

    it("should return correct token amount while calling shouldBeBoughtTotalTokensBeforeWindow()", async () => {
        let revSale = await REVSale.deployed();

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

    it("should return 0 while calling unsoldTokensBeforeWindow() without any purchases", async () => {
        let revSale = await REVSale.deployed();

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

    it("should return 0 while calling today()", async () => {
        let revSale = await REVSale.deployed();

        await initializeRevSale(revSale, accounts);

        assert.equal(0, (await revSale.today()).toString(10));
    });
});
