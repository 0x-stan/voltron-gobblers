// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { MockArtGobblers } from "../test/utils/mocks/MockArtGobblers.sol";
import { RandProvider } from "art-gobblers/src/utils/rand/RandProvider.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import { ProofHelper } from "./utils/ProofHelper.sol";
import { DeploymentHelper } from "./utils/DeploymentHelper.sol";

contract MockMint is Script {
    MockArtGobblers gobblers;
    RandProvider randProvider;
    VRFCoordinatorMock vrfCoordinator;

    bytes seed = "seed";

    function setUp() public {
        vrfCoordinator = VRFCoordinatorMock(DeploymentHelper.loadDeployAddress(".vrfCoordinator"));
        randProvider = RandProvider(DeploymentHelper.loadDeployAddress(".randProvider"));
        gobblers = MockArtGobblers(DeploymentHelper.loadDeployAddress(".gobblers"));
    }

    function run() public {
        vm.startBroadcast();

        uint256 mintNum = 10;

        uint256[] memory ids = gobblers.mintByOwner(mintNum);
        string memory idsStr = "mint gobblers id: ";
        for (uint256 i = 0; i < ids.length; i++) {
            idsStr = string.concat(idsStr, vm.toString(ids[i]), ", ");
        }
        console.log(idsStr);

        // mintLegendaryGobbler();

        vm.stopBroadcast();
    }

    function mintLegendaryGobbler() internal {
        uint256 legendaryPrice = gobblers.legendaryGobblerPrice();
        console.log("legendaryPrice", legendaryPrice);
        uint256[] memory ids = new uint256[](legendaryPrice);
        for (uint256 i = 0; i < legendaryPrice; i++) {
            ids[i] = i + 1;
        }
        uint256 legendaryId = gobblers.mintLegendaryGobbler(ids);
        console.log("mint legendaryId:", legendaryId);
    }
}
