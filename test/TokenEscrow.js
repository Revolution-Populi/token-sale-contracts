require('babel-polyfill');

import expectThrow from './helpers/expectThrow';

const Token = artifacts.require('Token');
const TokenEscrow = artifacts.require('TokenEscrow');

contract('TokenEscrow', function (accounts) {
    function wait(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    it('should unlock tokens by equal parts', async () => {
        const tokenHolders = [
            '0xd12cFD596279CDb76915827d5039936cc48e2B8D',
            '0xbd44980Ca3B93Ce93A5C7393F93E6A3dD545EF23'
        ];

        const TOTAL = 1600;
        const SHARE_1 = 33;
        const SHARE_2 = 67;

        const sharePart1 = (step) => Math.floor(TOTAL * Math.floor(SHARE_1 / 2 * step) / (SHARE_1 + SHARE_2));
        const sharePart2 = (step) => Math.floor(TOTAL * Math.floor(SHARE_2 / 3 * step) / (SHARE_1 + SHARE_2));

        const token = await Token.new(web3.utils.fromAscii('RevolutionPopuli ERC20 Token'), web3.utils.fromAscii('RVP'));
        await token.mint(accounts[0], 10000000000000);

        const escrow = await TokenEscrow.new(token.address, { from: accounts[0] });
        const now = Math.floor((new Date()).getTime() / 1000);
        await escrow.setUnlockStart(now);

        await token.mint(escrow.address, TOTAL);

        await escrow.addShare(tokenHolders[0], SHARE_1, 2, 10 /*seconds*/, { from: accounts[0] });
        await escrow.addShare(tokenHolders[1], SHARE_2, 3, 10 /*seconds*/, { from: accounts[0] });

        await expectThrow(escrow.unlockFor(tokenHolders[0]));
        await expectThrow(escrow.unlockFor(tokenHolders[1]));

        assert.equal(await token.balanceOf(tokenHolders[0]), 0, '0 tokens wasn\'t on tokenHolders[0]');
        assert.equal(await token.balanceOf(tokenHolders[1]), 0, '0 tokens wasn\'t on tokenHolders[1]');
        assert.equal(await token.balanceOf(escrow.address), TOTAL, '0 tokens wasn\'t on escrow');

        await wait(10000);
        await token.mint(accounts[0], 1); // mine tokens for adding new block to restrpc

        await escrow.unlockFor(tokenHolders[0]);
        await escrow.unlockFor(tokenHolders[1]);

        assert.equal(await token.balanceOf(tokenHolders[0]), sharePart1(1), 'sharePart1 tokens wasn\'t on tokenHolders[0]');
        assert.equal(await token.balanceOf(tokenHolders[1]), sharePart2(1), 'sharePart2 tokens wasn\'t on tokenHolders[1]');
        assert.equal(await token.balanceOf(escrow.address), TOTAL - (sharePart1(1) + sharePart2(1)), 'TOTAL - (sharePart1 + sharePart2) tokens wasn\'t on escrow');

        await wait(10000);
        await token.mint(accounts[0], 1); // mine tokens for adding new block to restrpc

        await escrow.unlockFor(tokenHolders[0]);
        await escrow.unlockFor(tokenHolders[1]);
        await escrow.unlockFor(tokenHolders[0]); // Repeating unlockFor at same period should not transfer tokens
        await escrow.unlockFor(tokenHolders[1]);

        assert.equal(await token.balanceOf(tokenHolders[0]), sharePart1(2), '2 * sharePart1 tokens wasn\'t on tokenHolders[0]');
        assert.equal(await token.balanceOf(tokenHolders[1]), sharePart2(2), '2 * sharePart2 tokens wasn\'t on tokenHolders[1]');
        assert.equal(await token.balanceOf(escrow.address), TOTAL - (sharePart1(2) + sharePart2(2)), 'TOTAL - 2 * (sharePart1 + sharePart2) tokens wasn\'t on escrow');

        await wait(10000);
        await token.mint(accounts[0], 1); // mine tokens for adding new block to restrpc

        await escrow.unlockFor(tokenHolders[0]);
        await escrow.unlockFor(tokenHolders[1]);

        assert.equal(await token.balanceOf(tokenHolders[0]), sharePart1(2), '2 * sharePart1 tokens wasn\'t on tokenHolders[0]');
        assert.equal(await token.balanceOf(tokenHolders[1]), sharePart2(3), '3 * sharePart2 tokens wasn\'t on tokenHolders[1]');
        assert.equal(await token.balanceOf(escrow.address), 0, '0 tokens wasn\'t on escrow');
    });

});
