// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";


contract ContractScript is Script {

    function setUp() public {
    }

    function run() public {
        vm.startBroadcast();
        
        vm.stopBroadcast();
    }
}
