// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/UniswapV2TWAPOracle.sol";

contract UniswapV2TWAPOracleTest is Test {
    address token0;
    address token1;
    address uniswapV2Factory;
    address admin;
    UniswapV2TWAPOracle oracle;
    uint256 periodSize = 86400;
    uint256 granularity = 2;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"));
        token0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        admin = makeAddr("admin");
    }

    function testCreateJob(uint104 _granularity) public {
        vm.assume(_granularity > 1);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin);
        oracle.createJob(token1, token0, periodSize, _granularity);
    }

    function testUpdateJob(uint104 _granularity, uint104 _periodSize) public {
        vm.assume(_granularity > 1);
        vm.assume(_periodSize > 0);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin);
        oracle.createJob(token1, token0, periodSize, granularity);
        oracle.updateJob(1, _periodSize, _granularity);
    }

    function testDeleteJob() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin);
        oracle.createJob(token1, token0, periodSize, granularity);
        oracle.deleteJob(1);
        assertEq(oracle.getActiveJobIDs().length, 0);
    }

    function testForkQueryData() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin);
        oracle.createJob(token1, token0, periodSize, granularity);
        // oracle.performUpkeep(abi.encode(1));
    }
}
