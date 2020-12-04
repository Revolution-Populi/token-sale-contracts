var TestCreator = artifacts.require("TestCreator");
var TokenSale = artifacts.require("TokenSale");

var argv = require('yargs-parser')(process.argv.slice(2));

module.exports = async function (deployer) {
    await deployer.deploy(TestCreator);
    let creatorInstance = await TestCreator.deployed();

    return await deployer.deploy(TokenSale, creatorInstance.address);
};
