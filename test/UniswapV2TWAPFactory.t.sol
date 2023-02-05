// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/UniswapV2TWAPOracle.sol";
import "../contracts/UniswapV2TWAPFactory.sol";
import "../contracts/Mock/MockUniswapV2TWAPOracle.sol";

contract UniswapV2TWAPFactoryTest is Test {
    UniswapV2TWAPOracle oracle;
    MockUniswapV2TWAPOracle mockOracle;
    UniswapV2TWAPFactory factory;
    address uniswapV2Factory;
    address admin;
    address token0;
    address token1;
    uint256 mainnetFork;

    event InstanceCreated(address admin, address proxy);

    error InstanceDoesNotExist();

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"));
        uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        token0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        admin = makeAddr("admin");
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        factory = new UniswapV2TWAPFactory(address(oracle), "v0.0.1");
        vm.stopPrank();
    }

    function test_contructor_SetsOwner() public {
        assertEq(factory.owner(), admin);
    }

    function test_createTWAPOracle_CreateNewOracle() public {
        vm.expectEmit(true, true, true, true);
        emit InstanceCreated(admin, 0xc92122fe7f2Bde6e05fe6C0b215c8927C9E8549e);
        factory.createTWAPOracle(admin, uniswapV2Factory, admin);
    }

    function testRevert_getInstance_InstanceDoesntExist() public {
        vm.expectRevert(InstanceDoesNotExist.selector);
        factory.getInstance(makeAddr("non-existent"));
    }

    function test_getImplementation_ReturnsImplementation() public {
        assertEq(factory.getImplementation(), address(oracle));
    }

    function test_updateBeaconInstance_UpdatesImplementation() public {
        vm.startPrank(admin);
        UniswapV2TWAPOracle newOracle = new UniswapV2TWAPOracle();
        factory.updateBeaconInstance(address(newOracle), "v.0.0.2");
        assertEq(factory.getImplementation(), address(newOracle));
    }

    function test_proxy_RevertIfNotOwner() public {
        address random = makeAddr("random");
        vm.prank(admin);
        factory.createTWAPOracle(admin, uniswapV2Factory, admin);
        UniswapV2TWAPOracle p1 = UniswapV2TWAPOracle(factory.getInstance(admin));
        vm.prank(random);
        vm.expectRevert();
        p1.deleteJob(1);
    }

    function testFork_proxy_StateStaysAfterUpdate() public {
        vm.startPrank(admin);
        factory.createTWAPOracle(admin, uniswapV2Factory, admin);
        UniswapV2TWAPOracle p1 = UniswapV2TWAPOracle(factory.getInstance(admin));
        p1.createJob(token1, token0, 86400, 2);
        assertEq(p1.getVersion(), "v0.0.1");

        MockUniswapV2TWAPOracle newOracle = new MockUniswapV2TWAPOracle();
        factory.updateBeaconInstance(address(newOracle), "v0.0.2");
        assertEq(p1.getVersion(), "v0.0.2");

        uint256[] memory jobs = p1.getActiveJobIDs();
        assertEq(jobs[0], 1);
    }
}
