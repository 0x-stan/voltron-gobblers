// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import { MockArtGobblers } from "../test/utils/mocks/MockArtGobblers.sol";
import { RandProvider } from "2022-09-artgobblers/src/utils/rand/RandProvider.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";

interface IMulticall2 {
    struct Call {
        address target;
        bytes callData;
    }
    struct Result {
        bool success;
        bytes returnData;
    }
    function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData);
}

contract MintScript is Script {
    using stdJson for string;

    MockArtGobblers gobblers;
    RandProvider randProvider;
    VRFCoordinatorMock vrfCoordinator;
    IMulticall2 multicall2;

    bytes seed = "seed";

    function setUp() public {
        vrfCoordinator = VRFCoordinatorMock(0x91E32c14A3a87fDD652c17285BBF15fDf49E0013);
        randProvider = RandProvider(0x8391ffa7d2dB3e9841Eb745f7a56543682818928);
        gobblers = MockArtGobblers(0xa02Fa46099c5da1B0e8287CEEC6A690f102311F5);
        multicall2 = IMulticall2(0x5BA1e12693Dc8F9c48aAD8770482f4739bEeD696); // goerli multicall2
    }

    function run() public {
        vm.startBroadcast();

        uint256 mintNum = 50;

        mutltiMintByOwner(mintNum);

        // bytes32[] memory proof;
        // gobblers.claimGobbler(proof);

        // revealGobblers(mintNum+1);
        revealGobblersMock(mintNum);
        
        vm.stopBroadcast();
    }

    function mutltiMintByOwner(uint256 mintNum) internal {
        IMulticall2.Call[] memory calls = new IMulticall2.Call[](mintNum);
        for (uint256 i = 0; i < mintNum; i++) {
            calls[i].target = address(gobblers);
            calls[i].callData = abi.encodeWithSignature("mintByOwner()");
        }
        (uint256 blockNumber, bytes[] memory returnData) = multicall2.aggregate(calls);
        blockNumber;
        for (uint256 j = 0; j < returnData.length; j++) {
            uint256 _gobblerId = abi.decode(returnData[j], (uint256));
            console.log("new mint gobblersId", _gobblerId);
        }
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

    // struct Deployment {
    //     address linkToken;
    //     address vrfCoordinator;
    //     address team;
    //     address community;
    //     address randProvider;
    //     address goo;
    //     address gobblers;
    //     address pages;
    //     address voltron;
    // }
    // function loadDeployment() internal {
    //     string memory json = vm.readFile("deployment.json");
    //     bytes memory detail = json.parseRaw("gobblers");
    //     address addr = abi.decode(detail, (address));
    //     console.log(addr);
    // }

    function mintAndTransfer(address to, uint256 num) internal {
        for (uint256 i = 0; i < num; i++) {
            uint256 gobblerId = gobblers.mintByOwner();
            gobblers.transferFrom(msg.sender, to, gobblerId);
        }
    }
}
