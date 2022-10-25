// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { MockArtGobblers } from "../test/utils/mocks/MockArtGobblers.sol";
import { RandProvider } from "art-gobblers/src/utils/rand/RandProvider.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import { ProofHelper } from "./utils/ProofHelper.sol";
import { DeploymentHelper } from "./utils/DeploymentHelper.sol";

contract RevealsGobblers is Script {
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

        // check if can reveal gobblers by chainlink
        // else use mock reveal function
        (, uint64 nextRevealTimestamp, uint64 lastRevealedId, uint56 toBeRevealed, bool waitingForSeed) = gobblers.gobblerRevealsData();
        if (block.timestamp >= nextRevealTimestamp && !waitingForSeed) {
            revealGobblers(toBeRevealed);
        } else {
            uint256 num = gobblers.currentNonLegendaryId() - lastRevealedId;
            revealGobblersMock(num);
        }
        vm.stopBroadcast();
    }

    function revealGobblers(uint256 numGobblers) public {
        bytes32 requestId = gobblers.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // vrfCoordinator:
        //  gasleft() >= 206000, "not enough gas for consumer";
        vrfCoordinator.callBackWithRandomness{gas: 3000 + 206000}(requestId, randomness, address(randProvider));
        gobblers.revealGobblers(numGobblers);
    }

    function revealGobblersMock(uint256 numGobblers) public {
        gobblers.revealGobblersMock(numGobblers);
    }
}
