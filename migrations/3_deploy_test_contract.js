var TestCreator = artifacts.require("TestCreator");
var TokenSale = artifacts.require("TokenSale");

var argv = require('yargs-parser')(process.argv.slice(2));

module.exports = async function (deployer) {
    await deployer.deploy(TestCreator, {gas: 12500000});
    let creatorInstance = await TestCreator.deployed();

    return await deployer.deploy(TokenSale, creatorInstance.address, {gas: 12500000});
};
