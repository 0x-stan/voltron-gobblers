// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { RandProvider } from "art-gobblers/utils/rand/RandProvider.sol";
import { GobblersERC721 } from "art-gobblers/utils/token/GobblersERC721.sol";
import { Goo } from "art-gobblers/Goo.sol";
import { Pages } from "art-gobblers/Pages.sol";
import { ArtGobblers } from "art-gobblers/ArtGobblers.sol";

/// @title Art Gobblers NFT
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice An experimental decentralized art factory by Justin Roiland and Paradigm.
contract MockArtGobblers is ArtGobblers {
    mapping(address => uint256) public faucetClaimed;
    uint256 public maxFaucet;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets VRGDA parameters, mint config, relevant addresses, and URIs.
    /// @param _merkleRoot Merkle root of mint mintlist.
    /// @param _mintStart Timestamp for the start of the VRGDA mint.
    /// @param _goo Address of the Goo contract.
    /// @param _team Address of the team reserve.
    /// @param _community Address of the community reserve.
    /// @param _randProvider Address of the randomness provider.
    /// @param _baseUri Base URI for revealed gobblers.
    /// @param _unrevealedUri URI for unrevealed gobblers.
    constructor(
        // Mint config:
        bytes32 _merkleRoot,
        uint256 _mintStart,
        // Addresses:
        Goo _goo,
        Pages _pages,
        address _team,
        address _community,
        RandProvider _randProvider,
        // URIs:
        string memory _baseUri,
        string memory _unrevealedUri
    ) ArtGobblers(_merkleRoot, _mintStart, _goo, _pages, _team, _community, _randProvider, _baseUri, _unrevealedUri) { }

    function batchOwnerFaucet(uint256 num) external returns (uint256[] memory gobblerIds) {
        gobblerIds = new uint256[](num);
        uint256 gobblerId;
        for (uint256 i = 0; i < num; i++) {
            unchecked {
                // Overflow should be impossible due to supply cap of 10,000.
                emit GobblerClaimed(msg.sender, gobblerId = ++currentNonLegendaryId);
            }
            gobblerIds[i] = gobblerId;

            _mint(msg.sender, gobblerId);
        }
    }

    /// @notice Mint a gobbler from faucet.
    /// @return gobblerId The id of the gobbler that was minted.
    function mintFromFaucet() external returns (uint256 gobblerId) {
        require(faucetClaimed[msg.sender] < maxFaucet, "Couldn't claimed faucet gobbler any more");
        faucetClaimed[msg.sender] += 1;

        unchecked {
            // Overflow should be impossible due to supply cap of 10,000.
            emit GobblerClaimed(msg.sender, gobblerId = ++currentNonLegendaryId);
        }

        _mint(msg.sender, gobblerId);
    }

    /// @notice Mint a gobbler by owner.
    /// @return gobblerIds The ids of the gobblers that was minted.
    function mintByOwner(uint256 mintNum) external onlyOwner returns (uint256[] memory gobblerIds) {
        gobblerIds = new uint256[](mintNum);
        for (uint256 i = 0; i < mintNum; i++) {
            uint256 currentPrice = gobblerPrice();
            uint256 _gobblerId;

            unchecked {
                ++numMintedFromGoo; // Overflow should be impossible due to the supply cap.

                emit GobblerPurchased(msg.sender, _gobblerId = ++currentNonLegendaryId, currentPrice);
            }

            _mint(msg.sender, _gobblerId);
            gobblerIds[i] = _gobblerId;
        }
    }

    /// @notice mock function: requestRandomSeed + revealGobblers.
    /// @param numGobblers The number of gobblers to reveal.
    function revealGobblersMock(uint256 numGobblers) external {
        // don't update nextRevealTimestamp just for mock
        // uint256 nextRevealTimestamp = gobblerRevealsData.nextRevealTimestamp;

        unchecked {
            // Prevent revealing while we wait for the seed.
            gobblerRevealsData.waitingForSeed = true;

            // Compute the number of gobblers to be revealed with the seed.
            uint256 toBeRevealed = currentNonLegendaryId - gobblerRevealsData.lastRevealedId;

            // Ensure that there are more than 0 gobblers to be revealed,
            // otherwise the contract could waste LINK revealing nothing.
            if (toBeRevealed == 0) {
                revert ZeroToBeRevealed();
            }

            // Lock in the number of gobblers to be revealed from seed.
            gobblerRevealsData.toBeRevealed = uint56(toBeRevealed);

            // We want at most one batch of reveals every 24 hours.
            // Timestamp overflow is impossible on human timescales.
            // gobblerRevealsData.nextRevealTimestamp = uint64(nextRevealTimestamp + 1 days);

            emit RandomnessRequested(msg.sender, toBeRevealed);
        }

        uint256 randomSeed = 1024;

        uint256 lastRevealedId = gobblerRevealsData.lastRevealedId;

        uint256 totalRemainingToBeRevealed = gobblerRevealsData.toBeRevealed;

        // Can't reveal more gobblers than are currently remaining to be revealed with the seed.
        if (numGobblers > totalRemainingToBeRevealed) {
            revert NotEnoughRemainingToBeRevealed(totalRemainingToBeRevealed);
        }

        // Implements a Knuth shuffle. If something in
        // here can overflow, we've got bigger problems.
        unchecked {
            for (uint256 i = 0; i < numGobblers; ++i) {
                /*//////////////////////////////////////////////////////////////
                                      DETERMINE RANDOM SWAP
                //////////////////////////////////////////////////////////////*/

                // Number of ids that have not been revealed. Subtract 1
                // because we don't want to include any legendaries in the swap.
                uint256 remainingIds = FIRST_LEGENDARY_GOBBLER_ID - lastRevealedId - 1;

                // Randomly pick distance for swap.
                uint256 distance = randomSeed % remainingIds;

                // Current id is consecutive to last reveal.
                uint256 currentId = ++lastRevealedId;

                // Select swap id, adding distance to next reveal id.
                uint256 swapId = currentId + distance;

                /*//////////////////////////////////////////////////////////////
                                       GET INDICES FOR IDS
                //////////////////////////////////////////////////////////////*/

                // Get the index of the swap id.
                uint64 swapIndex = getGobblerData[swapId].idx == 0
                    ? uint64(swapId) // Hasn't been shuffled before.
                    : getGobblerData[swapId].idx; // Shuffled before.

                // Get the owner of the current id.
                address currentIdOwner = getGobblerData[currentId].owner;

                // Get the index of the current id.
                uint64 currentIndex = getGobblerData[currentId].idx == 0
                    ? uint64(currentId) // Hasn't been shuffled before.
                    : getGobblerData[currentId].idx; // Shuffled before.

                /*//////////////////////////////////////////////////////////////
                                  SWAP INDICES AND SET MULTIPLE
                //////////////////////////////////////////////////////////////*/

                // Determine the current id's new emission multiple.
                uint256 newCurrentIdMultiple = 9; // For beyond 7963.

                // The branchless expression below is equivalent to:
                //      if (swapIndex <= 3054) newCurrentIdMultiple = 6;
                // else if (swapIndex <= 5672) newCurrentIdMultiple = 7;
                // else if (swapIndex <= 7963) newCurrentIdMultiple = 8;
                assembly {
                    // prettier-ignore
                    newCurrentIdMultiple :=
                        sub(sub(sub(newCurrentIdMultiple, lt(swapIndex, 7964)), lt(swapIndex, 5673)), lt(swapIndex, 3055))
                }

                // Swap the index and multiple of the current id.
                getGobblerData[currentId].idx = swapIndex;
                getGobblerData[currentId].emissionMultiple = uint32(newCurrentIdMultiple);

                // Swap the index of the swap id.
                getGobblerData[swapId].idx = currentIndex;

                /*//////////////////////////////////////////////////////////////
                                   UPDATE CURRENT ID MULTIPLE
                //////////////////////////////////////////////////////////////*/

                // Update the user data for the owner of the current id.
                getUserData[currentIdOwner].lastBalance = uint128(gooBalance(currentIdOwner));
                getUserData[currentIdOwner].lastTimestamp = uint64(block.timestamp);
                getUserData[currentIdOwner].emissionMultiple += uint32(newCurrentIdMultiple);

                // Update the random seed to choose a new distance for the next iteration.
                // It is critical that we cast to uint64 here, as otherwise the random seed
                // set after calling revealGobblers(1) thrice would differ from the seed set
                // after calling revealGobblers(3) a single time. This would enable an attacker
                // to choose from a number of different seeds and use whichever is most favorable.
                // Equivalent to randomSeed = uint64(uint256(keccak256(abi.encodePacked(randomSeed))))
                assembly {
                    mstore(0, randomSeed) // Store the random seed in scratch space.

                    // Moduloing by 1 << 64 (2 ** 64) is equivalent to a uint64 cast.
                    randomSeed := mod(keccak256(0, 32), shl(64, 1))
                }
            }

            // Update all relevant reveal state.
            gobblerRevealsData.randomSeed = uint64(randomSeed);
            gobblerRevealsData.lastRevealedId = uint56(lastRevealedId);
            gobblerRevealsData.toBeRevealed = uint56(totalRemainingToBeRevealed - numGobblers);

            emit GobblersRevealed(msg.sender, numGobblers, lastRevealedId);
        }
    }

    function setMaxFaucet(uint256 newMaxFaucet) external onlyOwner {
        maxFaucet = newMaxFaucet;
    }
}
