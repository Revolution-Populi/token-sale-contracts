const Creator = artifacts.require('Creator');
const TokenSale = artifacts.require('TokenSale');

module.exports = async function (deployer) {
    await deployer.deploy(Creator, {gas: 12500000});
    let creatorInstance = await Creator.deployed();

    return await deployer.deploy(TokenSale, creatorInstance.address, {gas: 12500000});
};
