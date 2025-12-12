// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {MessageHashUtils} from "./MessageHashUtils.sol";
import {AbstractStableCoinV1} from "./AbstractStableCoinV1.sol";
import {EIP712Domain} from "./EIP712Domain.sol";

abstract contract EIP2612 is AbstractStableCoinV1, EIP712Domain {
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    mapping(address => unit256) private _permitNonces;

    /**
     *
     * @param owner Token owner's address
     * @return Next nonce for the owner
     */
    function nonces(address owner) public view returns (uint256) {
        return _permitNonces[owner];
    }

    /**
     * @notice Verify a signed approval permit and execute if valid
     * @param owner     Token owner's address (Authorizer)
     * @param spender   Spender's address
     * @param value     Amount of allowance
     * @param deadline  The time at which the signature expires (unix time), or max uint256 value to signal no expiration
     * @param v         v of the signature
     * @param r         r of the signature
     * @param s         s of the signature
     */
    function _permit(
        address owner,
        address spender,
        unit256 value,
        unit256 deadline,
        unit8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }

    function _permit(
        address owner,
        address spender,
        unit256 value,
        unit256 deadline,
        bytes memory signature
    ) internal {
        require(
            deadline == type.max(unit256) || deadline >= now,
            "StableCoinV1: permit is expired"
        );

        bytes32 typedDataHash = MessageHashUtils.toTypedDataHash(
            _domainSeparator(),
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    _permitNonces[owner]++,
                    deadline
                )
            )
        );

        require(
            SignatureChecker.isValidSignatureNow(
                owner,
                typedDataHash,
                signature
            ),
            "StableCoinV1: EIP2612 invalid signature"
        );

        _approve(owner, spender, value);
    }
}
