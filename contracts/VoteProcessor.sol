// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract VoteProcessor {
    struct Vote {
        uint256 timestamp;
        uint256 choice;
        string version;
        string space;
        string voteType;
    }

    mapping(string => Vote) public proposals;

    // # save them for on-chain checkups
    function setProposal(
        uint256 choice,
        uint256 timestamp,
        string memory version,
        string memory proposal,
        string memory space,
        string memory voteType
    ) external {
        Vote memory vote = Vote(timestamp, choice, version, space, voteType);
        proposals[proposal] = vote;
    }
    // # hash them in contract

    // #
}
