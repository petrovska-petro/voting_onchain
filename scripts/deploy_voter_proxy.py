from brownie import VoterCVXProxy, accounts


def main(deployer_label=None):
    deployer = accounts.load(deployer_label)

    voter_proxy = VoterCVXProxy.deploy(
        deployer.address, {"from": deployer}, publish_source=True
    )
