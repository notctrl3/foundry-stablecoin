// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DecentralizedStableCoinProxy} from "../src/DecentralizedStableCoinProxy.sol";
import {DSCEngineProxy} from "../src/DSCEngineProxy.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run()
        external
        returns (DecentralizedStableCoin, DSCEngine, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        address deployAddress = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);

        // ----------------------------------------------------
        // 1. Deploy DSC logic + proxy
        // ----------------------------------------------------
        DecentralizedStableCoin dscLogic = new DecentralizedStableCoin();
        DecentralizedStableCoinProxy dscProxy = new DecentralizedStableCoinProxy(
                address(dscLogic)
            );

        // dsc initialize()
        bytes memory dscInitData = abi.encodeWithSelector(
            DecentralizedStableCoin.initialize.selector,
            "dsc",
            "USD",
            6,
            deployAddress, // pauser
            deployAddress // owner
        );
        dscProxy.upgradeToAndCall(address(dscLogic), dscInitData);

        // cast proxy to DSC type
        DecentralizedStableCoin dsc = DecentralizedStableCoin(
            address(dscProxy)
        );

        // ----------------------------------------------------
        // 2. Deploy DSCEngine logic + proxy
        // ----------------------------------------------------
        DSCEngine dscEngineLogic = new DSCEngine();
        DSCEngineProxy dscEngineProxy = new DSCEngineProxy(
            address(dscEngineLogic)
        );

        // dscEngine initialize()
        bytes memory engineInitData = abi.encodeWithSelector(
            DSCEngine.initialize.selector,
            tokenAddresses,
            priceFeedAddresses,
            address(dscProxy)
        );
        dscEngineProxy.upgradeToAndCall(
            address(dscEngineLogic),
            engineInitData
        );

        // cast proxy to DSCEngine type
        DSCEngine dscEngine = DSCEngine(address(dscEngineProxy));

        // -------------------------------
        // 3. Transfer DSC ownership to Engine proxy
        // -------------------------------
        dsc.transferOwnership(address(dscEngineProxy));

        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }
}
