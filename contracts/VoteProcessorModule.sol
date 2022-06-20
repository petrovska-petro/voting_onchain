// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "interfaces/gnosis/IGnosisSafe.sol";
import "interfaces/snapshot/IProposalRegistry.sol";

/// @title   VoteProcessorModule
/// @author  Petrovska @ BadgerDAO
/// @notice  Allows whitelisted proposers to vote on a proposal
/// and validators to approve it, then the tx can get exec signing the vote on-chain
// directly thru the safe, where this module had being enabled.
contract VoteProcessorModule is Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ========== STRUCT ========== */
    struct Vote {
        uint256 timestamp;
        string choices;
        string version;
        string space;
        string voteType;
        bytes hashed;
        bool approved;
        uint256 proposedTimestamp;
    }

    /* ========== ADDRESS CONSTANT, VERSION & ONCHAIN NAMING ========== */
    string public constant NAME = "Vote Processor Module";
    string public constant VERSION = "0.1.0";
    uint256 public constant MIN_WINDOW_VERIFICATION = 20 minutes;
    // https://etherscan.io/address/0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2#code#F17#L20
    address public constant SIGN_MESSAGE_LIB =
        0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2;

    IProposalRegistry public proposalRegistry;

    /* ========== STATE VARIABLES ========== */
    address public governance;

    mapping(string => Vote) public proposals;

    EnumerableSet.AddressSet internal _proposers;
    EnumerableSet.AddressSet internal _validators;

    /* ========== EVENT ========== */
    event VoteProposed(
        address indexed proposer,
        string indexed space,
        string indexed proposal,
        string choices,
        bytes hashed
    );
    event VoteApproved(
        address indexed approver,
        string indexed space,
        string indexed proposal
    );

    /// @param _governance Governance allowed to add/remove proposers & validators
    constructor(address _governance, address _proposalRegistry) {
        governance = _governance;
        proposalRegistry = IProposalRegistry(_proposalRegistry);
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

    function pause() external onlyGovernance {
        _pause();
    }

    function unpause() external onlyGovernance {
        _unpause();
    }

    function setGovernance(address _governance) external onlyGovernance {
        require(_governance != address(0), "zero-address!");
        governance = _governance;
    }

    /***************************************
       VOTE PROPOSAL, VALIDATION & EXEC
    ****************************************/

    /// @dev Allows to WL addresses propose a vote
    /// @param choices Choices selected
    /// @param timestamp Time when the voting proposal was generated
    /// @param version Snapshot version
    /// @param proposal Proposal hash
    /// @param space Space where voting occurs
    /// @param voteType Type of vote (single-choice, weighted)
    function setProposalVote(
        string memory choices,
        uint256 timestamp,
        string memory version,
        string memory proposal,
        string memory space,
        string memory voteType,
        bytes memory hashed
    ) external onlyVoteProposers {
        bytes32 proposalHash = keccak256(abi.encodePacked(proposal));
        IProposalRegistry.Proposal memory proposalInfo = proposalRegistry
            .proposalInfo(proposalHash);

        require(proposalInfo.deadline > block.timestamp, "deadline!");

        // NOTE: since there is concern of front-run, we add a back-stop
        require(
            block.timestamp >
                proposals[proposal].proposedTimestamp + MIN_WINDOW_VERIFICATION,
            "in-verification-window!"
        );

        Vote memory vote = Vote(
            timestamp,
            choices,
            version,
            space,
            voteType,
            hashed,
            false,
            block.timestamp
        );
        proposals[proposal] = vote;

        emit VoteProposed(msg.sender, space, proposal, choices, hashed);
    }

    /// @dev Allows to WL addresses to verify a vote to be exec
    /// @param proposal Proposal being approved
    function verifyVote(string memory proposal) external onlyVoteValidators {
        Vote storage vote = proposals[proposal];
        vote.approved = true;
        emit VoteApproved(msg.sender, vote.space, proposal);
    }

    /// @dev Triggers tx on-chain to sign a specific proposal. It will not be permissionless as needs to notify relayers
    /// @param safe Safe from where this tx will be exec and this module is enabled
    /// @param proposal Proposal being signed on the vote preference
    function sign(IGnosisSafe safe, string memory proposal)
        external
        whenNotPaused
    {
        require(proposals[proposal].approved, "not-approved!");

        bytes memory data = abi.encodeWithSignature(
            "signMessage(bytes)",
            proposals[proposal].hashed
        );

        require(
            safe.execTransactionFromModule(
                SIGN_MESSAGE_LIB,
                0,
                data,
                IGnosisSafe.Operation.DelegateCall
            ),
            "sign-error!"
        );
    }

    /***************************************
                VIEW METHODS
    ****************************************/
    function getProposers() public view returns (address[] memory) {
        return _proposers.values();
    }

    function getValidators() public view returns (address[] memory) {
        return _validators.values();
    }

    function getHash(string memory proposal)
        public
        view
        returns (bytes memory)
    {
        return proposals[proposal].hashed;
    }

    function getChoices(string memory proposal)
        public
        view
        returns (string memory)
    {
        return proposals[proposal].choices;
    }
}
