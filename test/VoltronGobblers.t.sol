// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/console.sol";

import { VoltronGobblers } from "src/VoltronGobblers.sol";
import { ArtGobblers, FixedPointMathLib } from "art-gobblers/ArtGobblers.sol";
import { ArtGobblersDeployHelper } from "./utils/ArtGobblersDeployHelper.sol";

contract VoltronGobblersTest is ArtGobblersDeployHelper {
    using FixedPointMathLib for uint256;

    address minterAddr = address(0x1377);

    VoltronGobblers public voltron;

    function setUp() public {
        deployArtGobblers();

        vm.warp(block.timestamp + 1 days);
        voltron = new VoltronGobblers();
        voltron.initialize(msg.sender, minterAddr, address(gobblers), address(goo), address(goober), 3 days);

        vm.prank(voltron.owner());
        voltron.setMintLock(false);
    }

    function testArtGobblersAddr() public {
        assertEq(voltron.artGobblers(), address(gobblers));
    }

    function testDepositGobblers() public {
        uint256 gobblersNum = 2;

        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        (uint32 userGobblersOwnedBefore, uint32 userEmissionMultipleBefore,,,,) = voltron.getUserData(users[0]);

        deposit(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(voltron)), gobblersNum);
        assertEq(gobblers.balanceOf(users[0]), 0);

        uint32 sumEmissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), address(voltron));
            assertEq(voltron.getUserByGobblerId(gobblerIds[i]), users[0]);
            (,, uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[i]);
            sumEmissionMultiple += emissionMultiple;
        }

        (uint32 userGobblersOwnedAfter, uint32 userEmissionMultipleAfter,,,,) = voltron.getUserData(users[0]);
        assertEq(userGobblersOwnedBefore + gobblersNum, userGobblersOwnedAfter);
        assertEq(userEmissionMultipleBefore + sumEmissionMultiple, userEmissionMultipleAfter);

        (uint32 totalGobblersDeposited, uint32 totalEmissionMultiple,,) = voltron.globalData();
        assertEq(totalGobblersDeposited, gobblersNum);
        assertEq(totalEmissionMultiple, sumEmissionMultiple);
    }

    function testDepositGobblersWithGoo() public {
        uint256 gobblersNum = 2;
        uint256 gooAmount = 1e18;

        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        (uint32 userGobblersOwnedBefore, uint32 userEmissionMultipleBefore,,,,) = voltron.getUserData(users[0]);

        depositWithGoo(users[0], gobblerIds, gooAmount);

        assertEq(gobblers.balanceOf(address(voltron)), gobblersNum);
        assertEq(gobblers.balanceOf(users[0]), 0);

        assertEq(gobblers.gooBalance(address(voltron)), gooAmount);

        uint32 sumEmissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), address(voltron));
            assertEq(voltron.getUserByGobblerId(gobblerIds[i]), users[0]);
            (,, uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[i]);
            sumEmissionMultiple += emissionMultiple;
        }

        (uint32 userGobblersOwnedAfter, uint32 userEmissionMultipleAfter,,,,) = voltron.getUserData(users[0]);
        assertEq(userGobblersOwnedBefore + gobblersNum, userGobblersOwnedAfter);
        assertEq(userEmissionMultipleBefore + sumEmissionMultiple, userEmissionMultipleAfter);

        (uint32 totalGobblersDeposited, uint32 totalEmissionMultiple, uint128 totalVirtualBalance,) = voltron.globalData();
        assertEq(totalGobblersDeposited, gobblersNum);
        assertEq(totalEmissionMultiple, sumEmissionMultiple);
        assertEq(totalVirtualBalance, gooAmount);
    }

    function testAddGoo() public {
        uint256 gooAmount = 1e18;
        vm.warp(block.timestamp + 1 days);

        vm.prank(address(gobblers));
        goo.mintForGobblers(users[0], gooAmount);

        uint256 poolBalanceBefore = gobblers.gooBalance(address(voltron));
        uint256 totalVirtualBalanceBefore = voltron.globalGooBalance();
        (,, uint128 virtualBalanceBefore,,, uint48 lastGooDepositedTimestampBefore) = voltron.getUserData(users[0]);
        assertEq(lastGooDepositedTimestampBefore, 0);

        vm.startPrank(users[0]);
        goo.approve(address(voltron), gooAmount);
        voltron.addGoo(gooAmount);
        vm.stopPrank();

        (,, uint128 virtualBalanceAfter,,, uint48 lastGooDepositedTimestampAfter) = voltron.getUserData(users[0]);
        uint256 totalVirtualBalanceAfter = voltron.globalGooBalance();

        assertEq(poolBalanceBefore + gooAmount, gobblers.gooBalance(address(voltron)));
        assertEq(virtualBalanceBefore + gooAmount, virtualBalanceAfter);
        assertEq(totalVirtualBalanceBefore + gooAmount, totalVirtualBalanceAfter);
        assertEq(lastGooDepositedTimestampAfter, block.timestamp);
    }

    function testAddGooFuzz(uint256 gooAmount) public {
        vm.assume(gooAmount > 0);
        vm.assume(gooAmount < 1e32);
        vm.warp(block.timestamp + 1 days);

        vm.prank(address(gobblers));
        goo.mintForGobblers(users[0], gooAmount);

        uint256 poolBalanceBefore = gobblers.gooBalance(address(voltron));
        uint256 totalVirtualBalanceBefore = voltron.globalGooBalance();
        (,, uint128 virtualBalanceBefore,,, uint48 lastGooDepositedTimestampBefore) = voltron.getUserData(users[0]);
        assertEq(lastGooDepositedTimestampBefore, 0);

        vm.startPrank(users[0]);
        goo.approve(address(voltron), gooAmount);
        voltron.addGoo(gooAmount);
        vm.stopPrank();

        (,, uint128 virtualBalanceAfter,,, uint48 lastGooDepositedTimestampAfter) = voltron.getUserData(users[0]);
        uint256 totalVirtualBalanceAfter = voltron.globalGooBalance();

        assertEq(poolBalanceBefore + gooAmount, gobblers.gooBalance(address(voltron)));
        assertEq(virtualBalanceBefore + gooAmount, virtualBalanceAfter);
        assertEq(totalVirtualBalanceBefore + gooAmount, totalVirtualBalanceAfter);
        assertEq(lastGooDepositedTimestampAfter, block.timestamp);
    }

    function testWithdrawGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum);
        uint256[] memory gobblerIds2 = mintGobblers(users[2], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum * 3, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);
        deposit(users[2], gobblerIds2);

        (uint32 userGobblersOwnedBefore, uint32 userEmissionMultipleBefore,,,,) = voltron.getUserData(users[0]);
        (uint32 totalGobblersDepositedBefore, uint32 totalEmissionMultipleBefore,,) = voltron.globalData();

        vm.warp(block.timestamp + 5 days);
        withraw(users[0], gobblerIds0);
        vm.warp(block.timestamp + 5 days);
        withraw(users[1], gobblerIds1);
        withraw(users[2], gobblerIds2);

        assertEq(gobblers.balanceOf(address(voltron)), 0);
        assertEq(gobblers.balanceOf(users[0]), gobblersNum);

        uint256 sumEmissionMultiple;
        uint256 sumUserEmissionMultiple;
        uint32 emissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds0[i]), users[0]);
            assertEq(voltron.getUserByGobblerId(gobblerIds0[i]), address(0));
            (,, emissionMultiple) = gobblers.getGobblerData(gobblerIds0[i]);
            sumEmissionMultiple += emissionMultiple;
            sumUserEmissionMultiple += emissionMultiple;

            assertEq(gobblers.ownerOf(gobblerIds1[i]), users[1]);
            assertEq(voltron.getUserByGobblerId(gobblerIds1[i]), address(0));
            (,, emissionMultiple) = gobblers.getGobblerData(gobblerIds1[i]);
            sumEmissionMultiple += emissionMultiple;

            assertEq(gobblers.ownerOf(gobblerIds2[i]), users[2]);
            assertEq(voltron.getUserByGobblerId(gobblerIds2[i]), address(0));
            (,, emissionMultiple) = gobblers.getGobblerData(gobblerIds2[i]);
            sumEmissionMultiple += emissionMultiple;
        }

        (uint32 userGobblersOwnedAfter, uint32 userEmissionMultipleAfter,,,,) = voltron.getUserData(users[0]);
        assertEq(userGobblersOwnedBefore - gobblersNum, userGobblersOwnedAfter);
        assertEq(userEmissionMultipleBefore - sumUserEmissionMultiple, userEmissionMultipleAfter);

        (uint32 totalGobblersDepositedAfter, uint32 totalEmissionMultipleAfter,,) = voltron.globalData();
        assertEq(totalGobblersDepositedBefore - gobblersNum * 3, totalGobblersDepositedAfter);
        assertEq(totalEmissionMultipleBefore - sumEmissionMultiple, totalEmissionMultipleAfter);
    }

    function testMintGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        deposit(users[0], gobblerIds);

        vm.warp(block.timestamp + 5 days);

        voltron.mintGobblers(type(uint256).max, 1);

        uint256 voltronGobblerId = voltron.claimableGobblers(0);

        assertEq(voltron.claimableGobblersNum(), 1);
        assertEq(voltronGobblerId, gobblers.currentNonLegendaryId());
        assertTrue(voltron.gobblerClaimable(voltronGobblerId));
        assertEq(gobblers.ownerOf(voltronGobblerId), address(voltron));
    }

    function testUpdateGlobalBalance() public {
        uint256 sum = 0;
        uint256[] memory gobblersNums = new uint256[](3);
        gobblersNums[0] = 30;
        gobblersNums[1] = 20;
        gobblersNums[2] = 10;
        uint256[][] memory gobblersIds = new uint256[][](3);
        for (uint256 i = 0; i < gobblersNums.length; i++) {
            sum += gobblersNums[i];
            gobblersIds[i] = mintGobblers(users[i], gobblersNums[i]);
        }
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(sum, "seed");

        for (uint256 i = 0; i < gobblersNums.length; i++) {
            deposit(users[i], gobblersIds[i]);
        }

        vm.warp(block.timestamp + 5 days);

        uint256 gooSum;
        for (uint256 i = 0; i < gobblersNums.length; i++) {
            gooSum += voltron.gooBalance(users[i]);
        }
        assertEq(gooSum, voltron.globalGooBalance());

        gooSum = 0;
        uint256 lastId = gobblers.currentNonLegendaryId();
        voltron.mintGobblers(type(uint256).max, 2);
        vm.warp(block.timestamp + 5 days);
        for (uint256 i = 0; i < gobblersNums.length; i++) {
            gooSum += voltron.gooBalance(users[i]);
        }
        assertEq(gooSum, voltron.globalGooBalance());
        assertEq(voltron.claimableGobblersNum(), 2);
        assertEq(voltron.claimableGobblers(0), lastId + 1);
        assertEq(voltron.claimableGobblers(1), lastId + 2);

        gooSum = 0;
        voltron.mintGobblers(type(uint256).max, 3);
        vm.warp(block.timestamp + 5 days);
        for (uint256 i = 0; i < gobblersNums.length; i++) {
            gooSum += voltron.gooBalance(users[i]);
        }
        assertEq(gooSum, voltron.globalGooBalance());
        assertEq(voltron.claimableGobblersNum(), 2 + 3);
        assertEq(voltron.claimableGobblers(2), lastId + 3);
        assertEq(voltron.claimableGobblers(3), lastId + 4);
        assertEq(voltron.claimableGobblers(4), lastId + 5);
    }

    function testClaimVoltronGobblers() public {
        uint256 goblbersNum0 = 4;
        uint256 goblbersNum1 = 1;

        uint256 gooAmount = 69e18;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], goblbersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], goblbersNum1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(goblbersNum0 + goblbersNum1, "seed");

        deposit(users[0], gobblerIds0);
        vm.warp(block.timestamp + 3 days);

        depositWithGoo(users[1], gobblerIds1, gooAmount);

        vm.warp(block.timestamp + voltron.timeLockDuration() - 1);
        voltron.mintGobblers(type(uint256).max, 3);
        assertEq(voltron.claimableGobblersNum(), 3);
        assertTrue(voltron.gobblerClaimable(voltron.claimableGobblers(0)));
        assertTrue(voltron.gobblerClaimable(voltron.claimableGobblers(1)));
        assertTrue(voltron.gobblerClaimable(voltron.claimableGobblers(2)));

        vm.prank(users[0]);
        vm.expectRevert("GOBBLER_NOT_CLAIMABLE");
        voltron.claimGobblers(gobblerIds1);
        assertEq(voltron.claimableGobblersNum(), 3);
        assertFalse(voltron.gobblerClaimable(gobblerIds1[0]));

        uint256[] memory claimIds = new uint256[](1);
        claimIds[0] = voltron.claimableGobblers(0);
        vm.prank(users[0]);
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), 2);
        assertFalse(voltron.gobblerClaimable(claimIds[0]));

        claimIds[0] = voltron.claimableGobblers(1);

        vm.prank(users[1]);
        vm.expectRevert("CANT_CLAIM_NOW");
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), 2);
        assertTrue(voltron.gobblerClaimable(claimIds[0]));

        vm.warp(block.timestamp + 1);
        vm.prank(users[1]);
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), 1);
        assertFalse(voltron.gobblerClaimable(claimIds[0]));
    }

    function testClaimVoltronGobblersFuzz(uint32 percent) public {
        // the percent of users[0] deposit of total 100
        uint256 percentOne = type(uint32).max / 100;
        vm.assume(percent > percentOne && percent < percentOne * 99);
        uint256 gobblersNum0 = uint256(percent).divWadDown(type(uint32).max).mulWadDown(100);
        uint256 gobblersNum1 = 100 - gobblersNum0;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        // try to mint most voltron gobblers
        uint256 totalMintNum;
        for (uint256 i = 0;; i++) {
            try voltron.mintGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }
        assertEq(voltron.claimableGobblersNum(), totalMintNum);

        uint256 virtualBalance0 = voltron.gooBalance(users[0]);
        uint256 totalVirtualBalance = voltron.globalGooBalance();
        uint256 claimNum = virtualBalance0.divWadDown(totalVirtualBalance).mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        uint256 snapshotId = vm.snapshot();

        // shuold claimable
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = voltron.claimableGobblers(i);
        }
        vm.startPrank(users[0]);
        voltron.claimGobblers(claimIds);
        (,,, uint64 claimedNum,,) = voltron.getUserData(users[0]);
        assertEq(claimedNum, claimNum);
        assertEq(voltron.claimableGobblersNum(), totalMintNum - claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            assertEq(gobblers.ownerOf(claimIds[i]), users[0]);
        }
        vm.stopPrank();
        vm.revertTo(snapshotId);

        // can't claim over max claimable number of user
        uint256 claimNumOvered = claimNum + 1;
        claimIds = new uint256[](claimNumOvered);
        for (uint256 i = 0; i < claimNumOvered; i++) {
            claimIds[i] = voltron.claimableGobblers(i);
        }
        vm.startPrank(users[0]);
        vm.expectRevert("CLAIM_TOO_MUCH");
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), totalMintNum);
        vm.stopPrank();
        vm.revertTo(snapshotId);
    }

    function testClaimVoltronGobblersAfterWidraw() public {
        uint256 gobblersNum0 = 50;
        uint256 gobblersNum1 = 50;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        // try to mint most voltron gobblers
        uint256 totalMintNum;
        for (uint256 i = 0;; i++) {
            try voltron.mintGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }
        assertEq(voltron.claimableGobblersNum(), totalMintNum);

        uint256 claimNum = voltron.gooBalance(users[0]).divWadDown(voltron.globalGooBalance()).mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        vm.prank(users[0]);
        voltron.withdrawGobblers(gobblerIds0);

        uint256 snapshotId = vm.snapshot();

        // should claimable after withdraw
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = voltron.claimableGobblers(i);
        }

        vm.prank(users[0]);
        voltron.claimGobblers(claimIds);
        vm.revertTo(snapshotId);

        // claimable number shuold decrease after time pasted
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = voltron.claimableGobblers(i);
        }
        vm.warp(block.timestamp + 1 days);
        vm.prank(users[0]);
        vm.expectRevert("CLAIM_TOO_MUCH");
        voltron.claimGobblers(claimIds);
        vm.revertTo(snapshotId);

        uint256 newClaimNum = voltron.gooBalance(users[0]).divWadDown(voltron.globalGooBalance()).mulWadDown(totalMintNum);
        uint256[] memory newClaimIds = new uint256[](newClaimNum);
        for (uint256 i = 0; i < newClaimNum; i++) {
            newClaimIds[i] = voltron.claimableGobblers(i);
        }
        vm.prank(users[0]);
        voltron.claimGobblers(newClaimIds);
        assertEq(voltron.claimableGobblersNum(), totalMintNum - newClaimNum);
        vm.revertTo(snapshotId);
    }

    function testSwapFromGoober() public {
        address owner = voltron.owner();
        uint256 gobblersNum = 20;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        uint256[] memory gooberIds = prepareGoober(10, 690e18);

        deposit(users[0], gobblerIds);

        vm.warp(block.timestamp + 30 days);
        int256 erroneousGoo;
        uint256 maxGoo;
        uint256 voltronGooBefore;
        voltronGooBefore = gobblers.gooBalance(address(voltron));
        uint256[] memory noGobblers = new uint256[](0);
        uint256[] memory gobblersOut = new uint256[](2);
        gobblersOut[0] = gooberIds[0];
        gobblersOut[1] = gooberIds[1];
        erroneousGoo = goober.previewSwap(noGobblers, 1, gobblersOut, 0);
        maxGoo = uint256(erroneousGoo) + 1;

        vm.prank(owner);
        voltron.setMintLock(true);

        vm.expectRevert("MINT_LOCK");
        voltron.swapFromGoober(maxGoo, gobblersOut);

        vm.prank(owner);
        voltron.setMintLock(false);

        voltron.swapFromGoober(maxGoo, gobblersOut);
        assertEq(gobblers.gooBalance(address(voltron)), voltronGooBefore - maxGoo);
        assertEq(gobblers.ownerOf(gobblersOut[0]), address(voltron));
        assertEq(gobblers.ownerOf(gobblersOut[1]), address(voltron));

        voltronGooBefore = gobblers.gooBalance(address(voltron));
        gobblersOut[0] = gooberIds[2];
        gobblersOut[1] = gooberIds[3];
        erroneousGoo = goober.previewSwap(noGobblers, 1, gobblersOut, 0);
        maxGoo = uint256(erroneousGoo) + 1;

        vm.expectRevert("ONLY_MINTER");
        voltron.swapFromGooberByMinter(maxGoo, gobblersOut);

        vm.prank(minterAddr);
        voltron.swapFromGooberByMinter(maxGoo, gobblersOut);
        assertEq(gobblers.gooBalance(address(voltron)), voltronGooBefore - maxGoo);
        assertEq(gobblers.ownerOf(gobblersOut[0]), address(voltron));
        assertEq(gobblers.ownerOf(gobblersOut[1]), address(voltron));
    }

    function testAdminClaimGobblersAndGoo() public {
        uint256 gobblersNum0 = 5;
        uint256 gobblersNum1 = 5;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        voltron.mintGobblers(type(uint256).max, 3);
        assertEq(voltron.claimableGobblersNum(), 3);

        uint256[] memory claimIds = new uint256[](1);

        vm.startPrank(users[0]);
        voltron.withdrawGobblers(gobblerIds0);
        claimIds[0] = voltron.claimableGobblers(0);
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), 2);
        vm.stopPrank();

        claimIds[0] = voltron.claimableGobblers(2);
        vm.prank(voltron.owner());
        vm.expectRevert("ADMIN_CANT_CLAIM");
        voltron.adminClaimGobblersAndGoo(claimIds);

        // just in case round down cause "CLAIM_TOO_MUCH"
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(users[1]);
        voltron.withdrawGobblers(gobblerIds1);
        claimIds[0] = voltron.claimableGobblers(1);
        voltron.claimGobblers(claimIds);
        assertEq(voltron.claimableGobblersNum(), 1);
        vm.stopPrank();

        claimIds[0] = voltron.claimableGobblers(2);

        uint256 voltronGoo = gobblers.gooBalance(address(voltron)) + goo.balanceOf(address(voltron));
        vm.prank(voltron.owner());
        voltron.adminClaimGobblersAndGoo(claimIds);

        assertEq(voltron.claimableGobblersNum(), 0);
        assertEq(goo.balanceOf(voltron.owner()), voltronGoo);
    }

    function testAdminFunction() public {
        address owner = voltron.owner();

        vm.expectRevert("Ownable: caller is not the owner");
        voltron.setMintLock(true);

        vm.expectRevert("Ownable: caller is not the owner");
        voltron.setClaimGobblerLock(true);

        vm.expectRevert("Ownable: caller is not the owner");
        voltron.setTimeLockDuration(10 days);

        vm.expectRevert("ONLY_MINTER");
        voltron.mintGobblersByMinter(type(uint256).max, 1);

        vm.prank(owner);
        voltron.setMintLock(true);
        assertTrue(voltron.mintLock());
        vm.expectRevert("MINT_LOCK");
        voltron.mintGobblers(type(uint256).max, 1);

        vm.prank(owner);
        voltron.setClaimGobblerLock(true);
        assertTrue(voltron.claimGobblerLock());
        uint256[] memory claimIds = new uint256[](1);
        claimIds[0] = 1;
        vm.expectRevert("CLAIM_GOBBLER_LOCK");
        voltron.claimGobblers(claimIds);

        vm.prank(owner);
        voltron.setTimeLockDuration(10 days);
        assertEq(voltron.timeLockDuration(), 10 days);

        uint256 gooAmount = gobblers.gobblerPrice();
        vm.prank(address(gobblers));
        goo.mintForGobblers(address(voltron), gooAmount);
        vm.prank(address(voltron));
        gobblers.addGoo(gooAmount);
        vm.prank(minterAddr);
        voltron.mintGobblersByMinter(type(uint256).max, 1);
    }

    function testMintByMinter() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        deposit(users[0], gobblerIds);

        vm.warp(block.timestamp + 5 days);

        vm.prank(minterAddr);
        voltron.mintGobblersByMinter(type(uint256).max, 1);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    function deposit(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        gobblers.setApprovalForAll(address(voltron), true);
        voltron.depositGobblers(gobblerIds, 0);
        vm.stopPrank();
    }

    function depositWithGoo(address user, uint256[] memory gobblerIds, uint256 gooAmount) internal {
        vm.prank(address(gobblers));
        goo.mintForGobblers(user, gooAmount);
        vm.startPrank(user);
        gobblers.setApprovalForAll(address(voltron), true);
        goo.approve(address(voltron), gooAmount);
        voltron.depositGobblers(gobblerIds, gooAmount);
        vm.stopPrank();
    }

    function withraw(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        voltron.withdrawGobblers(gobblerIds);
        vm.stopPrank();
    }
}
