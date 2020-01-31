const Creator = artifacts.require('Creator');
const RevSale = artifacts.require('REVSale');

module.exports = async function (deployer) {
    await deployer.deploy(Creator);
    let creatorInstance = await Creator.deployed();

    return await deployer.deploy(RevSale, creatorInstance.address);
};
