// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {PermitHelper} from "../helper/PermitHelper.sol";

contract DSC_Permit_Test is Test {
    DecentralizedStableCoin dsc;
    address owner = address(1);
    address pauser = address(2);
    address masterMinter = address(3);
    address minter1 = address(4);
    uint256 userPk = 0xA11CE;
    address user = vm.addr(userPk);
    address spender = address(6);

    function setUp() public {
        dsc = new DecentralizedStableCoin();
        dsc.initialize("dsc", "dsc", "USD", 6, masterMinter, pauser, owner);
        vm.prank(masterMinter);
        dsc.configureMinter(minter1, 1_000_000e6);
        vm.prank(minter1);
        dsc.mint(user, 1000e6);
    }

    // Additional tests for permit functionality would go here
    function testPermitSuccess() public {
        vm.startPrank(user);
        uint256 nonces = dsc.nonces(user);
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = PermitHelper.digest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            nonces,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        dsc.permit(user, spender, 500e6, deadline, v, r, s);
        assertEq(dsc.allowance(user, spender), 500e6);
        vm.stopPrank();
    }

    function testPermitExpired() public {
        vm.startPrank(user);
        uint256 nonces = dsc.nonces(user);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = PermitHelper.digest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            nonces,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.expectRevert("StableCoinV1: permit is expired");
        vm.warp(block.timestamp + 2 hours);
        dsc.permit(user, spender, 500e6, deadline, v, r, s);
        vm.stopPrank();
    }

}
