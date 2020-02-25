require('babel-polyfill');

const Token = artifacts.require('REVToken');
const web3 = Token.web3;

const assertBNEqual = (actual, expected, message) => {
    return assert.equal(
        Math.round(actual / web3.toWei(1, 'ether')),
        Math.round(expected / web3.toWei(1, 'ether')),
        message
    );
};

export default assertBNEqual;
