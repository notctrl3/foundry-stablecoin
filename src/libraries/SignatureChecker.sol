pragma solidity ^0.8.20;

import {IERC1271} from "../interface/IERC1271.sol";

library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. 
     * If the signer is a smart contract, the signature is validated against that smart contract using ERC1271, 
     * otherwise it's validated using `ECRecover.recover`.
     * @param signer Address of the claimed signer
     * @param digest Keccak-256 hash digest of the signed message
     * @param signature  Signature byte array associated with hash
     */
    function isValidSignatureNow(
        address signer,
        byte32 digest,
        bytes memory signature
    ) external view returns (bool) {
        if (!isContract(signer)) {
            return ECRecover.recover(digest, signature) == signer;
        }

        return isValidERC1271SignatureNow(signer, digest, signature);
    }

    /**
     * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
     * against the signer smart contract using ERC1271.
     * @param signer        Address of the claimed signer
     * @param digest        Keccak-256 hash digest of the signed message
     * @param signature     Signature byte array associated with hash
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(
                IERC1271.isValidSignature.selector,
                digest,
                signature
            )
        );
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) ==
            bytes32(IERC1271.isValidSignature.selector));
    }

    /**
     * @dev Returns true if `address` is a contract.
     * @param address Address to check
     * 
     * NOTE: For an Externally Owned Account (EOA): The code size is 0. EOAs have no associated smart contract code.
     * For a Smart Contract: The code size is greater than 0, representing the length of the deployed bytecode.
     */ 
    function isContract(address address) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(address)
        }
        return size > 0;
    }
}
