from brownie import web3
import requests
import json
import time


SNAPSHOT_VOTE_RELAYER = "https://snapshot-relayer.herokuapp.com/api/message"

SNAPSHOT_DEFAULT_HEADERS = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Referer": "https://snapshot.org/",
}


def test_vote_flow(vote_processor, proposal_registry, governance, validator, proposer, safe, proposal_hash):
    vote_processor.addProposer(proposer, {'from': governance})
    vote_processor.addValidator(validator, {'from': governance})

    proposal_registry.initiateProposal(
        bytes(web3.keccak(text=proposal_hash)),
        1655164829,
        2,
        0,
        {'from': governance}
        )

    vote_processor.setProposalVote(
        2,
        1654732831,
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


    payload = {
        "version": "0.1.3",
        "timestamp": 1654732831,
        "space": "cvx.eth",
        "type": 1,
        "payload": {
            "proposal": proposal_hash,
            "choice": 2,
            "metadata": json.dumps({}),
        },
    }

    payload_stringify = json.dumps(payload, separators=(",", ":"))

    response = requests.post(
        SNAPSHOT_VOTE_RELAYER,
        headers=SNAPSHOT_DEFAULT_HEADERS,
        data=json.dumps(
            {
                "address": safe.address,
                "msg": payload_stringify,
                "sig": "0x",
            },
            separators=(",", ":"),
        ),
    )

    assert response.ok
    response_id = response.text

    assert str(vote_processor.hash(proposal_hash)) in response_id

    vote_processor.sign(safe.address, proposal_hash, {'from': safe})
