// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {AuthHelper} from "../helper/AuthHelper.sol";
import {CommonHelper} from "../helper/Common.sol";

contract DSCCancelAuth3009Test is CommonHelper {
    DecentralizedStableCoin dsc;
    address owner = address(1);
    address pauser = address(2);
    address masterMinter = address(3);
    address minter1 = address(4);
    uint256 userPk = 0xA11CE;
    address user = vm.addr(userPk);
    address spender = address(6);
    uint256 bobPk = 0xB0B;
    address bob = vm.addr(bobPk);
    uint256 charliePk = 0xC141E;
    address charlie = vm.addr(charliePk);

    function setUp() public {
        dsc = new DecentralizedStableCoin();
        dsc.initialize("dsc", "dsc", "USD", 6, masterMinter, pauser, owner);
        vm.prank(masterMinter);
        dsc.configureMinter(minter1, 1_000_000e6);
        vm.prank(minter1);
        dsc.mint(user, 500e6);
    }

    function testHasTheExpectedTypeHash() public {
        assertEq(
            dsc.CANCEL_AUTHORIZATION_TYPEHASH(),
            AuthHelper.CANCEL_AUTHORIZATION_TYPEHASH
        );
    }

    function testCancelsUnusedTransferAuthorizationIfSignatureIsValid() public {
        vm.startPrank(spender);
        bytes32 nonces = _generateNonce("auth-1");
        assertEq(dsc.authorizationState(user, nonces), false);
        bytes32 cancelDigest = AuthHelper.cancelDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            nonces
        );
        dsc.cancelAuthorization(user, nonces, _sign(cancelDigest, userPk));
        assertEq(dsc.authorizationState(user, nonces), true);

        uint256 currentTime = block.timestamp;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            currentTime,
            currentTime + 1 days,
            nonces
        );
        vm.warp(currentTime + 1 seconds);
        vm.expectRevert("StableCoinV1: authorization is used or canceled");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            currentTime,
            currentTime + 1 days,
            nonces,
            _sign(digest, userPk)
        );
        vm.stopPrank();
    }

    function testRevertsIfTheAuthorizationHasAlreadyBeenCanceled() public {
        vm.startPrank(spender);
        bytes32 nonces = _generateNonce("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 transferDigest = AuthHelper.cancelDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            nonces
        );
        dsc.cancelAuthorization(user, nonces, _sign(transferDigest, userPk));
        vm.expectRevert("StableCoinV1: authorization is used or canceled");
        dsc.cancelAuthorization(user, nonces, _sign(transferDigest, userPk));
        vm.stopPrank();
    }

    function testRevertsIftheContractIsPaused() public {
        vm.prank(pauser);
        dsc.pause();
        vm.startPrank(user);
        bytes32 nonces = _generateNonce("auth-1");
        bytes32 transferDigest = AuthHelper.cancelDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            nonces
        );
        vm.expectRevert("Pausable: paused");
        dsc.cancelAuthorization(user, nonces, _sign(transferDigest, userPk));
        vm.stopPrank();
    }
}
