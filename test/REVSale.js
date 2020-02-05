const REVSale = artifacts.require('REVSale');
const REVToken = artifacts.require('REVToken');

contract('REVSale', accounts => {
    it("should initialize with given values", async () => {
        let revSale = await REVSale.deployed();
        let startTime = new Date().getTime();
        let otherStartTime = startTime + 100;

        await revSale.initialize(
            300,
            2000000000,
            startTime,
            otherStartTime,
            1000,
            accounts[1],
            {from: accounts[0]}
        );

        assert.equal(300, await revSale.numberOfOtherWindows());
        assert.equal(2000000000, await revSale.totalSupply());
        assert.equal(startTime, await revSale.firstWindowStartTime());
        assert.equal(otherStartTime, await revSale.otherWindowsStartTime());

        let revToken = await REVToken.at(await revSale.REV());

        assert.equal(2000000000, await revToken.totalSupply.call());
        assert.equal(2000000000-1000, await revToken.balanceOf(await revSale.address));
        assert.equal(1000, await revToken.balanceOf(accounts[1]));
    });
});
