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
        uint128 lastBalance;
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
        uint128 totalBalance;
        // Timestamp of the last goo balance checkpoint.
        uint64 lastTimestamp;
    }
    GlobalData public globalData;



    // Events

    event GooBalanceUpdated(address indexed user, uint256 newGooBalance);


    constructor(address admin_, address artGobblers_) Owned(admin_) {
        artGobblers = artGobblers_;
    }

    function depositGobblers(uint256[] calldata gobblerIds)
        external
    {
        // update user virtual balance of GOO
        updateUserGooBalance(msg.sender, 0, GooBalanceUpdateType.INCREASE);

        uint256 id;
        address holder;
        uint32 emissionMultiple;
        uint32 sumGobblersOwned;
        uint32 sumEmissionMultiple;
        
        for (uint256 i = 0; i < gobblerIds.length; ++i) {
            id = gobblerIds[i];
            (holder, , emissionMultiple) = IArtGobblers(artGobblers).getGobblerData(id);
            require(holder == msg.sender, "WRONG_OWNER");

            sumGobblersOwned += 1;
            sumEmissionMultiple += emissionMultiple;

            getUserByGobblerId[id] = msg.sender;

            IArtGobblers(artGobblers).transferFrom(msg.sender, address(this), id);
        }

        // update user data
        getUserData[msg.sender].gobblersOwned += sumGobblersOwned;
        getUserData[msg.sender].emissionMultiple += sumEmissionMultiple;

        // update global data
        globalData.totalGobblersOwned += sumGobblersOwned;
        globalData.totalEmissionMultiple += sumEmissionMultiple;
        updateGlobalBalance();

    }

    function withdrawGobblers(uint256[] calldata gobblerIds)
        external
    {
        // update user virtual balance of GOO
        updateUserGooBalance(msg.sender, 0, GooBalanceUpdateType.DECREASE);

        uint256 id;
        address holder;
        uint32 emissionMultiple;
        uint32 sumGobblersOwned;
        uint32 sumEmissionMultiple;
        
        for (uint256 i = 0; i < gobblerIds.length; ++i) {
            id = gobblerIds[i];
            (holder, , emissionMultiple) = IArtGobblers(artGobblers).getGobblerData(id);
            require(getUserByGobblerId[id] == msg.sender, "WRONG_OWNER");

            sumGobblersOwned += 1;
            sumEmissionMultiple += emissionMultiple;

            delete getUserByGobblerId[id];

            IArtGobblers(artGobblers).transferFrom(address(this), msg.sender, id);
        }
        
        // update user data
        getUserData[msg.sender].gobblersOwned -= sumGobblersOwned;
        getUserData[msg.sender].emissionMultiple -= sumEmissionMultiple;

        // update global data
        globalData.totalGobblersOwned -= sumGobblersOwned;
        globalData.totalEmissionMultiple -= sumEmissionMultiple;
        updateGlobalBalance();
    }

    function mintGobblersFromPool(uint256 maxPrice) external returns (uint256 gobblerId){
        gobblerId = IArtGobblers(artGobblers).mintFromGoo(maxPrice, true);

    }

    function updateGlobalBalance() public {
        // update global balance
        globalData.totalBalance = uint128(gooBalance(address(this)));
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
        getUserData[user].lastBalance = uint128(updatedBalance);
        getUserData[user].lastTimestamp = uint64(block.timestamp);

        emit GooBalanceUpdated(user, updatedBalance);

        // update global balance
        updatedBalance = updateType == GooBalanceUpdateType.INCREASE
            ? gooBalance(address(this)) + gooAmount
            : gooBalance(address(this)) - gooAmount;

        globalData.totalBalance = uint128(updatedBalance);
        globalData.lastTimestamp = uint64(block.timestamp);
    }

    /// @notice Calculate a user's virtual goo balance.
    /// @param user The user to query balance for.
    function gooBalance(address user) public view returns (uint256) {
        // Compute the user's virtual goo balance by leveraging LibGOO.
        // prettier-ignore
        return LibGOO.computeGOOBalance(
            getUserData[user].emissionMultiple,
            getUserData[user].lastBalance,
            uint(toDaysWadUnsafe(block.timestamp - getUserData[user].lastTimestamp))
        );
    }
}
