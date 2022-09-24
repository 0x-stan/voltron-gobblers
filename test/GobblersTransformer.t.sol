// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";

import {GobblersTransformer} from "src/GobblersTransformer.sol";
import {ArtGobblers, FixedPointMathLib} from "2022-09-artgobblers/src/ArtGobblers.sol";
import {ArtGobblersDeployHelper} from "./utils/ArtGobblersDeployHelper.sol";

contract GobblersTransformerTest is ArtGobblersDeployHelper {
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
            (, , uint32 emissionMultiple) = gobblers.getGobblerData(
                gobblerIds[i]
            );
            sumEmissionMultiple += emissionMultiple;
        }

        uint32 totalGobblersOwned;
        uint32 totalEmissionMultiple;
        uint128 totalVirtualBalance;

        (
            totalGobblersOwned,
            totalEmissionMultiple,
            totalVirtualBalance,

        ) = transformer.globalData();
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

        (
            uint32 gobblersOwned,
            uint32 emissionMultiple,
            uint128 virtualBalance,
            uint64 claimedNum,
            uint64 lastTimestamp
        ) = transformer.getUserData(users[0]);

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
        (uint256 poolGobblerId, bool claimed) = transformer.poolMintedGobblers(
            idx
        );

        assertEq(transformer.poolMintedToClaimNum(), 1);
        assertEq(idx, 1);
        assertFalse(claimed);
        assertEq(gobblers.ownerOf(poolGobblerId), address(transformer));
    }

    function testClaimPoolGobblers() public {
        uint256 gobblersNum = 10;
        uint256[] memory gobblerIds0 = mintGobblers(users[0], gobblersNum);
        uint256[] memory gobblerIds1 = mintGobblers(users[1], gobblersNum);

        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(gobblersNum * 2, "seed");

        deposit(users[0], gobblerIds0);
        deposit(users[1], gobblerIds1);

        console2.log(block.timestamp);

        vm.warp(block.timestamp + 5 days);

        transformer.mintPoolGobblers(type(uint256).max, 10);

        uint256 claimNum;
        uint256 poolMintedGobblersIdx;
        uint256[] memory idxs;

        uint256 snapshotId = vm.snapshot();

        claimNum = 5;
        poolMintedGobblersIdx = transformer.poolMintedGobblersIdx();
        idxs = new uint256[](claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            idxs[i] = poolMintedGobblersIdx - i;
        }

        vm.prank(users[0]);
        transformer.claimPoolGobblers(idxs);

        assertEq(transformer.poolMintedGobblersIdx(), poolMintedGobblersIdx - claimNum);

        for (uint256 i = 0; i < claimNum; i++) {
            assertEq(gobblers.ownerOf(idxs[i]), users[0]);
        }

        vm.revertTo(snapshotId);

        claimNum = 6;
        poolMintedGobblersIdx = transformer.poolMintedGobblersIdx();
        idxs = new uint256[](claimNum);
        for (uint256 i = 0; i < claimNum; i++) {
            idxs[i] = poolMintedGobblersIdx - i;
        }

        vm.prank(users[0]);
        vm.expectRevert("CLAIM_TOO_MORE");
        transformer.claimPoolGobblers(idxs);

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
