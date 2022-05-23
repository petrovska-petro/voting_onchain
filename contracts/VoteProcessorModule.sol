// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "interfaces/Votium/IVotiumBribe.sol";
import "interfaces/Gnosis/IGnosisSafe.sol";

/*
 * @title   VoteProcessorModule
 * @author  BadgerDAO @ petrovska
 * @notice  Allows whitelisted proposers to vote on a proposal 
 * and validators to approve it, then the tx can get exec signing the vote on-chain
 directly thru the safe, where this module had being enabled.
 Hashing vote on-chain methods were taken from Aura finance repository @contracts/mocks/MockVoteStorage.sol
 */
contract VoteProcessorModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ========== STRUCT ========== */
    struct Vote {
        uint256 timestamp;
        uint256 choice;
        string version;
        string space;
        string voteType;
        bool approved;
    }

    /* ========== ADDRESS CONSTANT, VERSION & ONCHAIN NAMING ========== */
    string public constant NAME = "Vote Processor Module";
    string public constant VERSION = "0.1.0";
    // https://etherscan.io/address/0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2#code#F17#L20
    address public constant signMessageLib =
        0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2;
    // may be useful to enforce deadline from the bribes on-chain
    // https://etherscan.io/address/0x19bbc3463dd8d07f55438014b021fb457ebd4595#code#F7#L26
    IVotiumBribe public votiumBribe =
        IVotiumBribe(0x19BBC3463Dd8d07f55438014b021Fb457EBD4595);

    /* ========== STATE VARIABLES ========== */
    address public governance;

    mapping(string => Vote) public proposals;

    EnumerableSet.AddressSet internal _proposers;
    EnumerableSet.AddressSet internal _validators;

    /* ========== EVENT ========== */
    event VoteApproved(address approver, string proposal);

    /// @param _governance Governance allowed to add/remove proposers & validators
    constructor(address _governance) {
        governance = _governance;
    }

    /***************************************
                    MODIFIERS
    ****************************************/
    modifier onlyVoteProposers() {
        require(_proposers.contains(msg.sender), "not-proposer!");
        _;
    }

    modifier onlyVoteValidators() {
        require(_validators.contains(msg.sender), "not-validator!");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "not-governance!");
        _;
    }

    /***************************************
               ADMIN - GOVERNANCE
    ****************************************/

    function addProposer(address _proposer) external onlyGovernance {
        require(_proposer != address(0), "zero-address!");
        _proposers.add(_proposer);
    }

    function removeProposer(address _proposer) external onlyGovernance {
        require(_proposer != address(0), "zero-address!");
        _proposers.remove(_proposer);
    }

    function addValidator(address _validator) external onlyGovernance {
        require(_validator != address(0), "zero-address!");
        _validators.add(_validator);
    }

    function removeValidator(address _validator) external onlyGovernance {
        require(_validator != address(0), "zero-address!");
        _validators.remove(_validator);
    }

    /***************************************
       VOTE PROPOSAL, VALIDATION & EXEC
    ****************************************/

    /// @dev Allows to WL addresses propose a vote
    /// @param choice Choices selected
    /// @param timestamp Time when the voting proposal was generated
    /// @param version Snapshot version
    /// @param proposal Proposal hash
    /// @param space Space where voting occurs
    /// @param voteType Type of vote (single-choice...etc)
    function setProposalVote(
        uint256 choice,
        uint256 timestamp,
        string memory version,
        string memory proposal,
        string memory space,
        string memory voteType
    ) external onlyVoteProposers {
        //IVotiumBribe.Proposal memory proposalInfo = votiumBribe.proposalInfo(proposal);
        //require(proposalInfo.deadline > block.timestamp, "invalid proposal");
        Vote memory vote = Vote(
            timestamp,
            choice,
            version,
            space,
            voteType,
            false
        );
        proposals[proposal] = vote;
    }

    /// @dev Allows to WL addresses to verify a vote to be exec
    /// @param proposal Proposal being approved
    function verifyVote(string memory proposal) external onlyVoteValidators {
        Vote storage vote = proposals[proposal];
        vote.approved = true;
        emit VoteApproved(msg.sender, proposal);
    }

    /// @dev Triggers tx on-chain to sign a specific proposal
    /// @param safe Safe from where this tx will be exec and this module is enabled
    /// @param proposal Proposal being signed on the vote preference
    function sign(IGnosisSafe safe, string memory proposal) external {
        require(proposals[proposal].approved, "not-approved!");

        bytes memory data = abi.encodeWithSignature(
            "signMessage(bytes32)",
            hash(proposal)
        );

        require(
            safe.execTransactionFromModule(
                signMessageLib,
                0,
                data,
                IGnosisSafe.Operation.Call
            ),
            "sign-error!"
        );
    }

    /***************************************
       HASH GENERATION ON-CHAIN FOR SIGNING
    ****************************************/

    function hash(string memory proposal) public view returns (bytes32) {
        Vote memory vote = proposals[proposal];

        return
            hashStr(
                string(
                    abi.encodePacked(
                        "{",
                        '"version":"',
                        vote.version,
                        '",',
                        '"timestamp":"',
                        uint2str(vote.timestamp),
                        '",',
                        '"space":"',
                        vote.space,
                        '",',
                        '"type":"',
                        vote.voteType,
                        '",',
                        payloadStr(proposal, vote.choice),
                        "}"
                    )
                )
            );
    }

    function payloadStr(string memory proposal, uint256 choice)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    '"payload":',
                    "{",
                    '"proposal":',
                    '"',
                    proposal,
                    '",',
                    '"choice":',
                    uint2str(choice),
                    ","
                    '"metadata":',
                    '"{}"',
                    "}"
                )
            );
    }

    function hashStr(string memory str) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n",
                    uint2str(bytes(str).length),
                    str
                )
            );
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
