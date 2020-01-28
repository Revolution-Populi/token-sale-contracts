pragma solidity >=0.4.21 <0.7.0;

contract DSAuthority {
    function canCall(
    address src, address dst, bytes4 sig
    ) view returns (bool);
}
