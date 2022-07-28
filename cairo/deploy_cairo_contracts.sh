set -e
starknet deploy --network=alpha-goerli --contract ./artifacts/compiled/NFTLendingController.json --no_wallet
