// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { MockArtGobblers } from "../test/utils/mocks/MockArtGobblers.sol";
import { ProofHelper } from "./utils/ProofHelper.sol";
import { DeploymentHelper } from "./utils/DeploymentHelper.sol";

contract WhitelistClaim is Script {
    MockArtGobblers gobblers;

    function setUp() public {
        gobblers = MockArtGobblers(DeploymentHelper.loadDeployAddress(".gobblers"));
    }

    function run() public {
        vm.startBroadcast();

        // claim gobbler onece
        uint256 proofLen = ProofHelper.calcProofLen(20);
        if (!gobblers.hasClaimedMintlistGobbler(msg.sender)) {
            console.log("whitelist claim by ", msg.sender);
            bytes32[] memory proof = ProofHelper.readProofs(msg.sender, proofLen);
            gobblers.claimGobbler(proof);
        }

        vm.stopBroadcast();
    }
}
