pragma solidity ^0.8.20;
import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract CreateBadUser is Script {
    function run() external {
        vm.startBroadcast();

        address engineAddress = 0x9E7088C23e5C0B2D02cD7886A1BDbC7FE8b71016;
        DSCEngine engine = DSCEngine(engineAddress);

        address userAddress = 0x544eAe853EA3774A8857573C6423E6Db95b79258;

        engine.depositCollateralAndMintDsc(userAddress, 1 ether, 1500e18);

        vm.stopBroadcast();
    }
}
