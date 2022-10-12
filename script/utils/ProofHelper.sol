// SPDX-Lisence-Identifier: MIT
pragma solidity >= 0.8.15;

import "forge-std/Vm.sol";

library ProofHelper {
    address private constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    Vm public constant vm = Vm(VM_ADDRESS);

    string constant WHITE_LIST_PATH = "./whitelist.txt";
    string constant MERKLE_PROOFS_PATH = "./merkleproofs.json";

    function calcProofLen(uint256 len) internal returns (uint256) {
        // calc the number of  merkle tree levels
        uint256 level = 0;
        uint256 nodesNum = len;
        for (uint256 i = 0; i < 255; i++) {
            nodesNum = nodesNum / 2 + nodesNum % 2;
            level++;
            if (nodesNum == 1) break;
        }
        return level;
    }

    function readWhitelist() internal returns (uint256 len, address[] memory whitelist) {
        for (uint256 i = 0; i < 1000; i++) {
            string memory raw = vm.readLine(WHITE_LIST_PATH);
            if (bytes(raw).length == 0) {
                len = i;
                break;
            }
        }
        vm.closeFile(WHITE_LIST_PATH);

        whitelist = new address[](len);
        for (uint256 j = 0; j < len; j++) {
            string memory raw = vm.readLine(WHITE_LIST_PATH);
            whitelist[j] = vm.parseAddress(raw);
        }
    }

    function readRoot() internal returns (bytes32 root) {
        string[] memory cmds = new string[](4);
        cmds[0] = "jq";
        cmds[1] = string.concat(".root");
        cmds[2] = MERKLE_PROOFS_PATH;
        cmds[3] = "-r";
        root = bytes32(vm.ffi(cmds));
    }

    function readProofs(address addr, uint256 len) internal returns (bytes32[] memory proof) {
        proof = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            proof[i] = rawProof(addr, i);
            // console.log("load proof of", addr, ": ", vm.toString(proof[i]));
        }
    }

    function rawProof(address addr, uint256 index) internal returns (bytes32 result) {
        string[] memory cmds = new string[](4);
        cmds[0] = "jq";
        cmds[1] = string.concat(".\"", vm.toString(addr), "\"[", vm.toString(index), "]");
        cmds[2] = "./merkleproofs.json";
        cmds[3] = "-r";
        result = bytes32(vm.ffi(cmds));
    }
}
