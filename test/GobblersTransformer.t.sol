// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";

import {GobblersTransformer} from "src/GobblersTransformer.sol";
import {ArtGobblers, FixedPointMathLib} from "2022-09-artgobblers/src/ArtGobblers.sol";
import {ArtGobblersDeployHelper} from "./utils/ArtGobblersDeployHelper.sol";

contract GobblersTransformerTest is ArtGobblersDeployHelper {
    using FixedPointMathLib for uint256;

    GobblersTransformer transformer;

    function setUp() public {
        deployArtGobblers();
        vm.warp(block.timestamp + 1 days);
        transformer = new GobblersTransformer(msg.sender, address(gobblers), address(goo));
    }

    function testArtGobblersAddr() public {
        assertEq(transformer.artGobblers(), address(gobblers));
    }

    function testDepositGobblers() public {
        uint256 gobblersNum = 2;

        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        deposit(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(transformer)), gobblersNum);
        assertEq(gobblers.balanceOf(users[0]), 0);

        uint32 sumEmissionMultiple;
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), address(transformer));
            assertEq(transformer.getUserByGobblerId(gobblerIds[i]), users[0]);
            (,, uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[i]);
            sumEmissionMultiple += emissionMultiple;
        }

        uint32 totalGobblersOwned;
        uint32 totalEmissionMultiple;
        uint128 totalVirtualBalance;

        (totalGobblersOwned, totalEmissionMultiple, totalVirtualBalance,) = transformer.globalData();
        assertEq(totalGobblersOwned, gobblersNum);
        assertEq(totalEmissionMultiple, sumEmissionMultiple);
    }

    function testWithdrawGobblers() public {
        uint256 gobblersNum = 2;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        deposit(users[0], gobblerIds);
        withraw(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(transformer)), 0);
        assertEq(gobblers.balanceOf(users[0]), gobblersNum);
        for (uint256 i = 0; i < gobblersNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), users[0]);
            assertEq(transformer.getUserByGobblerId(gobblerIds[i]), address(0));
        }
    }

    function testMintPoolGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        deposit(users[0], gobblerIds);

        vm.warp(block.timestamp + 5 days);


        transformer.mintPoolGobblers(type(uint256).max, 1);

        uint256 poolGobblerId = transformer.claimableGobblers(0);
        bool claimed = transformer.gobblersClaimed(0);

        assertFalse(claimed);
        assertEq(gobblers.ownerOf(poolGobblerId), address(transformer));
    }

    function testClaimPoolGobblersFuzz(uint32 percent) public {
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

        // try to mint most pool gobblers
        uint256 totalMintNum;
        for (uint256 i = 0; ; i++) {
            // transformer.mintPoolGobblers(type(uint256).max, 1);
            try transformer.mintPoolGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }
        
        transformer.updateGlobalBalance();
        
        uint256 virtualBalance0 = transformer.gooBalance(users[0]);
        (,,uint128 virtualBalanceTotal,) = transformer.globalData();
        uint256 claimNum = virtualBalance0
            .divWadDown(virtualBalanceTotal)
            .mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        uint256 snapshotId = vm.snapshot();

        // shuold claimable
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = transformer.claimableGobblers(i);
        }
        vm.startPrank(users[0]);
        transformer.claimPoolGobblers(claimIds);
        (, , , uint64 claimedNum, ) = transformer.getUserData(users[0]);
        assertEq(claimedNum, claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            assertEq(gobblers.ownerOf(claimIds[i]), users[0]);
        }
        vm.stopPrank();
        vm.revertTo(snapshotId);

        

        // can't claim over max claimable number of user
        uint256 claimNumOvered = claimNum + 1;
        claimIds = new uint256[](claimNumOvered);
        for (uint256 i = 0; i < claimNumOvered; i++) {
            claimIds[i] = transformer.claimableGobblers(i);
        }
        vm.startPrank(users[0]);
        vm.expectRevert("CLAIM_TOO_MORE");
        transformer.claimPoolGobblers(claimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);

    }

    function testClaimPoolGobblersAfterWidraw() public {
        uint256 gobblersNum0 = 50;
        uint256 gobblersNum1 = 50;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        // try to mint most pool gobblers
        uint256 totalMintNum;
        for (uint256 i = 0; ; i++) {
            // transformer.mintPoolGobblers(type(uint256).max, 1);
            try transformer.mintPoolGobblers(type(uint256).max, 1) {
                totalMintNum++;
            } catch {
                break;
            }
        }
        
        transformer.updateGlobalBalance();
        
        uint256 virtualBalance0 = transformer.gooBalance(users[0]);
        (,,uint128 virtualBalanceTotal,) = transformer.globalData();
        uint256 claimNum = virtualBalance0
            .divWadDown(virtualBalanceTotal)
            .mulWadDown(totalMintNum);
        uint256[] memory claimIds = new uint256[](claimNum);

        uint256 snapshotId = vm.snapshot();

        // should claimable after withdraw
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = transformer.claimableGobblers(i);
        }

        vm.startPrank(users[0]);
        transformer.withdrawGobblers(gobblerIds0);
        transformer.claimPoolGobblers(claimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);

        // claimable number shuold decrease after time pasted
        for (uint256 i = 0; i < claimNum; i++) {
            claimIds[i] = transformer.claimableGobblers(i);
        }
        vm.startPrank(users[0]);
        transformer.withdrawGobblers(gobblerIds0);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("CLAIM_TOO_MORE");
        transformer.claimPoolGobblers(claimIds);
        
        uint256[] memory newClaimIds = new uint256[](claimNum-5);
        for (uint256 i = 0; i < claimNum-5; i++) {
            newClaimIds[i] = transformer.claimableGobblers(i);
        }
        transformer.claimPoolGobblers(newClaimIds);
        vm.stopPrank();
        vm.revertTo(snapshotId);
    }

    function testClaimPoolGoo() public {
        uint256 gobblersNum0 = 5;
        uint256 gobblersNum1 = 5;

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);

        transformer.mintPoolGobblers(type(uint256).max, 2);
        
        transformer.updateGlobalBalance();

        uint256[] memory claimIds = new uint256[](1);

        vm.startPrank(users[0]);
        transformer.withdrawGobblers(gobblerIds0);
        claimIds[0] = transformer.claimableGobblers(0);
        transformer.claimPoolGobblers(claimIds);
        vm.stopPrank();

        // just in case round down cause "CLAIM_TOO_MORE"
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(users[1]);
        transformer.withdrawGobblers(gobblerIds1);
        claimIds[0] = transformer.claimableGobblers(1);
        transformer.claimPoolGobblers(claimIds);
        vm.stopPrank();
        
        
        vm.startPrank(transformer.owner());
        transformer.setMintLock(true);
        transformer.setClaimGooLock(false);
        vm.stopPrank();

        uint256 transformerGoo = gobblers.gooBalance(address(transformer));

        vm.startPrank(users[0]);
        uint256 claimGoo0 = goo.balanceOf(users[0]);
        transformer.claimPoolGoo();
        claimGoo0 = goo.balanceOf(users[0]) - claimGoo0;
        vm.stopPrank();

        vm.startPrank(users[1]);
        uint256 claimGoo1 = goo.balanceOf(users[1]);
        transformer.claimPoolGoo();
        claimGoo1 = goo.balanceOf(users[1]) - claimGoo1;
        vm.stopPrank();

        uint256 sumClaimGoo = claimGoo0 + claimGoo1;
        uint256 lastGoo = (transformerGoo - sumClaimGoo).divWadDown(sumClaimGoo);
        assertTrue(lastGoo < 5e16);

    }



    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    function deposit(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        for (uint256 i = 0; i < gobblerIds.length; i++) {
            gobblers.approve(address(transformer), gobblerIds[i]);
        }
        transformer.depositGobblers(gobblerIds);
        vm.stopPrank();
    }

    function withraw(address user, uint256[] memory gobblerIds) internal {
        vm.startPrank(user);
        transformer.withdrawGobblers(gobblerIds);
        vm.stopPrank();
    }
}
