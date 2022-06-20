import pytest
from brownie import interface, VoteProcessorModule, ProposalRegistry


@pytest.fixture
def deployer(accounts):
    return accounts[0]


@pytest.fixture
def governance(accounts):
    return accounts[1]


@pytest.fixture
def proposer(accounts):
    return accounts[2]


@pytest.fixture
def validator(accounts):
    return accounts[3]


@pytest.fixture
def safe():
    return interface.IGnosisSafe("0xb86f6c9e3158cC4C540219244b80722d6bd9B033")


@pytest.fixture
def proposal_registry(deployer, governance):
    return ProposalRegistry.deploy(governance, {"from": deployer})


@pytest.fixture
def vote_processor(deployer, governance, proposal_registry):
    return VoteProcessorModule.deploy(
        governance, proposal_registry.address, {"from": deployer}
    )


@pytest.fixture
def proposal_hash():
    return "QmeKWbpinBwRSiLg7MbfycipUUE935faELRMYgdX2syWQV"


@pytest.fixture
def proposal_hash_weighted():
    return "QmdcYCVSaGgmfQ8wkTzEZficEPJMNX7s4YqjbwfMa4ewjs"


@pytest.fixture
def weighted_choices():
    return {
        "34": 25.02272641297546593397216281,
        "26": 12.52272641297546524008277281,
        "83": 5.722726412975464862606944521,
        "88": 19.42272641297546562310971609,
        "53": 24.92272641297546592842104769,
        "70": 12.38636793512267241180735594,
    }
