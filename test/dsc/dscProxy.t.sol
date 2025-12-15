// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DecentralizedStableCoinProxy} from "../../src/DecentralizedStableCoinProxy.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract DecentralizedStablecoinProxyTest is Test {
    DecentralizedStableCoin dscImpl;
    DecentralizedStableCoinProxy dscProxy;
    DecentralizedStableCoin dsc; // proxy casted as logic contract

    address owner = address(1);
    address pauser = address(2);

    function setUp() public {
        dscImpl = new DecentralizedStableCoin();
        dscProxy = new DecentralizedStableCoinProxy(address(dscImpl));

        // dsc initialize()
        bytes memory dscInitData = abi.encodeWithSelector(
            DecentralizedStableCoin.initialize.selector,
            "dsc",
            "USD",
            6,
            pauser, // pauser
            owner // owner
        );
        dscProxy.upgradeToAndCall(address(dscImpl), dscInitData);

        dsc = DecentralizedStableCoin(address(dscProxy));
    }

    function testInitializeOnlyOnce() public {
        vm.prank(owner);
        vm.expectRevert();
        dscProxy.upgradeToAndCall(
            address(dscImpl),
            abi.encodeWithSelector(
                DecentralizedStableCoin.initialize.selector,
                "dsc",
                "USD",
                6,
                pauser,
                owner
            )
        );
    }

    

    
}
