// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {UniswapV2TWAPOracle} from "../contracts/UniswapV2TWAPOracle.sol";
import {UniswapV2TWAPFactory} from "../contracts/UniswapV2TWAPFactory.sol";

contract UniswapV2TWAPFactoryScript is Script {
    UniswapV2TWAPOracle blueprint;
    UniswapV2TWAPFactory factory;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        blueprint = new UniswapV2TWAPOracle();

        factory = new UniswapV2TWAPFactory(address(blueprint), "1.0.0");

        vm.stopBroadcast();
    }
}
