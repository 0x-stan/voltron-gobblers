// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { ArtGobblers, FixedPointMathLib } from "art-gobblers/ArtGobblers.sol";

import { VoltronGobblers } from "../src/VoltronGobblers.sol";
import { ArtGobblersDeployHelper } from "./utils/ArtGobblersDeployHelper.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeableProxyTest is ArtGobblersDeployHelper {
    using FixedPointMathLib for uint256;

    address ownerAddr = address(0x10086);
    address minterAddr = address(0x1377);

    VoltronGobblers public voltron;
    VoltronGobblers public voltronProxy;
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public proxy;

    function setUp() public {
        deployArtGobblers();

        vm.warp(block.timestamp + 1 days);
        voltron = new VoltronGobblers();

        proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(ownerAddr);
        proxy = new TransparentUpgradeableProxy(address(voltron), address(proxyAdmin), "");
        voltronProxy = VoltronGobblers(address(proxy));

        voltronProxy.initialize(ownerAddr, minterAddr, address(gobblers), address(goo), address(goober), 3 days);
    }

    function testUpgradeable() public {
        address oldVoltronAddr = proxyAdmin.getProxyImplementation(proxy);
        address newVoltronAddr = address(new VoltronGobblers());

        vm.prank(ownerAddr);
        proxyAdmin.upgrade(proxy, newVoltronAddr);

        assertEq(proxyAdmin.getProxyImplementation(proxy), newVoltronAddr);
        assertTrue(oldVoltronAddr != newVoltronAddr);
    }

}
