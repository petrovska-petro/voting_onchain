// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IVotiumBribe {
    struct Proposal {
        uint256 deadline;
        uint256 maxIndex;
    }
    /// bytes32 of snapshot IPFS hash id for a given proposal
    function proposalInfo(bytes32 proposalHash)
        external
        returns (Proposal memory ProposalInfo);
}
