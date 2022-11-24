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

    function testDepositGobblers() public {
        uint256 gobblersNum = 2;

        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        (uint32 userGobblersOwnedBefore, uint32 userEmissionMultipleBefore,,,,) = voltronProxy.getUserData(users[0]);

        deposit(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(voltronProxy)), gobblersNum);
        assertEq(gobblers.balanceOf(users[0]), 0);

        uint32 sumEmissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), address(voltronProxy));
            assertEq(voltronProxy.getUserByGobblerId(gobblerIds[i]), users[0]);
            (,, uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[i]);
            sumEmissionMultiple += emissionMultiple;
        }

        (uint32 userGobblersOwnedAfter, uint32 userEmissionMultipleAfter,,,,) = voltronProxy.getUserData(users[0]);
        assertEq(userGobblersOwnedBefore + gobblersNum, userGobblersOwnedAfter);
        assertEq(userEmissionMultipleBefore + sumEmissionMultiple, userEmissionMultipleAfter);

        (uint32 totalGobblersDeposited, uint32 totalEmissionMultiple,,) = voltronProxy.globalData();
        assertEq(totalGobblersDeposited, gobblersNum);
        assertEq(totalEmissionMultiple, sumEmissionMultiple);
    }

    function deposit(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        gobblers.setApprovalForAll(address(voltronProxy), true);
        voltronProxy.depositGobblers(gobblerIds, 0);
        vm.stopPrank();
    }
}
