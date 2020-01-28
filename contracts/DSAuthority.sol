pragma solidity >=0.5.16;

contract DSAuthority {
    function canCall(
    address src, address dst, bytes4 sig
    ) view returns (bool);
}
