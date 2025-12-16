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
    address masterMinter = address(3);
    address minter1 = address(4);
    address user = address(5);

    event Mint(address indexed minter, address indexed to, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);
        dscImpl = new DecentralizedStableCoin();
        dscProxy = new DecentralizedStableCoinProxy(address(dscImpl));

        // dsc initialize()
        bytes memory dscInitData = abi.encodeWithSelector(
            DecentralizedStableCoin.initialize.selector,
            "dsc",
            "dsc",
            "USD",
            6,
            masterMinter,
            pauser,
            owner
        );
        dscProxy.upgradeToAndCall(address(dscImpl), dscInitData);

        dsc = DecentralizedStableCoin(address(dscProxy));
        vm.stopPrank();
        vm.prank(masterMinter);
        dsc.configureMinter(minter1, 1_000_000e6);
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

    function testAdminCantNotCallLogicFunctions() public {
        vm.prank(owner);
        vm.expectRevert();
        dsc.totalSupply();
    }

    function testOwnerStoredInProxy() public {
        vm.prank(user);
        assertEq(dsc.owner(), owner);
    }

    function testMintViaProxyWorks() public {
        vm.startPrank(minter1);
        vm.expectEmit(true, true, true, true);
        emit Mint(minter1, user, 100);
        uint256 totalSupply = dsc.totalSupply();
        dsc.mint(user, 100);
        uint256 balance = dsc.balanceOf(user);
        assertEq(balance, 100);
        assertEq(dsc.totalSupply(), totalSupply + 100);
        vm.stopPrank();
    }

    function testOnlyMinterCanMint() public {
        vm.prank(masterMinter);
        vm.expectRevert();
        dsc.mint(user, 100);
    }

    function testMintMustMoreThanZero() public {
        vm.prank(minter1);
        vm.expectRevert();
        dsc.mint(user, 0);
    }

    function testUpgradeToNewImplementationKeepsState() public {
        vm.prank(minter1);
        dsc.mint(minter1, 500);
        uint256 balanceBefore = dsc.balanceOf(minter1);
        uint256 totalSupplyBefore = dsc.totalSupply();

        // Deploy new implementation
        vm.startPrank(owner);
        DecentralizedStableCoin implV2 = new DecentralizedStableCoin();
        dscProxy.upgradeTo(address(implV2));
        vm.stopPrank();
        DecentralizedStableCoin dscV2 = DecentralizedStableCoin(
            address(dscProxy)
        );
        vm.startPrank(minter1);
        uint256 balanceAfter = dscV2.balanceOf(minter1);
        assertEq(balanceAfter, balanceBefore);
        uint256 totalSupplyAfter = dscV2.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore);

        dscV2.burn(200);
        balanceAfter = dscV2.balanceOf(minter1);
        assertEq(dscV2.balanceOf(minter1), balanceBefore - 200);
        assertEq(dscV2.totalSupply(), totalSupplyBefore - 200);
        vm.stopPrank();
    }
}
