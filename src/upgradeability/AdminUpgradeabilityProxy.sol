// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {UpgradeabilityProxy} from "./UpgradeabilityProxy.sol";

contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
    /**
     * @dev Emitted when the administration has been transferred.
     * @param previousAdmin Address of the previous admin.
     * @param newAdmin Address of the new admin.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the address of the admin.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Modifier to check whether the `msg.sender` is the admin.
     * If it is, it will run the function. Otherwise, it will delegate the call
     * to the implementation.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Contract constructor.
     * @param implementation Address of the initial implementation.
     */
    constructor(address implementation) UpgradeabilityProxy(implementation) {
        assert(
            ADMIN_SLOT == 
                bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
        );
        _setAdmin(msg.sender);
    }

    /**
     * @return The Address of the proxy admin.
     */
    function admin() external view returns(address) {
        return _admin();
    }

    /**
     * @return The Address of the implementation.
     */
    function implementation() external view returns (address) {
        return _implementation();
    }
    
    /**
     * @dev Changes the admin of the proxy.
     * Only the current admin can call this function.
     * @param newAdmin Address to transfer proxy administration to.
     */
    function changeAdmin(address newAdmin) external ifAdmin {
        require(
            newAdmin != address(0),
            "AdminUpgradeabilityProxy: new admin is the zero address"
        );
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }
    
    /**
     * @dev Upgrade the backing implementation of the proxy.
     * Only the admin can call this function.
     * @param newImplementation Address of the new implementation.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy and call a function
     * on the new implementation.
     * This is useful to initialize the proxied contract.
     * @param newImplementation Address of the new implementation.
     * @param data Data to send as msg.data in the low level call.
     * It should include the signature and the parameters of the function to be
     * called, as described in
     * https://solidity.readthedocs.io/en/develop/abi-spec.html#function-selector-and-argument-encoding.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        external
        payable
        ifAdmin
    {
        _upgradeTo(newImplementation);
        (bool success,) = address(this).call{value: msg.value}(data);
        require(success);
    }

    function _admin() internal view returns (address adm){
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _willFallback() internal override {
        require(
            msg.sender != _admin(),
            "AdminUpgradeabilityProxy: admin cannot fallback to proxy target"
        );
        super._willFallback();
    }
}
