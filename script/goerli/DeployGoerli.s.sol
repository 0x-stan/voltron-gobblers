// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MockArtGobblersDeployHelper } from "../utils/MockArtGobblersDeployHelper.sol";
import { VoltronGobblers } from "src/VoltronGobblers.sol";

contract DeployGoerliScript is MockArtGobblersDeployHelper {
    address public immutable ownerAddr = 0xF57C58400732E5693D9967bf4c1138095762d8f5;
    address public immutable minterAddr = 0x47f8f7AdD6bBaFDd0C28782B5912dB1b9A37bDcf;

    VoltronGobblers voltron;

    function setUp() public override {
        super.setUp();
    }

    function run() public {
        vm.startBroadcast();

        deployArtGobblers();

        voltron = new VoltronGobblers();
        voltron.initialize(ownerAddr, minterAddr, address(gobblers), address(goo), address(goober), 3 days);

        logDeployedAddresses();

        vm.stopBroadcast();
    }

    function logDeployedAddresses() internal {
        string memory network = "goerli";
        if (block.chainid == 1) network = "mainnet";

        string memory path = string.concat("./deployment.", network, ".json");
        string memory data = "{";

        data = string.concat(data, "\"linkToken\":\"", vm.toString(address(linkToken)), "\",");
        data = string.concat(data, "\"vrfCoordinator\":\"", vm.toString(address(vrfCoordinator)), "\",");
        data = string.concat(data, "\"team\":\"", vm.toString(address(team)), "\",");
        data = string.concat(data, "\"community\":\"", vm.toString(address(community)), "\",");
        data = string.concat(data, "\"randProvider\":\"", vm.toString(address(randProvider)), "\",");
        data = string.concat(data, "\"goo\":\"", vm.toString(address(goo)), "\",");
        data = string.concat(data, "\"gobblers\":\"", vm.toString(address(gobblers)), "\",");
        data = string.concat(data, "\"pages\":\"", vm.toString(address(pages)), "\",");
        data = string.concat(data, "\"voltron\":\"", vm.toString(address(voltron)), "\"");

        data = string.concat(data, "}");

        vm.writeFile(path, data);
    }
}
