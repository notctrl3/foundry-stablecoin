// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AdminUpgradeabilityProxy} from "./upgradeability/AdminUpgradeabilityProxy.sol";

contract DecentralizedStableCoinProxy is AdminUpgradeabilityProxy {
    constructor(address implementation) AdminUpgradeabilityProxy(implementation) {
        
    }
}