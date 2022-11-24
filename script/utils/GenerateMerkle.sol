// SPDX-Lisence-Identifier: MIT
pragma solidity >= 0.8.15;

import "forge-std/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ProofHelper } from "./ProofHelper.sol";

contract GenerateMerkle is Script {
    Merkle merkleTree;

    mapping(address => bytes32[]) proofs;

    function setUp() public {
        merkleTree = new Merkle();
    }

    function run() public {
        (uint256 len, address[] memory whitelist) = ProofHelper.readWhitelist();

        string memory path = string.concat("./merkleproofs.json");
        string memory data = "{";

        bytes32 root = createMerkleProofs(whitelist);

        data = string.concat(data, "\"root\":\"", vm.toString(root), "\",");

        for (uint256 i = 0; i < whitelist.length; i++) {
            data = string.concat(data, "\"", vm.toString(address(whitelist[i])), "\":[");
            bytes32[] memory _proof = proofs[whitelist[i]];
            for (uint256 j = 0; j < _proof.length; j++) {
                data = string.concat(data, "\"", vm.toString(_proof[j]), "\"");
                if (j < _proof.length - 1) data = string.concat(data, ",");
            }
            data = string.concat(data, "]");
            if (i < whitelist.length - 1) data = string.concat(data, ",");
        }
        data = string.concat(data, "}");
        vm.writeFile(path, data);

        uint256 proofLen = ProofHelper.calcProofLen(whitelist.length);
        bytes32[] memory proof = ProofHelper.readProofs(whitelist[0], proofLen);
        bool verified = merkleTree.verifyProof(root, proof, keccak256(abi.encodePacked(whitelist[0])));
        console.log("verified:", verified);
    }

    function createMerkleProofs(address[] memory addrs) internal returns (bytes32 root) {
        uint256 len = addrs.length;
        bytes32[] memory data = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            data[i] = keccak256(abi.encodePacked(addrs[i]));
        }
        root = merkleTree.getRoot(data);
        // get proof
        for (uint256 i = 0; i < len; i++) {
            bytes32[] memory proof = merkleTree.getProof(data, i);
            proofs[addrs[i]] = proof;
        }
    }
}
