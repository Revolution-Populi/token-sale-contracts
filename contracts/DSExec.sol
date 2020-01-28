pragma solidity >=0.4.21 <0.7.0;

contract DSExec {
    function tryExec( address target, bytes calldata, uint value)
    internal
    returns (bool call_ret)
    {
        return target.call.value(value)(calldata);
    }
    function exec( address target, bytes calldata, uint value)
    internal
    {
        if(!tryExec(target, calldata, value)) {
            throw;
        }
    }

    // Convenience aliases
    function exec( address t, bytes c )
    internal
    {
        exec(t, c, 0);
    }
    function exec( address t, uint256 v )
    internal
    {
        bytes memory c; exec(t, c, v);
    }
    function tryExec( address t, bytes c )
    internal
    returns (bool)
    {
        return tryExec(t, c, 0);
    }
    function tryExec( address t, uint256 v )
    internal
    returns (bool)
    {
        bytes memory c; return tryExec(t, c, v);
    }
}
