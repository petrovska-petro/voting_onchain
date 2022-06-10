import brownie
from brownie import web3


def test_gov_controls(
    vote_processor,
    proposal_registry,
    governance,
    proposer,
    validator,
    deployer,
    proposal_hash,
):
    vote_processor.addProposer(proposer, {"from": governance})
    vote_processor.addValidator(validator, {"from": governance})

    vote_processor.pause({"from": governance})
    vote_processor.unpause({"from": governance})

    with brownie.reverts("not-governance!"):
        vote_processor.addProposer(deployer, {"from": deployer})

    with brownie.reverts("not-governance!"):
        vote_processor.addValidator(deployer, {"from": deployer})

    with brownie.reverts("not-governance!"):
        vote_processor.removeProposer(proposer, {"from": deployer})

    with brownie.reverts("not-governance!"):
        vote_processor.removeValidator(validator, {"from": deployer})

    with brownie.reverts("not-governance!"):
        vote_processor.pause({"from": deployer})

    with brownie.reverts("not-governance!"):
        vote_processor.unpause({"from": deployer})

    with brownie.reverts("not-governance!"):
        proposal_registry.initiateProposal(
            bytes(web3.keccak(text=proposal_hash)), 1654810593, 2, 0, {"from": proposer}
        )


def test_proposer_controls(
    vote_processor, governance, validator, proposer, proposal_hash
):
    vote_processor.addProposer(proposer, {"from": governance})
    vote_processor.addValidator(validator, {"from": governance})

    with brownie.reverts("not-proposer!"):
        vote_processor.setProposalVote(
            2,
            1654551440,
            "0.1.3",
            proposal_hash,
            "cvx.eth",
            "vote",
            {"from": governance},
        )


def test_validator_controls(vote_processor, validator, proposal_hash):
    with brownie.reverts("not-validator!"):
        vote_processor.verifyVote(proposal_hash, {"from": validator})
