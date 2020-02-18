pragma solidity ^0.6.0;

contract DSExec {
    function tryExec( address target, bytes memory data, uint value) internal returns (bool ok) {
        assembly {
            ok := call(gas, target, value, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function exec( address target, bytes memory data, uint value) internal {
        if(!tryExec(target, data, value)) {
            revert("ds-exec-call-failed");
        }
    }

    // Convenience aliases
    function exec( address t, bytes memory c ) internal {
        exec(t, c, 0);
    }

    function exec( address t, uint256 v ) internal {
        bytes memory c; exec(t, c, v);
    }

    function tryExec( address t, bytes memory c ) internal returns (bool) {
        return tryExec(t, c, 0);
    }

    function tryExec( address t, uint256 v ) internal returns (bool) {
        bytes memory c; return tryExec(t, c, v);
    }
}
