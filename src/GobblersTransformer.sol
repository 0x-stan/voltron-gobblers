// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IArtGobblers} from "src/utils/IArtGobblers.sol";

contract GobblersTransformer is Owned {
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

    uint32 totalEmissionMultiple;

    constructor(address admin_, address artGobblers_) Owned(admin_) {
        artGobblers = artGobblers_;
    }

    function depositGobblers(uint256[] calldata gobblerIds)
        external
    {
        uint256 id;
        address holder;
        uint32 emissionMultiple;
        UserData memory userData = getUserData[msg.sender];
        for (uint256 i = 0; i < gobblerIds.length; ++i) {
            id = gobblerIds[i];
            (holder, , emissionMultiple) = IArtGobblers(artGobblers).getGobblerData(id);
            require(holder == msg.sender, "WRONG_OWNER");

            userData.emissionMultiple += emissionMultiple;
        }
    }
}
