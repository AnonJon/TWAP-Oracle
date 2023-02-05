//SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import {UniswapV2TWAPOracle} from "./UniswapV2TWAPOracle.sol";
import {IUniswapV2TWAPFactory} from "./interfaces/IUniswapV2TWAPFactory.sol";
import {IUniswapV2TWAPOracle} from "./interfaces/IUniswapV2TWAPOracle.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {OracleBeacon} from "./upgrades/OracleBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapV2TWAPFactory is IUniswapV2TWAPFactory, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public instanceCounter;
    OracleBeacon public immutable beacon;
    mapping(address => Instance) public instances;
    mapping(address => bool) public isInstance;

    struct Instance {
        BeaconProxy proxy;
        address owner;
    }

    modifier isAuthorized(address user) {
        if (user == address(0)) {
            revert ZeroAddress();
        }
        if (!(msg.sender == user || msg.sender == owner())) {
            revert Unauthorized();
        }
        _;
    }

    modifier hasAnInstance(address user) {
        if (isInstance[user]) {
            revert InstanceAlreadyInitialized();
        }
        _;
    }

    constructor(address bluePrint, string memory version) {
        beacon = new OracleBeacon(bluePrint, version);
    }

    /**
     * @notice Creates a new instance of the UniswapV2TWAPOracle contract.
     * @param admin The address of who will own the contract.
     * @param factory The address of the UniswapV2Factory contract.
     * @param keeperAddress The address of the keeper registry contract.
     * @return The address of the new instance.
     */
    function createTWAPOracle(address admin, address factory, address keeperAddress)
        external
        hasAnInstance(admin)
        returns (address)
    {
        BeaconProxy proxy = new BeaconProxy(address(beacon), abi.encodeCall(
                IUniswapV2TWAPOracle.initialize,
                (factory,
                keeperAddress,
                admin)
            ));

        Instance storage newTenant = instances[admin];
        newTenant.proxy = proxy;
        newTenant.owner = admin;
        isInstance[admin] = true;
        instances[admin] = newTenant;
        instanceCounter.increment();

        emit InstanceCreated(admin, address(proxy));

        return address(proxy);
    }

    /**
     * @notice Updates the beacon with a new implementation.
     * @param newBlueprint The address of the new implementation.
     * @param updatedVersion The version of the new implementation.
     */
    function updateBeaconInstance(address newBlueprint, string calldata updatedVersion) external onlyOwner {
        beacon.update(newBlueprint, updatedVersion);
    }

    /**
     * @notice Returns the address of an instance.
     * @param instanceOwner The address of the contract owner.
     */
    function getInstance(address instanceOwner) external view returns (address) {
        if (!isInstance[instanceOwner]) {
            revert InstanceDoesNotExist();
        }
        return address(instances[instanceOwner].proxy);
    }

    /**
     * @notice Returns the current implementation address of the beacon.
     */
    function getImplementation() external view returns (address) {
        return beacon.implementation();
    }

    /**
     * @notice Returns the current version of the beacon.
     */
    function getCurrentVersion() external view returns (string memory) {
        return beacon.getVersion();
    }
}
