const Creator = artifacts.require('Creator');
const TokenSale = artifacts.require('TokenSale');

module.exports = async function (deployer) {
    await deployer.deploy(Creator);
    let creatorInstance = await Creator.deployed();

    return await deployer.deploy(TokenSale, creatorInstance.address);
};
