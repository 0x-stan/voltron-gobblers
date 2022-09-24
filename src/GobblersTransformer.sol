// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IArtGobblers} from "src/utils/IArtGobblers.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {toWadUnsafe, toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {LibGOO} from "goo-issuance/LibGOO.sol";

contract GobblersTransformer is Owned {
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ADDRESSES
    //////////////////////////////////////////////////////////////*/

    address public immutable artGobblers;

    // gobblerId => user
    mapping(uint256 => address) public getUserByGobblerId;

    /// @notice Struct holding data relevant to each user's account.
    struct UserData {
        // The total number of gobblers currently owned by the user.
        uint32 gobblersOwned;
        // The sum of the multiples of all gobblers the user holds.
        uint32 emissionMultiple;
        // User's goo balance at time of last checkpointing.
        uint128 virtualBalance;
        // claimed pool's gobbler number
        uint64 claimedNum;
        // Timestamp of the last goo balance checkpoint.
        uint64 lastTimestamp;
    }
    /// @notice Maps user addresses to their account data.
    mapping(address => UserData) public getUserData;

    /// @dev An enum for representing whether to
    /// increase or decrease a user's goo balance.
    enum GooBalanceUpdateType {
        INCREASE,
        DECREASE
    }

    struct GlobalData {
        // The total number of gobblers currently owned by the user.
        uint32 totalGobblersOwned;
        // The sum of the multiples of all gobblers the user holds.
        uint32 totalEmissionMultiple;
        // User's goo balance at time of last checkpointing.
        uint128 totalVirtualBalance;
        // Timestamp of the last goo balance checkpoint.
        uint64 lastTimestamp;
    }
    GlobalData public globalData;

    // pool idx => gobblerId
    struct PoolMintedGobbler {
        uint256 gobblerId;
        bool claimed;
    }
    mapping(uint256 => PoolMintedGobbler) public poolMintedGobblers;
    uint256 public poolMintedGobblersIdx;
    uint256 public poolMintedToClaimNum;

    // Events

    event GooBalanceUpdated(address indexed user, uint256 newGooBalance);
    event MintPoolGobblers(uint256 indexed num, uint256 indexed gobblerId);
    event ClaimPoolGobblers(uint256[] indexed idxs);

    constructor(address admin_, address artGobblers_) Owned(admin_) {
        artGobblers = artGobblers_;
    }

    function depositGobblers(uint256[] calldata gobblerIds) external {
        // update user virtual balance of GOO
        updateGlobalBalance();
        updateUserGooBalance(msg.sender, 0, GooBalanceUpdateType.INCREASE);

        uint256 id;
        address holder;
        uint32 emissionMultiple;
        uint32 sumGobblersOwned;
        uint32 sumEmissionMultiple;

        for (uint256 i = 0; i < gobblerIds.length; ++i) {
            id = gobblerIds[i];
            (holder, , emissionMultiple) = IArtGobblers(artGobblers)
                .getGobblerData(id);
            require(holder == msg.sender, "WRONG_OWNER");
            require(emissionMultiple > 0, "GOBBLER_MUST_REVEALED");

            sumGobblersOwned += 1;
            sumEmissionMultiple += emissionMultiple;

            getUserByGobblerId[id] = msg.sender;

            IArtGobblers(artGobblers).transferFrom(
                msg.sender,
                address(this),
                id
            );
        }

        // update user data
        getUserData[msg.sender].gobblersOwned += sumGobblersOwned;
        getUserData[msg.sender].emissionMultiple += sumEmissionMultiple;

        // update global data
        globalData.totalGobblersOwned += sumGobblersOwned;
        globalData.totalEmissionMultiple += sumEmissionMultiple;
    }

    function withdrawGobblers(uint256[] calldata gobblerIds) external {
        // update user virtual balance of GOO
        updateGlobalBalance();
        updateUserGooBalance(msg.sender, 0, GooBalanceUpdateType.DECREASE);

        uint256 id;
        address holder;
        uint32 emissionMultiple;
        uint32 sumGobblersOwned;
        uint32 sumEmissionMultiple;

        for (uint256 i = 0; i < gobblerIds.length; ++i) {
            id = gobblerIds[i];
            (holder, , emissionMultiple) = IArtGobblers(artGobblers)
                .getGobblerData(id);
            require(getUserByGobblerId[id] == msg.sender, "WRONG_OWNER");

            sumGobblersOwned += 1;
            sumEmissionMultiple += emissionMultiple;

            delete getUserByGobblerId[id];

            IArtGobblers(artGobblers).transferFrom(
                address(this),
                msg.sender,
                id
            );
        }

        // update user data
        getUserData[msg.sender].gobblersOwned -= sumGobblersOwned;
        getUserData[msg.sender].emissionMultiple -= sumEmissionMultiple;

        // update global data
        globalData.totalGobblersOwned -= sumGobblersOwned;
        globalData.totalEmissionMultiple -= sumEmissionMultiple;
    }

    function mintPoolGobblers(uint256 maxPrice, uint256 num) external {
        uint256 gobblerId;
        for (uint256 i = 0; i < num; i++) {
            gobblerId = IArtGobblers(artGobblers).mintFromGoo(maxPrice, true);
            poolMintedGobblers[++poolMintedGobblersIdx].gobblerId = gobblerId;
        }
        poolMintedToClaimNum += num;
        emit MintPoolGobblers(num, gobblerId);
    }

    function claimPoolGobblers(uint256[] calldata idxs) external {
        updateGlobalBalance();
        updateUserGooBalance(msg.sender, 0, GooBalanceUpdateType.DECREASE);

        // check virtual balance enough

        // (user's virtual goo / global virtual goo) * total cliamable num - claimed num
        uint256 claimableNum = uint256(getUserData[msg.sender].virtualBalance)
            .divWadDown(globalData.totalVirtualBalance)
            .mulWadDown(poolMintedToClaimNum) -
            uint256(getUserData[msg.sender].claimedNum);

        uint256 claimNum = idxs.length;
        require(claimableNum >= claimNum, "CLAIM_TOO_MORE");

        // claim gobblers
        uint256 idx;
        for (uint256 i = 0; i < claimNum; i++) {
            idx = idxs[i];

            require(
                poolMintedGobblers[idx].claimed == false,
                "GOBBLER_CANT_CLAIM"
            );

            poolMintedGobblers[idx].claimed = true;
            uint256 gobblerId = poolMintedGobblers[idx].gobblerId;
            IArtGobblers(artGobblers).transferFrom(
                address(this),
                msg.sender,
                gobblerId
            );
        }

        getUserData[msg.sender].claimedNum += uint64(claimNum);

        emit ClaimPoolGobblers(idxs);
    }

    function updateGlobalBalance() public {
        uint256 updatedBalance = LibGOO.computeGOOBalance(
            globalData.totalEmissionMultiple,
            globalData.totalVirtualBalance,
            uint256(toDaysWadUnsafe(block.timestamp - globalData.lastTimestamp))
        );
        // update global balance
        globalData.totalVirtualBalance = uint128(updatedBalance);
        globalData.lastTimestamp = uint64(block.timestamp);
    }

    /// @notice Update a user's virtual goo balance.
    /// @param user The user whose virtual goo balance we should update.
    /// @param gooAmount The amount of goo to update the user's virtual balance by.
    /// @param updateType Whether to increase or decrease the user's balance by gooAmount.
    function updateUserGooBalance(
        address user,
        uint256 gooAmount,
        GooBalanceUpdateType updateType
    ) internal {
        // Will revert due to underflow if we're decreasing by more than the user's current balance.
        // Don't need to do checked addition in the increase case, but we do it anyway for convenience.
        uint256 updatedBalance = updateType == GooBalanceUpdateType.INCREASE
            ? gooBalance(user) + gooAmount
            : gooBalance(user) - gooAmount;

        // Snapshot the user's new goo balance with the current timestamp.
        getUserData[user].virtualBalance = uint128(updatedBalance);
        getUserData[user].lastTimestamp = uint64(block.timestamp);

        emit GooBalanceUpdated(user, updatedBalance);
    }

    /// @notice Calculate a user's virtual goo balance.
    /// @param user The user to query balance for.
    function gooBalance(address user) public view returns (uint256) {
        // Compute the user's virtual goo balance by leveraging LibGOO.
        // prettier-ignore
        return LibGOO.computeGOOBalance(
            getUserData[user].emissionMultiple,
            getUserData[user].virtualBalance,
            uint(toDaysWadUnsafe(block.timestamp - getUserData[user].lastTimestamp))
        );
    }
}
