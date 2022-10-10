// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";
import { Script } from "forge-std/Script.sol";
import { stdError } from "forge-std/Test.sol";
import { console } from "2022-09-artgobblers/test/utils/Console.sol";
import { ArtGobblers, FixedPointMathLib } from "2022-09-artgobblers/src/ArtGobblers.sol";
import { Goo } from "2022-09-artgobblers/src/Goo.sol";
import { Pages } from "2022-09-artgobblers/src/Pages.sol";
import { GobblerReserve } from "2022-09-artgobblers/src/utils/GobblerReserve.sol";
import { RandProvider } from "2022-09-artgobblers/src/utils/rand/RandProvider.sol";
import { ChainlinkV1RandProvider } from "2022-09-artgobblers/src/utils/rand/ChainlinkV1RandProvider.sol";
import { LinkToken } from "2022-09-artgobblers/test/utils/mocks/LinkToken.sol";
import { console } from "2022-09-artgobblers/test/utils/Console.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { MockERC1155 } from "solmate/test/utils/mocks/MockERC1155.sol";
import { LibString } from "solmate/utils/LibString.sol";
import { fromDaysWadUnsafe } from "solmate/utils/SignedWadMath.sol";

import { MockArtGobblers } from "../../test/utils/mocks/MockArtGobblers.sol";
import { LibRLP } from "2022-09-artgobblers/test/utils/LibRLP.sol";

/// @notice Unit test for Art Gobbler Contract.
abstract contract MockArtGobblersDeployHelper is Script {
    using LibString for uint256;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;
    address internal teamColdWallet;

    // Chainlink hash:
    bytes32 private keyHash = keccak256(abi.encode("GobblersChainlinkHash"));
    // Chainlink fee:
    uint256 private fee = 0.01e18;

    uint256[] ids;

    string public constant gobblerBaseUri = "https://testnet.ag.xyz/api/nfts/gobblers/";
    string public constant gobblerUnrevealedUri = "https://testnet.ag.xyz/api/nfts/unrevealed";
    string public constant pagesBaseUri = "https://testnet.ag.xyz/api/nfts/pages/";

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() virtual public {
        teamColdWallet = tx.origin;
    }

    function deployArtGobblers() internal {
        uint256 mintStart = block.timestamp - 1 days;
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));
        // need link token to reqeustRandomSeed
        linkToken.transfer(address(vrfCoordinator), 10000e18);

        // Precomputed contract addresses, based on contract deploy nonces.
        // tx.origin is the address who will actually broadcast the contract creations below.
        address gobblerAddress = LibRLP.computeAddress(tx.origin, vm.getNonce(tx.origin) + 4);
        address pagesAddress = LibRLP.computeAddress(tx.origin, vm.getNonce(tx.origin) + 5);

        team = new GobblerReserve(ArtGobblers(gobblerAddress), teamColdWallet);
        community = new GobblerReserve(ArtGobblers(gobblerAddress), teamColdWallet);
        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers contract address:
            gobblerAddress,
            // Pages contract address:
            pagesAddress
        );

        gobblers = new MockArtGobblers(
            keccak256(abi.encodePacked(teamColdWallet)),
            mintStart,
            goo,
            Pages(pagesAddress),
            address(team),
            address(community),
            randProvider,
            gobblerBaseUri,
            gobblerUnrevealedUri
        );

        pages = new Pages(mintStart, goo, teamColdWallet, gobblers, pagesBaseUri);
    }

    /// @notice Call back vrf with randomness and reveal gobblers.
    function setRandomnessAndReveal(uint256 numReveal, string memory seed) internal {
        bytes32 requestId = gobblers.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // call back from coordinator
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        gobblers.revealGobblers(numReveal);
    }

    function predictContractAddress(address user, uint256 distanceFromCurrentNonce) internal returns (address) {
        return LibRLP.computeAddress(user, vm.getNonce(user) + distanceFromCurrentNonce);
    }
}
