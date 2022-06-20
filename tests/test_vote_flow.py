from brownie import web3, chain
import requests
import json
import brownie
import pytest
from eth_account import messages


SNAPSHOT_VOTE_RELAYER = "https://snapshot-relayer.herokuapp.com/api/message"

SNAPSHOT_DEFAULT_HEADERS = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Referer": "https://snapshot.org/",
}


@pytest.fixture(scope="function", autouse=True)
def test_vote_flow(
    vote_processor,
    proposal_registry,
    governance,
    validator,
    proposer,
    safe,
    proposal_hash,
    proposal_hash_weighted,
    weighted_choices,
):
    vote_processor.addProposer(proposer, {"from": governance})
    vote_processor.addValidator(validator, {"from": governance})

    # test single-type vote type
    proposal_registry.initiateProposal(
        bytes(web3.keccak(text=proposal_hash)), 1665849155, 2, 0, {"from": governance}
    )

    payload = {
        "version": "0.1.3",
        "timestamp": str(1656633600),
        "space": "cvx.eth",
        "type": "single-type",
        "payload": {
            "proposal": proposal_hash,
            "choice": 2,
            "metadata": json.dumps({}),
        },
    }

    payload_stringify = json.dumps(payload, separators=(",", ":"))

    hash = messages.defunct_hash_message(text=payload_stringify)

    vote_processor.setProposalVote(
        "2",
        1656633600,
        "0.1.3",
        proposal_hash,
        "cvx.eth",
        "single-type",
        hash,
        {"from": proposer},
    )

    assert not vote_processor.proposals(proposal_hash)["approved"]

    vote_processor.verifyVote(proposal_hash, {"from": validator})
    assert vote_processor.proposals(proposal_hash)["approved"]

    safe.enableModule(vote_processor.address, {"from": safe})
    assert safe.isModuleEnabled(vote_processor.address)

    # verifiers will need this info to replicate hash and confirm
    print("getChoices()", vote_processor.getChoices(proposal_hash))

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

    assert str(vote_processor.getHash(proposal_hash)) in response_id

    vote_processor.sign(safe.address, proposal_hash, {"from": safe})

    # test weighted vote type
    payload = {
        "version": "0.1.3",
        "timestamp": str(1656633600),
        "space": "cvx.eth",
        "type": "weighted",
        "payload": {
            "proposal": proposal_hash_weighted,
            "choice": json.dumps(weighted_choices, separators=(",", ":")),
            "metadata": json.dumps({}),
        },
    }

    payload_stringify = json.dumps(payload, separators=(",", ":"))

    hash = messages.defunct_hash_message(text=payload_stringify)

    proposal_registry.initiateProposal(
        bytes(web3.keccak(text=proposal_hash_weighted)),
        1665849155,
        2,
        0,
        {"from": governance},
    )

    vote_processor.setProposalVote(
        json.dumps(weighted_choices, separators=(",", ":")),
        1656633600,
        "0.1.3",
        proposal_hash_weighted,
        "cvx.eth",
        "weighted",
        hash,
        {"from": proposer},
    )

    assert not vote_processor.proposals(proposal_hash_weighted)["approved"]

    vote_processor.verifyVote(proposal_hash_weighted, {"from": validator})
    assert vote_processor.proposals(proposal_hash_weighted)["approved"]

    # verifiers will need this info to replicate hash and confirm
    print("getChoices()", vote_processor.getChoices(proposal_hash_weighted))

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

    assert str(vote_processor.getHash(proposal_hash_weighted)) in response_id

    vote_processor.sign(safe.address, proposal_hash, {"from": safe})


def test_set_vote_frontrun(
    vote_processor,
    proposer,
    proposal_hash,
):
    chain.sleep(60 * 19)  # 20 min window

    with brownie.reverts("in-verification-window!"):
        vote_processor.setProposalVote(
            1,
            1656633600,
            "0.1.3",
            proposal_hash,
            "cvx.eth",
            "single-type",
            bytes(),
            {"from": proposer},
        )
