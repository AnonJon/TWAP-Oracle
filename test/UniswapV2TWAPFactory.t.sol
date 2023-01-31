// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/UniswapV2TWAPOracle.sol";
import "../contracts/UniswapV2TWAPFactory.sol";

contract UniswapV2TWAPFactoryTest is Test {
    UniswapV2TWAPOracle oracle;
    UniswapV2TWAPFactory factory;
    address uniswapV2Factory;
    address admin;

    event InstanceCreated(address admin, address proxy);

    error InstanceDoesNotExist();

    function setUp() public {
        uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
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
}
