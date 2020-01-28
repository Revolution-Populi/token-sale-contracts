pragma solidity >=0.4.21 <0.7.0;

contract ERC20 {
    function totalSupply() view returns (uint supply);
    function balanceOf( address who ) view returns (uint value);
    function allowance( address owner, address spender ) view returns (uint _allowance);

    function transfer( address to, uint value) returns (bool ok);
    function transferFrom( address from, address to, uint value) returns (bool ok);
    function approve( address spender, uint value ) returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}
