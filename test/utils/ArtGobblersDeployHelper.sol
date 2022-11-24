// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";
import { Utilities } from "lib/art-gobblers/test/utils/Utilities.sol";
import { console } from "lib/art-gobblers/test/utils/Console.sol";
import { Vm } from "forge-std/Vm.sol";
import { stdError } from "forge-std/Test.sol";
import { ArtGobblers, FixedPointMathLib } from "art-gobblers/ArtGobblers.sol";
import { Goo } from "art-gobblers/Goo.sol";
import { Pages } from "art-gobblers/Pages.sol";
import { GobblerReserve } from "art-gobblers/utils/GobblerReserve.sol";
import { RandProvider } from "art-gobblers/utils/rand/RandProvider.sol";
import { ChainlinkV1RandProvider } from "art-gobblers/utils/rand/ChainlinkV1RandProvider.sol";
import { LinkToken } from "lib/art-gobblers/test/utils/mocks/LinkToken.sol";
import { VRFCoordinatorMock } from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { MockERC1155 } from "solmate/test/utils/mocks/MockERC1155.sol";
import { LibString } from "solmate/utils/LibString.sol";
import { fromDaysWadUnsafe } from "solmate/utils/SignedWadMath.sol";
import { DeploymentHelper } from "script/goerli/utils/DeploymentHelper.sol";
import { Goober } from "goobervault/Goober.sol";

/// @notice Unit test for Art Gobbler Contract.
abstract contract ArtGobblersDeployHelper is DSTestPlus {
    using LibString for uint256;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;

    Goober internal goober;

    bytes32 private keyHash;
    uint256 private fee;

    uint256[] ids;

    address anvilAccount0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address internal constant FEE_TO = address(0xFEEE);
    address internal constant MINTER = address(0x1337);

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function deployArtGobblers() internal {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        utils = new Utilities();
        users = utils.createUsers(5);

        if (chainId == 1) {
            linkToken = LinkToken(DeploymentHelper.loadDeployAddress(".linkToken"));
            vrfCoordinator = VRFCoordinatorMock(DeploymentHelper.loadDeployAddress(".vrfCoordinator"));
            team = GobblerReserve(DeploymentHelper.loadDeployAddress(".team"));
            community = GobblerReserve(DeploymentHelper.loadDeployAddress(".community"));
            randProvider = ChainlinkV1RandProvider(DeploymentHelper.loadDeployAddress(".randProvider"));
            goo = Goo(DeploymentHelper.loadDeployAddress(".goo"));
            gobblers = ArtGobblers(DeploymentHelper.loadDeployAddress(".gobblers"));
            pages = Pages(DeploymentHelper.loadDeployAddress(".pages"));
            return;
        }

        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        //gobblers contract will be deployed after 4 contract deploys, and pages after 5
        address gobblerAddress = utils.predictContractAddress(address(this), 4);
        address pagesAddress = utils.predictContractAddress(address(this), 5);

        team = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        community = new GobblerReserve(
            ArtGobblers(gobblerAddress),
            address(this)
        );
        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers:
            utils.predictContractAddress(address(this), 1),
            // Pages:
            utils.predictContractAddress(address(this), 2)
        );

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            goo,
            Pages(pagesAddress),
            address(team),
            address(community),
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");

        // Deploy Goober
        goober = new Goober({
            _gobblersAddress: address(gobblers),
            _gooAddress: address(goo),
            _feeTo: FEE_TO,
            _minter: MINTER
        });
    }

    /// @notice Mint a number of gobblers to the given address
    function mintGobblers(address addr, uint256 num) internal returns (uint256[] memory gobblerIds) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        gobblerIds = new uint256[](num);

        if (chainId == 1) {
            uint256 i = 0;
            for (uint256 id = 1;; id++) {
                if (gobblers.ownerOf(id) == anvilAccount0) {
                    gobblerIds[i] = id;
                    vm.prank(anvilAccount0);
                    gobblers.transferFrom(anvilAccount0, addr, id);
                    ++i;
                }
                if (i == num) break;
            }
        } else {
            for (uint256 i = 0; i < num; i++) {
                vm.startPrank(address(gobblers));
                goo.mintForGobblers(addr, gobblers.gobblerPrice());
                vm.stopPrank();

                vm.prank(addr);
                gobblerIds[i] = gobblers.mintFromGoo(type(uint256).max, false);
            }
        }
    }

    function prepareGoober(uint256 num, uint256 gooTokens) internal returns (uint256[] memory gobblerIds) {
        gobblerIds = mintGobblers(MINTER, num);
        setRandomnessAndReveal(num, "seed");

        vm.prank(address(gobblers));
        goo.mintForGobblers(MINTER, gooTokens);

        vm.startPrank(MINTER);
        goo.approve(address(goober), type(uint256).max);
        gobblers.setApprovalForAll(address(goober), true);
        goober.deposit(gobblerIds, gooTokens, MINTER);
        vm.stopPrank();
    }

    /// @notice Call back vrf with randomness and reveal gobblers.
    function setRandomnessAndReveal(uint256 numReveal, string memory seed) internal {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        if (chainId == 1) { } else {
            bytes32 requestId = gobblers.requestRandomSeed();
            uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
            // call back from coordinator
            vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
            gobblers.revealGobblers(numReveal);
        }
    }
}
