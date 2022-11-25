// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { DeploymentHelper } from "script/utils/DeploymentHelper.sol";
import { VoltronGobblers } from "src/VoltronGobblers.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";

contract DeployMainnetScript is Script {
    address immutable ownerAddr = 0xF57C58400732E5693D9967bf4c1138095762d8f5;
    address immutable minterAddr = 0x47f8f7AdD6bBaFDd0C28782B5912dB1b9A37bDcf;

    address immutable gobblersAddr = 0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769;
    address immutable gooAddr = 0x600000000a36F3cD48407e35eB7C5c910dc1f7a8;
    address immutable pagesAddr = 0x600Df00d3E42F885249902606383ecdcb65f2E02;

    address immutable gooberAddr = 0x2275d4937b6bFd3c75823744d3EfBf6c3a8dE473;

    address immutable linkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address immutable vrfCoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
    address immutable randProvider = 0xe901e31B756a69ABE8Bb0FD37B5aa02a9173a4dC;
    address immutable team = 0xE974159205528502237758439da8c4dcc03D3023;
    address immutable community = 0xDf2aAeead21Cf2BFF3965E858332aC8c8364E991;
    address immutable governor = 0x2719E6FdDd9E33c077866dAc6bcdC40eB54cD4f7;

    address proxyAdminAddr;
    address proxyAddr;

    TransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    VoltronGobblers voltron;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        voltron = new VoltronGobblers();

        proxyAdminAddr = DeploymentHelper.loadDeployAddress(".proxyAdmin");
        proxyAddr = DeploymentHelper.loadDeployAddress(".voltron");

        if (!Address.isContract(proxyAdminAddr)) {
            proxyAdmin = new ProxyAdmin();
            proxyAdmin.transferOwnership(ownerAddr);
        } else {
            proxyAdmin = ProxyAdmin(payable(proxyAdminAddr));
        }

        if (!Address.isContract(proxyAddr)) {
            proxy = new TransparentUpgradeableProxy(address(voltron), address(proxyAdmin), "");
            VoltronGobblers(proxyAddr).initialize(ownerAddr, minterAddr, gobblersAddr, gooAddr, gooberAddr, 3 days);
        } else {
            proxy = TransparentUpgradeableProxy(payable(proxyAddr));
        }

        vm.stopBroadcast();
        console.log("Voltron", proxyAddr);
        console.log("proxyAdmin", address(proxyAdmin));
        console.log("implementation", address(voltron));
        console.log("ownerAddr", ownerAddr);
        console.log("minterAddr", minterAddr);

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
        data = string.concat(data, "\"goober\":\"", vm.toString(gooberAddr), "\",");
        data = string.concat(data, "\"voltron\":\"", vm.toString(proxyAddr), "\",");
        data = string.concat(data, "\"proxyAdmin\":\"", vm.toString(address(proxyAdmin)), "\",");
        data = string.concat(data, "\"implementation\":\"", vm.toString(address(voltron)), "\"");

        data = string.concat(data, "}");

        vm.writeFile(path, data);
    }
}
