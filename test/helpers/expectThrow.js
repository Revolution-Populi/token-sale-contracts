export default async (promise, msg) => {
    try {
        await promise;
    } catch (error) {
        const invalidJump = error.message.search('invalid JUMP') >= 0;
        const outOfGas = error.message.search('out of gas') >= 0;
        const exception = error.message.search('Exception') >= 0;

        if (msg) {
            assert(error.message.search(msg) >= 0);
        }

        assert(
            invalidJump || outOfGas || exception,
            "Expected throw, got '" + error + "' instead",
        );
        return;
    }
    assert.fail('Expected throw not received');
};
