// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title EIP712
 * @dev Implementation of the EIP712 standard for hashing and signing typed structured data.
 */
library EIP712 {
    function makeDomainSeparator(
        string memory name,
        string memory version,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    address(this)
                )
            );
    }

    function makeDomainSeparator(
        string memory name,
        string memory version
    ) internal pure returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return makeDomainSeparator(name, version, chainId);
    }
}
