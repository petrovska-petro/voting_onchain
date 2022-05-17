import json
import time

from eth_account import messages
from brownie import VoterCVXProxy, accounts

"""
{
  "version": "0.1.3",
  "timestamp": "1652821387",
  "space": "cvx.eth",
  "type": "vote",
  "payload": {
    "proposal": "QmdcYCVSaGgmfQ8wkTzEZficEPJMNX7s4YqjbwfMa4ewjs",
    "choice": 2,
    "metadata": {}
  }
}
"""
# 0x85a5affe000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000206cdce1dd297d47ddfff07bb94d6eaa8827e60760c8675cbe06f48cd198754ef9
# 0x6cdce1dd297d47ddfff07bb94d6eaa8827e60760c8675cbe06f48cd198754ef9
def main(deployer_label=None):
    deployer = accounts.load(deployer_label)

    payload = {
        "version": "0.1.3",
        "timestamp": str(int(time.time())),
        "space": "cvx.eth",
        "type": "vote",
        "payload": {
            "proposal": "QmdcYCVSaGgmfQ8wkTzEZficEPJMNX7s4YqjbwfMa4ewjs",
            "choice": 2,
            "metadata": json.dumps({}),
        },
    }

    payload_stringify = json.dumps(payload, separators=(",", ":"))

    hash = messages.defunct_hash_message(text=payload_stringify)

    voter_proxy = VoterCVXProxy.at("0xAd78a13d5739FF09aa8375745832e9382F1F33c3")

    voter_proxy.vote(hash, True, {"from": deployer, "nonce": 89})
