// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Proxy} from "./Proxy.sol";

contract UpgradeabilityProxy is Proxy {
    /**
     * @dev Emitted when the implementation is upgraded.
     * @param implementation Address of the new implementation.
     */
    event Upgraded(address implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Contract constructor.
     * @param implementationContract Address of the initial implementation.
     */
    constructor(address implementationContract) {
        assert(
            IMPLEMENTATION_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        _setImplementation(implementationContract);
    }

    /**
     * @dev Returns the current implementation address.
     * @return impl Address of the current implementation.
     */
    function _implementation() internal view override returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the implementation to a new address.
     * @param newImplementation Address of the new implementation.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation address in storage.
     * @param newImplementation Address of the new implementation.
     */
    function _setImplementation(address newImplementation) private {
        require(
            isContract(newImplementation),
            "UpgradeabilityProxy: new implementation is not a contract"
        );
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    /**
     * @dev Returns true if `address` is a contract.
     * @param addr Address to check
     *
     * NOTE: For an Externally Owned Account (EOA): The code size is 0. EOAs have no associated smart contract code.
     * For a Smart Contract: The code size is greater than 0, representing the length of the deployed bytecode.
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
