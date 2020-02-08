const REVSale = artifacts.require('REVSale');
const REVToken = artifacts.require('REVToken');

contract('REVSale', accounts => {
    it("should initialize with given values", async () => {
        let revSale = await REVSale.deployed();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + 432000; // 432000 = 5 days

        await revSale.initialize(
            '2000000000000000000000000000', // 2 000 000 000 * 10**18
            startTime,
            otherStartTime,
            360,
            '1000000000000000000000', // 1000 * 10**18
            accounts[1],
            {from: accounts[0]}
        );

        assert.equal(360, await revSale.numberOfOtherWindows());
        assert.equal(2000000000000000000000000000, await revSale.totalSupply());
        assert.equal(startTime, await revSale.firstWindowStartTime());
        assert.equal(otherStartTime, await revSale.otherWindowsStartTime());

        // Check token transfers and total supply
        let revToken = await REVToken.at(await revSale.REV());

        assert.equal(2000000000000000000000000000, await revToken.totalSupply.call());
        assert.equal(2000000000000000000000000000 - 1000000000000000000000, await revToken.balanceOf(await revSale.address));
        assert.equal(1000000000000000000000, await revToken.balanceOf(accounts[1]));

        // Check distribution per first and other windows
        let revPerFirstWindow = '82191739726027397260224000';
        let revPerOtherWindow = '61657898028355600653';

        let actualRevPerFirstWindow = (await revSale.createPerFirstWindow()).toString(10);
        let actualRevPerOtherWindow = (await revSale.createPerOtherWindow()).toString(10);

        assert.equal(revPerFirstWindow, actualRevPerFirstWindow);
        assert.equal(revPerOtherWindow, actualRevPerOtherWindow);
    });
});
