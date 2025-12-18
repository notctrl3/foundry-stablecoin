// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

contract CommonHelper is Test {
    function _sign(bytes32 digest, uint256 pk) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _generateNonce(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("nonce-", id));
    }
}
