// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {AuthHelper} from "../helper/AuthHelper.sol";

contract DSC_ReceiveAuth_3009_Test is Test {
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
            dsc.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(),
            AuthHelper.RECEIVE_WITH_AUTHORIZATION_TYPEHASH
        );
    }

    function testReceiveWithAuthorization() public {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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

    function testRevertsIfTheCallerIsNotThePayee() public {
        vm.startPrank(charlie);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        vm.expectRevert("StableCoinV1: caller is not the payee");
        dsc.receiveWithAuthorization(
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

    function testRevertIfTheSignatureDoesNotMuchGivenParameters() public {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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

    function testreceiveAuthExpired() public {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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

    function testreceiveAuthIsNotYetValid() public {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime + 1 days;
        uint256 vaildBefore = currentTime + 2 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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

    function testreceiveAuthReusedNonce() public {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 2 days;
        bytes32 digest = AuthHelper.receiveDigest(
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

        dsc.receiveWithAuthorization(
            user,
            spender,
            500e6,
            vaildAfter,
            vaildBefore,
            nonces,
            abi.encodePacked(r, s, v)
        );
        vm.expectRevert("StableCoinV1: authorization is used or canceled");
        dsc.receiveWithAuthorization(
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

    function testRevertsIftheAuthorizationIncludesInvalidreceiveParameters()
        public
    {
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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
        vm.startPrank(spender);
        bytes32 nonces = keccak256("auth-1");
        uint256 currentTime = block.timestamp;
        uint256 vaildAfter = currentTime;
        uint256 vaildBefore = currentTime + 1 days;
        bytes32 digest = AuthHelper.receiveDigest(
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
        dsc.receiveWithAuthorization(
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
