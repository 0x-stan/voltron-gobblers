// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { VoltronGobblers } from "src/VoltronGobblers.sol";

contract DeployMainnetScript is Script {
    address public immutable ownerAddr = 0xF57C58400732E5693D9967bf4c1138095762d8f5;
    address public immutable gobblersAddr = 0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769;
    address public immutable gooAddr = 0x600000000a36F3cD48407e35eB7C5c910dc1f7a8;
    address public immutable pagesAddr = 0x600Df00d3E42F885249902606383ecdcb65f2E02;

    address public immutable linkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public immutable vrfCoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
    address public immutable randProvider = 0xe901e31B756a69ABE8Bb0FD37B5aa02a9173a4dC;
    address public immutable team = 0xE974159205528502237758439da8c4dcc03D3023;
    address public immutable community = 0xDf2aAeead21Cf2BFF3965E858332aC8c8364E991;
    address public immutable governor = 0x2719E6FdDd9E33c077866dAc6bcdC40eB54cD4f7;

    VoltronGobblers voltron;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        voltron = new VoltronGobblers(ownerAddr, gobblersAddr, gooAddr, 3 days);

        vm.stopBroadcast();
        console.log("Voltron", address(voltron));
        console.log("ownerAddr", ownerAddr);

        logDeployedAddresses();
    }

    function logDeployedAddresses() internal {
        string memory network = "goerli";
        if (block.chainid == 1) network = "mainnet";

        string memory path = string.concat("./deployment.", network, ".json");
        string memory data = "{";

        data = string.concat(data, "\"linkToken\":\"", vm.toString(linkToken), "\",");
        data = string.concat(data, "\"vrfCoordinator\":\"", vm.toString(vrfCoordinator), "\",");
        data = string.concat(data, "\"team\":\"", vm.toString(team), "\",");
        data = string.concat(data, "\"community\":\"", vm.toString(community), "\",");
        data = string.concat(data, "\"randProvider\":\"", vm.toString(randProvider), "\",");
        data = string.concat(data, "\"goo\":\"", vm.toString(gooAddr), "\",");
        data = string.concat(data, "\"gobblers\":\"", vm.toString(gobblersAddr), "\",");
        data = string.concat(data, "\"pages\":\"", vm.toString(pagesAddr), "\",");
        data = string.concat(data, "\"voltron\":\"", vm.toString(address(voltron)), "\"");

        data = string.concat(data, "}");

        vm.writeFile(path, data);
    }
}
