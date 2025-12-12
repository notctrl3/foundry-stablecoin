// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract EIP712Domain {
    bytes32 internal CACHED_DOMAIN_SEPARATOR;

    /**
     * @notice Get the EIP712 Domain Separator.
     * @return The bytes32 EIP712 domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /**
     * @dev Internal method to get the EIP712 Domain Separator.
     * @return The bytes32 EIP712 domain separator.
     */
    function _domainSeparator() internal virtual view returns (bytes32) {
        return CACHED_DOMAIN_SEPARATOR;
    }
}