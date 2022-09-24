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
        transformer = new GobblersTransformer(msg.sender, address(gobblers));
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

    function testStaking() public {
        uint256 gobblersNum = 1;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");

        deposit(users[0], gobblerIds);

        (uint32 gobblersOwned, uint32 emissionMultiple, uint128 virtualBalance, uint64 claimedNum, uint64 lastTimestamp)
        = transformer.getUserData(users[0]);

        assertEq(gobblersOwned, gobblersNum);

        vm.warp(block.timestamp + 1 days);

        // console2.log(emissionMultiple);
        // console2.log(gobblers.gooBalance(address(transformer)));
    }

    function testMintPoolGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds = mintGobblers(users[0], gobblersNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum, "seed");
        deposit(users[0], gobblerIds);

        vm.warp(block.timestamp + 5 days);

        assertEq(transformer.poolMintedToClaimNum(), 0);

        transformer.mintPoolGobblers(type(uint256).max, 1);

        uint256 idx = transformer.poolMintedGobblersIdx();
        (uint256 poolGobblerId, bool claimed) = transformer.poolMintedGobblers(idx);

        assertEq(transformer.poolMintedToClaimNum(), 1);
        assertEq(idx, 1);
        assertFalse(claimed);
        assertEq(gobblers.ownerOf(poolGobblerId), address(transformer));
    }

    function testClaimPoolGobblersFuzz(
        uint256 gobblersNum0,
        uint256 gobblersNum1
    ) public {
        vm.assume(gobblersNum0 < 100 && gobblersNum0 > 10);
        vm.assume(gobblersNum1 < 100 && gobblersNum0 > 10);

        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum0);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum1);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum0 + gobblersNum1, "seed");


        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        vm.warp(block.timestamp + 10 days);
        console2.log(transformer.gooBalance(users[0]));
        console2.log(transformer.gooBalance(users[1]));

        transformer.mintPoolGobblers(type(uint256).max, 10);
        
        transformer.updateGlobalBalance();
        
        uint256 virtualBalance0 = transformer.gooBalance(users[0]);
        uint256 virtualBalance1 = transformer.gooBalance(users[1]);
        (,,uint128 virtualBalanceTotal,) = transformer.globalData();
        console2.log(virtualBalance0);
        console2.log(virtualBalance1);
        console2.log(virtualBalanceTotal);

        uint256 claimNum = virtualBalance0
            .divWadDown(virtualBalanceTotal)
            .mulWadDown(transformer.poolMintedToClaimNum());

        uint256 poolMintedGobblersIdx;
        uint256[] memory idxs;

        poolMintedGobblersIdx = transformer.poolMintedGobblersIdx();

        uint256 snapshotId = vm.snapshot();

        idxs = new uint256[](claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            idxs[i] = poolMintedGobblersIdx - i;
        }

        vm.startPrank(users[0]);
        transformer.claimPoolGobblers(idxs);
        vm.stopPrank();

        assertEq(
            transformer.poolMintedGobblersIdx(),
            poolMintedGobblersIdx - claimNum
        );

        (, , , uint64 claimedNum, ) = transformer.getUserData(users[0]);

        assertEq(claimedNum, claimNum);

        for (uint256 i = 0; i < claimNum; i++) {
            assertEq(gobblers.ownerOf(idxs[i]), users[0]);
        }

        vm.revertTo(snapshotId);

        claimNum += 2;
        idxs = new uint256[](claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            idxs[i] = poolMintedGobblersIdx - i;
        }

        vm.startPrank(users[0]);
        vm.expectRevert("CLAIM_TOO_MORE");
        transformer.claimPoolGobblers(idxs);
        vm.stopPrank();
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
