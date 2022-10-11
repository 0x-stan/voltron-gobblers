// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import { MockArtGobblers } from "../test/utils/mocks/MockArtGobblers.sol";
import { RandProvider } from "2022-09-artgobblers/src/utils/rand/RandProvider.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";

contract MintScript is Script {
    using stdJson for string;

    MockArtGobblers gobblers;
    RandProvider randProvider;
    VRFCoordinatorMock vrfCoordinator;

    bytes seed = "seed";

    function setUp() public {
        vrfCoordinator = VRFCoordinatorMock(loadDeployAddress(".vrfCoordinator"));
        randProvider = RandProvider(loadDeployAddress(".randProvider"));
        gobblers = MockArtGobblers(loadDeployAddress(".gobblers"));
    }

    function run() public {
        vm.startBroadcast();

        uint256 mintNum = 10;

        uint256[] memory ids = gobblers.mintByOwner(mintNum);
        string memory idsStr = "mint gobblers id: ";
        for (uint256 i = 0; i < ids.length; i++) {
            idsStr = string.concat(idsStr, vm.toString(ids[ i]), ", ");
        }
        console.log(idsStr);

        // claim gobbler onece
        if (!gobblers.hasClaimedMintlistGobbler(msg.sender)) {
            bytes32[] memory proof;
            gobblers.claimGobbler(proof);
            mintNum++;
        }

        // check if can reveal gobblers by chainlink
        // else use mock reveal function
        (, uint64 nextRevealTimestamp,, uint56 toBeRevealed, bool waitingForSeed) = gobblers.gobblerRevealsData();
        if (block.timestamp >= nextRevealTimestamp && !waitingForSeed) {
            revealGobblers(toBeRevealed);
        } else {
            revealGobblersMock(mintNum);
        }

        // mintLegendaryGobbler();

        vm.stopBroadcast();
    }

    function revealGobblers(uint256 numGobblers) public {
        bytes32 requestId = gobblers.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // vrfCoordinator:
        //  gasleft() >= 206000, "not enough gas for consumer";
        vrfCoordinator.callBackWithRandomness{gas: 30000 + 206000}(requestId, randomness, address(randProvider));
        gobblers.revealGobblers(numGobblers);
    }

    function revealGobblersMock(uint256 numGobblers) public {
        gobblers.revealGobblersMock(numGobblers);
    }

    function mintLegendaryGobbler() internal {
        uint256 legendaryPrice = gobblers.legendaryGobblerPrice();
        console.log("legendaryPrice", legendaryPrice);
        uint256[] memory ids = new uint256[](legendaryPrice);
        for (uint256 i = 0; i < legendaryPrice; i++) {
            ids[ i] = i + 1;
        }
        uint256 legendaryId = gobblers.mintLegendaryGobbler(ids);
        console.log("mint legendaryId:", legendaryId);
    }

    function loadDeployAddress(string memory key) internal returns (address addr) {
        string[] memory cmds = new string[](4);
        cmds[ 0] = "jq";
        cmds[ 1] = key;
        cmds[ 2] = "./deployment.json";
        cmds[ 3] = "-r";
        bytes memory result = vm.ffi(cmds);
        addr = address(bytes20(result));
        console.log("loadDeployAddress", key, addr);
    }
}
