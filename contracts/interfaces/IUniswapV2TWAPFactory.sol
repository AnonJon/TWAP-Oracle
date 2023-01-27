//SPDX-License-Identifier: MIT
pragma solidity <=0.8.17;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

interface IUniswapV2TWAPFactory {
    event InstanceCreated(address admin, address proxy);

    error Unauthorized();
    error InstanceAlreadyInitialized();
    error InstanceDoesNotExist();
    error ZeroAddress();

    function createTWAPOracle(address admin, address factory, address keeperAddress) external;
    function updateBeaconInstance(address newBlueprint, string calldata updatedVersion) external;
    function getInstance(address instanceOwner) external view returns (BeaconProxy);
    function getImplementation() external view returns (address);
    function getCurrentVersion() external view returns (string memory);
}
