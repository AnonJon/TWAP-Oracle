// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OracleBeacon is Ownable {
    UpgradeableBeacon beacon;
    string currentVersion;

    constructor(address initBlueprint, string memory version) {
        beacon = new UpgradeableBeacon(initBlueprint);
        currentVersion = version;
    }

    function update(address newBlueprint, string calldata updatedVersion) public onlyOwner {
        beacon.upgradeTo(newBlueprint);
        currentVersion = updatedVersion;
    }

    function implementation() public view returns (address) {
        return beacon.implementation();
    }

    function getVersion() public view returns (string memory) {
        return currentVersion;
    }
}
