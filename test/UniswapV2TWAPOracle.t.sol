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
    address twapFactory;

    event JobDeleted(uint256 indexed jobID);
    event JobCreated(uint256 indexed jobID);
    event JobExecuted(uint256 indexed jobID, uint256 timestamp);

    error PairNotFound(address token0, address token1);

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"));
        token0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        twapFactory = address(0);
        admin = makeAddr("admin");
    }

    function forkFixture() public {
        vm.selectFork(mainnetFork);
        vm.rollFork(16_461_853);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        vm.label(address(oracle), "oracle");
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);
        oracle.createJob(token1, token0, periodSize, granularity);
    }

    function test_create_CreatesJob(uint104 _granularity) public {
        vm.assume(_granularity > 1);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);

        vm.expectEmit(true, true, true, true);
        emit JobCreated(1);
        oracle.createJob(token1, token0, periodSize, _granularity);
    }

    function testRevert_create_CreateJobFail() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);

        vm.expectRevert();
        oracle.createJob(token1, token0, periodSize, 1);
    }

    function testRevert_create_PairNotFound() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);

        vm.expectRevert(abi.encodeWithSelector(PairNotFound.selector, token1, token1));
        oracle.createJob(token1, token1, periodSize, 2);
    }

    function test_update_UpdatesJob(uint104 _granularity, uint104 _periodSize) public {
        vm.assume(_granularity > 1);
        vm.assume(_periodSize > 0);
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);
        oracle.createJob(token1, token0, periodSize, granularity);
        oracle.updateJob(1, _periodSize, _granularity);
    }

    function test_delete_DeletesJob() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);
        oracle.createJob(token1, token0, periodSize, granularity);

        vm.expectEmit(true, true, true, true);
        emit JobDeleted(1);
        oracle.deleteJob(1);
        assertEq(oracle.getActiveJobIDs().length, 0);
    }

    function testRevert_delete_DeleteNonExistantJob() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);
        oracle.createJob(token1, token0, periodSize, granularity);

        vm.expectRevert();
        oracle.deleteJob(2);
    }

    function testForkRevert_queryPrice_QueryPriceWithZeroValue() public {
        vm.startPrank(admin);
        oracle = new UniswapV2TWAPOracle();
        oracle.initialize(uniswapV2Factory, admin, admin, twapFactory);

        vm.expectRevert();
        oracle.queryPrice(1, token1, 0, token0);
    }

    function testFork_queryPrice_QuerysData() public {
        forkFixture();
        vm.warp(block.timestamp + 100);
        oracle.performUpkeep(abi.encode(1));

        vm.warp(block.timestamp + 100);
        oracle.performUpkeep(abi.encode(1));
        oracle.queryPrice(1, token1, 1 ether, token0);
    }

    function testFork_performUpkeep_RunUpkeep() public {
        forkFixture();
        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, true, true, true);
        emit JobExecuted(1, block.timestamp);
        oracle.performUpkeep(abi.encode(1));
    }
}
