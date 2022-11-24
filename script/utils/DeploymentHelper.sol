// SPDX-Lisence-Identifier: MIT
pragma solidity >= 0.8.15;

import "forge-std/Vm.sol";
import "forge-std/console.sol";

library DeploymentHelper {
    address private constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    Vm public constant vm = Vm(VM_ADDRESS);

    function loadDeployAddress(string memory key) internal returns (address addr) {
        string memory network = "goerli";
        if (block.chainid == 1) network = "mainnet";
        string[] memory cmds = new string[](4);
        cmds[0] = "jq";
        cmds[1] = key;
        cmds[2] = string.concat("./deployment.", network, ".json");
        cmds[3] = "-r";
        bytes memory result = vm.ffi(cmds);
        addr = address(bytes20(result));
        // console.log("loadDeployAddress", key, addr);
    }
}
