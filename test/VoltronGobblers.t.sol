// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console2 } from "forge-std/console2.sol";

import { VoltronGobblers } from "src/VoltronGobblers.sol";
import { ArtGobblers, FixedPointMathLib } from "2022-09-artgobblers/src/ArtGobblers.sol";
import { ArtGobblersDeployHelper } from "./utils/ArtGobblersDeployHelper.sol";

contract VoltronGobblersTest is ArtGobblersDeployHelper {
    using FixedPointMathLib for uint256;

    VoltronGobblers voltron;

    function setUp() public {
        deployArtGobblers();
        vm.warp(block.timestamp + 1 days);
        voltron = new VoltronGobblers(msg.sender, address(gobblers), address(goo));
    }

    function testArtGobblersAddr() public {
        assertEq(voltron.artGobblers(), address(gobblers));
    }

    function testDepositGobblers() public {
        uint256 gobblersNum = 2;

        uint256[] memory gobblerIds = mintGobblers(users[ 0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        deposit(users[ 0], gobblerIds);

        assertEq(gobblers.balanceOf(address(voltron)), gobblersNum);
        assertEq(gobblers.balanceOf(users[ 0]), 0);

        uint32 sumEmissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[ i]), address(voltron));
            assertEq(voltron.getUserByGobblerId(gobblerIds[ i]), users[ 0]);
            (,, uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[ i]);
            sumEmissionMultiple += emissionMultiple;
        }

        uint32 totalGobblersOwned;
        uint32 totalEmissionMultiple;
        uint128 totalVirtualBalance;

        (totalGobblersOwned, totalEmissionMultiple, totalVirtualBalance,) = voltron.globalData();
        assertEq(totalGobblersOwned, gobblersNum);
        assertEq(totalEmissionMultiple, sumEmissionMultiple);
    }

    function testWithdrawGobblers() public {
        uint256 gobblersNum = 2;
        uint256[] memory gobblerIds = mintGobblers(users[ 0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        deposit(users[ 0], gobblerIds);
        withraw(users[ 0], gobblerIds);

        assertEq(gobblers.balanceOf(address(voltron)), 0);
        assertEq(gobblers.balanceOf(users[ 0]), gobblersNum);
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[ i]), users[ 0]);
            assertEq(voltron.getUserByGobblerId(gobblerIds[ i]), address(0));
        }
    }

    function testMintVoltronGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds = mintGobblers(users[ 0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        deposit(users[ 0], gobblerIds);

        vm.warp(block.timestamp + 5 days);

        voltron.mintVoltronGobblers(type(uint256).max, 1);

        uint256 voltronGobblerId = voltron.claimableGobblers(0);
        bool claimed = voltron.gobblersClaimed(0);

        assertFalse(claimed);
        assertEq(gobblers.ownerOf(voltronGobblerId), address(voltron));
    }

    function testClaimVoltronGobblersFuzz(uint32 percent) public {
        // the percent of users[0] deposit of total 100
        uint256 percentOne = type(uint32).max / 100;
        vm.assume(percent > percentOne && percent < percentOne * 99);
        uint256 gobblersNum0 = uint256(percent).divWadDown(type(uint32).max).mulWadDown(100);
        uint256 gobblersNum1 = 100 - gobblersNum0;

        uint256[] memory gobblerIds0 = mintGobblers(users[ 0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[ 1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[ 0], gobblerIds0);
        deposit(users[ 1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        // try to mint most voltron gobblers
        uint256 totalMintNum;
        for (uint256 i = 0;; i++) {
            // voltron.mintVoltronGobblers(type(uint256).max, 1);
            try voltron.mintVoltronGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }

        voltron.updateGlobalBalance();

        uint256 virtualBalance0 = voltron.gooBalance(users[ 0]);
        (,, uint128 virtualBalanceTotal,) = voltron.globalData();
        uint256 claimNum = virtualBalance0.divWadDown(virtualBalanceTotal).mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        uint256 snapshotId = vm.snapshot();

        // shuold claimable
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[ i] = voltron.claimableGobblers(i);
        }
        vm.startPrank(users[ 0]);
        voltron.claimVoltronGobblers(claimIds);
        (,,, uint64 claimedNum,) = voltron.getUserData(users[ 0]);
        assertEq(claimedNum, claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            assertEq(gobblers.ownerOf(claimIds[ i]), users[ 0]);
        }
        vm.stopPrank();
        vm.revertTo(snapshotId);

        // can't claim over max claimable number of user
        uint256 claimNumOvered = claimNum + 1;
        claimIds = new uint256[](claimNumOvered);
        for (uint256 i = 0; i < claimNumOvered; i++) {
            claimIds[ i] = voltron.claimableGobblers(i);
        }
        vm.startPrank(users[ 0]);
        vm.expectRevert("CLAIM_TOO_MORE");
        voltron.claimVoltronGobblers(claimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);
    }

    function testClaimVoltronGobblersAfterWidraw() public {
        uint256 gobblersNum0 = 50;
        uint256 gobblersNum1 = 50;

        uint256[] memory gobblerIds0 = mintGobblers(users[ 0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[ 1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[ 0], gobblerIds0);
        deposit(users[ 1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        // try to mint most voltron gobblers
        uint256 totalMintNum;
        for (uint256 i = 0;; i++) {
            // voltron.mintVoltronGobblers(type(uint256).max, 1);
            try voltron.mintVoltronGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }

        voltron.updateGlobalBalance();

        uint256 virtualBalance0 = voltron.gooBalance(users[ 0]);
        (,, uint128 virtualBalanceTotal,) = voltron.globalData();
        uint256 claimNum = virtualBalance0.divWadDown(virtualBalanceTotal).mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        uint256 snapshotId = vm.snapshot();

        // should claimable after withdraw
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[ i] = voltron.claimableGobblers(i);
        }

        vm.startPrank(users[ 0]);
        voltron.withdrawGobblers(gobblerIds0);
        voltron.claimVoltronGobblers(claimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);

        // claimable number shuold decrease after time pasted
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[ i] = voltron.claimableGobblers(i);
        }
        vm.startPrank(users[ 0]);
        voltron.withdrawGobblers(gobblerIds0);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("CLAIM_TOO_MORE");
        voltron.claimVoltronGobblers(claimIds);

        uint256[] memory newClaimIds = new uint256[](claimNum-5);
        for (uint256 i = 0; i < claimNum - 5; i++) {
            newClaimIds[ i] = voltron.claimableGobblers(i);
        }
        voltron.claimVoltronGobblers(newClaimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);
    }

    function testClaimVoltronGoo() public {
        uint256 gobblersNum0 = 5;
        uint256 gobblersNum1 = 5;

        uint256[] memory gobblerIds0 = mintGobblers(users[ 0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[ 1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[ 0], gobblerIds0);
        deposit(users[ 1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        voltron.mintVoltronGobblers(type(uint256).max, 2);

        voltron.updateGlobalBalance();

        uint256[] memory claimIds = new uint256[](1);

        vm.startPrank(users[ 0]);
        voltron.withdrawGobblers(gobblerIds0);
        claimIds[ 0] = voltron.claimableGobblers(0);
        voltron.claimVoltronGobblers(claimIds);
        vm.stopPrank();

        // just in case round down cause "CLAIM_TOO_MORE"
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(users[ 1]);
        voltron.withdrawGobblers(gobblerIds1);
        claimIds[ 0] = voltron.claimableGobblers(1);
        voltron.claimVoltronGobblers(claimIds);
        vm.stopPrank();

        vm.startPrank(voltron.owner());
        voltron.setMintLock(true);
        voltron.setClaimGooLock(false);
        vm.stopPrank();

        uint256 voltronGoo = gobblers.gooBalance(address(voltron));

        vm.startPrank(users[ 0]);
        uint256 claimGoo0 = goo.balanceOf(users[ 0]);
        voltron.claimVoltronGoo();
        claimGoo0 = goo.balanceOf(users[ 0]) - claimGoo0;
        vm.stopPrank();

        vm.startPrank(users[ 1]);
        uint256 claimGoo1 = goo.balanceOf(users[ 1]);
        voltron.claimVoltronGoo();
        claimGoo1 = goo.balanceOf(users[ 1]) - claimGoo1;
        vm.stopPrank();

        uint256 sumClaimGoo = claimGoo0 + claimGoo1;
        uint256 lastGoo = (voltronGoo - sumClaimGoo).divWadDown(sumClaimGoo);
        assertTrue(lastGoo < 5e16);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    function deposit(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        for (uint256 i = 0; i < gobblerIds.length; i++) {
            gobblers.approve(address(voltron), gobblerIds[ i]);
        }
        voltron.depositGobblers(gobblerIds);
        vm.stopPrank();
    }

    function withraw(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        voltron.withdrawGobblers(gobblerIds);
        vm.stopPrank();
    }
}