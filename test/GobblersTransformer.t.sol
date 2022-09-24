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
        transformer = new GobblersTransformer(msg.sender, address(gobblers));
    }

    function testArtGobblersAddr() public {
        assertEq(transformer.artGobblers(), address(gobblers));
    }

    function testDepositGobblers() public {
        uint256 depositNum = 2;

        uint256[] memory gobblerIds = mintGobblersFromGoo(users[0], depositNum);
        deposit(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(transformer)), depositNum);
        assertEq(gobblers.balanceOf(users[0]), 0);
        for (uint256 i = 0; i < depositNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), address(transformer));
            assertEq(transformer.getUserByGobblerId(gobblerIds[i]), users[0]);
        }

        (, , uint32 emissionMultiple) = gobblers.getGobblerData(gobblerIds[0]);

        uint32 totalGobblersOwned;
        uint32 totalEmissionMultiple;
        uint128 totalBalance;

        (totalGobblersOwned, totalEmissionMultiple, totalBalance, ) = transformer.globalData();
        assertEq(totalGobblersOwned, depositNum);
        assertEq(totalEmissionMultiple, emissionMultiple);
    }

    function testWithdrawGobblers() public {
        uint256 withdrawNum = 2;
        uint256[] memory gobblerIds = mintGobblersFromGoo(users[0], withdrawNum);
        deposit(users[0], gobblerIds);
        withraw(users[0], gobblerIds);

        assertEq(gobblers.balanceOf(address(transformer)), 0);
        assertEq(gobblers.balanceOf(users[0]), withdrawNum);
        for (uint256 i = 0; i < withdrawNum; i++) {
            assertEq(gobblers.ownerOf(gobblerIds[i]), users[0]);
            assertEq(transformer.getUserByGobblerId(gobblerIds[i]), address(0));
        }
    }

    function testStaking() public {
        uint256 stakingNum = 1;

        uint256[] memory gobblerIds = mintGobblersFromGoo(users[0], stakingNum);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(stakingNum, "seed");


        deposit(users[0], gobblerIds);

        (
            uint32 gobblersOwned,
            uint32 emissionMultiple,
            uint128 lastBalance,
            uint64 lastTimestamp
        ) = transformer.getUserData(users[0]);

        assertEq(gobblersOwned, stakingNum);

        vm.warp(block.timestamp + 1 days);

        console2.log(emissionMultiple);
        console2.log(gobblers.gooBalance(address(transformer)));
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
