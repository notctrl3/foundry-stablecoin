// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {AuthHelper} from "../helper/AuthHelper.sol";

contract DSC_TransferAuth_3009_Test is Test {
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
            dsc.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(),
            AuthHelper.TRANSFER_WITH_AUTHORIZATION_TYPEHASH
        );
    }

    function testTransferWithAuthorization() public {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 1 seconds);
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        assertEq(dsc.balanceOf(spender), 500e6);
        vm.stopPrank();
    }

    function testRevertIfTheSignatureDoesNotMuchGivenParameters() public {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 1 seconds);
        vm.expectRevert("StableCoinV1: EIP2612 invalid signature");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6 * 2,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testRevertIfTheSignatureIsNotSignedWithTheRightKey() public {
        vm.startPrank(charlie);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            bob,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);
        vm.warp(currentTime + 1 seconds);
        vm.expectRevert("StableCoinV1: EIP2612 invalid signature");
        dsc.transferWithAuthorization(
            user,
            bob,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testTransferAuthExpired() public {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 3 days);
        vm.expectRevert("StableCoinV1: authorization is expired");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testTransferAuthIsNotYetValid() public {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime + 1 days;
        uint256 vaildBefore = currentTime + 2 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.expectRevert("StableCoinV1: authorization is not yet valid");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testTransferAuthReusedNonce() public {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 2 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 1 seconds);

        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.expectRevert("StableCoinV1: authorization is used or canceled");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testRevertsIftheAuthorizationIncludesInvalidTransferParameters()
        public
    {
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 1 seconds);
        vm.expectRevert("StableCoinV1: EIP2612 invalid signature");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6 + 1,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }

    function testRevertsIftheContractIsPaused() public {
        vm.prank(pauser);
        dsc.pause();
        vm.startPrank(user);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.transferDigest(
            dsc.DOMAIN_SEPARATOR(),
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        vm.warp(currentTime + 1 seconds);
        vm.expectRevert("Pausable: paused");
        dsc.transferWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.stopPrank();
    }
}
