from brownie import web3


def test_proposer_controls(vote_processor, proposal_registry, governance, validator, proposer, safe, proposal_hash):
    vote_processor.addProposer(proposer, {'from': governance})
    vote_processor.addValidator(validator, {'from': governance})

    proposal_registry.initiateProposal(
        bytes(web3.keccak(text=proposal_hash)),
        1654810593,
        2,
        0,
        {'from': governance}
        )

    vote_processor.setProposalVote(
        2,
        1654551440,
        '0.1.3',
        proposal_hash,
        'cvx.eth',
        'vote',
        {'from': proposer}
    )

    assert not vote_processor.proposals(proposal_hash)['approved']

    vote_processor.addValidator(validator, {'from': governance})
    vote_processor.verifyVote(proposal_hash, {'from': validator})
    assert vote_processor.proposals(proposal_hash)['approved']

    safe.enableModule(vote_processor.address, {'from': safe})
    assert safe.isModuleEnabled(vote_processor.address)

    vote_processor.sign(safe.address, proposal_hash, {'from': safe})
